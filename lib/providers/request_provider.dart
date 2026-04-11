/// Request provider - manages blood request state and operations
/// Now includes smart donor routing with nearest-first targeting & timeout escalation
library;

import 'package:flutter/material.dart';
import '../core/services/firestore_service.dart';
import '../core/services/matching_engine.dart';
import '../core/services/notification_service.dart';
import '../core/services/ambulance_service.dart';
import '../core/services/smart_donor_routing_service.dart';
import '../models/blood_request_model.dart';
import '../models/user_model.dart';
import '../core/services/sms_service.dart';

class RequestProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();
  final SmartDonorRoutingService _routingService = SmartDonorRoutingService();

  final List<BloodRequestModel> _requests = [];
  List<DonorMatch> _currentMatches = [];
  bool _isLoading = false;
  String? _error;

  // Track last ambulance assignment for navigation
  AmbulanceAssignment? _lastAmbulanceAssignment;
  String? _lastAcceptedRequestId;

  // Track last targeted donor result from smart routing
  DonorTargetResult? _lastTargetResult;

  List<BloodRequestModel> get requests => _requests;
  List<DonorMatch> get currentMatches => _currentMatches;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AmbulanceAssignment? get lastAmbulanceAssignment => _lastAmbulanceAssignment;
  String? get lastAcceptedRequestId => _lastAcceptedRequestId;
  DonorTargetResult? get lastTargetResult => _lastTargetResult;
  SmartDonorRoutingService get routingService => _routingService;

  /// Active requests count
  int get activeRequestCount => _requests.where((r) => r.isActive).length;

  /// SOS requests count
  int get sosRequestCount => _requests.where((r) => r.isSOS && r.isActive).length;

  /// Create a new blood request
  Future<String?> createRequest({
    required String hospitalId,
    required String hospitalName,
    required String bloodGroup,
    required int units,
    required String urgency,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    _setLoading(true);
    try {
      final request = BloodRequestModel(
        id: '',
        hospitalId: hospitalId,
        hospitalName: hospitalName,
        bloodGroup: bloodGroup,
        units: units,
        urgency: urgency,
        latitude: latitude,
        longitude: longitude,
        notes: notes,
      );

      final requestId = await _firestoreService.createBloodRequest(request);

      // ─── SMART DONOR ROUTING ───
      // Instead of broadcasting to ALL donors, find the NEAREST compatible donor
      // and send a targeted notification. Start a 5-min escalation timer.
      final channelId = urgency == 'SOS' ? 'sos_channel' : 'request_channel';

      final targetResult = await _routingService.findAndTargetNearestDonor(
        requestId: requestId,
        request: BloodRequestModel(
          id: requestId,
          hospitalId: hospitalId,
          hospitalName: hospitalName,
          bloodGroup: bloodGroup,
          units: units,
          urgency: urgency,
          latitude: latitude,
          longitude: longitude,
          notes: notes,
        ),
        startEscalationTimer: true,
      );

      _lastTargetResult = targetResult;

      if (targetResult != null) {
        // Notify hospital about the targeted donor
        await _notificationService.showNotification(
          title: urgency == 'SOS' ? '🆘 SOS Request Created' : '🩸 Request Created',
          body: 'Nearest donor: ${targetResult.donorName} • ${targetResult.formattedDistance} away • Waiting for response...',
          channelId: channelId,
        );

        debugPrint('>>> Smart Routing: Targeted ${targetResult.donorName} at ${targetResult.formattedDistance}');

        // Listen for acceptance to cancel escalation timer
        _routingService.listenForAcceptance(requestId);
      } else {
        // No nearby donor found — fallback to topic broadcast
        await _notificationService.showNotification(
          title: urgency == 'SOS' ? '🆘 Request Broadcasted' : '🩸 Request Broadcasted',
          body: 'No nearby donors found. Broadcasting to all $bloodGroup donors.',
          channelId: channelId,
        );

        final safeGroup = bloodGroup.replaceAll('+', '_pos').replaceAll('-', '_neg');
        await _notificationService.sendTopicNotification(
          topic: 'blood_$safeGroup',
          title: urgency == 'SOS'
              ? '🆘 URGENT: $bloodGroup Needed at $hospitalName!'
              : '🩸 Alert: $bloodGroup Requested at $hospitalName',
          body: 'Urgency: $urgency • $units unit(s) required. Tap to respond immediately and save a life!',
          urgency: urgency,
        );
      }

      // For SOS: also broadcast to ALL + send SMS backup
      if (urgency == 'SOS') {
        final safeGroup = bloodGroup.replaceAll('+', '_pos').replaceAll('-', '_neg');
        await _notificationService.sendTopicNotification(
          topic: 'blood_$safeGroup',
          title: '🆘 URGENT: $bloodGroup Needed at $hospitalName!',
          body: 'SOS Emergency • $units unit(s) required. Respond immediately!',
          urgency: urgency,
        );

        await SmsService.sendSOSAlert(
          hospitalName: hospitalName,
          bloodGroup: bloodGroup,
          patientCondition: notes ?? 'Critical Emergency',
          toPhoneNumbers: ['+1234567890', '+0987654321'],
        );
      }

      _setLoading(false);
      notifyListeners();
      return requestId;
    } catch (e) {
      _error = 'Failed to create request: $e';
      _setLoading(false);
      return null;
    }
  }

  /// Find matching donors for a request
  void findMatches(BloodRequestModel request, List<UserModel> donors) {
    _currentMatches = MatchingEngine.findMatches(
      request: request,
      donors: donors,
    );
    notifyListeners();
  }

  /// Accept a request (donor) — also auto-dispatches nearest ambulance
  Future<bool> acceptRequest(
    String requestId,
    String donorId,
    String donorName, {
    double? donorLat,
    double? donorLng,
  }) async {
    _setLoading(true);
    try {
      // 1. Assign donor to request
      await _firestoreService.assignDonor(requestId, donorId, donorName);

      // 2. Cancel smart routing escalation (donor has responded)
      _routingService.cancelEscalation(requestId);

      // 2. Notify about acceptance
      await _notificationService.showNotification(
        title: '✅ Request Accepted',
        body: '$donorName has accepted the blood request',
        channelId: 'request_channel',
      );

      // 3. Update donor location in Firestore for ambulance tracking
      if (donorLat != null && donorLng != null && donorLat != 0 && donorLng != 0) {
        await _firestoreService.updateUserLocation(donorId, donorLat, donorLng);
      }

      // 4. Auto-dispatch nearest ambulance
      _lastAcceptedRequestId = requestId;
      _lastAmbulanceAssignment = null;

      try {
        // Get the request details to find hospital location
        final reqDoc = await _firestoreService.getRequest(requestId);
        if (reqDoc != null) {
          final assignment = await SmartAmbulanceService.autoAssign(
            requestLat: donorLat ?? 0,
            requestLng: donorLng ?? 0,
            hospitalLat: reqDoc.latitude,
            hospitalLng: reqDoc.longitude,
            urgency: reqDoc.urgency,
          );

          if (assignment != null) {
            // Assign ambulance to the request
            await _firestoreService.assignAmbulance(assignment.ambulanceId, requestId);
            _lastAmbulanceAssignment = assignment;

            // Notify about ambulance dispatch
            await _notificationService.showNotification(
              title: '🚑 Ambulance Dispatched!',
              body: 'ETA: ${assignment.etaMinutes} min • ${assignment.distanceKm} km away',
              channelId: 'request_channel',
            );

            debugPrint('>>> Ambulance dispatched: ${assignment.ambulanceId} | ETA: ${assignment.etaMinutes}min');
          }
        }
      } catch (e) {
        debugPrint('Ambulance auto-dispatch error (non-critical): $e');
        // Don't fail the acceptance if ambulance dispatch fails
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Failed to accept request: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Reject a request (donor) — immediately escalates to next nearest donor
  Future<bool> rejectRequest(String requestId, String donorId) async {
    try {
      await _firestoreService.addRejectedDonor(requestId, donorId);

      // Cancel current escalation timer for this request
      _routingService.cancelEscalation(requestId);

      // Immediately find and target the next nearest donor
      final updatedRequest = await _firestoreService.getRequest(requestId);
      if (updatedRequest != null && updatedRequest.status == 'pending') {
        // Clear current target
        await _firestoreService.updateRequestTargetDonor(requestId, null, null, null);

        // Re-run smart routing to find next donor
        final nextTarget = await _routingService.findAndTargetNearestDonor(
          requestId: requestId,
          request: updatedRequest,
          startEscalationTimer: true,
        );

        if (nextTarget != null) {
          debugPrint('>>> Reject escalation: Now targeting ${nextTarget.donorName} at ${nextTarget.formattedDistance}');
          _lastTargetResult = nextTarget;
          _routingService.listenForAcceptance(requestId);
        } else {
          debugPrint('>>> Reject escalation: No more donors available');
        }

        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Failed to reject request';
      return false;
    }
  }

  /// Update request status
  Future<void> updateStatus(String requestId, String status) async {
    try {
      await _firestoreService.updateRequestStatus(requestId, status);

      // Cancel smart routing if request is no longer active
      if (status == 'completed' || status == 'cancelled') {
        _routingService.cancelEscalation(requestId);

        try {
          final req = await _firestoreService.getRequest(requestId);
          if (req?.assignedAmbulanceId != null) {
            await _firestoreService.releaseAmbulance(req!.assignedAmbulanceId!);
          }
        } catch (e) {
          debugPrint('Release ambulance error: $e');
        }
      }
    } catch (e) {
      _error = 'Failed to update status: $e';
      notifyListeners();
    }
  }

  /// Assign ambulance manually
  Future<void> assignAmbulance(String ambulanceId, String requestId) async {
    try {
      await _firestoreService.assignAmbulance(ambulanceId, requestId);
    } catch (e) {
      _error = 'Failed to assign ambulance: $e';
      notifyListeners();
    }
  }

  void clearLastAssignment() {
    _lastAmbulanceAssignment = null;
    _lastAcceptedRequestId = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

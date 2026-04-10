/// Request provider - manages blood request state and operations
/// Now includes automatic ambulance dispatch when donor accepts
library;

import 'package:flutter/material.dart';
import '../core/services/firestore_service.dart';
import '../core/services/matching_engine.dart';
import '../core/services/notification_service.dart';
import '../core/services/ambulance_service.dart';
import '../models/blood_request_model.dart';
import '../models/user_model.dart';
import '../core/services/sms_service.dart';

class RequestProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  final List<BloodRequestModel> _requests = [];
  List<DonorMatch> _currentMatches = [];
  bool _isLoading = false;
  String? _error;

  // Track last ambulance assignment for navigation
  AmbulanceAssignment? _lastAmbulanceAssignment;
  String? _lastAcceptedRequestId;

  List<BloodRequestModel> get requests => _requests;
  List<DonorMatch> get currentMatches => _currentMatches;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AmbulanceAssignment? get lastAmbulanceAssignment => _lastAmbulanceAssignment;
  String? get lastAcceptedRequestId => _lastAcceptedRequestId;

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

      // Send notification
      final channelId = urgency == 'SOS' ? 'sos_channel' : 'request_channel';
      await _notificationService.showNotification(
        title: urgency == 'SOS'
            ? '🆘 SOS EMERGENCY!'
            : '🩸 New Blood Request',
        body: '$hospitalName needs $units unit(s) of $bloodGroup blood ($urgency)',
        channelId: channelId,
      );

      // Trigger SMS Backup Alerts for critical emergencies
      if (urgency == 'SOS') {
        await SmsService.sendSOSAlert(
          hospitalName: hospitalName,
          bloodGroup: bloodGroup,
          patientCondition: notes ?? 'Critical Emergency',
          toPhoneNumbers: ['+1234567890', '+0987654321'],
        );
      }

      _setLoading(false);
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

  /// Reject a request (donor)
  Future<bool> rejectRequest(String requestId, String donorId) async {
    try {
      await _firestoreService.addRejectedDonor(requestId, donorId);
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

      // If completed, free up ambulance
      if (status == 'completed' || status == 'cancelled') {
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

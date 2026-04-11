/// Smart Donor Routing Service
/// AI-driven iterative donor targeting system:
/// 1. When hospital raises a request, finds nearest compatible donor
/// 2. Sends notification ONLY to that donor
/// 3. If donor doesn't accept within timeout (5 min), escalates to next nearest
/// 4. Tracks distance from hospital to each targeted donor
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/matching_engine.dart';
import '../utils/location_utils.dart';
import '../../models/blood_request_model.dart';
import '../../models/user_model.dart';

/// Result of a donor targeting operation
class DonorTargetResult {
  final String donorId;
  final String donorName;
  final double distanceKm;
  final String formattedDistance;
  final String estimatedETA;
  final double donorLat;
  final double donorLng;

  DonorTargetResult({
    required this.donorId,
    required this.donorName,
    required this.distanceKm,
    required this.donorLat,
    required this.donorLng,
  })  : formattedDistance = LocationUtils.formatDistance(distanceKm),
        estimatedETA = LocationUtils.estimateETA(distanceKm);
}

class SmartDonorRoutingService {
  static final SmartDonorRoutingService _instance = SmartDonorRoutingService._internal();
  factory SmartDonorRoutingService() => _instance;
  SmartDonorRoutingService._internal();

  final FirestoreService _fs = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  /// Timeout duration for donor response (5 minutes)
  static const Duration donorTimeout = Duration(minutes: 5);

  /// Active escalation timers: requestId -> Timer
  final Map<String, Timer> _escalationTimers = {};

  /// Active escalation streams: requestId -> StreamSubscription
  final Map<String, StreamSubscription> _escalationListeners = {};

  /// Cancel all active timers for a request
  void cancelEscalation(String requestId) {
    _escalationTimers[requestId]?.cancel();
    _escalationTimers.remove(requestId);
    _escalationListeners[requestId]?.cancel();
    _escalationListeners.remove(requestId);
    debugPrint('>>> SmartRouting: Cancelled escalation for request $requestId');
  }

  /// Cancel all active escalations
  void cancelAllEscalations() {
    for (final timer in _escalationTimers.values) {
      timer.cancel();
    }
    _escalationTimers.clear();
    for (final sub in _escalationListeners.values) {
      sub.cancel();
    }
    _escalationListeners.clear();
  }

  /// Find and target the nearest compatible donor for a request.
  /// Returns the target result or null if no donor found.
  Future<DonorTargetResult?> findAndTargetNearestDonor({
    required String requestId,
    required BloodRequestModel request,
    bool startEscalationTimer = true,
  }) async {
    try {
      // 1. Get all donors from Firestore
      final donorsSnapshot = await _fs.getAllDonors();
      if (donorsSnapshot.isEmpty) {
        debugPrint('>>> SmartRouting: No donors found in system');
        return null;
      }

      // 2. Use matching engine to find ranked donors
      final matches = MatchingEngine.findMatches(
        request: request,
        donors: donorsSnapshot,
      );

      if (matches.isEmpty) {
        debugPrint('>>> SmartRouting: No compatible donors within range');
        return null;
      }

      // 3. Find the first donor who hasn't been notified or rejected yet
      DonorMatch? bestMatch;
      for (final match in matches) {
        if (!request.notifiedDonorIds.contains(match.donor.id) &&
            !request.rejectedDonorIds.contains(match.donor.id) &&
            request.assignedDonorId != match.donor.id) {
          bestMatch = match;
          break;
        }
      }

      if (bestMatch == null) {
        debugPrint('>>> SmartRouting: All compatible donors already notified/rejected');
        // Fall back to topic-based broadcast as last resort
        await _broadcastToAllCompatible(request);
        return null;
      }

      final donor = bestMatch.donor;
      final distance = bestMatch.distanceKm;

      debugPrint('>>> SmartRouting: Targeting donor ${donor.name} at ${distance.toStringAsFixed(1)}km');

      // 4. Update request with current target donor and distance
      await _fs.updateRequestTargetDonor(
        requestId,
        donor.id,
        donor.name,
        distance,
      );

      // 5. Mark donor as notified
      await _fs.addNotifiedDonor(requestId, donor.id);

      // 6. Send targeted notification to this specific donor
      await _sendTargetedNotification(
        donor: donor,
        request: request,
        distance: distance,
      );

      // 7. Save notification to Firestore for the donor
      await _fs.saveNotification(
        userId: donor.id,
        title: request.urgency == 'SOS'
            ? '🆘 URGENT: ${request.bloodGroup} Needed!'
            : '🩸 ${request.bloodGroup} Blood Request',
        body: '${request.hospitalName} needs ${request.units} unit(s) • ${LocationUtils.formatDistance(distance)} away • Respond within 5 min',
        type: 'blood_request',
        requestId: requestId,
      );

      // 8. Start escalation timer
      if (startEscalationTimer) {
        _startEscalationTimer(requestId);
      }

      return DonorTargetResult(
        donorId: donor.id,
        donorName: donor.name,
        distanceKm: distance,
        donorLat: donor.latitude,
        donorLng: donor.longitude,
      );
    } catch (e) {
      debugPrint('>>> SmartRouting Error: $e');
      return null;
    }
  }

  /// Start an escalation timer for a request.
  /// After timeout, if still pending, escalate to next nearest donor.
  void _startEscalationTimer(String requestId) {
    // Cancel any existing timer
    _escalationTimers[requestId]?.cancel();

    debugPrint('>>> SmartRouting: Starting ${donorTimeout.inMinutes}min escalation timer for $requestId');

    _escalationTimers[requestId] = Timer(donorTimeout, () async {
      debugPrint('>>> SmartRouting: Timeout reached for request $requestId, checking status...');

      try {
        // Get fresh request data
        final updatedRequest = await _fs.getRequest(requestId);
        if (updatedRequest == null) {
          debugPrint('>>> SmartRouting: Request $requestId no longer exists');
          cancelEscalation(requestId);
          return;
        }

        // Only escalate if still pending (donor didn't respond)
        if (updatedRequest.status == 'pending') {
          debugPrint('>>> SmartRouting: Donor did not respond. Escalating to next nearest...');

          // Clear current target
          await _fs.updateRequestTargetDonor(requestId, null, null, null);

          // Find next nearest donor
          final nextTarget = await findAndTargetNearestDonor(
            requestId: requestId,
            request: updatedRequest,
            startEscalationTimer: true,
          );

          if (nextTarget == null) {
            debugPrint('>>> SmartRouting: No more donors available. Broadcasting to all.');
            await _broadcastToAllCompatible(updatedRequest);
          } else {
            debugPrint('>>> SmartRouting: Escalated to ${nextTarget.donorName} at ${nextTarget.formattedDistance}');
          }
        } else {
          debugPrint('>>> SmartRouting: Request $requestId is no longer pending (status: ${updatedRequest.status})');
          cancelEscalation(requestId);
        }
      } catch (e) {
        debugPrint('>>> SmartRouting: Escalation error: $e');
      }
    });
  }

  /// Listen for request status changes to auto-cancel escalation
  void listenForAcceptance(String requestId) {
    _escalationListeners[requestId]?.cancel();

    _escalationListeners[requestId] = _fs
        .streamRequestById(requestId)
        .listen((request) {
      if (request != null && request.status != 'pending') {
        debugPrint('>>> SmartRouting: Request $requestId status changed to ${request.status}, cancelling escalation');
        cancelEscalation(requestId);
      }
    });
  }

  /// Send notification to a specific donor
  Future<void> _sendTargetedNotification({
    required UserModel donor,
    required BloodRequestModel request,
    required double distance,
  }) async {
    // Send via FCM topic targeting the individual donor
    final donorTopic = 'donor_${donor.id}';
    await _notificationService.sendTopicNotification(
      topic: donorTopic,
      title: request.urgency == 'SOS'
          ? '🆘 CRITICAL: ${request.bloodGroup} Needed Now!'
          : '🩸 ${request.bloodGroup} Blood Request for You',
      body: '${request.hospitalName} • ${request.units} unit(s) • '
          '${LocationUtils.formatDistance(distance)} away • '
          'Respond within ${donorTimeout.inMinutes} min or request goes to next donor',
      urgency: request.urgency,
    );

    // Also show local notification (for same-device testing)
    await _notificationService.showNotification(
      title: request.urgency == 'SOS'
          ? '🆘 YOU are the nearest donor!'
          : '🩸 Blood Request — You\'re closest!',
      body: '${request.hospitalName} needs ${request.bloodGroup} • ${LocationUtils.formatDistance(distance)} away',
      channelId: request.urgency == 'SOS' ? 'sos_channel' : 'request_channel',
    );
  }

  /// Broadcast to all compatible donors as a fallback
  Future<void> _broadcastToAllCompatible(BloodRequestModel request) async {
    final safeGroup = request.bloodGroup.replaceAll('+', '_pos').replaceAll('-', '_neg');
    await _notificationService.sendTopicNotification(
      topic: 'blood_$safeGroup',
      title: '🩸 ${request.bloodGroup} Still Needed at ${request.hospitalName}',
      body: 'All nearby donors have been contacted. ${request.units} unit(s) still needed. Please respond!',
      urgency: request.urgency,
    );
  }

  /// Get ranked list of all compatible donors with distances for a request
  Future<List<DonorTargetResult>> getRankedDonorsForRequest(BloodRequestModel request) async {
    try {
      final donors = await _fs.getAllDonors();
      final matches = MatchingEngine.findMatches(
        request: request,
        donors: donors,
      );

      return matches.map((m) => DonorTargetResult(
        donorId: m.donor.id,
        donorName: m.donor.name,
        distanceKm: m.distanceKm,
        donorLat: m.donor.latitude,
        donorLng: m.donor.longitude,
      )).toList();
    } catch (e) {
      debugPrint('>>> SmartRouting: getRankedDonors error: $e');
      return [];
    }
  }
}

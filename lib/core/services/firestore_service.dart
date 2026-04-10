/// Firestore service - centralized database operations
/// Enhanced with ambulance release and request getter
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../../models/blood_request_model.dart';
import '../../models/blood_inventory_model.dart';
import '../../models/ambulance_model.dart';
import '../constants/app_constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============ USER OPERATIONS ============

  /// Create or update user profile
  Future<void> saveUser(UserModel user) async {
    await _db.collection(AppConstants.usersCollection)
        .doc(user.id)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  /// Get user by ID
  Future<UserModel?> getUser(String userId) async {
    final doc = await _db.collection(AppConstants.usersCollection).doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Stream user data for real-time updates
  Stream<UserModel?> streamUser(String userId) {
    return _db.collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  /// Get users by role
  Stream<List<UserModel>> streamUsersByRole(String role) {
    return _db.collection(AppConstants.usersCollection)
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snap) => snap.docs.map((d) => UserModel.fromFirestore(d)).toList());
  }

  /// Get available donors by blood group
  Stream<List<UserModel>> streamAvailableDonors(String bloodGroup) {
    return _db.collection(AppConstants.usersCollection)
        .where('role', isEqualTo: 'donor')
        .where('bloodGroup', isEqualTo: bloodGroup)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => UserModel.fromFirestore(d)).toList());
  }

  /// Get all donors for map display
  Stream<List<UserModel>> streamAllDonors() {
    return _db.collection(AppConstants.usersCollection)
        .where('role', isEqualTo: 'donor')
        .snapshots()
        .map((snap) => snap.docs.map((d) => UserModel.fromFirestore(d)).toList());
  }

  /// Get network users (donors and blood banks) for Hospital dashboard
  Stream<List<UserModel>> streamNetworkUsers() {
    return _db.collection(AppConstants.usersCollection)
        .where('role', whereIn: ['donor', 'blood_bank'])
        .snapshots()
        .map((snap) => snap.docs.map((d) => UserModel.fromFirestore(d)).toList());
  }

  /// Update user availability
  Future<void> updateUserAvailability(String userId, bool isAvailable) async {
    await _db.collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'isAvailable': isAvailable});
  }

  /// Update user location
  Future<void> updateUserLocation(String userId, double lat, double lng) async {
    await _db.collection(AppConstants.usersCollection)
        .doc(userId)
        .update({
          'location': {'lat': lat, 'lng': lng},
        });
  }

  /// Update FCM token
  Future<void> updateFcmToken(String userId, String token) async {
    await _db.collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'fcmToken': token});
  }

  // ============ BLOOD REQUEST OPERATIONS ============

  /// Create new blood request
  Future<String> createBloodRequest(BloodRequestModel request) async {
    final docRef = await _db.collection(AppConstants.requestsCollection)
        .add(request.toFirestore());
    return docRef.id;
  }

  /// Get a single request by ID
  Future<BloodRequestModel?> getRequest(String requestId) async {
    try {
      final doc = await _db.collection(AppConstants.requestsCollection).doc(requestId).get();
      if (!doc.exists) return null;
      return BloodRequestModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('>>> Error getting request: $e');
      return null;
    }
  }

  /// Stream all active requests (sorted client-side to avoid needing composite index)
  Stream<List<BloodRequestModel>> streamActiveRequests() {
    return _db.collection(AppConstants.requestsCollection)
        .where('status', whereIn: ['pending', 'matched', 'accepted', 'in_transit'])
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => BloodRequestModel.fromFirestore(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((e) {
          debugPrint('>>> Error streaming active requests: $e');
        });
  }

  /// Stream requests for a specific hospital (sorted client-side)
  Stream<List<BloodRequestModel>> streamHospitalRequests(String hospitalId) {
    return _db.collection(AppConstants.requestsCollection)
        .where('hospitalId', isEqualTo: hospitalId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => BloodRequestModel.fromFirestore(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((e) {
          debugPrint('>>> Error streaming hospital requests: $e');
        });
  }

  /// Stream requests assigned to a donor (sorted client-side)
  Stream<List<BloodRequestModel>> streamDonorRequests(String donorId) {
    return _db.collection(AppConstants.requestsCollection)
        .where('assignedDonorId', isEqualTo: donorId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => BloodRequestModel.fromFirestore(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((e) {
          debugPrint('>>> Error streaming donor requests: $e');
        });
  }

  /// Stream all requests (admin)
  Stream<List<BloodRequestModel>> streamAllRequests() {
    return _db.collection(AppConstants.requestsCollection)
        .limit(100)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => BloodRequestModel.fromFirestore(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((e) {
          debugPrint('>>> Error streaming all requests: $e');
        });
  }

  /// Stream pending requests for donors (to receive alerts)
  Stream<List<BloodRequestModel>> streamPendingRequests() {
    debugPrint('>>> streamPendingRequests() called');
    return _db.collection(AppConstants.requestsCollection)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          debugPrint('>>> Pending requests snapshot: ${snap.docs.length} docs');
          final list = snap.docs.map((d) => BloodRequestModel.fromFirestore(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((e) {
          debugPrint('>>> Error streaming pending requests: $e');
        });
  }

  /// Update request status
  Future<void> updateRequestStatus(String requestId, String status) async {
    final Map<String, dynamic> update = {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 'completed') {
      update['completedAt'] = FieldValue.serverTimestamp();
    }
    await _db.collection(AppConstants.requestsCollection)
        .doc(requestId)
        .update(update);
  }

  /// Assign donor to request
  Future<void> assignDonor(String requestId, String donorId, String donorName) async {
    await _db.collection(AppConstants.requestsCollection)
        .doc(requestId)
        .update({
          'assignedDonorId': donorId,
          'assignedDonorName': donorName,
          'status': 'accepted',
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Add donor to notified list
  Future<void> addNotifiedDonor(String requestId, String donorId) async {
    await _db.collection(AppConstants.requestsCollection)
        .doc(requestId)
        .update({
          'notifiedDonorIds': FieldValue.arrayUnion([donorId]),
        });
  }

  /// Add donor to rejected list
  Future<void> addRejectedDonor(String requestId, String donorId) async {
    await _db.collection(AppConstants.requestsCollection)
        .doc(requestId)
        .update({
          'rejectedDonorIds': FieldValue.arrayUnion([donorId]),
        });
  }

  // ============ BLOOD INVENTORY OPERATIONS ============

  /// Stream inventory for a blood bank
  Stream<List<BloodInventoryModel>> streamBloodBankInventory(String bloodBankId) {
    return _db.collection(AppConstants.bloodInventoryCollection)
        .where('bloodBankId', isEqualTo: bloodBankId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BloodInventoryModel.fromFirestore(d)).toList());
  }

  /// Stream all blood inventory
  Stream<List<BloodInventoryModel>> streamAllInventory() {
    return _db.collection(AppConstants.bloodInventoryCollection)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BloodInventoryModel.fromFirestore(d)).toList());
  }

  /// Update or create inventory item
  Future<void> updateInventory(BloodInventoryModel inventory) async {
    if (inventory.id.isEmpty) {
      await _db.collection(AppConstants.bloodInventoryCollection)
          .add(inventory.toFirestore());
    } else {
      await _db.collection(AppConstants.bloodInventoryCollection)
          .doc(inventory.id)
          .set(inventory.toFirestore());
    }
  }

  // ============ AMBULANCE OPERATIONS ============

  /// Stream available ambulances
  Stream<List<AmbulanceModel>> streamAvailableAmbulances() {
    return _db.collection(AppConstants.ambulancesCollection)
        .where('available', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AmbulanceModel.fromFirestore(d)).toList());
  }

  /// Assign ambulance to request
  Future<void> assignAmbulance(String ambulanceId, String requestId) async {
    final batch = _db.batch();

    batch.update(
      _db.collection(AppConstants.ambulancesCollection).doc(ambulanceId),
      {'available': false, 'assignedRequestId': requestId},
    );

    batch.update(
      _db.collection(AppConstants.requestsCollection).doc(requestId),
      {
        'assignedAmbulanceId': ambulanceId,
        'status': 'in_transit',
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  /// Release ambulance (make available again)
  Future<void> releaseAmbulance(String ambulanceId) async {
    try {
      await _db.collection(AppConstants.ambulancesCollection)
          .doc(ambulanceId)
          .update({
            'available': true,
            'assignedRequestId': null,
          });
    } catch (e) {
      debugPrint('>>> Release ambulance error: $e');
    }
  }

  /// Update ambulance location
  Future<void> updateAmbulanceLocation(String ambulanceId, double lat, double lng) async {
    await _db.collection(AppConstants.ambulancesCollection)
        .doc(ambulanceId)
        .update({
          'location': {'lat': lat, 'lng': lng},
        });
  }

  // ============ NOTIFICATIONS ============

  /// Save notification to Firestore
  Future<void> saveNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? requestId,
  }) async {
    await _db.collection(AppConstants.notificationsCollection).add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'requestId': requestId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream user notifications
  Stream<QuerySnapshot> streamUserNotifications(String userId) {
    return _db.collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // ============ ANALYTICS (Admin) ============

  /// Get total request counts
  Future<Map<String, int>> getRequestStats() async {
    final all = await _db.collection(AppConstants.requestsCollection).get();
    final Map<String, int> stats = {
      'total': all.docs.length,
      'pending': 0,
      'completed': 0,
      'cancelled': 0,
    };

    for (final doc in all.docs) {
      final status = doc.data()['status'] as String?;
      if (stats.containsKey(status)) {
        stats[status!] = stats[status]! + 1;
      }
    }

    return stats;
  }

  /// Get donor count
  Future<int> getDonorCount() async {
    final snap = await _db.collection(AppConstants.usersCollection)
        .where('role', isEqualTo: 'donor')
        .count()
        .get();
    return snap.count ?? 0;
  }
}

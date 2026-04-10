/// Fraud Prevention Service
/// Detects fake donors, limits frequent requests, checks for suspicious activity
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';

class FraudCheckResult {
  final bool isSuspicious;
  final double riskScore;
  final String riskLevel;
  final List<String> flags;
  final String recommendation;

  FraudCheckResult({
    required this.isSuspicious,
    required this.riskScore,
    required this.riskLevel,
    required this.flags,
    required this.recommendation,
  });

  factory FraudCheckResult.fromJson(Map<String, dynamic> json) {
    return FraudCheckResult(
      isSuspicious: json['is_suspicious'] ?? false,
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['risk_level'] ?? 'low',
      flags: List<String>.from(json['flags'] ?? []),
      recommendation: json['recommendation'] ?? '',
    );
  }
}

class FraudPreventionService {
  static const String _baseUrl = AppConstants.aiApiBaseUrl;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Check a user action for fraud indicators
  static Future<FraudCheckResult> checkFraud({
    required String userId,
    required String action, // 'donate' or 'request'
  }) async {
    try {
      // Gather activity data from Firestore
      final activityData = await _getUserActivity(userId, action);

      final response = await http.post(
        Uri.parse('$_baseUrl/api/fraud_check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(activityData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return FraudCheckResult.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Fraud check API error: $e');
    }

    // Local fallback
    return _localFraudCheck(userId, action);
  }

  /// Get user activity data from Firestore for fraud analysis
  static Future<Map<String, dynamic>> _getUserActivity(String userId, String action) async {
    int donationCount30d = 0;
    int requestCount24h = 0;
    int accountAgeDays = 0;
    int previousRejections = 0;

    try {
      // Get user creation date
      final userDoc = await _db.collection(AppConstants.usersCollection).doc(userId).get();
      if (userDoc.exists) {
        final createdAt = (userDoc.data()?['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          accountAgeDays = DateTime.now().difference(createdAt).inDays;
        }
      }

      // Count recent requests
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));
      final monthAgo = now.subtract(const Duration(days: 30));

      final requestsSnap = await _db
          .collection(AppConstants.requestsCollection)
          .where('hospitalId', isEqualTo: userId)
          .limit(50)
          .get();

      for (final doc in requestsSnap.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && createdAt.isAfter(yesterday)) {
          requestCount24h++;
        }
        final rejectedDonors = List<String>.from(data['rejectedDonorIds'] ?? []);
        previousRejections += rejectedDonors.length;
      }

      // Count donations (requests where user is assignedDonorId)
      final donationsSnap = await _db
          .collection(AppConstants.requestsCollection)
          .where('assignedDonorId', isEqualTo: userId)
          .limit(50)
          .get();

      for (final doc in donationsSnap.docs) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && createdAt.isAfter(monthAgo)) {
          donationCount30d++;
        }
      }
    } catch (e) {
      debugPrint('Error gathering activity data: $e');
    }

    return {
      'user_id': userId,
      'action': action,
      'donation_count_30d': donationCount30d,
      'request_count_24h': requestCount24h,
      'account_age_days': accountAgeDays,
      'location_changes_24h': 0,
      'previous_rejections': previousRejections,
    };
  }

  /// Local fallback fraud check
  static Future<FraudCheckResult> _localFraudCheck(String userId, String action) async {
    double score = 0;
    final flags = <String>[];

    try {
      final activityData = await _getUserActivity(userId, action);

      if (activityData['donation_count_30d'] as int > 1 && action == 'donate') {
        score += 40;
        flags.add('Multiple donations within 30 days');
      }

      if (activityData['request_count_24h'] as int > 5) {
        score += 35;
        flags.add('Excessive request frequency');
      }

      if (activityData['account_age_days'] as int < 1) {
        score += 25;
        flags.add('Brand new account');
      }
    } catch (e) {
      debugPrint('Local fraud check error: $e');
    }

    final riskLevel = score >= 70 ? 'critical' : score >= 45 ? 'high' : score >= 20 ? 'medium' : 'low';

    return FraudCheckResult(
      isSuspicious: score >= 45,
      riskScore: score,
      riskLevel: riskLevel,
      flags: flags.isEmpty ? ['No suspicious indicators found'] : flags,
      recommendation: score >= 45 ? 'Manual review required' : 'Approved — no issues detected',
    );
  }
}

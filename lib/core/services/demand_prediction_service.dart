/// Blood Demand Prediction Service
/// Predicts which blood groups will be needed based on historical data & seasonal trends
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';

class DemandPrediction {
  final String bloodGroup;
  final int predictedDemand;
  final double confidence;
  final String trend; // rising, falling, stable
  final String seasonalFactor;
  final String reasoning;

  DemandPrediction({
    required this.bloodGroup,
    required this.predictedDemand,
    required this.confidence,
    required this.trend,
    required this.seasonalFactor,
    required this.reasoning,
  });

  factory DemandPrediction.fromJson(Map<String, dynamic> json) {
    return DemandPrediction(
      bloodGroup: json['blood_group'] ?? '',
      predictedDemand: json['predicted_demand'] ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      trend: json['trend'] ?? 'stable',
      seasonalFactor: json['seasonal_factor'] ?? '',
      reasoning: json['reasoning'] ?? '',
    );
  }
}

class DemandPredictionService {
  static const String _baseUrl = AppConstants.aiApiBaseUrl;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch demand predictions from AI API using historical Firestore data
  static Future<List<DemandPrediction>> getPredictions() async {
    try {
      // Gather historical request data from Firestore
      final historicalData = await _getHistoricalData();

      final response = await http.post(
        Uri.parse('$_baseUrl/api/predict_demand'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'historical_requests': historicalData,
          'current_month': DateTime.now().month,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((d) => DemandPrediction.fromJson(d)).toList();
      }
    } catch (e) {
      debugPrint('Demand prediction API error: $e');
    }

    // Fallback: local prediction
    return _localPrediction();
  }

  /// Get historical request data from Firestore
  static Future<List<Map<String, dynamic>>> _getHistoricalData() async {
    try {
      final snapshot = await _db
          .collection(AppConstants.requestsCollection)
          .limit(200)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'blood_group': data['bloodGroup'] ?? '',
          'units': data['units'] ?? 1,
          'urgency': data['urgency'] ?? 'Normal',
          'date': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching historical data: $e');
      return [];
    }
  }

  /// Local fallback prediction when API is unavailable
  static List<DemandPrediction> _localPrediction() {
    final month = DateTime.now().month;
    final seasonName = _getSeasonName(month);

    // Base demand patterns (India population distribution)
    final baseDemand = {
      'O+': 8, 'A+': 6, 'B+': 7, 'AB+': 3,
      'O-': 4, 'A-': 3, 'B-': 3, 'AB-': 2,
    };

    // Seasonal multipliers
    final seasonalMult = _getSeasonalMultiplier(month);

    return AppConstants.bloodGroups.map((bg) {
      final base = baseDemand[bg] ?? 3;
      final mult = seasonalMult[bg] ?? 1.0;
      final predicted = (base * mult).round();

      return DemandPrediction(
        bloodGroup: bg,
        predictedDemand: predicted,
        confidence: 0.65,
        trend: mult > 1.1 ? 'rising' : mult < 0.9 ? 'falling' : 'stable',
        seasonalFactor: seasonName,
        reasoning: 'Local prediction based on population distribution and seasonal patterns',
      );
    }).toList()
      ..sort((a, b) => b.predictedDemand.compareTo(a.predictedDemand));
  }

  static String _getSeasonName(int month) {
    const names = {
      1: 'Winter (Flu Season)', 2: 'Late Winter', 3: 'Spring',
      4: 'Early Summer', 5: 'Summer', 6: 'Peak Summer',
      7: 'Peak Summer', 8: 'Late Summer', 9: 'Monsoon',
      10: 'Festive Season', 11: 'Pre-Winter', 12: 'Winter',
    };
    return names[month] ?? 'Unknown';
  }

  static Map<String, double> _getSeasonalMultiplier(int month) {
    // Summer months (May-Jul) - more accidents
    if (month >= 5 && month <= 7) {
      return {'O+': 1.4, 'O-': 1.3, 'A+': 1.2, 'B+': 1.2, 'AB+': 1.0, 'A-': 1.1, 'B-': 1.1, 'AB-': 1.0};
    }
    // Monsoon (Aug-Sep) - dengue
    if (month >= 8 && month <= 9) {
      return {'O+': 1.2, 'O-': 1.1, 'A+': 1.1, 'B+': 1.3, 'AB+': 1.0, 'A-': 1.0, 'B-': 1.2, 'AB-': 1.0};
    }
    // Festive + Winter (Oct-Jan) - accidents + flu
    if (month >= 10 || month <= 1) {
      return {'O+': 1.3, 'O-': 1.2, 'A+': 1.1, 'B+': 1.1, 'AB+': 1.0, 'A-': 1.1, 'B-': 1.0, 'AB-': 0.9};
    }
    // Spring/default
    return {'O+': 1.0, 'O-': 1.0, 'A+': 1.0, 'B+': 1.0, 'AB+': 1.0, 'A-': 1.0, 'B-': 1.0, 'AB-': 1.0};
  }
}

/// AI Emergency Priority Classifier
/// Auto-classifies blood requests as Normal / Urgent / Critical / SOS
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class EmergencyClassification {
  final String priority;
  final double priorityScore;
  final List<String> reasoning;
  final List<String> recommendedActions;

  EmergencyClassification({
    required this.priority,
    required this.priorityScore,
    required this.reasoning,
    required this.recommendedActions,
  });

  factory EmergencyClassification.fromJson(Map<String, dynamic> json) {
    return EmergencyClassification(
      priority: json['priority'] ?? 'Normal',
      priorityScore: (json['priority_score'] as num?)?.toDouble() ?? 0.0,
      reasoning: List<String>.from(json['reasoning'] ?? []),
      recommendedActions: List<String>.from(json['recommended_actions'] ?? []),
    );
  }
}

class EmergencyClassifierService {
  static const String _baseUrl = AppConstants.aiApiBaseUrl;

  /// Classify emergency priority using AI
  static Future<EmergencyClassification> classify({
    int? patientAge,
    String? patientCondition,
    int unitsNeeded = 1,
    String bloodGroup = '',
    bool isSurgery = false,
    bool isAccident = false,
    double? hemoglobinLevel,
    bool isPregnant = false,
    double? timeCriticalHours,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/classify_emergency'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patient_age': patientAge,
          'patient_condition': patientCondition,
          'units_needed': unitsNeeded,
          'blood_group': bloodGroup,
          'is_surgery': isSurgery,
          'is_accident': isAccident,
          'hemoglobin_level': hemoglobinLevel,
          'is_pregnant': isPregnant,
          'time_critical_hours': timeCriticalHours,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return EmergencyClassification.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Emergency classification API error: $e');
    }

    // Local fallback
    return _localClassify(
      unitsNeeded: unitsNeeded,
      patientCondition: patientCondition,
      isAccident: isAccident,
      isSurgery: isSurgery,
      hemoglobinLevel: hemoglobinLevel,
      bloodGroup: bloodGroup,
    );
  }

  /// Local fallback classification
  static EmergencyClassification _localClassify({
    required int unitsNeeded,
    String? patientCondition,
    bool isAccident = false,
    bool isSurgery = false,
    double? hemoglobinLevel,
    String bloodGroup = '',
  }) {
    double score = 0;
    final reasons = <String>[];
    final actions = <String>[];

    if (unitsNeeded >= 5) {
      score += 35;
      reasons.add('High blood requirement: $unitsNeeded units');
    } else if (unitsNeeded >= 3) {
      score += 20;
      reasons.add('Moderate blood requirement: $unitsNeeded units');
    } else {
      score += 5;
      reasons.add('Standard requirement: $unitsNeeded unit(s)');
    }

    if (isAccident) {
      score += 25;
      reasons.add('Accident case');
      actions.add('Alert trauma team and prepare OR');
    }
    if (isSurgery) {
      score += 15;
      reasons.add('Surgical procedure required');
    }

    if (hemoglobinLevel != null && hemoglobinLevel < 7) {
      score += 25;
      reasons.add('Low hemoglobin: $hemoglobinLevel g/dL');
      actions.add('Immediate transfusion required');
    }

    if (['AB-', 'B-', 'O-'].contains(bloodGroup)) {
      score += 10;
      reasons.add('Rare blood type: $bloodGroup');
    }

    if (patientCondition != null) {
      final condition = patientCondition.toLowerCase();
      if (condition.contains('trauma') || condition.contains('hemorrhage') ||
          condition.contains('accident') || condition.contains('critical')) {
        score += 25;
        reasons.add('Critical condition detected');
      }
    }

    String priority;
    if (score >= 80) {
      priority = 'SOS';
    } else if (score >= 50) {
      priority = 'Critical';
    } else if (score >= 25) {
      priority = 'Urgent';
    } else {
      priority = 'Normal';
    }

    actions.add('Classified as $priority priority');

    return EmergencyClassification(
      priority: priority,
      priorityScore: score.clamp(0, 100),
      reasoning: reasons,
      recommendedActions: actions,
    );
  }
}

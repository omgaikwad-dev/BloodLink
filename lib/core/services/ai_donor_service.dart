/// AI Donor Prioritization Service - connects to external Python API
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// AI prediction result for donor prioritization
class AIPrediction {
  final String donorId;
  final double score;
  final String reasoning;

  AIPrediction({
    required this.donorId,
    required this.score,
    required this.reasoning,
  });

  factory AIPrediction.fromJson(Map<String, dynamic> json) {
    return AIPrediction(
      donorId: json['donor_id'] ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      reasoning: json['reasoning'] ?? '',
    );
  }
}

class AIDonorService {
  static const String _baseUrl = AppConstants.aiApiBaseUrl;

  /// Get AI-prioritized donors for a blood request
  /// Calls external Flask/FastAPI endpoint
  static Future<List<AIPrediction>> getPrioritizedDonors({
    required String bloodGroup,
    required double latitude,
    required double longitude,
    required List<Map<String, dynamic>> donors,
    String? apiKey,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/prioritize'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': ?apiKey,
        },
        body: jsonEncode({
          'blood_group': bloodGroup,
          'location': {'lat': latitude, 'lng': longitude},
          'donors': donors,
          'max_radius_km': AppConstants.searchRadiusKm,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predictions = (data['predictions'] as List?)
            ?.map((p) => AIPrediction.fromJson(p))
            .toList();
        return predictions ?? [];
      }
    } catch (e) {
      // Fall back to local matching if AI API is unavailable
    }
    return [];
  }

  /// Check if the AI API is reachable
  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

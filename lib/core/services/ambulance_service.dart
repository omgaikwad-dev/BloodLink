/// Smart Ambulance Service
/// Auto-assigns nearest ambulance, ETA calculation, route optimization
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../utils/location_utils.dart';
import '../../models/ambulance_model.dart';

class AmbulanceAssignment {
  final String ambulanceId;
  final double distanceKm;
  final int etaMinutes;
  final double routeScore;
  final String reasoning;

  AmbulanceAssignment({
    required this.ambulanceId,
    required this.distanceKm,
    required this.etaMinutes,
    required this.routeScore,
    required this.reasoning,
  });

  factory AmbulanceAssignment.fromJson(Map<String, dynamic> json) {
    return AmbulanceAssignment(
      ambulanceId: json['ambulance_id'] ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      etaMinutes: json['eta_minutes'] ?? 0,
      routeScore: (json['route_score'] as num?)?.toDouble() ?? 0.0,
      reasoning: json['reasoning'] ?? '',
    );
  }
}

class SmartAmbulanceService {
  static const String _baseUrl = AppConstants.aiApiBaseUrl;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Auto-assign the best ambulance for a request
  static Future<AmbulanceAssignment?> autoAssign({
    required double requestLat,
    required double requestLng,
    required double hospitalLat,
    required double hospitalLng,
    required String urgency,
  }) async {
    try {
      // Get available ambulances from Firestore
      final ambulancesSnap = await _db
          .collection(AppConstants.ambulancesCollection)
          .where('available', isEqualTo: true)
          .get();

      if (ambulancesSnap.docs.isEmpty) return null;

      final ambulances = ambulancesSnap.docs
          .map((d) => AmbulanceModel.fromFirestore(d))
          .where((a) => a.latitude != 0 && a.longitude != 0)
          .toList();

      if (ambulances.isEmpty) return null;

      // Try AI API first
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/api/assign_ambulance'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'request_location': {'lat': requestLat, 'lng': requestLng},
            'hospital_location': {'lat': hospitalLat, 'lng': hospitalLng},
            'ambulances': ambulances.map((a) => {
              'id': a.id,
              'lat': a.latitude,
              'lng': a.longitude,
              'is_available': a.isAvailable,
              'vehicle_type': 'basic',
            }).toList(),
            'urgency': urgency,
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return AmbulanceAssignment.fromJson(jsonDecode(response.body));
        }
      } catch (e) {
        debugPrint('Ambulance assignment API error: $e');
      }

      // Local fallback: find nearest ambulance
      return _localAssign(ambulances, requestLat, requestLng, hospitalLat, hospitalLng, urgency);
    } catch (e) {
      debugPrint('Auto-assign ambulance error: $e');
      return null;
    }
  }

  /// Calculate ETA between two points
  static int calculateETA(double fromLat, double fromLng, double toLat, double toLng, String urgency) {
    final distance = LocationUtils.calculateDistance(fromLat, fromLng, toLat, toLng);
    // Average speeds based on urgency
    final speedKmh = switch (urgency) {
      'SOS' => 60.0,
      'Critical' => 50.0,
      'Urgent' => 40.0,
      _ => 30.0,
    };
    return ((distance / speedKmh) * 60).ceil().clamp(1, 999);
  }

  /// Local fallback ambulance assignment
  static AmbulanceAssignment _localAssign(
    List<AmbulanceModel> ambulances,
    double requestLat,
    double requestLng,
    double hospitalLat,
    double hospitalLng,
    String urgency,
  ) {
    AmbulanceModel? best;
    double bestDist = double.infinity;

    for (final amb in ambulances) {
      final dist = LocationUtils.calculateDistance(
        amb.latitude, amb.longitude, requestLat, requestLng,
      );
      if (dist < bestDist) {
        bestDist = dist;
        best = amb;
      }
    }

    final eta = calculateETA(best!.latitude, best.longitude, requestLat, requestLng, urgency);
    final totalDist = bestDist + LocationUtils.calculateDistance(
      requestLat, requestLng, hospitalLat, hospitalLng,
    );

    return AmbulanceAssignment(
      ambulanceId: best.id,
      distanceKm: double.parse(bestDist.toStringAsFixed(2)),
      etaMinutes: eta,
      routeScore: double.parse((100 - bestDist * 3).clamp(0, 100).toStringAsFixed(2)),
      reasoning: 'Nearest ambulance: ${bestDist.toStringAsFixed(1)}km | ETA: ${eta}min | Total route: ${totalDist.toStringAsFixed(1)}km',
    );
  }

  /// Stream real-time ambulance position
  static Stream<AmbulanceModel?> streamAmbulance(String ambulanceId) {
    return _db
        .collection(AppConstants.ambulancesCollection)
        .doc(ambulanceId)
        .snapshots()
        .map((doc) => doc.exists ? AmbulanceModel.fromFirestore(doc) : null);
  }
}

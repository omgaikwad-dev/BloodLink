/// Haversine formula implementation for calculating distances between GPS coordinates
/// Used for the Smart Matching Engine to find donors within 20km radius
library;

import 'dart:math';

class LocationUtils {
  LocationUtils._();

  /// Calculate distance between two GPS points using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const double earthRadius = 6371.0; // Earth's radius in km

    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Check if a point is within a given radius
  static bool isWithinRadius(
    double lat1, double lng1,
    double lat2, double lng2,
    double radiusKm,
  ) {
    return calculateDistance(lat1, lng1, lat2, lng2) <= radiusKm;
  }

  /// Estimate travel time based on distance (rough approximation)
  /// Assumes average urban speed of 30 km/h for ambulance
  static String estimateETA(double distanceKm) {
    const double avgSpeedKmh = 30.0;
    final double timeHours = distanceKm / avgSpeedKmh;
    final int timeMinutes = (timeHours * 60).ceil();

    if (timeMinutes < 1) return '< 1 min';
    if (timeMinutes < 60) return '$timeMinutes min';
    final int hours = timeMinutes ~/ 60;
    final int mins = timeMinutes % 60;
    return '${hours}h ${mins}m';
  }
}

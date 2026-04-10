/// Smart Matching Engine - finds best donors using distance, availability, and compatibility
library;

import '../../models/user_model.dart';
import '../../models/blood_request_model.dart';
import '../constants/app_constants.dart';
import '../utils/location_utils.dart';

/// Represents a matched donor with calculated priority score
class DonorMatch {
  final UserModel donor;
  final double distanceKm;
  final double score;
  final String formattedDistance;
  final String estimatedETA;

  DonorMatch({
    required this.donor,
    required this.distanceKm,
    required this.score,
  }) : formattedDistance = LocationUtils.formatDistance(distanceKm),
       estimatedETA = LocationUtils.estimateETA(distanceKm);
}

class MatchingEngine {
  MatchingEngine._();

  /// Find and rank compatible donors for a blood request
  /// Uses: blood group compatibility, distance (< 20km), availability, donation eligibility
  static List<DonorMatch> findMatches({
    required BloodRequestModel request,
    required List<UserModel> donors,
    double maxRadiusKm = AppConstants.searchRadiusKm,
  }) {
    final List<DonorMatch> matches = [];

    // Get compatible blood groups that can donate to the requested group
    final compatibleGroups = _getCompatibleDonorGroups(request.bloodGroup);

    for (final donor in donors) {
      // Skip if not available
      if (!donor.isAvailable) continue;

      // Skip if can't donate (too recent donation)
      if (!donor.canDonate) continue;

      // Skip if blood group not compatible
      if (!compatibleGroups.contains(donor.bloodGroup)) continue;

      // Skip if already notified and rejected
      if (request.rejectedDonorIds.contains(donor.id)) continue;

      // Calculate distance
      final distance = LocationUtils.calculateDistance(
        request.latitude, request.longitude,
        donor.latitude, donor.longitude,
      );

      // Skip if too far
      if (distance > maxRadiusKm) continue;

      // Calculate priority score (higher is better)
      final score = _calculateScore(
        distance: distance,
        maxRadius: maxRadiusKm,
        isExactMatch: donor.bloodGroup == request.bloodGroup,
        donor: donor,
        urgency: request.urgency,
      );

      matches.add(DonorMatch(
        donor: donor,
        distanceKm: distance,
        score: score,
      ));
    }

    // Sort by score (highest first)
    matches.sort((a, b) => b.score.compareTo(a.score));

    return matches;
  }

  /// Calculate priority score for a donor
  static double _calculateScore({
    required double distance,
    required double maxRadius,
    required bool isExactMatch,
    required UserModel donor,
    required String urgency,
  }) {
    double score = 0;

    // Distance score (0-40 points) - closer is better
    score += (1 - (distance / maxRadius)) * 40;

    // Exact blood group match bonus (20 points)
    if (isExactMatch) score += 20;

    // Donation history score (0-20 points)
    // Donors who haven't donated recently get higher scores
    if (donor.lastDonationDate != null) {
      final lastDonation = DateTime.tryParse(donor.lastDonationDate!);
      if (lastDonation != null) {
        final daysSince = DateTime.now().difference(lastDonation).inDays;
        score += (daysSince / 365.0).clamp(0, 1) * 20;
      }
    } else {
      score += 15; // No donation history - moderate score
    }

    // Urgency bonus - for SOS, increase all scores
    switch (urgency) {
      case 'SOS':
        score *= 1.5;
      case 'Critical':
        score *= 1.3;
      case 'Urgent':
        score *= 1.1;
    }

    return score;
  }

  /// Get blood groups that can donate to the given group
  static List<String> _getCompatibleDonorGroups(String recipientGroup) {
    // Reverse the compatibility map to find who can donate TO this group
    final List<String> compatibleDonors = [];

    for (final entry in AppConstants.bloodCompatibility.entries) {
      if (entry.value.contains(recipientGroup)) {
        compatibleDonors.add(entry.key);
      }
    }

    return compatibleDonors;
  }
}

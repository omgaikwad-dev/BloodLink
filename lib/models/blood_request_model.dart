/// Blood request model - represents an emergency blood request
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class BloodRequestModel {
  final String id;
  final String hospitalId;
  final String hospitalName;
  final String bloodGroup;
  final int units;
  final String urgency; // Normal, Urgent, Critical, SOS
  final String status; // pending, matched, accepted, in_transit, completed, cancelled
  final String? assignedDonorId;
  final String? assignedDonorName;
  final String? assignedAmbulanceId;
  final double latitude;
  final double longitude;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final List<String> notifiedDonorIds;
  final List<String> rejectedDonorIds;

  BloodRequestModel({
    required this.id,
    required this.hospitalId,
    required this.hospitalName,
    required this.bloodGroup,
    required this.units,
    required this.urgency,
    this.status = 'pending',
    this.assignedDonorId,
    this.assignedDonorName,
    this.assignedAmbulanceId,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.notes,
    DateTime? createdAt,
    this.updatedAt,
    this.completedAt,
    this.notifiedDonorIds = const [],
    this.rejectedDonorIds = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  /// Check if this is an SOS request
  bool get isSOS => urgency == 'SOS';

  /// Check if request is still active
  bool get isActive =>
      status != 'completed' && status != 'cancelled';

  /// Create from Firestore document
  factory BloodRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final location = data['location'] as Map<String, dynamic>?;

    return BloodRequestModel(
      id: doc.id,
      hospitalId: data['hospitalId'] ?? '',
      hospitalName: data['hospitalName'] ?? '',
      bloodGroup: data['bloodGroup'] ?? '',
      units: (data['units'] as num?)?.toInt() ?? 1,
      urgency: data['urgency'] ?? 'Normal',
      status: data['status'] ?? 'pending',
      assignedDonorId: data['assignedDonorId'],
      assignedDonorName: data['assignedDonorName'],
      assignedAmbulanceId: data['assignedAmbulanceId'],
      latitude: (location?['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (location?['lng'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      notifiedDonorIds: List<String>.from(data['notifiedDonorIds'] ?? []),
      rejectedDonorIds: List<String>.from(data['rejectedDonorIds'] ?? []),
    );
  }

  /// Convert to Firestore document map
  Map<String, dynamic> toFirestore() {
    return {
      'hospitalId': hospitalId,
      'hospitalName': hospitalName,
      'bloodGroup': bloodGroup,
      'units': units,
      'urgency': urgency,
      'status': status,
      'assignedDonorId': assignedDonorId,
      'assignedDonorName': assignedDonorName,
      'assignedAmbulanceId': assignedAmbulanceId,
      'location': {
        'lat': latitude,
        'lng': longitude,
      },
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'notifiedDonorIds': notifiedDonorIds,
      'rejectedDonorIds': rejectedDonorIds,
    };
  }

  /// Copy with updated fields
  BloodRequestModel copyWith({
    String? status,
    String? assignedDonorId,
    String? assignedDonorName,
    String? assignedAmbulanceId,
    DateTime? updatedAt,
    DateTime? completedAt,
    List<String>? notifiedDonorIds,
    List<String>? rejectedDonorIds,
  }) {
    return BloodRequestModel(
      id: id,
      hospitalId: hospitalId,
      hospitalName: hospitalName,
      bloodGroup: bloodGroup,
      units: units,
      urgency: urgency,
      status: status ?? this.status,
      assignedDonorId: assignedDonorId ?? this.assignedDonorId,
      assignedDonorName: assignedDonorName ?? this.assignedDonorName,
      assignedAmbulanceId: assignedAmbulanceId ?? this.assignedAmbulanceId,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      completedAt: completedAt ?? this.completedAt,
      notifiedDonorIds: notifiedDonorIds ?? this.notifiedDonorIds,
      rejectedDonorIds: rejectedDonorIds ?? this.rejectedDonorIds,
    );
  }
}

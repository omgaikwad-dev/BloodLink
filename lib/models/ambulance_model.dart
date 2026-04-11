/// Ambulance model for real-time tracking
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class AmbulanceModel {
  final String id;
  final String driverName;
  final String vehicleNumber;
  final double latitude;
  final double longitude;
  final bool isAvailable;
  final String? assignedRequestId;
  final String? phone;

  AmbulanceModel({
    required this.id,
    this.driverName = '',
    this.vehicleNumber = '',
    this.latitude = 18.5196,
    this.longitude = 73.8553,
    this.isAvailable = true,
    this.assignedRequestId,
    this.phone,
  });

  factory AmbulanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final location = data['location'] as Map<String, dynamic>?;

    return AmbulanceModel(
      id: doc.id,
      driverName: data['driverName'] ?? '',
      vehicleNumber: data['vehicleNumber'] ?? '',
      latitude: ((location?['lat'] as num?)?.toDouble() ?? 18.5196) == 0.0 ? 18.5196 : ((location?['lat'] as num?)?.toDouble() ?? 18.5196),
      longitude: ((location?['lng'] as num?)?.toDouble() ?? 73.8553) == 0.0 ? 73.8553 : ((location?['lng'] as num?)?.toDouble() ?? 73.8553),
      isAvailable: data['available'] ?? true,
      assignedRequestId: data['assignedRequestId'],
      phone: data['phone'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'driverName': driverName,
      'vehicleNumber': vehicleNumber,
      'location': {
        'lat': latitude,
        'lng': longitude,
      },
      'available': isAvailable,
      'assignedRequestId': assignedRequestId,
      'phone': phone,
    };
  }
}

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
    this.latitude = 0.0,
    this.longitude = 0.0,
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
      latitude: (location?['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (location?['lng'] as num?)?.toDouble() ?? 0.0,
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

/// User model for BloodLink AI - stores all user profile information
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // hospital, donor, blood_bank, admin
  final String bloodGroup;
  final double latitude;
  final double longitude;
  final String? lastDonationDate;
  final bool isAvailable;
  final String? fcmToken;
  final String? profileImageUrl;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
    this.bloodGroup = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.lastDonationDate,
    this.isAvailable = true,
    this.fcmToken,
    this.profileImageUrl,
    DateTime? createdAt,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final location = data['location'] as Map<String, dynamic>?;

    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'donor',
      bloodGroup: data['bloodGroup'] ?? '',
      latitude: (location?['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (location?['lng'] as num?)?.toDouble() ?? 0.0,
      lastDonationDate: data['lastDonationDate'],
      isAvailable: data['isAvailable'] ?? true,
      fcmToken: data['fcmToken'],
      profileImageUrl: data['profileImageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'],
    );
  }

  /// Convert to Firestore document map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'bloodGroup': bloodGroup,
      'location': {
        'lat': latitude,
        'lng': longitude,
      },
      'lastDonationDate': lastDonationDate,
      'isAvailable': isAvailable,
      'fcmToken': fcmToken,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  /// Check if donor is eligible to donate
  bool get canDonate {
    if (lastDonationDate == null) return true;
    final lastDate = DateTime.tryParse(lastDonationDate!);
    if (lastDate == null) return true;
    return DateTime.now().difference(lastDate).inDays >= 56;
  }

  /// Copy with updated fields
  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? bloodGroup,
    double? latitude,
    double? longitude,
    String? lastDonationDate,
    bool? isAvailable,
    String? fcmToken,
    String? profileImageUrl,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      isAvailable: isAvailable ?? this.isAvailable,
      fcmToken: fcmToken ?? this.fcmToken,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

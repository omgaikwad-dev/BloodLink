/// Blood inventory model - tracks blood bank stock
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class BloodInventoryModel {
  final String id;
  final String bloodBankId;
  final String bloodBankName;
  final String bloodGroup;
  final int units;
  final DateTime? expiryDate;
  final DateTime updatedAt;

  BloodInventoryModel({
    required this.id,
    required this.bloodBankId,
    required this.bloodBankName,
    required this.bloodGroup,
    required this.units,
    this.expiryDate,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Check if blood has expired
  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Days until expiry
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  factory BloodInventoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BloodInventoryModel(
      id: doc.id,
      bloodBankId: data['bloodBankId'] ?? '',
      bloodBankName: data['bloodBankName'] ?? '',
      bloodGroup: data['bloodGroup'] ?? '',
      units: (data['units'] as num?)?.toInt() ?? 0,
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bloodBankId': bloodBankId,
      'bloodBankName': bloodBankName,
      'bloodGroup': bloodGroup,
      'units': units,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BloodInventoryModel copyWith({
    int? units,
    DateTime? expiryDate,
  }) {
    return BloodInventoryModel(
      id: id,
      bloodBankId: bloodBankId,
      bloodBankName: bloodBankName,
      bloodGroup: bloodGroup,
      units: units ?? this.units,
      expiryDate: expiryDate ?? this.expiryDate,
      updatedAt: DateTime.now(),
    );
  }
}

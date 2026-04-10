/// Demo data seeder - populates Firestore with sample users, requests, and inventory
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DemoDataSeeder {
  static final _db = FirebaseFirestore.instance;

  /// Seed all demo data
  static Future<void> seedAll() async {
    debugPrint('>>> Seeding demo data...');
    await _seedDonors();
    await _seedHospitals();
    await _seedBloodBanks();
    await _seedBloodRequests();
    debugPrint('>>> Demo data seeded successfully!');
  }

  static Future<void> _seedDonors() async {
    final donors = [
      {
        'name': 'Rajesh Kumar', 'email': 'rajesh.donor@demo.com', 'phone': '9876543210',
        'role': 'donor', 'bloodGroup': 'A+', 'isAvailable': true,
        'location': {'lat': 19.0760, 'lng': 72.8777},
      },
      {
        'name': 'Priya Sharma', 'email': 'priya.donor@demo.com', 'phone': '9876543211',
        'role': 'donor', 'bloodGroup': 'B+', 'isAvailable': true,
        'location': {'lat': 19.0820, 'lng': 72.8810},
      },
      {
        'name': 'Amit Patel', 'email': 'amit.donor@demo.com', 'phone': '9876543212',
        'role': 'donor', 'bloodGroup': 'O+', 'isAvailable': false,
        'location': {'lat': 19.0690, 'lng': 72.8690},
        'lastDonationDate': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      },
      {
        'name': 'Sneha Gupta', 'email': 'sneha.donor@demo.com', 'phone': '9876543213',
        'role': 'donor', 'bloodGroup': 'AB-', 'isAvailable': true,
        'location': {'lat': 19.0900, 'lng': 72.8650},
      },
      {
        'name': 'Vikram Singh', 'email': 'vikram.donor@demo.com', 'phone': '9876543214',
        'role': 'donor', 'bloodGroup': 'O-', 'isAvailable': true,
        'location': {'lat': 19.0650, 'lng': 72.8900},
      },
    ];

    for (int i = 0; i < donors.length; i++) {
      final id = 'demo_donor_${i + 1}';
      donors[i]['createdAt'] = Timestamp.now();
      await _db.collection('users').doc(id).set(donors[i], SetOptions(merge: true));
    }
  }

  static Future<void> _seedHospitals() async {
    final hospitals = [
      {
        'name': 'City General Hospital', 'email': 'citygeneral@demo.com', 'phone': '022-12345678',
        'role': 'hospital', 'bloodGroup': '', 'isAvailable': true,
        'location': {'lat': 19.0730, 'lng': 72.8800},
      },
      {
        'name': 'LifeCare Medical Center', 'email': 'lifecare@demo.com', 'phone': '022-87654321',
        'role': 'hospital', 'bloodGroup': '', 'isAvailable': true,
        'location': {'lat': 19.0850, 'lng': 72.8750},
      },
      {
        'name': 'Apollo Emergency', 'email': 'apollo@demo.com', 'phone': '022-55667788',
        'role': 'hospital', 'bloodGroup': '', 'isAvailable': true,
        'location': {'lat': 19.0600, 'lng': 72.8650},
      },
    ];

    for (int i = 0; i < hospitals.length; i++) {
      final id = 'demo_hospital_${i + 1}';
      hospitals[i]['createdAt'] = Timestamp.now();
      await _db.collection('users').doc(id).set(hospitals[i], SetOptions(merge: true));
    }
  }

  static Future<void> _seedBloodBanks() async {
    final banks = [
      {
        'name': 'Red Cross Blood Bank', 'email': 'redcross@demo.com', 'phone': '022-99887766',
        'role': 'blood_bank', 'bloodGroup': '', 'isAvailable': true,
        'location': {'lat': 19.0780, 'lng': 72.8850},
      },
      {
        'name': 'National Blood Center', 'email': 'nbc@demo.com', 'phone': '022-11223344',
        'role': 'blood_bank', 'bloodGroup': '', 'isAvailable': true,
        'location': {'lat': 19.0700, 'lng': 72.8700},
      },
    ];

    for (int i = 0; i < banks.length; i++) {
      final id = 'demo_bank_${i + 1}';
      banks[i]['createdAt'] = Timestamp.now();
      await _db.collection('users').doc(id).set(banks[i], SetOptions(merge: true));
    }
  }

  static Future<void> _seedBloodRequests() async {
    final requests = [
      {
        'hospitalId': 'demo_hospital_1', 'hospitalName': 'City General Hospital',
        'bloodGroup': 'A+', 'units': 3, 'urgency': 'Critical', 'status': 'pending',
        'location': {'lat': 19.0730, 'lng': 72.8800},
        'notes': 'Patient in ICU, needs urgent transfusion',
        'createdAt': Timestamp.now(),
        'notifiedDonorIds': <String>[], 'rejectedDonorIds': <String>[],
      },
      {
        'hospitalId': 'demo_hospital_2', 'hospitalName': 'LifeCare Medical Center',
        'bloodGroup': 'O+', 'units': 2, 'urgency': 'Urgent', 'status': 'pending',
        'location': {'lat': 19.0850, 'lng': 72.8750},
        'notes': 'Surgery scheduled tomorrow morning',
        'createdAt': Timestamp.now(),
        'notifiedDonorIds': <String>[], 'rejectedDonorIds': <String>[],
      },
      {
        'hospitalId': 'demo_hospital_3', 'hospitalName': 'Apollo Emergency',
        'bloodGroup': 'B+', 'units': 1, 'urgency': 'SOS', 'status': 'accepted',
        'assignedDonorId': 'demo_donor_2', 'assignedDonorName': 'Priya Sharma',
        'location': {'lat': 19.0600, 'lng': 72.8650},
        'notes': 'Emergency accident case',
        'createdAt': Timestamp.now(),
        'notifiedDonorIds': <String>[], 'rejectedDonorIds': <String>[],
      },
      {
        'hospitalId': 'demo_hospital_1', 'hospitalName': 'City General Hospital',
        'bloodGroup': 'AB-', 'units': 4, 'urgency': 'Normal', 'status': 'pending',
        'location': {'lat': 19.0730, 'lng': 72.8800},
        'notes': 'Scheduled surgery next week, building stock',
        'createdAt': Timestamp.now(),
        'notifiedDonorIds': <String>[], 'rejectedDonorIds': <String>[],
      },
      {
        'hospitalId': 'demo_hospital_2', 'hospitalName': 'LifeCare Medical Center',
        'bloodGroup': 'O-', 'units': 2, 'urgency': 'Critical', 'status': 'pending',
        'location': {'lat': 19.0850, 'lng': 72.8750},
        'notes': 'Rare blood type needed for transplant',
        'createdAt': Timestamp.now(),
        'notifiedDonorIds': <String>[], 'rejectedDonorIds': <String>[],
      },
    ];

    for (int i = 0; i < requests.length; i++) {
      await _db.collection('requests').doc('demo_request_${i + 1}').set(
          requests[i], SetOptions(merge: true));
    }

    // Seed some inventory for blood banks
    final inventory = [
      {'bloodBankId': 'demo_bank_1', 'bloodBankName': 'Red Cross Blood Bank', 'bloodGroup': 'A+', 'units': 25,
        'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)))},
      {'bloodBankId': 'demo_bank_1', 'bloodBankName': 'Red Cross Blood Bank', 'bloodGroup': 'B+', 'units': 18,
        'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 20)))},
      {'bloodBankId': 'demo_bank_1', 'bloodBankName': 'Red Cross Blood Bank', 'bloodGroup': 'O+', 'units': 12,
        'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 15)))},
      {'bloodBankId': 'demo_bank_2', 'bloodBankName': 'National Blood Center', 'bloodGroup': 'AB+', 'units': 8,
        'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 25)))},
      {'bloodBankId': 'demo_bank_2', 'bloodBankName': 'National Blood Center', 'bloodGroup': 'O-', 'units': 5,
        'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 10)))},
    ];

    for (int i = 0; i < inventory.length; i++) {
      inventory[i]['createdAt'] = Timestamp.now();
      await _db.collection('bloodInventory').doc('demo_inv_${i + 1}').set(
          inventory[i], SetOptions(merge: true));
    }
  }
}

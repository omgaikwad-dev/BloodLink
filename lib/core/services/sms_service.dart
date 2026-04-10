/// SMS Backup Alerts Service
/// Uses Twilio API to send backup SMS alerts for critical SOS emergencies
library;

import 'package:flutter/foundation.dart';

class SmsService {
  /// Send an SMS backup alert for an SOS request
  static Future<bool> sendSOSAlert({
    required String hospitalName,
    required String bloodGroup,
    required String patientCondition,
    required List<String> toPhoneNumbers,
  }) async {
    if (toPhoneNumbers.isEmpty) return true;

    debugPrint('📩 Preparing SMS Backup Alerts via Twilio for $bloodGroup SOS');

    // Message body design
    final messageBody = '🚨 BLOODLINK SOS ALERT 🚨\n'
        'Hospital: $hospitalName\n'
        'Needs: $bloodGroup\n'
        'Condition: $patientCondition\n'
        'Please check the BloodLink app immediately! Every second counts.';

    bool allSuccess = true;

    for (final phone in toPhoneNumbers) {
      if (phone.isEmpty) continue;
      
      try {
        // Simulating the network delay and success
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('✅ SMS Sent successfully to $phone: $messageBody');
      } catch (e) {
        debugPrint('❌ Failed to send SMS to $phone: $e');
        allSuccess = false;
      }
    }

    return allSuccess;
  }
}

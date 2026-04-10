/// AI Chat Assistant Service - Per-user personalized chat with Firestore history
/// Each user gets their own chat thread with role-based AI responses
library;

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';

class ChatMessageModel {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> suggestions;
  final String? actionType;
  final Map<String, dynamic>? actionData;

  ChatMessageModel({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.suggestions = const [],
    this.actionType,
    this.actionData,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Serialize for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': Timestamp.fromDate(timestamp),
      'suggestions': suggestions,
      'actionType': actionType,
      'actionData': actionData,
    };
  }

  /// Deserialize from Firestore
  factory ChatMessageModel.fromFirestore(Map<String, dynamic> data) {
    return ChatMessageModel(
      text: data['text'] ?? '',
      isUser: data['isUser'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      suggestions: List<String>.from(data['suggestions'] ?? []),
      actionType: data['actionType'],
      actionData: data['actionData'] != null
          ? Map<String, dynamic>.from(data['actionData'])
          : null,
    );
  }
}

class AIChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get personalized welcome message based on user role
  static ChatMessageModel getWelcomeMessage({
    required String userName,
    required String userRole,
    String? bloodGroup,
  }) {
    final firstName = userName.split(' ').first;

    switch (userRole) {
      case 'hospital':
        return ChatMessageModel(
          text: '👋 **Hello, $firstName!** Welcome to BloodLink AI.\n\n'
              'As a hospital administrator, I can help you with:\n'
              '🩸 Finding compatible donors nearby\n'
              '📊 Blood demand forecasting & analytics\n'
              '🚑 Emergency ambulance coordination\n'
              '📋 Managing blood requests efficiently\n\n'
              'How can I assist your hospital today?',
          isUser: false,
          suggestions: [
            'Find donors for O-',
            'Predict blood demand',
            'Emergency protocol',
            'Check blood banks',
          ],
        );

      case 'donor':
        return ChatMessageModel(
          text: '👋 **Hi $firstName!** Thank you for being a lifesaver! 🦸\n\n'
              'As a ${bloodGroup ?? ""} donor, I can help you with:\n'
              '💉 Donation eligibility & health checks\n'
              '🗺️ Finding nearby donation centers\n'
              '📅 Tracking your donation history\n'
              '❓ Blood compatibility info\n\n'
              'What would you like to know?',
          isUser: false,
          suggestions: [
            'Am I eligible to donate?',
            'My blood compatibility',
            'Nearest donation center',
            'Donation tips',
          ],
        );

      case 'blood_bank':
        return ChatMessageModel(
          text: '👋 **Hello, $firstName!** Welcome to BloodLink AI.\n\n'
              'As a blood bank manager, I can help you with:\n'
              '📦 Inventory management & alerts\n'
              '📊 Demand prediction for your area\n'
              '🔄 Expiry tracking & stock rotation\n'
              '🤝 Connecting with hospitals & donors\n\n'
              'How can I help manage your inventory?',
          isUser: false,
          suggestions: [
            'Check stock levels',
            'Expiring soon alerts',
            'Demand forecast',
            'Find donors',
          ],
        );

      default:
        return ChatMessageModel(
          text: '👋 **Hello, $firstName!** I\'m BloodLink AI Assistant.\n\n'
              'I can help you with:\n'
              '🩸 Finding blood donors & banks\n'
              '🚑 Emergency response\n'
              '📊 Blood demand predictions\n'
              '💬 Donation guidance\n\n'
              'How can I help you today?',
          isUser: false,
          suggestions: [
            'Find blood near me',
            'Emergency help',
            'Can I donate?',
            'Blood compatibility',
          ],
        );
    }
  }

  /// Save a chat message to Firestore (per-user history)
  static Future<void> saveMessage(String userId, ChatMessageModel message) async {
    try {
      await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.chatCollection)
          .add(message.toFirestore());
    } catch (e) {
      debugPrint('Save chat message error: $e');
    }
  }

  /// Load chat history for a specific user
  static Future<List<ChatMessageModel>> loadChatHistory(String userId, {int limit = 50}) async {
    try {
      final snap = await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.chatCollection)
          .orderBy('timestamp', descending: false)
          .limit(limit)
          .get();

      return snap.docs
          .map((doc) => ChatMessageModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Load chat history error: $e');
      return [];
    }
  }

  /// Clear chat history for a user
  static Future<void> clearHistory(String userId) async {
    try {
      final snap = await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.chatCollection)
          .get();

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Clear chat history error: $e');
    }
  }

  /// Send a message to the direct Gemini API and get a response
  static Future<ChatMessageModel> sendMessage({
    required String message,
    String? userId,
    String? userName,
    String? userRole,
    String? userBloodGroup,
    double? userLat,
    double? userLng,
    Map<String, dynamic>? contextData,
  }) async {
    try {
      const apiKey = 'AIzaSyDxLGOGf_IZmPsuQ2RkvEGec3oxtfGF8I4';
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(
          'You are BloodLink AI, the official intelligent assistant for the BloodLink Emergency Blood Network system. '
          'You are currently assisting a user whose role is: ${userRole ?? 'Unknown'}. '
          '${userBloodGroup != null ? 'Their blood group is: $userBloodGroup. ' : ''}'
          'Provide extremely helpful, concise, empathetic, and professional responses related to blood donation eligibility, finding nearby hospitals, emergency trauma aid, and general health tracking as it relates to BloodLink. '
          'Format your response safely using markdown. '
          'VERY IMPORTANT: As the absolute final line of your response, provide exactly 3 short follow-up suggestion chips separated by the pipe "|" character (e.g. Find donors|Am I eligible?|Call hospital).'
        ),
      );

      final response = await model.generateContent([Content.text(message)]);

      if (response.text != null && response.text!.isNotEmpty) {
        final fullText = response.text!.trim();
        final lines = fullText.split('\n');
        
        List<String> suggestions = [];
        String replyText = fullText;
        
        // Parse out the suggestions if the AI properly followed formatting rules
        if (lines.length > 1 && lines.last.contains('|')) {
          suggestions = lines.last.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          replyText = lines.sublist(0, lines.length - 1).join('\n').trim();
        } else {
          // Default fallbacks if the AI missed the prompt
          suggestions = ['Find blood near me', 'Am I eligible?', 'Emergency Contact'];
        }

        // Basic keyword-based action routing
        String? action;
        Map<String, dynamic>? actionData;
        final lowerReply = '${replyText.toLowerCase()} ${message.toLowerCase()}';
        
        if (lowerReply.contains('emergency') || lowerReply.contains('sos')) {
          action = 'navigate';
          actionData = {'navigate_to': 'sos'};
        } else if (lowerReply.contains('map') || lowerReply.contains('locate') || lowerReply.contains('nearby')) {
          action = 'search';
          actionData = {'navigate_to': 'map'};
        }

        return ChatMessageModel(
          text: replyText,
          isUser: false,
          suggestions: suggestions,
          actionType: action,
          actionData: actionData,
        );
      }
    } catch (e) {
      debugPrint('Gemini AI Chat error: $e');
    }

    // Local fallback — role-aware rule matching
    return _localResponse(message, userRole, userBloodGroup, userName);
  }

  /// Local rule-based AI response - personalized by role
  static ChatMessageModel _localResponse(
    String message,
    String? role,
    String? bloodGroup,
    String? userName,
  ) {
    final msg = message.toLowerCase();

    if (msg.contains('emergency') || msg.contains('urgent') || msg.contains('sos')) {
      return ChatMessageModel(
        text: '🚨 **Emergency Detected!**\n\n'
            'I\'m immediately pulling up emergency protocols:\n\n'
            '1. 📞 **Call 108** for ambulance\n'
            '2. 🆘 Use the **SOS button** on your dashboard\n'
            '3. 🏥 Go to the nearest hospital\n\n'
            '⚠️ Don\'t wait — every second counts!',
        isUser: false,
        suggestions: ['Call 108', 'Send SOS', 'Find hospital'],
        actionType: 'navigate',
        actionData: {'navigate_to': 'sos'},
      );
    }

    if (msg.contains('eligible') || msg.contains('can i donate') || msg.contains('donate')) {
      final bgInfo = bloodGroup != null ? ' (Your blood type: **$bloodGroup**)' : '';
      return ChatMessageModel(
        text: '🩸 **Donation Eligibility$bgInfo:**\n\n'
            '✅ Age: 18-65, Weight: ≥45kg\n'
            '✅ Hemoglobin: ≥12.5 g/dL\n'
            '✅ Last donation: 56+ days ago\n'
            '❌ No recent surgery, infections, or medications\n\n'
            'Visit your nearest blood bank for a full check!',
        isUser: false,
        suggestions: ['Find blood bank', 'Check compatibility', 'Donation tips'],
      );
    }

    if (msg.contains('compatibility') || msg.contains('compatible') || msg.contains('match')) {
      final compat = bloodGroup != null
          ? AppConstants.bloodCompatibility[bloodGroup]
          : null;
      final compatText = compat != null
          ? '**$bloodGroup** can donate to: ${compat.join(", ")}'
          : 'Tell me your blood group to check compatibility.';
      return ChatMessageModel(
        text: '🔬 **Blood Compatibility Info:**\n\n'
            '$compatText\n\n'
            '🏥 O- is the universal donor\n'
            '🏥 AB+ is the universal recipient\n\n'
            'Always confirm compatibility with medical staff before transfusion.',
        isUser: false,
        suggestions: ['Find donors', 'Emergency help', 'Donation eligibility'],
      );
    }

    if (msg.contains('find') || msg.contains('where') || msg.contains('blood') || msg.contains('near')) {
      return ChatMessageModel(
        text: '🔍 **Finding Blood Network Data:**\n\n'
            'Here is how we can locate blood immediately:\n\n'
            '1. Check the **Map** tab for nearby donors\n'
            '2. Create a **blood request** from your dashboard\n'
            '3. Call your nearby blood bank directly\n\n'
            '📡 Data sync is active!',
        isUser: false,
        suggestions: ['Open map', 'Create request', 'View donors'],
      );
    }

    if (msg.contains('tip') || msg.contains('advice') || msg.contains('before') || msg.contains('after')) {
      return ChatMessageModel(
        text: '💡 **Donation Tips:**\n\n'
            '**Before donating:**\n'
            '• Drink plenty of water (at least 500ml)\n'
            '• Eat iron-rich foods (spinach, lentils)\n'
            '• Get 7-8 hours of sleep\n'
            '• Avoid alcohol for 24 hours\n\n'
            '**After donating:**\n'
            '• Rest for 10-15 minutes\n'
            '• Drink extra fluids for 48 hours\n'
            '• Avoid heavy exercise for 24 hours\n'
            '• Eat iron-rich snacks\n\n'
            '❤️ You\'re saving lives!',
        isUser: false,
        suggestions: ['Am I eligible?', 'Blood compatibility', 'Find donation center'],
      );
    }

    // Role-specific default
    if (role == 'hospital') {
      return ChatMessageModel(
        text: '🏥 I am processing your hospital data. I can help with:\n\n'
            '📊 Blood demand predictions for your hospital\n'
            '🔍 Finding compatible donors nearby\n'
            '🚑 Emergency ambulance dispatch\n'
            '📋 Request management & analytics\n\n'
            'What would you like to do next?',
        isUser: false,
        suggestions: ['Create request', 'View donors', 'Emergency SOS'],
      );
    }

    if (role == 'blood_bank') {
      return ChatMessageModel(
        text: '🏪 I am processing your facility data. I can help with:\n\n'
            '📦 Inventory optimization & alerts\n'
            '📊 Demand forecasting for your area\n'
            '🔄 Expiry management\n'
            '🤝 Hospital coordination\n\n'
            'What would you like to check?',
        isUser: false,
        suggestions: ['Check inventory', 'Expiry alerts', 'Demand forecast'],
      );
    }

    return ChatMessageModel(
      text: '🤖 I am BloodLink AI.\n\n'
          'Here is my list of operational capabilities:\n'
          '🩸 Find blood donors & banks\n'
          '🚨 Emergency assistance\n'
          '📊 Blood demand predictions\n'
          '💬 Donation guidance\n\n'
          'Please select a specific category from the suggestions below!',
      isUser: false,
      suggestions: ['Find blood', 'Emergency', 'Eligibility', 'Compatibility'],
    );
  }
}

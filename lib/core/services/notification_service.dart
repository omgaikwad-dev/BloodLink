/// Notification service - handles FCM and local notifications
/// On Web: Firebase Messaging is skipped (requires service worker + VAPID key)
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize notification services
  Future<void> initialize() async {
    // Firebase Messaging is not supported on web without a service worker + VAPID key
    if (kIsWeb) {
      debugPrint('NotificationService: Skipping FCM init on web platform.');
      return;
    }

    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    // Initialize local notifications (Android / iOS only)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings);

    // Create notification channels for Android
    await _createNotificationChannels();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  }

  /// Get FCM token (returns null on web)
  Future<String?> getToken() async {
    if (kIsWeb) return null;
    return await _messaging.getToken();
  }

  /// Subscribe to topic (no-op on web)
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) return;
    await _messaging.subscribeToTopic(topic);
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    const sosChannel = AndroidNotificationChannel(
      'sos_channel',
      'SOS Alerts',
      description: 'Critical SOS emergency blood requests',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    const requestChannel = AndroidNotificationChannel(
      'request_channel',
      'Blood Requests',
      description: 'Blood request notifications',
      importance: Importance.high,
    );

    const generalChannel = AndroidNotificationChannel(
      'general_channel',
      'General',
      description: 'General notifications',
      importance: Importance.defaultImportance,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(sosChannel);
      await androidPlugin.createNotificationChannel(requestChannel);
      await androidPlugin.createNotificationChannel(generalChannel);
    }
  }

  /// Show local notification (no-op on web)
  Future<void> showNotification({
    required String title,
    required String body,
    String channelId = 'general_channel',
    Map<String, String>? payload,
  }) async {
    if (kIsWeb) {
      debugPrint('NotificationService: [$title] $body');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'sos_channel' ? 'SOS Alerts' : 'Blood Requests',
      importance: channelId == 'sos_channel' ? Importance.max : Importance.high,
      priority: channelId == 'sos_channel' ? Priority.max : Priority.high,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    final channelId = message.data['urgency'] == 'SOS'
        ? 'sos_channel'
        : 'request_channel';

    showNotification(
      title: message.notification?.title ?? 'BloodLink AI',
      body: message.notification?.body ?? '',
      channelId: channelId,
    );
  }

  /// Send push notification via FCM Legacy API
  Future<void> sendTopicNotification({
    required String topic,
    required String title,
    required String body,
    String urgency = 'Normal',
  }) async {
    try {
      const String fcmServerKey = 'YOUR_FCM_SERVER_KEY_HERE';

      if (fcmServerKey == 'YOUR_FCM_SERVER_KEY_HERE') {
        debugPrint('FCM sending skipped: Provide a valid server key.');
        return;
      }

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=$fcmServerKey',
        },
        body: jsonEncode(
          <String, dynamic>{
            'notification': <String, dynamic>{
              'title': title,
              'body': body,
              'android_channel_id': urgency == 'SOS' ? 'sos_channel' : 'request_channel',
              'sound': 'default',
              'icon': '@mipmap/ic_launcher',
            },
            'priority': 'high',
            'data': <String, dynamic>{
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'urgency': urgency,
            },
            'to': '/topics/$topic',
          },
        ),
      );

      if (response.statusCode == 200) {
        debugPrint('Topic notification sent successfully');
      } else {
        debugPrint('FCM Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to send topic notification: $e');
    }
  }
}

/// Background message handler (must be top-level, Android/iOS only)
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  // Handle background message
}

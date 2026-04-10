/// Notification service - handles FCM and local notifications
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize notification services
  Future<void> initialize() async {
    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    // Initialize local notifications
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

  /// Get FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
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

  /// Show local notification
  Future<void> showNotification({
    required String title,
    required String body,
    String channelId = 'general_channel',
    Map<String, String>? payload,
  }) async {
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
}

/// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  // Handle background message
}

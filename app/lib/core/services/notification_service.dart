import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'events_channel',
  'Event Notifications',
  description: 'Notifications for new DPSG events',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseMessaging.instance.setAutoInitEnabled(true);
  log('Handling a background message: ${message.messageId}');
}

class NotificationService {
  Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _requestPermission();
    await _handleInitialMessage();
    _listenToForegroundMessages();
    _listenToMessageOpenedApp();
  }

  Future<void> _initializeLocalNotifications() async {
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIos = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIos,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (details) {
      log('Local notification tapped: ${details.payload}');
    });

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

  }

  Future<void> _requestPermission() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    log('Notification permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await messaging.registerForRemoteNotifications();
      final hasApnsToken = await _ensureApnsTokenAvailable();

      final fcmToken = await messaging.getToken();
      log('FCM token: $fcmToken');

      if (hasApnsToken) {
        await _subscribeToTopic();
      } else {
        log('Skipping topic subscription because APNS token is not available yet');
      }
    }
  }

  Future<bool> _ensureApnsTokenAvailable() async {
    const maxRetries = 5;
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        log('APNS token: $apnsToken');
        return true;
      }
      log('APNS token not yet available, retrying (${attempt + 1}/$maxRetries)');
      await Future.delayed(const Duration(seconds: 1));
    }
    log('APNS token still not available after retries');
    return false;
  }

  Future<void> _subscribeToTopic() async {
    await FirebaseMessaging.instance.subscribeToTopic('events');
    log('Subscribed to topic: events');
  }

  Future<void> _handleInitialMessage() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      log('App opened from notification: ${initialMessage.messageId}');
    }
  }

  void _listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) {
      log('Foreground message received: ${message.messageId}');
      _showLocalNotification(message);
    });
  }

  void _listenToMessageOpenedApp() {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      log('Notification opened app: ${message.messageId}');
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    if (notification.title == null && notification.body == null) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['eventId'],
    );
  }
}

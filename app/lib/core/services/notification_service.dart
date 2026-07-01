import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apnsTokenProvider = StateProvider<String?>((ref) => null);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
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
  NotificationService(this._ref);

  final Ref _ref;

  Future<void> initialize() async {
    log('NotificationService: initialize started');
    await _initializeLocalNotifications();
    await _requestPermission();
    await _handleInitialMessage();
    _listenToForegroundMessages();
    _listenToMessageOpenedApp();
    _listenToTokenRefresh();
    log('NotificationService: initialize finished');
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
      final apnsAvailable = await _ensureApnsTokenAvailable();
      if (!apnsAvailable) {
        log('APNS token not available before fetching FCM token');
      }

      await _logDeviceTokens();

      String? fcmToken;
      try {
        fcmToken = await messaging.getToken();
      } catch (error, stack) {
        log('Failed to fetch FCM token: $error');
        log('$stack');
      }
      log('FCM token: $fcmToken');

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _subscribeToTopic();
      } else {
        log('Skipping topic subscription because FCM token is not available yet');
      }
    }
  }

  Future<bool> _ensureApnsTokenAvailable() async {
    const maxRetries = 5;
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) {
          _ref.read(apnsTokenProvider.notifier).state = apnsToken;
          return true;
        }
      } catch (error, stack) {
        log('Failed to read APNS token: $error');
        log('$stack');
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

  Future<void> _logDeviceTokens() async {
    final messaging = FirebaseMessaging.instance;

    try {
      final fcmToken = await messaging.getToken();
      log('Device FCM token: $fcmToken');
    } catch (error, stack) {
      log('Failed to read device FCM token: $error');
      log('$stack');
    }

    try {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        _ref.read(apnsTokenProvider.notifier).state = apnsToken;
      }
    } catch (error, stack) {
      log('Failed to read device APNS token: $error');
      log('$stack');
    }
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

  void _listenToTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      log('FCM token refreshed: $token');
      if (token.isNotEmpty) {
        await _subscribeToTopic();
      }
    }, onError: (error, stack) {
      log('Failed to refresh FCM token: $error');
      log('$stack');
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

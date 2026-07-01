import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/settings_repository.dart';

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

      String? fcmToken;
      try {
        fcmToken = await messaging.getToken();
      } catch (error, stack) {
        log('Failed to fetch FCM token: $error');
        log('$stack');
      }
      log('FCM token: $fcmToken');

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await refreshTopicSubscriptions();
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

  Future<void> _subscribeToTopics(List<String> topics) async {
    final messaging = FirebaseMessaging.instance;
    for (final topic in topics) {
      try {
        await messaging.subscribeToTopic(topic);
        log('Subscribed to topic: $topic');
      } catch (error, stack) {
        log('Failed to subscribe to topic $topic: $error');
        log('$stack');
      }
    }
  }

  Future<void> _unsubscribeFromTopics(List<String> topics) async {
    final messaging = FirebaseMessaging.instance;
    for (final topic in topics) {
      try {
        await messaging.unsubscribeFromTopic(topic);
        log('Unsubscribed from topic: $topic');
      } catch (error, stack) {
        log('Failed to unsubscribe from topic $topic: $error');
        log('$stack');
      }
    }
  }

  Future<void> refreshTopicSubscriptions() async {
    log('Refreshing notification topic subscriptions');
    final settingsRepository = _ref.read(settingsRepositoryProvider);
    final selectedDvs = settingsRepository.getSelectedDvs();
    final selectedTopicsByDv = settingsRepository.getSelectedTopicsByDv();
    final topics = <String>{'events'};

    for (final dv in selectedDvs) {
      topics.add('events_${_normalizeTopicName(dv)}');
      final selectedTopics = selectedTopicsByDv[dv] ?? <String>[];
      for (final topic in selectedTopics) {
        topics.add('events_${_normalizeTopicName(dv)}_${_normalizeTopicName(topic)}');
      }
    }

    final newTopics = topics.toList();
    final currentTopics = settingsRepository.getSubscribedTopics();
    final removeTopics = currentTopics.where((topic) => !newTopics.contains(topic)).toList();
    final addTopics = newTopics.where((topic) => !currentTopics.contains(topic)).toList();

    if (removeTopics.isNotEmpty) {
      await _unsubscribeFromTopics(removeTopics);
    }
    if (addTopics.isNotEmpty) {
      await _subscribeToTopics(addTopics);
    }

    await settingsRepository.setSubscribedTopics(newTopics);
  }

  String _normalizeTopicName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
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
        await refreshTopicSubscriptions();
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

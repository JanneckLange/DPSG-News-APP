import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/settings_repository.dart';
import 'sync_service.dart' as sync_service;

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
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
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
    for (final topic in topics) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
        log('Subscribed to topic: $topic');
      } catch (error, stack) {
        log('Failed to subscribe to topic $topic: $error');
        log('$stack');
      }
    }
  }

  Future<void> _unsubscribeFromTopics(List<String> topics) async {
    for (final topic in topics) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
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
    final notificationsEnabled = settingsRepository.getNotificationsEnabled();
    final newEventPushEnabled = settingsRepository.getNewEventPushEnabled();
    final currentTopics = settingsRepository.getSubscribedTopics();

    if (!notificationsEnabled || !newEventPushEnabled) {
      if (currentTopics.isNotEmpty) {
        await _unsubscribeFromTopics(currentTopics);
      }
      await settingsRepository.setSubscribedTopics(<String>[]);
      return;
    }

    final selectedLayerIds = settingsRepository.getSelectedLayerIds();
    final selectedTopicIdsByLayer =
        settingsRepository.getSelectedTopicsByLayer();
    final savedEventIds = settingsRepository.getSavedEventIds();
    final topics = <String>{'events'};

    final hasTopicSelections =
        selectedTopicIdsByLayer.values.any((ids) => ids.isNotEmpty);
    final topicNameById = hasTopicSelections
        ? await _fetchTopicNamesById()
        : const <int, String>{};

    for (final layerId in selectedLayerIds) {
      topics.add('events_layer_$layerId');
      final selectedTopicIds = selectedTopicIdsByLayer[layerId] ?? <int>[];
      for (final topicId in selectedTopicIds) {
        final topicName = topicNameById[topicId];
        if (topicName == null) continue;
        topics.add('events_layer_${layerId}_${_normalizeTopicName(topicName)}');
      }
    }

    for (final eventId in savedEventIds) {
      topics.add('event_${_normalizeTopicName(eventId)}');
    }

    final newTopics = topics.toList();
    final removeTopics =
        currentTopics.where((topic) => !newTopics.contains(topic)).toList();
    final addTopics =
        newTopics.where((topic) => !currentTopics.contains(topic)).toList();

    if (removeTopics.isNotEmpty) {
      await _unsubscribeFromTopics(removeTopics);
    }
    if (addTopics.isNotEmpty) {
      await _subscribeToTopics(addTopics);
    }

    await settingsRepository.setSubscribedTopics(newTopics);
  }

  /// Loest die lokal nur als ID gespeicherten Topic-Auswahlen zu Namen auf,
  /// damit sich das FCM-Topic-String-Format (basiert auf dem Namen) nicht
  /// aendert. Schlaegt der Abruf fehl, werden betroffene Topic-IDs beim
  /// naechsten Refresh einfach erneut versucht (keine harte Fehlerausgabe).
  Future<Map<int, String>> _fetchTopicNamesById() async {
    try {
      final remote = _ref.read(sync_service.remoteEventSourceProvider);
      final response = await remote.fetchTopics();
      final topics =
          List<Map<String, dynamic>>.from(response['topics'] as List<dynamic>);
      return {
        for (final topic in topics)
          (topic['id'] as num).toInt(): topic['name'] as String,
      };
    } catch (error, stack) {
      log('Failed to fetch topic names for subscription refresh: $error');
      log('$stack');
      return const <int, String>{};
    }
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

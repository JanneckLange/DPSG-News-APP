import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/services/analytics_service.dart';
import 'core/services/hive_service.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    await dotenv.load(fileName: '.env.example');
  }

  await initializeDateFormatting('de');

  try {
    await Firebase.initializeApp();
  } catch (_) {
    rethrow;
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await HiveService.initialize();

  final errorContainer = ProviderContainer();
  final startupAnalytics = errorContainer.read(analyticsServiceProvider);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      startupAnalytics.trackError(
        details.exceptionAsString(),
        screen: details.context?.toDescription() ?? 'app',
        context: 'flutter_error',
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      startupAnalytics.trackError(
        error.toString(),
        screen: 'app',
        context: 'platform_dispatcher',
      ),
    );
    return true;
  };

  runApp(const ProviderScope(child: App()));
}

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

final loggingServiceProvider = Provider<LoggingService>((ref) => LoggingService());

class LoggingService {
  void logEvent(String event, {Map<String, Object?>? properties}) {
    final payload = properties == null ? event : '$event $properties';
    developer.log('event: $payload');
  }

  void logError(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log('error: $message', error: error, stackTrace: stackTrace);
  }
}

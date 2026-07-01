import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get defaultApiBaseUrl {
    final dotenvValue = _readDotenv('API_BASE_URL');
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    const compileTimeValue = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (compileTimeValue.isNotEmpty) {
      return compileTimeValue;
    }

    return Platform.environment['API_BASE_URL'] ?? 'https://dpsgnews.scout-link.de';
  }

  static String get wiredashProjectId {
    final dotenvValue = _readDotenv('WIREDASH_PROJECT_ID');
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    return const String.fromEnvironment('WIREDASH_PROJECT_ID', defaultValue: '');
  }

  static String get wiredashSecret {
    final dotenvValue = _readDotenv('WIREDASH_SECRET');
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    return const String.fromEnvironment('WIREDASH_SECRET', defaultValue: '');
  }

  static bool get hasWiredashConfig => wiredashProjectId.isNotEmpty && wiredashSecret.isNotEmpty;

  static String? _readDotenv(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
}

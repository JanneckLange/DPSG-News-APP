import 'dart:io';

class AppConfig {
  static String get defaultApiBaseUrl {
    const compileTimeValue = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (compileTimeValue.isNotEmpty) {
      return compileTimeValue;
    }

    return Platform.environment['API_BASE_URL'] ?? 'http://localhost:3000';
  }
}

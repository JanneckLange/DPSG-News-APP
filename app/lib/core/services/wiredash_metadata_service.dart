import 'package:flutter/material.dart';

class WiredashMetadataService {
  const WiredashMetadataService._();

  static Map<String, Object?> buildSafeCustomMetadata({
    required Locale locale,
    required TargetPlatform platform,
    required bool isReleaseMode,
    required String appThemeMode,
    required bool isLoggedIn,
    required int displayedEventCount,
    required List<String> selectedDvs,
  }) {
    return {
      'locale': locale.toLanguageTag(),
      'platform': platform.name,
      'environment': isReleaseMode ? 'release' : 'debug',
      'theme_mode': appThemeMode,
      'is_logged_in': isLoggedIn,
      'displayed_event_count': displayedEventCount,
      'selected_dvs': selectedDvs,
    };
  }
}

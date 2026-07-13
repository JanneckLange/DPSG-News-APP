import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/core/services/wiredash_metadata_service.dart';

void main() {
  test('builds privacy-safe Wiredash metadata without personal data', () {
    final metadata = WiredashMetadataService.buildSafeCustomMetadata(
      locale: const Locale('de', 'DE'),
      platform: TargetPlatform.android,
      isReleaseMode: true,
      appThemeMode: 'dark',
      isLoggedIn: true,
      displayedEventCount: 7,
      selectedDvs: ['DV1', 'DV2'],
    );

    expect(metadata['locale'], 'de-DE');
    expect(metadata['platform'], 'android');
    expect(metadata['environment'], 'release');
    expect(metadata['theme_mode'], 'dark');
    expect(metadata['is_logged_in'], isTrue);
    expect(metadata['displayed_event_count'], 7);
    expect(metadata['selected_dvs'], ['DV1', 'DV2']);
    expect(metadata.containsKey('user_id'), isFalse);
    expect(metadata.containsKey('email'), isFalse);
  });
}

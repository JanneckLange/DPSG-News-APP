import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/core/services/hive_service.dart';

void main() {
  test('initialize opens the settings and events boxes with an explicit path',
      () async {
    final tempDir = Directory.systemTemp.createTempSync('hive_service_test');
    await HiveService.initialize(path: tempDir.path);

    final settingsBox = HiveService.getSettingsBox();
    final eventsBox = HiveService.getEventsBox();

    expect(settingsBox.isOpen, isTrue);
    expect(eventsBox.isOpen, isTrue);

    await settingsBox.put('theme', 'dark');
    expect(HiveService.getSettingsBox().get('theme'), 'dark');

    await eventsBox.put('cached', ['event-1']);
    expect(HiveService.getEventsBox().get('cached'), ['event-1']);
  });

  test('close() closes both boxes so they can no longer be accessed',
      () async {
    final tempDir =
        Directory.systemTemp.createTempSync('hive_service_test_close');
    await HiveService.initialize(path: tempDir.path);
    expect(HiveService.getSettingsBox().isOpen, isTrue);

    await HiveService.close();

    expect(() => HiveService.getSettingsBox(), throwsA(anything));
    expect(() => HiveService.getEventsBox(), throwsA(anything));
  });
}

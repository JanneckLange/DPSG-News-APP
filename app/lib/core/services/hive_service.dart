import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class HiveService {
  static const String settingsBoxName = 'settings';
  static const String eventsBoxName = 'events';

  static Future<void> initialize({String? path}) async {
    final directoryPath = path ?? await _getHivePath();
    Hive.init(directoryPath);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox(eventsBoxName);
  }

  static Future<String> _getHivePath() async {
    try {
      final dir = await getApplicationDocumentsDirectory().timeout(
        const Duration(seconds: 2),
      );
      return dir.path;
    } catch (_) {
      final tempDir = Directory.systemTemp.createTempSync('dpsg_news_app_hive');
      return tempDir.path;
    }
  }

  static Box getSettingsBox() => Hive.box(settingsBoxName);

  static Box getEventsBox() => Hive.box(eventsBoxName);

  static Future<void> close() async {
    await Hive.close();
  }
}

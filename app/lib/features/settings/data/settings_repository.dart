import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/services/hive_service.dart';
import '../domain/layer_model.dart';
import 'settings_repository/settings_keys.dart';

part 'settings_repository/settings_repository_base.dart';
part 'settings_repository/notification_settings.dart';
part 'settings_repository/author_session_settings.dart';
part 'settings_repository/layer_tree_cache_settings.dart';
part 'settings_repository/settings_notifiers.dart';

class SettingsRepository extends _SettingsRepositoryBase
    with
        _NotificationSettings,
        _AuthorSessionSettings,
        _LayerTreeCacheSettings {
  static const int defaultSubscribedEventsReminderDaysBefore = 1;
  static const int defaultDeadlineReminderDaysBefore = 2;

  SettingsRepository(Box box) : super(box);
}

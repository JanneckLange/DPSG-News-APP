import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/events/data/event_repository.dart';
import '../../features/events/data/remote_event_source.dart';
import '../../features/settings/data/settings_repository.dart';
import 'hive_service.dart';
import 'logging_service.dart';
import '../config/app_config.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(HiveService.getSettingsBox());
});

final remoteEventSourceProvider = Provider<RemoteEventSource>((ref) {
  final settingsRepository = ref.watch(settingsRepositoryProvider);
  final configuredUrl = settingsRepository.getApiBaseUrl();
  final baseUrl = configuredUrl ?? AppConfig.defaultApiBaseUrl;
  return RemoteEventSource(baseUrl: Uri.parse(baseUrl));
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final repository = ref.read(eventRepositoryProvider);
  final remoteSource = ref.read(remoteEventSourceProvider);
  final logger = ref.read(loggingServiceProvider);
  return SyncService(repository, remoteSource, logger);
});

class SyncService {
  SyncService(this._repository, this._remoteSource, this._logger);

  final EventRepository _repository;
  final RemoteEventSource _remoteSource;
  final LoggingService _logger;

  Future<void> syncEvents() async {
    _logger.logEvent('events_sync_started');
    try {
      final events = await _remoteSource.fetchEvents();
      await _repository.saveEvents(events);
      _logger.logEvent('events_synced', properties: {'count': events.length});
    } catch (error, stackTrace) {
      _logger.logError('events_sync_failed', error: error, stackTrace: stackTrace);
    }
  }
}

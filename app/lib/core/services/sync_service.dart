import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/author/data/author_auth_provider.dart';
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
  final logger = ref.watch(loggingServiceProvider);
  final configuredUrl = settingsRepository.getApiBaseUrl();
  final baseUrl = configuredUrl ?? AppConfig.defaultApiBaseUrl;
  return RemoteEventSource(baseUrl: AppConfig.normalizeApiBaseUrl(baseUrl), logger: logger);
});

final eventSyncStatusProvider = StateProvider<String?>((_) => null);

final syncServiceProvider = Provider<SyncService>((ref) {
  final repository = ref.read(eventRepositoryProvider);
  final remoteSource = ref.read(remoteEventSourceProvider);
  final logger = ref.read(loggingServiceProvider);
  return SyncService(repository, remoteSource, logger, ref);
});

class SyncService {
  SyncService(this._repository, this._remoteSource, this._logger, this._ref);

  final EventRepository _repository;
  final RemoteEventSource _remoteSource;
  final LoggingService _logger;
  final Ref _ref;

  static const _minSyncInterval = Duration(seconds: 120);
  DateTime? _lastSyncedAt;

  /// Laedt Events vom Server und speichert sie lokal. Wird [force] nicht
  /// gesetzt, wird ein Aufruf innerhalb von [_minSyncInterval] seit dem
  /// letzten erfolgreichen Sync uebersprungen (z.B. beim Betreten der
  /// Events-Seite). Nutzeraktionen wie Pull-to-Refresh oder das
  /// Erstellen/Bearbeiten/Loeschen eines Events sollen [force] setzen, damit
  /// Aenderungen sofort sichtbar sind.
  Future<void> syncEvents({bool force = false}) async {
    if (!force &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      return;
    }
    _logger.logEvent('events_sync_started');
    _ref.read(eventSyncStatusProvider.notifier).state = null;
    try {
      final auth = _ref.read(authorAuthProvider);
      final token = auth.isLoggedIn
          ? await _ref.read(authorAuthProvider.notifier).getValidAccessToken()
          : null;
      final events = await _remoteSource.fetchEvents(token: token);
      await _repository.saveEvents(events);
      _lastSyncedAt = DateTime.now();
      _logger.logEvent('events_synced', properties: {'count': events.length});
    } catch (error, stackTrace) {
      _logger.logError('events_sync_failed', error: error, stackTrace: stackTrace);
      _ref.read(eventSyncStatusProvider.notifier).state = 'Server nicht erreichbar';
    }
  }
}

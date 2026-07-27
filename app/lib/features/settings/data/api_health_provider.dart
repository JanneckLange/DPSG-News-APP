import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/logging_service.dart';
import '../../events/data/remote_event_source.dart';

final apiHealthProvider =
    StateNotifierProvider<ApiHealthNotifier, ApiHealthStatus?>((ref) {
  return ApiHealthNotifier(ref.read(loggingServiceProvider));
});

class ApiHealthNotifier extends StateNotifier<ApiHealthStatus?> {
  ApiHealthNotifier(this._logger) : super(null);

  final LoggingService _logger;

  Future<void> refresh(String baseUrl) async {
    state = ApiHealthStatus(false, 'Prüfe Verbindung...');
    try {
      final uri = AppConfig.normalizeApiBaseUrl(baseUrl);
      final status =
          await RemoteEventSource(baseUrl: uri, logger: _logger).checkHealth();
      state = status;
    } catch (error) {
      state = ApiHealthStatus(false, 'Server nicht erreichbar');
    }
  }
}

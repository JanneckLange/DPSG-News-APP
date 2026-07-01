import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../events/data/remote_event_source.dart';
import '../../../core/services/sync_service.dart';
import 'settings_repository.dart' as settings_repo;

final dvTreeProvider = StateNotifierProvider<DvTreeNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  (ref) {
    final repository = ref.read(settingsRepositoryProvider);
    final remoteSource = ref.read(remoteEventSourceProvider);
    return DvTreeNotifier(repository, remoteSource);
  },
);

class DvTreeNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  DvTreeNotifier(this._repository, this._remoteSource) : super(const AsyncValue.loading()) {
    _loadTree();
  }

  final settings_repo.SettingsRepository _repository;
  final RemoteEventSource _remoteSource;

  Future<void> _loadTree() async {
    final localTree = _repository.getDvTree();
    if (localTree != null) {
      state = AsyncValue.data(localTree);
    }

    try {
      final response = await _remoteSource.fetchDvTree();
      final lastTreeChange = response['lastTreeChange'] as String? ?? '';
      final dvs = List<Map<String, dynamic>>.from(response['dvs'] as List<dynamic>);
      final currentVersion = _repository.getDvTreeLastChange();
      if (currentVersion == null || currentVersion != lastTreeChange) {
        await _repository.setDvTree(dvs, lastTreeChange);
      }
      state = AsyncValue.data(dvs);
    } catch (error, stackTrace) {
      if (localTree == null) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }
}

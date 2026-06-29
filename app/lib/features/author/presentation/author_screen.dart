import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/settings_repository.dart';
import '../../../core/services/hive_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(HiveService.getSettingsBox());
});

class AuthorScreen extends ConsumerWidget {
  const AuthorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(settingsRepositoryProvider);
    final isAuthorModeEnabled = repository.getAuthorMode();

    return Scaffold(
      appBar: AppBar(title: const Text('Autor')),
      body: Center(
        child: Text(
          isAuthorModeEnabled
              ? 'Autor-Modus ist aktiv.'
              : 'Aktiviere den Autor-Modus in den Einstellungen.',
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/logging_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(HiveService.getSettingsBox());
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(settingsRepositoryProvider);
    final logger = ref.watch(loggingServiceProvider);
    final selectedDv = repository.getSelectedDv();
    final authorMode = repository.getAuthorMode();

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Diözesanverband'),
            subtitle: Text(selectedDv ?? 'Nicht gesetzt'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final result = await _showDvDialog(context, repository);
              if (result != null) {
                logger.logEvent('dv_changed', properties: {'dv': result});
              }
            },
          ),
          SwitchListTile(
            title: const Text('Autor-Modus'),
            value: authorMode,
            onChanged: (value) async {
              await repository.setAuthorMode(value);
              logger.logEvent('author_mode_toggled', properties: {'enabled': value});
            },
          ),
        ],
      ),
    );
  }

  Future<String?> _showDvDialog(BuildContext context, SettingsRepository repository) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('DV auswählen'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'z. B. Köln'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  await repository.setSelectedDv(value);
                }
                if (context.mounted) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
  }
}

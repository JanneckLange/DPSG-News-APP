import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../../../core/services/logging_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../features/events/data/remote_event_source.dart';
import '../../../core/config/app_config.dart';

final apiHealthProvider = StateNotifierProvider<ApiHealthNotifier, ApiHealthStatus?>((ref) {
  return ApiHealthNotifier();
});

class ApiHealthNotifier extends StateNotifier<ApiHealthStatus?> {
  ApiHealthNotifier() : super(null);

  Future<void> refresh(String baseUrl) async {
    state = ApiHealthStatus(false, 'Prüfe Verbindung...');
    try {
      final uri = Uri.parse(baseUrl);
      final status = await RemoteEventSource(baseUrl: uri).checkHealth();
      state = status;
    } catch (error) {
      state = ApiHealthStatus(false, 'Server nicht erreichbar');
    }
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(settingsRepositoryProvider);
    final logger = ref.watch(loggingServiceProvider);
    final selectedDv = repository.getSelectedDv();
    final authorMode = ref.watch(authorModeProvider);
    final configuredUrl = repository.getApiBaseUrl();
    final effectiveUrl = configuredUrl ?? AppConfig.defaultApiBaseUrl;

    final apnsToken = ref.watch(apnsTokenProvider);
    final healthStatus = ref.watch(apiHealthProvider);

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
          ListTile(
            title: const Text('API-URL'),
            subtitle: Text(effectiveUrl),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              await _showApiUrlDialog(context, repository);
            },
          ),
          ListTile(
            title: const Text('API-Status'),
            subtitle: Text(
              healthStatus?.message ?? 'Nicht geprüft',
              style: TextStyle(
                color: healthStatus?.healthy == true ? Colors.green : Colors.red,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await ref.read(apiHealthProvider.notifier).refresh(effectiveUrl);
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('APNS-Token'),
            subtitle: Text(apnsToken ?? 'Noch nicht verfügbar'),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: apnsToken == null || apnsToken.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: apnsToken));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('APNS-Token kopiert')),
                        );
                      }
                    },
            ),
          ),
          SwitchListTile(
            title: const Text('Autor-Modus'),
            value: authorMode,
            onChanged: (value) async {
              await ref.read(authorModeProvider.notifier).setAuthorMode(value);
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

  Future<void> _showApiUrlDialog(BuildContext context, SettingsRepository repository) async {
    final controller = TextEditingController(text: repository.getApiBaseUrl() ?? AppConfig.defaultApiBaseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('API-URL ändern'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'https://example.com'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                final value = controller.text.trim();
                await repository.setApiBaseUrl(value.isEmpty ? null : value);
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

    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API-URL gespeichert.')),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../data/dv_tree_provider.dart';
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
    final selectedDvs = repository.getSelectedDvs();
    final authorMode = ref.watch(authorModeProvider);
    final configuredUrl = repository.getApiBaseUrl();
    final effectiveUrl = configuredUrl ?? AppConfig.defaultApiBaseUrl;

    final apnsToken = ref.watch(apnsTokenProvider);
    final healthStatus = ref.watch(apiHealthProvider);
    final dvTreeAsync = ref.watch(dvTreeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Diözesanverbaende'),
            subtitle: Text(selectedDvs.isEmpty ? 'Nicht gesetzt' : selectedDvs.join(', ')),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final changed = await _showDvDialog(context, ref, repository, dvTreeAsync);
              if (changed == true) {
                logger.logEvent('dv_changed', properties: {'dvs': repository.getSelectedDvs()});
                await ref.read(notificationServiceProvider).refreshTopicSubscriptions();
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

  Future<bool?> _showDvDialog(BuildContext context, WidgetRef ref, SettingsRepository repository, AsyncValue<List<Map<String, dynamic>>> dvTreeAsync) async {
    final selectedDvs = repository.getSelectedDvs().toSet();
    final selectedTopicsByDv = repository.getSelectedTopicsByDv();

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('DVs und Topics auswählen'),
              content: dvTreeAsync.when(
                data: (dvs) {
                  return SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: dvs.length,
                      itemBuilder: (context, index) {
                        final dv = dvs[index];
                        final dvName = dv['name'] as String;
                        final groups = (dv['groups'] as List<dynamic>?)?.whereType<String>().toList() ?? <String>[];
                        final isSelected = selectedDvs.contains(dvName);
                        final selectedTopics = selectedTopicsByDv[dvName] ?? <String>[];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              title: Text(dvName),
                              subtitle: dv['url'] != null ? Text(dv['url'] as String) : null,
                              value: isSelected,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    selectedDvs.add(dvName);
                                  } else {
                                    selectedDvs.remove(dvName);
                                    selectedTopicsByDv.remove(dvName);
                                  }
                                });
                              },
                            ),
                            if (isSelected && groups.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 16, bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        selectedTopics.isEmpty
                                            ? 'Keine spezifischen Topics ausgewählt.'
                                            : 'Topics: ${selectedTopics.join(', ')}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final updated = await _showTopicDialog(context, dvName, groups, selectedTopics);
                                        if (updated != null) {
                                          setState(() {
                                            selectedTopicsByDv[dvName] = updated;
                                          });
                                        }
                                      },
                                      child: const Text('Topics wählen'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('DV-Liste konnte nicht geladen werden.'),
                    const SizedBox(height: 16),
                    Text(error.toString()),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () async {
                    await repository.setSelectedDvs(selectedDvs.toList());
                    for (final dvName in selectedTopicsByDv.keys) {
                      if (selectedDvs.contains(dvName)) {
                        await repository.setSelectedTopicsForDv(dvName, selectedTopicsByDv[dvName] ?? <String>[]);
                      } else {
                        await repository.removeSelectedTopicsForDv(dvName);
                      }
                    }
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<String>?> _showTopicDialog(BuildContext context, String dvName, List<String> availableTopics, List<String> currentTopics) async {
    final selectedTopics = currentTopics.toSet();
    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Topics für $dvName auswählen'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableTopics.length,
                  itemBuilder: (context, index) {
                    final topic = availableTopics[index];
                    final isSelected = selectedTopics.contains(topic);
                    return CheckboxListTile(
                      title: Text(topic),
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selectedTopics.add(topic);
                          } else {
                            selectedTopics.remove(topic);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, selectedTopics.toList()),
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
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

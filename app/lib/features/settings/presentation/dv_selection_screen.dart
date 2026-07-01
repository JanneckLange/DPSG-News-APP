import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../data/dv_tree_provider.dart';
import '../data/settings_repository.dart';

class DvSelectionScreen extends ConsumerStatefulWidget {
  const DvSelectionScreen({super.key});

  @override
  ConsumerState<DvSelectionScreen> createState() => _DvSelectionScreenState();
}

class _DvSelectionScreenState extends ConsumerState<DvSelectionScreen> {
  late final Set<String> _selectedDvs;
  late final Map<String, List<String>> _selectedTopicsByDv;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(settingsRepositoryProvider);
    _selectedDvs = repository.getSelectedDvs().toSet();
    _selectedTopicsByDv = repository.getSelectedTopicsByDv();
  }

  @override
  Widget build(BuildContext context) {
    final dvTreeAsync = ref.watch(dvTreeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DVs und Topics'),
        actions: [
          TextButton(
            onPressed: _saveSelection,
            child: const Text('Speichern'),
          ),
        ],
      ),
      body: dvTreeAsync.when(
        data: (dvs) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: dvs.length,
            itemBuilder: (context, index) {
              final dv = dvs[index];
              final dvName = dv['name'] as String;
              final groups = (dv['groups'] as List<dynamic>?)?.whereType<String>().toList() ?? <String>[];
              final isSelected = _selectedDvs.contains(dvName);
              final selectedTopics = _selectedTopicsByDv[dvName] ?? <String>[];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        title: Text(dvName),
                        subtitle: dv['url'] != null ? Text(dv['url'] as String) : null,
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedDvs.add(dvName);
                            } else {
                              _selectedDvs.remove(dvName);
                              _selectedTopicsByDv.remove(dvName);
                            }
                          });
                        },
                      ),
                      if (isSelected && groups.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
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
                                  final updated = await _showTopicDialog(
                                    context,
                                    dvName,
                                    groups,
                                    selectedTopics,
                                  );
                                  if (updated != null) {
                                    setState(() {
                                      _selectedTopicsByDv[dvName] = updated;
                                    });
                                  }
                                },
                                child: const Text('Topics wählen'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('DV-Liste konnte nicht geladen werden: $error'),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveSelection() async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setSelectedDvs(_selectedDvs.toList());

    for (final dvName in _selectedTopicsByDv.keys) {
      if (_selectedDvs.contains(dvName)) {
        await repository.setSelectedTopicsForDv(dvName, _selectedTopicsByDv[dvName] ?? <String>[]);
      } else {
        await repository.removeSelectedTopicsForDv(dvName);
      }
    }

    await ref.read(notificationServiceProvider).refreshTopicSubscriptions();

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<List<String>?> _showTopicDialog(
    BuildContext context,
    String dvName,
    List<String> availableTopics,
    List<String> currentTopics,
  ) async {
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
}

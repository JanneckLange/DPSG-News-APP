import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/dv_tree_provider.dart';
import '../../settings/data/settings_repository.dart';
import '../../../core/services/sync_service.dart' as sync_service;

class AuthorScreen extends ConsumerStatefulWidget {
  const AuthorScreen({super.key});

  @override
  ConsumerState<AuthorScreen> createState() => _AuthorScreenState();
}

class _AuthorScreenState extends ConsumerState<AuthorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedDv;
  String? _selectedTopic;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime? initialDate) async {
    final localContext = context;
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 5);

    final date = await showDatePicker(
      context: localContext,
      initialDate: initialDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (!mounted || date == null) {
      return null;
    }

    // ignore: use_build_context_synchronously
    final time = await _pickTime(localContext, initialDate ?? now);
    if (!mounted || time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc();
  }

  Future<TimeOfDay?> _pickTime(BuildContext context, DateTime initialDate) {
    return showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Nicht gesetzt';
    }
    return value.toLocal().toString().split('.').first;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDv == null || _selectedDv!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte wähle einen Diözesanverband aus.')),
      );
      return;
    }

    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte wähle ein Startdatum.')),
      );
      return;
    }

    if (_endDate != null && _endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Das Enddatum muss nach dem Startdatum liegen.')),
      );
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim().isEmpty ? _selectedDv! : _locationController.text.trim();

    final eventData = {
      'title': title,
      'description': description,
      'startDate': _startDate!.toUtc().toIso8601String(),
      'endDate': _endDate?.toUtc().toIso8601String() ?? '',
      'location': location,
      'dv': _selectedDv!,
      if (_selectedTopic != null && _selectedTopic!.isNotEmpty) 'topic': _selectedTopic!,
    };

    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      await remote.createEvent(eventData);
      await ref.read(sync_service.syncServiceProvider).syncEvents();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event gespeichert.')),
        );
        _formKey.currentState!.reset();
        setState(() {
          _startDate = null;
          _endDate = null;
          _selectedDv = null;
          _selectedTopic = null;
          _locationController.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Erstellen des Events: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthorModeEnabled = ref.watch(authorModeProvider);
    final dvTreeAsync = ref.watch(dvTreeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Autor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isAuthorModeEnabled
            ? Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Titel'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Bitte gib einen Titel ein.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Beschreibung'),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Bitte gib eine Beschreibung ein.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Ort'),
                    ),
                    const SizedBox(height: 16),
                    dvTreeAsync.when(
                      data: (dvs) {
                        final options = dvs
                            .map((dv) => dv['name'] as String?)
                            .whereType<String>()
                            .toSet()
                            .toList();

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedDv,
                          decoration: const InputDecoration(labelText: 'Diözesanverband'),
                          items: options
                              .map((dv) => DropdownMenuItem(value: dv, child: Text(dv)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDv = value;
                              _selectedTopic = null;
                              if (_locationController.text.trim().isEmpty && value != null) {
                                _locationController.text = value;
                              }
                            });
                          },
                          validator: (value) => value == null || value.isEmpty ? 'Bitte wähle einen DV.' : null,
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => const Text('Diözesanverbände konnten nicht geladen werden.'),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedDv != null)
                      _buildTopicField(dvTreeAsync),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Startdatum'),
                      subtitle: Text(_formatDateTime(_startDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final selected = await _pickDateTime(context, _startDate);
                        if (selected != null) {
                          setState(() {
                            _startDate = selected;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Enddatum (optional)'),
                      subtitle: Text(_formatDateTime(_endDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final selected = await _pickDateTime(context, _endDate);
                        if (selected != null) {
                          setState(() {
                            _endDate = selected;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _submitForm,
                      child: const Text('Event speichern'),
                    ),
                  ],
                ),
              )
            : const Center(
                child: Text('Aktiviere den Autor-Modus in den Einstellungen.'),
              ),
      ),
    );
  }

  Widget _buildTopicField(AsyncValue<List<Map<String, dynamic>>> dvTreeAsync) {
    return dvTreeAsync.when(
      data: (dvs) {
        final dvItem = dvs.firstWhere(
          (dv) => dv['name'] == _selectedDv,
          orElse: () => <String, dynamic>{},
        );
        final groups = (dvItem['groups'] as List<dynamic>?)?.whereType<String>().toList() ?? <String>[];

        if (groups.isEmpty) {
          return const Text('Keine spezifischen Topics für diesen DV vorhanden.');
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedTopic,
          decoration: const InputDecoration(labelText: 'Topic (optional)'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Standard (DV-Channel)')),
            ...groups.map((topic) => DropdownMenuItem(value: topic, child: Text(topic))),
          ],
          onChanged: (value) {
            setState(() {
              _selectedTopic = value == '' ? null : value;
            });
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const Text('Topics konnten nicht geladen werden.'),
    );
  }
}

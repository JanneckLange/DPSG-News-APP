import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/sync_service.dart' as sync_service;
import '../../author/data/author_auth_provider.dart';
import '../../settings/data/dv_tree_provider.dart';

class EventEditorSheet extends ConsumerStatefulWidget {
  const EventEditorSheet({super.key, this.event});

  final Map<String, dynamic>? event;

  @override
  ConsumerState<EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends ConsumerState<EventEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedDv;
  String? _selectedTopic;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _titleController.text = event['title'] as String? ?? '';
      _descriptionController.text = event['description'] as String? ?? '';
      _locationController.text = event['location'] as String? ?? '';
      _selectedDv = event['dv'] as String?;
      _selectedTopic = event['topic'] as String?;
      _startDate = DateTime.tryParse(event['startDate'] as String? ?? '');
      _endDate = DateTime.tryParse(event['endDate'] as String? ?? '');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Nicht gesetzt';
    return value.toLocal().toString().split('.').first;
  }

  Future<DateTime?> _pickDateTime(DateTime? initialDate) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (!mounted || date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate ?? now),
    );
    if (!mounted || time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute)
        .toUtc();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDv == null || _selectedDv!.isEmpty || _startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte DV und Startdatum wählen.')),
      );
      return;
    }
    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    final payload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'startDate': _startDate!.toIso8601String(),
      'endDate': (_endDate ?? _startDate!).toIso8601String(),
      'location': _locationController.text.trim().isEmpty
          ? _selectedDv
          : _locationController.text.trim(),
      'dv': _selectedDv,
      if (_selectedTopic != null && _selectedTopic!.isNotEmpty)
        'topic': _selectedTopic,
    };

    setState(() => _saving = true);
    try {
      if (widget.event == null) {
        await remote.createOwnEvent(token: token, event: payload);
      } else {
        await remote.updateEvent(
          token: token,
          eventId: (widget.event!['id'] as num).toInt(),
          event: payload,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dvTreeAsync = ref.watch(dvTreeProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(widget.event == null ? 'Neues Event' : 'Event bearbeiten',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Titel'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Titel ist erforderlich.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
              maxLines: 3,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Beschreibung ist erforderlich.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Ort'),
            ),
            const SizedBox(height: 12),
            dvTreeAsync.when(
              data: (dvs) {
                final options = dvs
                    .map((dv) => dv['name'] as String?)
                    .whereType<String>()
                    .toSet()
                    .toList();
                return DropdownButtonFormField<String>(
                  initialValue: _selectedDv,
                  decoration:
                      const InputDecoration(labelText: 'Diözesanverband'),
                  items: options
                      .map((dv) => DropdownMenuItem(value: dv, child: Text(dv)))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedDv = value;
                    _selectedTopic = null;
                  }),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Bitte DV wählen.'
                      : null,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Text('DV-Liste konnte nicht geladen werden.'),
            ),
            const SizedBox(height: 12),
            if (_selectedDv != null)
              dvTreeAsync.when(
                data: (dvs) {
                  final dvItem = dvs.firstWhere(
                    (dv) => dv['name'] == _selectedDv,
                    orElse: () => <String, dynamic>{},
                  );
                  final groups = (dvItem['groups'] as List<dynamic>?)
                          ?.whereType<String>()
                          .toList() ??
                      <String>[];
                  if (groups.isEmpty) return const SizedBox.shrink();
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedTopic,
                    decoration:
                        const InputDecoration(labelText: 'Topic (optional)'),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('Standard (DV-Channel)')),
                      ...groups.map((topic) =>
                          DropdownMenuItem(value: topic, child: Text(topic))),
                    ],
                    onChanged: (value) => setState(
                        () => _selectedTopic = value == '' ? null : value),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Startdatum'),
              subtitle: Text(_formatDateTime(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final selected = await _pickDateTime(_startDate);
                if (selected != null) setState(() => _startDate = selected);
              },
            ),
            ListTile(
              title: const Text('Enddatum'),
              subtitle: Text(_formatDateTime(_endDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final selected = await _pickDateTime(_endDate ?? _startDate);
                if (selected != null) setState(() => _endDate = selected);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}

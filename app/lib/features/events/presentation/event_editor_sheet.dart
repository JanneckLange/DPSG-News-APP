import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'event_detail_screen.dart';

import '../../../core/services/sync_service.dart' as sync_service;
import '../../author/data/author_auth_provider.dart';
import '../../settings/data/dv_tree_provider.dart';

class EventEditorPage extends ConsumerStatefulWidget {
  const EventEditorPage({super.key, this.existingEvent});

  final Map<String, dynamic>? existingEvent;

  @override
  ConsumerState<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends ConsumerState<EventEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _cta1LabelController = TextEditingController();
  final _cta1UrlController = TextEditingController();
  final _cta2LabelController = TextEditingController();
  final _cta2UrlController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedDv;
  String? _selectedTopic;
  bool _saving = false;
  bool _showCta1 = false;
  bool _showCta2 = false;
  int _currentStep = 0;
  final List<bool> _stepHasError = [false, false, false];

  bool _validateAll() {
    // reset
    _stepHasError[0] = false;
    _stepHasError[1] = false;
    _stepHasError[2] = false;

    // step 0: title, dv, startDate
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedDv == null || _startDate == null) {
      _stepHasError[0] = true;
    }

    // step 1: description and CTA validity
    if (_descriptionController.text.trim().isEmpty) {
      _stepHasError[1] = true;
    }
    if (_showCta1) {
      final l1 = _cta1LabelController.text.trim();
      final u1 = _cta1UrlController.text.trim();
      if (l1.isEmpty || u1.isEmpty) _stepHasError[1] = true;
    }
    if (_showCta2) {
      final l2 = _cta2LabelController.text.trim();
      final u2 = _cta2UrlController.text.trim();
      if (l2.isEmpty || u2.isEmpty) _stepHasError[1] = true;
    }

    return !_stepHasError.contains(true);
  }

  @override
  void initState() {
    super.initState();
    final event = widget.existingEvent;
    if (event != null) {
      _titleController.text = event['title'] as String? ?? '';
      _descriptionController.text = event['description'] as String? ?? '';
      _locationController.text = event['location'] as String? ?? '';
      _selectedDv = event['dv'] as String?;
      _selectedTopic = event['topic'] as String?;
      _cta1LabelController.text = event['cta1Label'] as String? ?? '';
      _cta1UrlController.text = event['cta1Url'] as String? ?? '';
      _cta2LabelController.text = event['cta2Label'] as String? ?? '';
      _cta2UrlController.text = event['cta2Url'] as String? ?? '';
      _showCta1 = _cta1LabelController.text.isNotEmpty || _cta1UrlController.text.isNotEmpty;
      _showCta2 = _cta2LabelController.text.isNotEmpty || _cta2UrlController.text.isNotEmpty;
      _startDate = DateTime.tryParse(event['startDate'] as String? ?? '');
      _endDate = DateTime.tryParse(event['endDate'] as String? ?? '');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _cta1LabelController.dispose();
    _cta1UrlController.dispose();
    _cta2LabelController.dispose();
    _cta2UrlController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Nicht gesetzt';
    return formatEventDateTime(value.toIso8601String());
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

  Future<void> _saveEvent({required bool asDraft}) async {
    // Drafts: only title required
    final title = _titleController.text.trim();
    if (asDraft) {
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Titel ist erforderlich, auch für Entwürfe.')),
        );
        return;
      }
      // clear previous error markers for preview
      setState(() => _stepHasError.setAll(0, [false, false, false]));
    } else {
      // Full validation for publish
      final ok = _validateAll();
      if (!ok) {
        // focus first error step
        final first = _stepHasError.indexWhere((e) => e);
        if (first != -1) setState(() => _currentStep = first);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte Fehler in den markierten Schritten beheben.')),
        );
        return;
      }
    }
    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;
    final remote = ref.read(sync_service.remoteEventSourceProvider);
    final payload = <String, dynamic>{
      'title': title,
      'description': _descriptionController.text.trim(),
      if (_startDate != null) 'startDate': _startDate!.toIso8601String(),
      if (_endDate != null) 'endDate': _endDate!.toIso8601String(),
      'location': _locationController.text.trim().isEmpty
          ? _selectedDv
          : _locationController.text.trim(),
      if (_selectedDv != null) 'dv': _selectedDv,
      'isDraft': asDraft,
      if (_selectedTopic != null && _selectedTopic!.isNotEmpty)
        'topic': _selectedTopic,
      if (_showCta1 && _cta1LabelController.text.trim().isNotEmpty)
        'cta1Label': _cta1LabelController.text.trim(),
      if (_showCta1 && _cta1UrlController.text.trim().isNotEmpty)
        'cta1Url': _cta1UrlController.text.trim(),
      if (_showCta2 && _cta2LabelController.text.trim().isNotEmpty)
        'cta2Label': _cta2LabelController.text.trim(),
      if (_showCta2 && _cta2UrlController.text.trim().isNotEmpty)
        'cta2Url': _cta2UrlController.text.trim(),
    };

    setState(() => _saving = true);
    try {
      if (widget.existingEvent == null) {
        await remote.createOwnEvent(token: token, event: payload);
      } else {
        await remote.updateOwnEvent(
          token: token,
          eventId: (widget.existingEvent!['id'] as num).toInt(),
          event: payload,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _continue() {
    if (_currentStep < 2) {
      setState(() => _currentStep += 1);
    }
  }

  void _cancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dvTreeAsync = ref.watch(dvTreeProvider);
    final isEditing = widget.existingEvent != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Event bearbeiten' : 'Neues Event'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepContinue: _continue,
            onStepCancel: _cancel,
            onStepTapped: (index) {
              setState(() => _currentStep = index);
            },
            controlsBuilder: (context, details) {
              if (_currentStep < 2) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Row(
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : details.onStepContinue,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Weiter'),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _saving ? null : details.onStepCancel,
                        child: const Text('Zurück'),
                      ),
                    ],
                  ),
                );
              }

              // For the final preview step, hide the stepper primary button
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _saving ? null : details.onStepCancel,
                      child: const Text('Zurück'),
                    ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Eckdaten'),
                isActive: _currentStep >= 0,
                state: _stepHasError[0]
                  ? StepState.error
                  : (_currentStep > 0 ? StepState.complete : StepState.indexed),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Titel'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Titel ist erforderlich.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Ort'),
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
                    const SizedBox(height: 12),
                    ListTile(
                      title: const Text('Enddatum'),
                      subtitle: Text(_formatDateTime(_endDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final selected = await _pickDateTime(_endDate ?? _startDate);
                        if (selected != null) setState(() => _endDate = selected);
                      },
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
                          decoration: const InputDecoration(
                              labelText: 'Diözesanverband'),
                          items: options
                              .map((dv) => DropdownMenuItem(
                                  value: dv, child: Text(dv)))
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
                            decoration: const InputDecoration(
                                labelText: 'Topic (optional)'),
                            items: [
                              const DropdownMenuItem(
                                  value: '',
                                  child: Text('Standard (DV-Channel)')),
                              ...groups.map((topic) => DropdownMenuItem(
                                  value: topic, child: Text(topic))),
                            ],
                            onChanged: (value) => setState(
                                () => _selectedTopic = value == '' ? null : value),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
              Step(
                title: const Text('Details'),
                isActive: _currentStep >= 1,
                state: _stepHasError[1]
                  ? StepState.error
                  : (_currentStep > 1 ? StepState.complete : StepState.indexed),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Beschreibung'),
                      minLines: 4,
                      maxLines: 8,
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Beschreibung ist erforderlich.'
                          : null,
                      // Note: per-step validation removed for navigation; validators remain for publish.
                    ),
                    const SizedBox(height: 20),
                    const Text('Buttons', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (!_showCta1)
                      FilledButton.icon(
                        onPressed: () => setState(() => _showCta1 = true),
                        icon: const Icon(Icons.add),
                        label: const Text('Button hinzufügen'),
                      ),
                    if (_showCta1) ...[
                      TextFormField(
                        controller: _cta1LabelController,
                        decoration: const InputDecoration(labelText: 'Button 1 Beschriftung'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cta1UrlController,
                        decoration: const InputDecoration(labelText: 'Button 1 URL'),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (!_showCta2)
                            TextButton.icon(
                              onPressed: () => setState(() => _showCta2 = true),
                              icon: const Icon(Icons.add),
                              label: const Text('Weiteren Button hinzufügen'),
                            ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showCta1 = false;
                                _showCta2 = false;
                                _cta1LabelController.clear();
                                _cta1UrlController.clear();
                                _cta2LabelController.clear();
                                _cta2UrlController.clear();
                              });
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Button entfernen'),
                          ),
                        ],
                      ),
                    ],
                    if (_showCta2) ...[
                      const Divider(height: 32),
                      TextFormField(
                        controller: _cta2LabelController,
                        decoration: const InputDecoration(labelText: 'Button 2 Beschriftung'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cta2UrlController,
                        decoration: const InputDecoration(labelText: 'Button 2 URL'),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showCta2 = false;
                            _cta2LabelController.clear();
                            _cta2UrlController.clear();
                          });
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Button 2 entfernen'),
                      ),
                    ],
                  ],
                ),
              ),
              Step(
                title: const Text('Vorschau'),
                isActive: _currentStep >= 2,
                state: _stepHasError[2]
                  ? StepState.error
                  : (_currentStep == 2 ? StepState.editing : StepState.indexed),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _titleController.text.trim().isEmpty
                                  ? 'Vorschau-Titel'
                                  : _titleController.text.trim(),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(label: Text(_selectedDv ?? 'DV nicht ausgewählt')),
                                if (_selectedTopic != null && _selectedTopic!.isNotEmpty)
                                  Chip(label: Text(_selectedTopic!)),
                                Chip(label: Text(_locationController.text.trim().isEmpty
                                    ? 'Ort nicht gesetzt'
                                    : _locationController.text.trim())),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Start: ${_formatDateTime(_startDate)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'Ende: ${_formatDateTime(_endDate)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              _descriptionController.text.trim().isEmpty
                                  ? 'Beschreibung noch nicht ausgefüllt.'
                                  : _descriptionController.text.trim(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              children: [
                                if (_showCta1 && _cta1LabelController.text.trim().isNotEmpty)
                                  OutlinedButton(
                                    onPressed: null,
                                    child: Text(_cta1LabelController.text.trim()),
                                  ),
                                if (_showCta2 && _cta2LabelController.text.trim().isNotEmpty)
                                  OutlinedButton(
                                    onPressed: null,
                                    child: Text(_cta2LabelController.text.trim()),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : () => _saveEvent(asDraft: true),
                            child: const Text('Entwurf speichern'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : () => _saveEvent(asDraft: false),
                            child: const Text('Jetzt veröffentlichen'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

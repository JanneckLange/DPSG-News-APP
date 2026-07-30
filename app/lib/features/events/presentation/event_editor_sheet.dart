import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/error_toast_service.dart';
import '../../../core/services/logging_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../../../shared/utils/date_format_utils.dart';
import '../../../shared/utils/geoapify_service.dart';
import '../../../shared/utils/nominatim_service.dart';
import '../../../shared/utils/url_utils.dart';
import '../../admin/domain/topic_model.dart';
import '../../author/data/author_auth_provider.dart';
import '../../settings/data/dv_tree_provider.dart';
import '../../settings/domain/layer_model.dart';
import '../domain/event_cta_labels.dart';

class EventEditorPage extends ConsumerStatefulWidget {
  const EventEditorPage({super.key, this.existingEvent, this.existingDraft})
      : assert(
          existingEvent == null || existingDraft == null,
          'existingEvent and existingDraft are mutually exclusive',
        );

  final Map<String, dynamic>? existingEvent;
  final Map<String, dynamic>? existingDraft;

  @override
  ConsumerState<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends ConsumerState<EventEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cta1UrlController = TextEditingController();
  final _cta2UrlController = TextEditingController();
  String? _locationAddress;
  double? _locationLat;
  double? _locationLng;
  Timer? _locationAutocompleteDebounce;
  List<GeoapifyAddress> _locationSuggestions = [];
  TextEditingController? _locationTextController;
  int _locationRequestId = 0;
  bool _locationSearchUnavailable = false;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _publishAt;
  DateTime? _registrationDeadline;
  int? _selectedLayerId;
  int? _selectedTopicId;
  bool _isPublic = false;
  List<TopicModel> _topics = <TopicModel>[];
  bool _loadingTopics = false;
  bool _saving = false;
  int _currentStep = 0;
  final List<bool> _stepHasError = [false, false, false, false];

  static final RegExp _simpleEmailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Spiegelt `validateOptionalCtaUrl` aus `server/src/eventValidation.ts`:
  /// CTA1 erlaubt mailto- oder http(s)-Werte, CTA2 nur http(s). Leere Werte
  /// sind stets gueltig (optionales Feld). Schemalose Domains (z. B.
  /// "example.com") werden wie beim Oeffnen eines CTA-Links in
  /// `event_detail_screen.dart` (`_confirmAndOpenLink`) mit einem
  /// https-Fallback geprueft, damit Client- und Server-Validierung sowie das
  /// spaetere Oeffnen des Links konsistent denselben Wert akzeptieren.
  String? _ctaValidationError(String value, {required bool allowMailto}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (looksLikeMailto(trimmed)) {
      if (!allowMailto) {
        return 'Muss eine gültige http(s)-URL sein.';
      }
      final address = extractMailtoAddress(trimmed);
      return _simpleEmailRegex.hasMatch(address)
          ? null
          : 'Ungültige E-Mail-Adresse.';
    }
    var uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme.isEmpty) {
      // Dart's Uri.tryParse kodiert Leerzeichen unauffaellig in den Host
      // statt das Parsen abzulehnen (anders als der Server, der dafuer den
      // strengeren WHATWG-URL-Parser nutzt) - ohne diese Zusatzpruefung
      // wuerde z. B. "kein gueltiger wert" als gueltige Domain durchgehen.
      uri = trimmed.contains(RegExp(r'\s'))
          ? null
          : Uri.tryParse('https://$trimmed');
    }
    if (uri == null || uri.host.isEmpty || !isHttpOrHttpsUri(uri)) {
      return 'Muss eine gültige http(s)-URL oder E-Mail-Adresse sein.';
    }
    return null;
  }

  bool _validateAll() {
    // reset
    _stepHasError[0] = false;
    _stepHasError[1] = false;
    _stepHasError[2] = false;
    _stepHasError[3] = false;

    // Schritt 0 "Titel & Beschreibung"
    final title = _titleController.text.trim();
    if (title.isEmpty || _descriptionController.text.trim().isEmpty) {
      _stepHasError[0] = true;
    }

    // Schritt 1 "Termin & Ort": Startdatum erforderlich, Enddatum darf
    // (falls gesetzt) nicht vor dem Startdatum liegen.
    final hasInvalidDateRange = _startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!);
    if (_startDate == null || hasInvalidDateRange) {
      _stepHasError[1] = true;
    }

    // Schritt 2 "Einstellungen": Layer erforderlich, CTA-Format optional aber
    // wenn ausgefuellt muss es gueltig sein.
    final cta1Error =
        _ctaValidationError(_cta1UrlController.text, allowMailto: true);
    final cta2Error =
        _ctaValidationError(_cta2UrlController.text, allowMailto: false);
    if (_selectedLayerId == null || cta1Error != null || cta2Error != null) {
      _stepHasError[2] = true;
    }

    return !_stepHasError.contains(true);
  }

  bool get _isEditingEvent => widget.existingEvent != null;
  bool get _isEditingDraft => widget.existingDraft != null;

  /// Ob der aktuell gewaehlte Layer der Wurzel-Layer ("Bundesverband DPSG")
  /// ist. Auf dieser Ebene hat "Global bewerben" keinen Effekt, da der
  /// Layer ohnehin bereits layeruebergreifend sichtbar ist (siehe #37).
  bool get _isSelectedLayerRoot {
    if (_selectedLayerId == null) return false;
    final layers =
        ref.read(layerTreeProvider).asData?.value ?? const <LayerModel>[];
    for (final layer in layers) {
      if (layer.id == _selectedLayerId) return layer.parentId == null;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final event = widget.existingEvent ?? widget.existingDraft;
    if (event != null) {
      _titleController.text = event['title'] as String? ?? '';
      _descriptionController.text = event['description'] as String? ?? '';
      _locationAddress = event['locationAddress'] as String?;
      _locationLat = (event['locationLat'] as num?)?.toDouble();
      _locationLng = (event['locationLng'] as num?)?.toDouble();
      _selectedLayerId = (event['layerId'] as num?)?.toInt();
      _selectedTopicId = (event['topicId'] as num?)?.toInt();
      _isPublic = event['isPublic'] as bool? ?? false;
      _cta1UrlController.text = event['cta1Url'] as String? ?? '';
      _cta2UrlController.text = event['cta2Url'] as String? ?? '';
      _startDate = DateTime.tryParse(event['startDate'] as String? ?? '');
      _endDate = DateTime.tryParse(event['endDate'] as String? ?? '');
      _publishAt = DateTime.tryParse(event['publishAt'] as String? ?? '');
      _registrationDeadline =
          DateTime.tryParse(event['registrationDeadline'] as String? ?? '');
    }
    if (_selectedLayerId != null) {
      unawaited(_loadTopicsForLayer(_selectedLayerId!));
    }
    // Layer-Liste und Autoren-Rechte laden sonst nur einmal beim App-Start
    // bzw. bei Login/Token-Refresh -- ohne diesen Refresh wuerden kuerzlich
    // hinzugefuegte Layer bzw. neu vergebene Layer-Rechte hier erst nach
    // einem App-Neustart auftauchen.
    unawaited(ref.read(layerTreeProvider.notifier).refresh());
    unawaited(ref.read(authorAuthProvider.notifier).refreshSession());
  }

  Future<void> _loadTopicsForLayer(int layerId) async {
    setState(() {
      _loadingTopics = true;
      _topics = <TopicModel>[];
    });
    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final response = await remote.fetchTopics(layerId: layerId);
      final topics =
          List<Map<String, dynamic>>.from(response['topics'] as List<dynamic>)
              .map(TopicModel.fromJson)
              .toList();
      if (!mounted) return;
      setState(() {
        _topics = topics;
        if (_selectedTopicId != null &&
            !topics.any((topic) => topic.id == _selectedTopicId)) {
          _selectedTopicId = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Themen konnten nicht geladen werden: ${describeRemoteError(error)}',
      );
    } finally {
      if (mounted) setState(() => _loadingTopics = false);
    }
  }

  String? get _selectedTopicName {
    if (_selectedTopicId == null) return null;
    for (final topic in _topics) {
      if (topic.id == _selectedTopicId) return topic.name;
    }
    return null;
  }

  Widget _buildTopicDropdown(List<int> topicGrantIds) {
    if (_loadingTopics) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_topics.isEmpty) {
      return const SizedBox.shrink();
    }
    final authorizedTopics =
        _topics.where((topic) => topicGrantIds.contains(topic.id)).toList();

    // Genau ein berechtigtes Topic (oder keins) -> keine echte Auswahl,
    // Feld schreibgeschuetzt auf den einzig moeglichen Wert vorbelegen.
    if (authorizedTopics.length <= 1) {
      final onlyTopicId =
          authorizedTopics.isEmpty ? null : authorizedTopics.single.id;
      if (_selectedTopicId != onlyTopicId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedTopicId = onlyTopicId);
        });
      }
      return DropdownButtonFormField<int?>(
        initialValue: onlyTopicId,
        decoration: const InputDecoration(labelText: 'Topic (optional)'),
        items: [
          DropdownMenuItem<int?>(
            value: onlyTopicId,
            child: Text(authorizedTopics.isEmpty
                ? 'Standard (DV-Channel)'
                : authorizedTopics.single.name),
          ),
        ],
        onChanged: null,
      );
    }

    return DropdownButtonFormField<int?>(
      initialValue:
          authorizedTopics.any((topic) => topic.id == _selectedTopicId)
              ? _selectedTopicId
              : null,
      decoration: const InputDecoration(labelText: 'Topic (optional)'),
      items: [
        const DropdownMenuItem<int?>(
            value: null, child: Text('Standard (DV-Channel)')),
        ...authorizedTopics.map((topic) =>
            DropdownMenuItem<int?>(value: topic.id, child: Text(topic.name))),
      ],
      onChanged: (value) => setState(() => _selectedTopicId = value),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cta1UrlController.dispose();
    _cta2UrlController.dispose();
    _locationAutocompleteDebounce?.cancel();
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
          const SnackBar(
              content: Text('Titel ist erforderlich, auch für Entwürfe.')),
        );
        return;
      }
      // clear previous error markers for preview
      setState(() => _stepHasError.setAll(0, [false, false, false, false]));
    } else {
      // Full validation for publish. _formKey.currentState.validate() loest
      // zusaetzlich die eingebaute Inline-Fehleranzeige der TextFormFields
      // aus (Titel/Beschreibung/CTA1/CTA2) - ohne diesen Aufruf bleiben die
      // validator-Funktionen wirkungslos und nur die generische SnackBar/das
      // rote Schritt-Icon zeigen ueberhaupt an, dass etwas fehlt.
      final formValid = _formKey.currentState?.validate() ?? true;
      final ok = _validateAll() && formValid;
      if (!ok) {
        // focus first error step
        final first = _stepHasError.indexWhere((e) => e);
        if (first != -1) setState(() => _currentStep = first);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Bitte Fehler in den markierten Schritten beheben.')),
        );
        return;
      }
    }
    // Falls keine Adresse aus der Vorschlagsliste ausgewaehlt wurde, aber
    // Freitext im Ortsfeld steht (z. B. weil die Adresssuche nicht verfuegbar
    // war), diesen Text ohne Koordinaten als Ortsangabe uebernehmen.
    final typedLocation = _locationTextController?.text.trim();
    final resolvedLocationAddress = _locationAddress ??
        ((typedLocation != null && typedLocation.isNotEmpty)
            ? typedLocation
            : null);
    final payload = <String, dynamic>{
      'title': title,
      'description': _descriptionController.text.trim(),
      if (_startDate != null) 'startDate': _startDate!.toIso8601String(),
      if (_endDate != null) 'endDate': _endDate!.toIso8601String(),
      if (_publishAt != null) 'publishAt': _publishAt!.toIso8601String(),
      if (_registrationDeadline != null)
        'registrationDeadline': _registrationDeadline!.toIso8601String(),
      if (resolvedLocationAddress != null)
        'locationAddress': resolvedLocationAddress,
      if (_locationLat != null) 'locationLat': _locationLat,
      if (_locationLng != null) 'locationLng': _locationLng,
      if (_selectedLayerId != null) 'layerId': _selectedLayerId,
      if (_selectedTopicId != null) 'topicId': _selectedTopicId,
      'isPublic': _isPublic && !_isSelectedLayerRoot,
      if (_cta1UrlController.text.trim().isNotEmpty)
        'cta1Url': _cta1UrlController.text.trim(),
      if (_cta2UrlController.text.trim().isNotEmpty)
        'cta2Url': _cta2UrlController.text.trim(),
    };

    setState(() => _saving = true);
    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
        (token) async {
          final remote = ref.read(sync_service.remoteEventSourceProvider);
          if (asDraft) {
            if (_isEditingDraft) {
              await remote.updateDraft(
                token: token,
                draftId: (widget.existingDraft!['id'] as num).toInt(),
                draft: payload,
              );
            } else {
              await remote.createDraft(token: token, draft: payload);
            }
          } else {
            if (_isEditingEvent) {
              await remote.updateOwnEvent(
                token: token,
                eventId: (widget.existingEvent!['id'] as num).toInt(),
                event: payload,
              );
            } else {
              await remote.createOwnEvent(token: token, event: payload);
              if (_isEditingDraft) {
                try {
                  await remote.deleteDraft(
                    token: token,
                    draftId: (widget.existingDraft!['id'] as num).toInt(),
                  );
                } catch (error) {
                  if (mounted) {
                    showErrorToast(
                      ref,
                      'Event wurde veröffentlicht, der ursprüngliche Entwurf konnte aber nicht automatisch gelöscht werden: ${describeRemoteError(error)}',
                    );
                  }
                }
              }
            }
          }
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showErrorToast(ref, describeRemoteError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _continue() {
    if (_currentStep < 3) {
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

  // ---------------------------------------------------------------------
  // Feldgruppen als eigene Builder-Methoden: eine kuenftige Umsortierung der
  // Schritte erfordert dadurch nur das Verschieben eines Methodenaufrufs
  // zwischen den `Step`s in build(), keine Restrukturierung der Widgets
  // selbst.
  // ---------------------------------------------------------------------

  List<Widget> _buildTitleField() {
    return [
      TextFormField(
        controller: _titleController,
        decoration: const InputDecoration(labelText: 'Titel'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Titel ist erforderlich.'
            : null,
      ),
    ];
  }

  List<Widget> _buildDescriptionField() {
    return [
      TextFormField(
        controller: _descriptionController,
        decoration: const InputDecoration(labelText: 'Beschreibung'),
        minLines: 4,
        maxLines: 8,
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Beschreibung ist erforderlich.'
            : null,
      ),
    ];
  }

  List<Widget> _buildScheduleFields() {
    final hasInvalidDateRange = _startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!);
    return [
      ListTile(
        title: const Text('Startdatum'),
        subtitle: Text(_formatDateTime(_startDate)),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          final selected = await _pickDateTime(_startDate);
          if (selected != null) {
            setState(() => _startDate = selected);
          }
        },
      ),
      const SizedBox(height: 12),
      ListTile(
        title: const Text('Enddatum'),
        subtitle: Text(_formatDateTime(_endDate)),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          final selected = await _pickDateTime(_endDate ?? _startDate);
          if (selected != null) {
            setState(() => _endDate = selected);
          }
        },
      ),
      if (hasInvalidDateRange)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 16),
          child: Text(
            'Enddatum darf nicht vor dem Startdatum liegen.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildLocationField() {
    return [
      Autocomplete<String>(
        initialValue: TextEditingValue(text: _locationAddress ?? ''),
        optionsBuilder: (TextEditingValue textEditingValue) async {
          final query = textEditingValue.text.trim();
          if (query.length < 3) {
            _locationSuggestions = [];
            return const Iterable<String>.empty();
          }
          if (_locationAutocompleteDebounce?.isActive ?? false) {
            _locationAutocompleteDebounce!.cancel();
          }
          final requestId = ++_locationRequestId;
          final logger = ref.read(loggingServiceProvider);
          final completer = Completer<Iterable<String>>();
          _locationAutocompleteDebounce = Timer(
            const Duration(milliseconds: 500),
            () async {
              List<GeoapifyAddress> results = [];
              var unavailable = false;
              try {
                results = await autocompleteAddress(query, logger: logger);
              } catch (primaryError, primaryStack) {
                await logger.logServiceError(
                  'geoapify',
                  'autocomplete_failed query_len=${query.length}',
                  error: primaryError,
                  stackTrace: primaryStack,
                );
                try {
                  results = await autocompleteAddressNominatim(
                    query,
                    logger: logger,
                  );
                } catch (fallbackError, fallbackStack) {
                  await logger.logServiceError(
                    'nominatim',
                    'autocomplete_fallback_failed query_len=${query.length}',
                    error: fallbackError,
                    stackTrace: fallbackStack,
                  );
                  unavailable = true;
                }
              }
              if (requestId != _locationRequestId) {
                // Ein neuerer Request laeuft bereits - dieses veraltete
                // Ergebnis verwerfen, damit die Vorschlagsliste nicht mit
                // _locationSuggestions auseinanderlaeuft (Race-Condition
                // durch Timer.cancel(), das laufende Callbacks nicht
                // stoppt).
                completer.complete(const Iterable<String>.empty());
                return;
              }
              _locationSuggestions = results;
              if (mounted) {
                setState(() => _locationSearchUnavailable = unavailable);
              } else {
                _locationSearchUnavailable = unavailable;
              }
              completer.complete(
                _locationSuggestions.map((address) => address.formatted),
              );
            },
          );
          return completer.future;
        },
        onSelected: (String selection) {
          final selected = _locationSuggestions.firstWhere(
            (address) => address.formatted == selection,
          );
          setState(() {
            _locationAddress = selected.formatted;
            _locationLat = selected.lat;
            _locationLng = selected.lon;
          });
        },
        fieldViewBuilder: (
          BuildContext context,
          TextEditingController textEditingController,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted,
        ) {
          _locationTextController = textEditingController;
          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'Ort',
              helperText: _locationSearchUnavailable
                  ? 'Adresssuche derzeit nicht verfügbar - Adresse kann unten frei eingegeben werden.'
                  : 'Adresse aus der Vorschlagsliste wählen oder frei eingeben, falls keine Vorschläge erscheinen.',
              suffixIcon: _locationAddress != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Ort entfernen',
                      onPressed: () {
                        setState(() {
                          _locationAddress = null;
                          _locationLat = null;
                          _locationLng = null;
                          textEditingController.clear();
                        });
                      },
                    )
                  : null,
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _buildLayerAndTopicFields(
    AsyncValue<List<LayerModel>> layerTreeAsync,
    List<int> layerGrantIds,
    List<int> topicGrantIds,
  ) {
    return [
      layerTreeAsync.when(
        data: (layers) {
          final authorizedLayers = layers
              .where((layer) => layerGrantIds.contains(layer.id))
              .toList();
          final optionIds = authorizedLayers.map((layer) => layer.id).toList();
          if (_selectedLayerId != null &&
              !optionIds.contains(_selectedLayerId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedLayerId = null;
                  _selectedTopicId = null;
                });
              }
            });
          }

          if (authorizedLayers.isEmpty) {
            return const Text(
              'Keine berechtigten Layer vorhanden. Bitte an einen Admin wenden.',
            );
          }

          // Genau ein berechtigter Layer -> keine echte Auswahl, Feld
          // schreibgeschuetzt auf den einzig moeglichen Wert vorbelegen.
          if (authorizedLayers.length == 1) {
            final onlyLayer = authorizedLayers.single;
            if (_selectedLayerId != onlyLayer.id) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _selectedLayerId = onlyLayer.id);
                  unawaited(_loadTopicsForLayer(onlyLayer.id));
                }
              });
            }
            return DropdownButtonFormField<int>(
              initialValue: onlyLayer.id,
              decoration: const InputDecoration(labelText: 'Layer'),
              items: [
                DropdownMenuItem(
                  value: onlyLayer.id,
                  child: Text(onlyLayer.name),
                ),
              ],
              onChanged: null,
            );
          }

          return DropdownButtonFormField<int>(
            initialValue:
                optionIds.contains(_selectedLayerId) ? _selectedLayerId : null,
            decoration: const InputDecoration(labelText: 'Layer'),
            items: authorizedLayers
                .map((layer) =>
                    DropdownMenuItem(value: layer.id, child: Text(layer.name)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedLayerId = value;
                _selectedTopicId = null;
                _topics = <TopicModel>[];
                if (value != null) {
                  final newLayer =
                      authorizedLayers.firstWhere((layer) => layer.id == value);
                  if (newLayer.parentId == null) {
                    _isPublic = false;
                  }
                }
              });
              if (value != null) {
                unawaited(_loadTopicsForLayer(value));
              }
            },
            validator: (value) => value == null ? 'Bitte Layer wählen.' : null,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Text('Layer-Liste konnte nicht geladen werden.'),
      ),
      const SizedBox(height: 12),
      if (_selectedLayerId != null) _buildTopicDropdown(topicGrantIds),
    ];
  }

  Widget _buildOptionalDateListTile({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return ListTile(
      title: Text(label),
      subtitle: Text(_formatDateTime(value)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Datum entfernen',
              onPressed: () => onChanged(null),
            ),
          const Icon(Icons.calendar_today),
        ],
      ),
      onTap: () async {
        final selected = await _pickDateTime(value);
        if (selected != null) onChanged(selected);
      },
    );
  }

  List<Widget> _buildPublishSettingsFields() {
    return [
      _buildOptionalDateListTile(
        label: 'Veröffentlichung ab',
        value: _publishAt,
        onChanged: (value) => setState(() => _publishAt = value),
      ),
      const SizedBox(height: 12),
      _buildOptionalDateListTile(
        label: 'Anmeldeschluss',
        value: _registrationDeadline,
        onChanged: (value) => setState(() => _registrationDeadline = value),
      ),
      if (_selectedLayerId != null && !_isSelectedLayerRoot) ...[
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Global bewerben'),
                value: _isPublic,
                onChanged: (value) =>
                    setState(() => _isPublic = value ?? false),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Global bewerben',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Global bewerben'),
                  content: const Text(
                    'Alle Events sind öffentlich einsehbar. '
                    'Wird diese Option aktiviert, wird das '
                    'Event zusätzlich layerübergreifend '
                    'beworben (z. B. Dashboard-Kachel).',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Verstanden'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _buildCtaFields() {
    return [
      const Text('Buttons', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      const Text(kEventCta1Label,
          style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      TextFormField(
        controller: _cta1UrlController,
        decoration: const InputDecoration(
          labelText: 'Link oder E-Mail-Adresse',
          hintText: 'https://... oder name@example.org',
        ),
        validator: (value) =>
            _ctaValidationError(value ?? '', allowMailto: true),
      ),
      const SizedBox(height: 20),
      const Text(kEventCta2Label,
          style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      TextFormField(
        controller: _cta2UrlController,
        decoration: const InputDecoration(
          labelText: 'Link oder E-Mail-Adresse',
          hintText: 'https://... oder name@example.org',
        ),
        validator: (value) =>
            _ctaValidationError(value ?? '', allowMailto: false),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final layerTreeAsync = ref.watch(layerTreeProvider);
    final layerGrantIds = ref.watch(authorAuthProvider).layerGrantIds;
    final topicGrantIds = ref.watch(authorAuthProvider).topicGrantIds;
    final layerNamesById = {
      for (final layer in layerTreeAsync.asData?.value ?? <LayerModel>[])
        layer.id: layer.name,
    };
    final selectedLayerDisplayName = layerNamesById[_selectedLayerId];
    final title = _isEditingEvent
        ? 'Event bearbeiten'
        : _isEditingDraft
            ? 'Entwurf bearbeiten'
            : 'Neues Event';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          // Bis zum ersten expliziten validate()-Aufruf (Veroeffentlichen)
          // bleiben unberuehrte Felder fehlerfrei; danach werden Korrekturen
          // sofort live sichtbar, statt erst beim naechsten Speicherversuch.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepContinue: _continue,
            onStepCancel: _cancel,
            onStepTapped: (index) {
              setState(() => _currentStep = index);
            },
            controlsBuilder: (context, details) {
              if (_currentStep < 3) {
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
                title: const Text('Titel & Beschreibung'),
                isActive: _currentStep >= 0,
                state: _stepHasError[0]
                    ? StepState.error
                    : (_currentStep > 0
                        ? StepState.complete
                        : StepState.indexed),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._buildTitleField(),
                    const SizedBox(height: 12),
                    ..._buildDescriptionField(),
                  ],
                ),
              ),
              Step(
                title: const Text('Termin & Ort'),
                isActive: _currentStep >= 1,
                state: _stepHasError[1]
                    ? StepState.error
                    : (_currentStep > 1
                        ? StepState.complete
                        : StepState.indexed),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._buildScheduleFields(),
                    const SizedBox(height: 12),
                    ..._buildLocationField(),
                  ],
                ),
              ),
              Step(
                title: const Text('Einstellungen'),
                isActive: _currentStep >= 2,
                state: _stepHasError[2]
                    ? StepState.error
                    : (_currentStep > 2
                        ? StepState.complete
                        : StepState.indexed),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._buildLayerAndTopicFields(
                        layerTreeAsync, layerGrantIds, topicGrantIds),
                    const SizedBox(height: 12),
                    ..._buildPublishSettingsFields(),
                    const SizedBox(height: 20),
                    ..._buildCtaFields(),
                  ],
                ),
              ),
              Step(
                title: const Text('Vorschau'),
                isActive: _currentStep >= 3,
                state: _stepHasError[3]
                    ? StepState.error
                    : (_currentStep == 3
                        ? StepState.editing
                        : StepState.indexed),
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
                                Chip(
                                    label: Text(selectedLayerDisplayName ??
                                        'Layer nicht ausgewählt')),
                                if (_selectedTopicName != null)
                                  Chip(label: Text(_selectedTopicName!)),
                                Chip(
                                    label: Text(_locationAddress ??
                                        'Ort nicht gesetzt')),
                                if (_isPublic && !_isSelectedLayerRoot)
                                  const Chip(label: Text('Global beworben')),
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
                            Text(
                              'Veröffentlichung ab: ${_formatDateTime(_publishAt)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'Anmeldeschluss: ${_formatDateTime(_registrationDeadline)}',
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
                            Builder(builder: (context) {
                              final previewHasCta1 =
                                  _cta1UrlController.text.trim().isNotEmpty;
                              final previewHasCta2 =
                                  _cta2UrlController.text.trim().isNotEmpty;
                              return Wrap(
                                spacing: 12,
                                children: [
                                  if (previewHasCta1)
                                    const FilledButton(
                                      onPressed: null,
                                      child: Text(kEventCta1Label),
                                    ),
                                  if (previewHasCta2)
                                    previewHasCta1
                                        ? const OutlinedButton(
                                            onPressed: null,
                                            child: Text(kEventCta2Label),
                                          )
                                        : const FilledButton(
                                            onPressed: null,
                                            child: Text(kEventCta2Label),
                                          ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (!_isEditingEvent) ...[
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () => _saveEvent(asDraft: true),
                              child: const Text('Entwurf speichern'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving
                                ? null
                                : () => _saveEvent(asDraft: false),
                            child: Text(_isEditingEvent
                                ? 'Änderungen veröffentlichen'
                                : 'Jetzt veröffentlichen'),
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

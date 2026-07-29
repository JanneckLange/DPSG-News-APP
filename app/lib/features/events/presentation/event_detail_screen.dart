import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/error_toast_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../../../core/theme/app_theme.dart';
import '../../author/data/author_auth_provider.dart';
import '../../settings/data/dv_tree_provider.dart';
import '../../settings/data/settings_repository.dart';
import '../../../shared/utils/date_format_utils.dart';
import '../../../shared/utils/url_utils.dart';
import '../../../shared/widgets/labeled_chip.dart';
import '../../../shared/widgets/location_map_view.dart';
import '../../../shared/widgets/safe_markdown_body.dart';
import '../../../shared/widgets/section_card.dart';
import '../../admin/domain/topic_model.dart';
import '../domain/event_cta_labels.dart';
import 'event_editor_sheet.dart';
import 'widgets/event_history_dialog.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.event});

  final Map<String, dynamic> event;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _saving = false;
  final _updateMessageController = TextEditingController();
  List<Map<String, dynamic>> _updates = <Map<String, dynamic>>[];
  bool _loadingUpdates = true;
  bool _postingUpdate = false;
  String? _topicName;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final analytics = ref.read(analyticsServiceProvider);
      final title = widget.event['title']?.toString() ?? 'unknown';
      analytics.trackFeatureEvent(
        'event_detail_viewed',
        screen: 'events',
        action: 'view',
        target: title,
      );
      if (_eventId.isNotEmpty) {
        ref.read(eventViewedAtProvider.notifier).markViewed(_eventId);
      }
    });
    _loadUpdates();
    _loadTopicName();
  }

  /// Loest den Themennamen ueber die Topics des Layers auf; das Thema ist rein
  /// informativ, daher bleibt der Chip bei einem Fehler einfach ausgeblendet.
  Future<void> _loadTopicName() async {
    final topicId = (widget.event['topicId'] as num?)?.toInt();
    final layerId = (widget.event['layerId'] as num?)?.toInt();
    if (topicId == null || layerId == null) return;
    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final response = await remote.fetchTopics(layerId: layerId);
      final topics =
          List<Map<String, dynamic>>.from(response['topics'] as List<dynamic>)
              .map(TopicModel.fromJson)
              .toList();
      final match = topics.where((topic) => topic.id == topicId);
      if (!mounted || match.isEmpty) return;
      setState(() => _topicName = match.first.name);
    } catch (_) {
      // Anzeige bleibt ohne Thema-Chip, kein Fehler-Feedback fuer diese
      // rein informative Zusatzinformation noetig.
    }
  }

  @override
  void dispose() {
    _updateMessageController.dispose();
    super.dispose();
  }

  String get _eventId => widget.event['id']?.toString() ?? '';

  int? get _eventIdAsInt =>
      widget.event['id'] is num ? (widget.event['id'] as num).toInt() : null;

  // Serverseitig berechnete Rechte (Rechtematrix #1/#16: Ownership ODER Admin
  // mit passendem Layer-Scope) statt lokaler isAdmin-Logik - der Client kennt
  // den Admin-Layer-Scope nicht und darf ihn nicht selbst nachbilden.
  bool get _canEditEvent => widget.event['canEdit'] == true;

  bool get _canDeleteEvent => widget.event['canDelete'] == true;

  bool get _canCreateUpdate => widget.event['canCreateUpdate'] == true;

  Future<void> _loadUpdates() async {
    final eventId = _eventIdAsInt;
    if (eventId == null) {
      if (mounted) setState(() => _loadingUpdates = false);
      return;
    }
    setState(() => _loadingUpdates = true);
    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final token = ref.read(authorAuthProvider).token;
      final updates =
          await remote.fetchEventUpdates(eventId: eventId, token: token);
      if (!mounted) return;
      setState(() => _updates = updates);
    } catch (error) {
      if (mounted) showErrorToast(ref, describeRemoteError(error));
    } finally {
      if (mounted) setState(() => _loadingUpdates = false);
    }
  }

  Future<void> _postUpdate() async {
    final eventId = _eventIdAsInt;
    final message = _updateMessageController.text.trim();
    if (eventId == null || message.isEmpty) return;

    setState(() => _postingUpdate = true);
    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
            (token) => ref
                .read(sync_service.remoteEventSourceProvider)
                .createEventUpdate(
                  token: token,
                  eventId: eventId,
                  message: message,
                ),
          );
      _updateMessageController.clear();
      await _loadUpdates();
    } catch (error) {
      if (mounted) showErrorToast(ref, describeRemoteError(error));
    } finally {
      if (mounted) setState(() => _postingUpdate = false);
    }
  }

  Future<void> _editUpdate(Map<String, dynamic> update) async {
    final eventId = _eventIdAsInt;
    final updateId = update['id'] is num ? (update['id'] as num).toInt() : null;
    if (eventId == null || updateId == null) return;

    final controller =
        TextEditingController(text: update['message'] as String? ?? '');
    final newMessage = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update bearbeiten'),
        content: TextFormField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Nachricht (Markdown)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newMessage == null || newMessage.isEmpty) return;

    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
            (token) => ref
                .read(sync_service.remoteEventSourceProvider)
                .updateEventUpdate(
                  token: token,
                  eventId: eventId,
                  updateId: updateId,
                  message: newMessage,
                ),
          );
      await _loadUpdates();
    } catch (error) {
      if (mounted) showErrorToast(ref, describeRemoteError(error));
    }
  }

  Future<void> _deleteUpdate(Map<String, dynamic> update) async {
    final eventId = _eventIdAsInt;
    final updateId = update['id'] is num ? (update['id'] as num).toInt() : null;
    if (eventId == null || updateId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update löschen'),
        content: const Text('Möchtest du dieses Update löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(authorAuthProvider.notifier).callAuthenticated(
            (token) => ref
                .read(sync_service.remoteEventSourceProvider)
                .deleteEventUpdate(
                  token: token,
                  eventId: eventId,
                  updateId: updateId,
                ),
          );
      await _loadUpdates();
    } catch (error) {
      if (mounted) showErrorToast(ref, describeRemoteError(error));
    }
  }

  bool get _isSaved {
    final savedEventIds = ref.watch(savedEventIdsProvider);
    return savedEventIds.contains(_eventId);
  }

  Future<void> _toggleSaved() async {
    if (_eventId.isEmpty) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(savedEventIdsProvider.notifier);
      if (_isSaved) {
        await notifier.removeEvent(_eventId);
      } else {
        await notifier.addEvent(_eventId);
      }
      await ref.read(notificationServiceProvider).refreshTopicSubscriptions();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static final RegExp _simpleEmailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  Future<void> _afterCtaConfirmed(String label, {String? channel, String? url}) async {
    if (_eventId.isNotEmpty) {
      final settingsRepository = ref.read(settingsRepositoryProvider);
      final autoSave = settingsRepository.getAutoSaveEventOnCtaClick();
      if (autoSave && !_isSaved) {
        await ref.read(savedEventIdsProvider.notifier).addEvent(_eventId);
        await ref.read(notificationServiceProvider).refreshTopicSubscriptions();
      }
    }

    final analytics = ref.read(analyticsServiceProvider);
    unawaited(analytics.trackFeatureEvent(
      'event_cta_clicked',
      screen: 'event_detail',
      action: 'cta_click',
      target: label,
      additionalProperties: channel != null
          ? {'event_id': _eventId, 'channel': channel}
          : {'event_id': _eventId, 'url': url},
    ));
  }

  Future<void> _confirmAndOpenLink(String url, String label, {bool allowMailto = false}) async {
    if (allowMailto && looksLikeMailto(url)) {
      final address = extractMailtoAddress(url).trim();
      if (!_simpleEmailRegex.hasMatch(address)) {
        if (mounted) {
          showErrorToast(ref, 'Ungültige E-Mail-Adresse');
        }
        return;
      }

      final title = widget.event['title']?.toString() ?? '';
      final startDate =
          formatEventDateTime(widget.event['startDate']?.toString());
      final mailUri = Uri(
        scheme: 'mailto',
        path: address,
        queryParameters: {
          'subject': 'Anmeldung $title',
          'body': 'Ich möchte mich zum Event $title am $startDate anmelden.',
        },
      );

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('E-Mail senden'),
          content: Text('Möchtest du eine E-Mail senden an: $address'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ja'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }

      await _afterCtaConfirmed(label, channel: 'mailto');

      if (!mounted) return;
      if (!await launchUrl(mailUri)) {
        if (mounted) {
          showErrorToast(ref, 'E-Mail-App konnte nicht geöffnet werden');
        }
      }
      return;
    }

    var uri = Uri.tryParse(url);
    if (uri != null && uri.scheme.isEmpty) {
      uri = Uri.tryParse('https://$url');
    }
    if (uri == null || uri.host.isEmpty) {
      if (mounted) {
        showErrorToast(ref, 'Ungültige URL');
      }
      return;
    }
    if (!isHttpOrHttpsUri(uri)) {
      if (mounted) {
        showErrorToast(ref, 'Ungültige URL');
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Webseite öffnen'),
        content: Text('Möchtest du folgende Webseite öffnen: $url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ja'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await _afterCtaConfirmed(label, url: url);

    if (!mounted) return;
    if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
      if (mounted) {
        showErrorToast(ref, 'Link konnte nicht geöffnet werden');
      }
    }
  }

  Future<void> _confirmAndOpenInMaps(double lat, double lng, String? label) async {
    final uri = Platform.isIOS
        ? Uri.parse('https://maps.apple.com/?ll=$lat,$lng'
            '${label != null && label.isNotEmpty ? '&q=${Uri.encodeComponent(label)}' : ''}')
        : Uri.parse('https://www.google.com/maps/search/?api=1'
            '&query=$lat,$lng');
    if (!isHttpOrHttpsUri(uri)) {
      if (mounted) {
        showErrorToast(ref, 'Ungültige URL');
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Navigation starten'),
        content: const Text('Möchtest du diesen Ort in einer Karten-App öffnen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Öffnen'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    if (!mounted) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showErrorToast(ref, 'Karten-App konnte nicht geöffnet werden');
      }
    }
  }

  Future<void> _editEvent() async {
    final analytics = ref.read(analyticsServiceProvider);
    unawaited(analytics.trackFeatureEvent(
      'event_edit_started',
      screen: 'event_detail',
      action: 'edit',
      target: widget.event['title']?.toString() ?? 'unknown',
    ));
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EventEditorPage(existingEvent: widget.event),
      ),
    );
    if (changed == true) {
      await ref.read(sync_service.syncServiceProvider).syncEvents(force: true);
    }
  }

  Future<void> _showHistoryDialog() async {
    final eventId = _eventIdAsInt;
    if (eventId == null) return;
    await showEventHistoryDialog(context, eventId: eventId);
  }

  Future<void> _deleteEvent() async {
    final analytics = ref.read(analyticsServiceProvider);
    unawaited(analytics.trackFeatureEvent(
      'event_delete_started',
      screen: 'event_detail',
      action: 'delete',
      target: widget.event['title']?.toString() ?? 'unknown',
    ));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Event löschen'),
        content: const Text('Möchtest du dieses Event löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final eventId = _eventIdAsInt;
    final token = ref.read(authorAuthProvider).token;
    if (eventId == null || token == null) return;

    await ref.read(sync_service.remoteEventSourceProvider).deleteEvent(
          token: token,
          eventId: eventId,
        );
    await ref.read(sync_service.syncServiceProvider).syncEvents(force: true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event['title']?.toString() ?? 'Unbenannt';
    final locationAddress = widget.event['locationAddress']?.toString();
    final locationLat = (widget.event['locationLat'] as num?)?.toDouble();
    final locationLng = (widget.event['locationLng'] as num?)?.toDouble();
    final eventLayerId = (widget.event['layerId'] as num?)?.toInt();
    final dv = ref.watch(layerNamesByIdProvider)[eventLayerId] ?? 'Unbekannt';
    final topic = _topicName;
    final description = widget.event['description']?.toString() ?? '';
    final startDate =
        formatEventDateTime(widget.event['startDate']?.toString());
    final endDate = formatEventDateTime(widget.event['endDate']?.toString());
    final cta1Url = widget.event['cta1Url']?.toString();
    final cta2Url = widget.event['cta2Url']?.toString();
    final hasCta1 = cta1Url != null && cta1Url.isNotEmpty;
    final hasCta2 = cta2Url != null && cta2Url.isNotEmpty;

    final canEditEvent = _canEditEvent;
    final canDeleteEvent = _canDeleteEvent;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _saving ? null : _toggleSaved,
            tooltip: _isSaved ? 'Gemerkt' : 'Merken',
          ),
          if (canEditEvent || canDeleteEvent)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editEvent();
                } else if (value == 'delete') {
                  _deleteEvent();
                } else if (value == 'history') {
                  _showHistoryDialog();
                }
              },
              itemBuilder: (context) => [
                if (canEditEvent)
                  const PopupMenuItem(
                      value: 'edit', child: Text('Bearbeiten')),
                if (canEditEvent)
                  const PopupMenuItem(
                      value: 'history', child: Text('Änderungsprotokoll')),
                if (canDeleteEvent)
                  const PopupMenuItem(
                      value: 'delete', child: Text('Löschen')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              LabeledChip(icon: Icons.groups, label: 'DV', value: dv),
              if (topic != null && topic.isNotEmpty)
                LabeledChip(
                  icon: Icons.topic,
                  label: 'Thema',
                  value: topic,
                  color: AppTheme.stufenfarbeFor(topic),
                ),
            ],
          ),
          if (locationLat != null && locationLng != null) ...[
            const SizedBox(height: 12),
            LocationMapView(
              lat: locationLat,
              lng: locationLng,
              address: locationAddress,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  _confirmAndOpenInMaps(locationLat, locationLng, locationAddress),
              icon: const Icon(Icons.directions),
              label: const Text('Navigation'),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Start: $startDate')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.event_available, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Ende: $endDate')),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          SafeMarkdownBody(data: description),
          const SizedBox(height: 24),
          if (hasCta1)
            FilledButton(
              onPressed: () => _confirmAndOpenLink(cta1Url, kEventCta1Label,
                  allowMailto: true),
              child: const Text(kEventCta1Label),
            ),
          if (hasCta1 && hasCta2) const SizedBox(height: 8),
          if (hasCta2)
            hasCta1
                ? OutlinedButton(
                    onPressed: () =>
                        _confirmAndOpenLink(cta2Url, kEventCta2Label),
                    child: const Text(kEventCta2Label),
                  )
                : FilledButton(
                    onPressed: () =>
                        _confirmAndOpenLink(cta2Url, kEventCta2Label),
                    child: const Text(kEventCta2Label),
                  ),
          const SizedBox(height: 24),
          SectionCard(
            title: 'Updates',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadingUpdates)
                  const Center(child: CircularProgressIndicator())
                else if (_updates.isEmpty)
                  const Text('Noch keine Updates vorhanden.')
                else
                  ..._updates.map((update) {
                    final authorUsername = update['authorUsername'] as String?;
                    final createdAt =
                        formatEventDateTime(update['createdAt'] as String?);
                    final canEditUpdate = update['canEdit'] == true;
                    final canDeleteUpdate = update['canDelete'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SafeMarkdownBody(
                                data: update['message'] as String? ?? ''),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${authorUsername ?? 'Unbekannt'} · $createdAt',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                if (canEditUpdate || canDeleteUpdate)
                                  PopupMenuButton<String>(
                                    iconSize: 18,
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editUpdate(update);
                                      } else if (value == 'delete') {
                                        _deleteUpdate(update);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (canEditUpdate)
                                        const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Bearbeiten')),
                                      if (canDeleteUpdate)
                                        const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Löschen')),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                if (_canCreateUpdate) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _updateMessageController,
                    decoration: const InputDecoration(
                      labelText: 'Neues Update (Markdown)',
                    ),
                    minLines: 3,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _postingUpdate ? null : _postUpdate,
                    child: _postingUpdate
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update senden'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

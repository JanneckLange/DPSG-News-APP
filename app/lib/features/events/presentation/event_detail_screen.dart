import 'dart:async';

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
import '../../../shared/widgets/location_placeholder.dart';
import '../../../shared/widgets/safe_markdown_body.dart';
import '../../../shared/widgets/section_card.dart';
import '../../admin/domain/topic_model.dart';
import 'event_editor_sheet.dart';

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

  bool get _canManageEvent {
    final authorAuth = ref.watch(authorAuthProvider);
    final eventAuthorId = widget.event['authorId'] is num
        ? (widget.event['authorId'] as num).toInt()
        : null;
    return authorAuth.isLoggedIn &&
        !authorAuth.isLocked &&
        !authorAuth.requiresPasswordChange &&
        (authorAuth.isAdmin || eventAuthorId == authorAuth.authorId);
  }

  Future<void> _loadUpdates() async {
    final eventId = _eventIdAsInt;
    if (eventId == null) {
      if (mounted) setState(() => _loadingUpdates = false);
      return;
    }
    setState(() => _loadingUpdates = true);
    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final updates = await remote.fetchEventUpdates(eventId: eventId);
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

  Future<void> _confirmAndOpenLink(String url, String label) async {
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
      additionalProperties: {'event_id': _eventId, 'url': url},
    ));

    if (!mounted) return;
    if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
      if (mounted) {
        showErrorToast(ref, 'Link konnte nicht geöffnet werden');
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
    final location = widget.event['location']?.toString() ?? 'Unbekannt';
    final eventLayerId = (widget.event['layerId'] as num?)?.toInt();
    final dv = ref.watch(layerNamesByIdProvider)[eventLayerId] ?? 'Unbekannt';
    final topic = _topicName;
    final description = widget.event['description']?.toString() ?? '';
    final startDate =
        formatEventDateTime(widget.event['startDate']?.toString());
    final endDate = formatEventDateTime(widget.event['endDate']?.toString());
    final cta1Label = widget.event['cta1Label']?.toString();
    final cta1Url = widget.event['cta1Url']?.toString();
    final cta2Label = widget.event['cta2Label']?.toString();
    final cta2Url = widget.event['cta2Url']?.toString();

    final canManageEvent = _canManageEvent;

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
          if (canManageEvent)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editEvent();
                } else if (value == 'delete') {
                  _deleteEvent();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                PopupMenuItem(value: 'delete', child: Text('Löschen')),
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
          const SizedBox(height: 12),
          LocationPlaceholder(label: location),
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
          if (cta1Label != null &&
              cta1Url != null &&
              cta1Label.isNotEmpty &&
              cta1Url.isNotEmpty)
            FilledButton(
              onPressed: () => _confirmAndOpenLink(cta1Url, cta1Label),
              child: Text(cta1Label),
            ),
          if (cta2Label != null &&
              cta2Url != null &&
              cta2Label.isNotEmpty &&
              cta2Url.isNotEmpty)
            FilledButton(
              onPressed: () => _confirmAndOpenLink(cta2Url, cta2Label),
              child: Text(cta2Label),
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
                            Text(
                              '${authorUsername ?? 'Unbekannt'} · $createdAt',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                if (canManageEvent) ...[
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

class EventDetailsPreview extends ConsumerWidget {
  const EventDetailsPreview({super.key, required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = event['title']?.toString() ?? 'Unbenannt';
    final location = event['location']?.toString() ?? 'Unbekannt';
    final eventLayerId = (event['layerId'] as num?)?.toInt();
    final dv = ref.watch(layerNamesByIdProvider)[eventLayerId] ?? 'Unbekannt';
    final topic = event['topic']?.toString();
    final description = event['description']?.toString() ?? '';
    final startDate = formatEventDateTime(event['startDate']?.toString());
    final endDate = formatEventDateTime(event['endDate']?.toString());
    final cta1Label = event['cta1Label']?.toString();
    final cta1Url = event['cta1Url']?.toString();
    final cta2Label = event['cta2Label']?.toString();
    final cta2Url = event['cta2Url']?.toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        LocationPlaceholder(label: location),
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
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Ende: $endDate')),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        Text(description, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          children: [
            if (cta1Label != null &&
                cta1Url != null &&
                cta1Label.isNotEmpty &&
                cta1Url.isNotEmpty)
              OutlinedButton(onPressed: null, child: Text(cta1Label)),
            if (cta2Label != null &&
                cta2Url != null &&
                cta2Label.isNotEmpty &&
                cta2Url.isNotEmpty)
              OutlinedButton(onPressed: null, child: Text(cta2Label)),
          ],
        ),
      ],
    );
  }
}

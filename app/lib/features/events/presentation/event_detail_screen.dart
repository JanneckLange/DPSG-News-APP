import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/error_toast_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../../author/data/author_auth_provider.dart';
import '../../settings/data/dv_tree_provider.dart';
import '../../settings/data/settings_repository.dart';

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
    });
    _loadUpdates();
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

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;

    setState(() => _postingUpdate = true);
    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      await remote.createEventUpdate(
        token: token,
        eventId: eventId,
        message: message,
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

  Future<void> _openExternalLink(String url, String label) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) {
        showErrorToast(ref, 'Ungültige URL');
      }
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

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showErrorToast(ref, 'Link konnte nicht geöffnet werden');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event['title']?.toString() ?? 'Unbenannt';
    final location = widget.event['location']?.toString() ?? 'Unbekannt';
    final eventLayerId = (widget.event['layerId'] as num?)?.toInt();
    final dv = ref.watch(layerNamesByIdProvider)[eventLayerId] ?? 'Unbekannt';
    final topic = widget.event['topic']?.toString();
    final description = widget.event['description']?.toString() ?? '';
    final startDate =
        formatEventDateTime(widget.event['startDate']?.toString());
    final endDate = formatEventDateTime(widget.event['endDate']?.toString());
    final cta1Label = widget.event['cta1Label']?.toString();
    final cta1Url = widget.event['cta1Url']?.toString();
    final cta2Label = widget.event['cta2Label']?.toString();
    final cta2Url = widget.event['cta2Url']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event-Details'),
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
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Chip(label: Text(dv)),
              if (topic != null && topic.isNotEmpty) Chip(label: Text(topic)),
              Chip(label: Text(location)),
            ],
          ),
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
          MarkdownBody(data: description),
          const SizedBox(height: 24),
          if (cta1Label != null &&
              cta1Url != null &&
              cta1Label.isNotEmpty &&
              cta1Url.isNotEmpty)
            FilledButton(
              onPressed: () => _openExternalLink(cta1Url, cta1Label),
              child: Text(cta1Label),
            ),
          if (cta2Label != null &&
              cta2Url != null &&
              cta2Label.isNotEmpty &&
              cta2Url.isNotEmpty)
            FilledButton(
              onPressed: () => _openExternalLink(cta2Url, cta2Label),
              child: Text(cta2Label),
            ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('Updates', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
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
                      MarkdownBody(data: update['message'] as String? ?? ''),
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
          if (_canManageEvent) ...[
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
    );
  }
}

String formatEventDateTime(String? value) {
  if (value == null) return 'Nicht gesetzt';
  final dateTime = DateTime.tryParse(value);
  if (dateTime == null) return value;
  final local = dateTime.toLocal();
  final now = DateTime.now();
  final showYear = local.year != now.year;
  final pattern = showYear ? 'EEEE, d. MMMM yyyy HH:mm' : 'EEEE, d. MMMM HH:mm';
  try {
    final df = DateFormat(pattern, 'de');
    return df.format(local);
  } catch (_) {
    return local.toLocal().toString().split('.').first;
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
            Chip(label: Text(dv)),
            if (topic != null && topic.isNotEmpty) Chip(label: Text(topic)),
            Chip(label: Text(location)),
          ],
        ),
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

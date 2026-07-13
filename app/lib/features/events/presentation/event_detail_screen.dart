import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/notification_service.dart';
import '../../settings/data/settings_repository.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.event});

  final Map<String, dynamic> event;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _saving = false;

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
  }

  String get _eventId => widget.event['id']?.toString() ?? '';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ungültige URL')), 
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link konnte nicht geöffnet werden')), 
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event['title']?.toString() ?? 'Unbenannt';
    final location = widget.event['location']?.toString() ?? 'Unbekannt';
    final dv = widget.event['dv']?.toString() ?? 'Unbekannt';
    final topic = widget.event['topic']?.toString();
    final description = widget.event['description']?.toString() ?? '';
    final startDate = formatEventDateTime(widget.event['startDate']?.toString());
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
          if (cta1Label != null && cta1Url != null && cta1Label.isNotEmpty && cta1Url.isNotEmpty)
            FilledButton(
              onPressed: () => _openExternalLink(cta1Url, cta1Label),
              child: Text(cta1Label),
            ),
          if (cta2Label != null && cta2Url != null && cta2Label.isNotEmpty && cta2Url.isNotEmpty)
            FilledButton(
              onPressed: () => _openExternalLink(cta2Url, cta2Label),
              child: Text(cta2Label),
            ),
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

class EventDetailsPreview extends StatelessWidget {
  const EventDetailsPreview({super.key, required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final title = event['title']?.toString() ?? 'Unbenannt';
    final location = event['location']?.toString() ?? 'Unbekannt';
    final dv = event['dv']?.toString() ?? 'Unbekannt';
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
            if (cta1Label != null && cta1Url != null && cta1Label.isNotEmpty && cta1Url.isNotEmpty)
              OutlinedButton(onPressed: null, child: Text(cta1Label)),
            if (cta2Label != null && cta2Url != null && cta2Label.isNotEmpty && cta2Url.isNotEmpty)
              OutlinedButton(onPressed: null, child: Text(cta2Label)),
          ],
        ),
      ],
    );
  }
}

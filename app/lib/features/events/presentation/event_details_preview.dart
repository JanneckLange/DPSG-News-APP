import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../settings/data/dv_tree_provider.dart';
import '../../../shared/utils/date_format_utils.dart';
import '../../../shared/widgets/labeled_chip.dart';
import '../../../shared/widgets/location_map_view.dart';

class EventDetailsPreview extends ConsumerWidget {
  const EventDetailsPreview({super.key, required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = event['title']?.toString() ?? 'Unbenannt';
    final locationAddress = event['locationAddress']?.toString();
    final locationLat = (event['locationLat'] as num?)?.toDouble();
    final locationLng = (event['locationLng'] as num?)?.toDouble();
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
        if (locationLat != null && locationLng != null) ...[
          const SizedBox(height: 12),
          LocationMapView(
            lat: locationLat,
            lng: locationLng,
            address: locationAddress,
            interactive: false,
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/features/admin/domain/topic_model.dart';
import 'package:dpsg_news_app/features/admin/presentation/widgets/layer_topic_grant_tree_dialog.dart';
import 'package:dpsg_news_app/features/settings/domain/layer_model.dart';

const _layers = [
  LayerModel(id: 1, name: 'Hamburg', parentId: null),
  LayerModel(id: 2, name: 'Köln', parentId: null),
];

final _topics = [
  const TopicModel(
    id: 10,
    name: 'Wölflinge',
    layerId: 1,
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  ),
];

void main() {
  testWidgets(
      'returns independently toggled layer and topic grants on save (#15/#18)',
      (tester) async {
    LayerTopicGrantSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showLayerTopicGrantTreeDialog(
                context,
                layers: _layers,
                topics: _topics,
                initialSelectedLayerIds: const {},
                initialSelectedTopicIds: const {},
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Nur Hamburg hat ein Topic als Kind-Knoten - bestaetigt, dass Topics
    // korrekt unter ihrem Layer eingehaengt werden, nicht global angezeigt.
    expect(find.widgetWithText(CheckboxListTile, 'Wölflinge'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Köln'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Wölflinge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    // Layer-Grant fuer Koeln gewaehlt, Hamburg NICHT (Topic-Grant vererbt
    // nicht auf den Layer selbst - unabhaengige Rechte, siehe Klassendoc).
    expect(result!.layerIds, {2});
    expect(result!.topicIds, {10});
    expect(tester.takeException(), isNull);
  });

  testWidgets('returns null on cancel', (tester) async {
    LayerTopicGrantSelection? result = const LayerTopicGrantSelection(
      layerIds: {99},
      topicIds: {99},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showLayerTopicGrantTreeDialog(
                context,
                layers: _layers,
                topics: _topics,
                initialSelectedLayerIds: const {},
                initialSelectedTopicIds: const {},
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}

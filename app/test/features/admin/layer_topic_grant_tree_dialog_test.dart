import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/features/admin/domain/topic_model.dart';
import 'package:dpsg_news_app/features/admin/presentation/widgets/layer_topic_grant_tree_dialog.dart';
import 'package:dpsg_news_app/features/settings/domain/layer_model.dart';

void main() {
  const layers = [
    LayerModel(id: 1, name: 'Bundesverband', parentId: null),
    LayerModel(id: 2, name: 'Koeln', parentId: 1),
  ];
  final topics = [
    const TopicModel(
      id: 5,
      name: 'Stufenaktion',
      layerId: 1,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    ),
  ];

  testWidgets(
      'renders layers and their topics, and returns toggled layer+topic selection on Speichern',
      (tester) async {
    LayerTopicGrantSelection? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showLayerTopicGrantTreeDialog(
              context,
              layers: layers,
              topics: topics,
              initialSelectedLayerIds: const {},
              initialSelectedTopicIds: const {},
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Autoren-Rechte auswählen'), findsOneWidget);
    expect(find.text('Bundesverband'), findsOneWidget);
    expect(find.text('Koeln'), findsOneWidget);
    expect(find.text('Stufenaktion'), findsOneWidget);

    await tester.tap(find.text('Koeln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stufenaktion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.layerIds, {2});
    expect(result!.topicIds, {5});
  });

  testWidgets('layer and topic selections are independent of each other',
      (tester) async {
    LayerTopicGrantSelection? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showLayerTopicGrantTreeDialog(
              context,
              layers: layers,
              topics: topics,
              initialSelectedLayerIds: const {},
              initialSelectedTopicIds: const {},
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Only toggle the topic, not its parent layer.
    await tester.tap(find.text('Stufenaktion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result!.layerIds, isEmpty);
    expect(result!.topicIds, {5});
  });

  testWidgets('canceling returns null without applying any toggles',
      (tester) async {
    LayerTopicGrantSelection? result;
    var wasCalledWithNonNull = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showLayerTopicGrantTreeDialog(
              context,
              layers: layers,
              topics: topics,
              initialSelectedLayerIds: const {},
              initialSelectedTopicIds: const {},
            );
            wasCalledWithNonNull = result != null;
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koeln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(wasCalledWithNonNull, isFalse);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/features/admin/domain/topic_model.dart';
import 'package:dpsg_news_app/features/admin/presentation/widgets/topic_multi_select_dialog.dart';

final _topics = [
  const TopicModel(
    id: 10,
    name: 'Wölflinge',
    layerId: 1,
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  ),
  const TopicModel(
    id: 11,
    name: 'Jungpfadfinder',
    layerId: 1,
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  ),
];

void main() {
  testWidgets('only offers the passed-in (already scoped) topics for selection',
      (tester) async {
    Set<int>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showTopicMultiSelectDialog(
                context,
                title: 'Topics auswählen',
                availableTopics: _topics,
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

    expect(find.widgetWithText(CheckboxListTile, 'Wölflinge'), findsOneWidget);
    expect(
        find.widgetWithText(CheckboxListTile, 'Jungpfadfinder'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Wölflinge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, {10});
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a placeholder instead of an empty list when no topics are available',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await showTopicMultiSelectDialog(
                context,
                title: 'Topics auswählen',
                availableTopics: const [],
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

    expect(find.text('Keine Topics verfügbar.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

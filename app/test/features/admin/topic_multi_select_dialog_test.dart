import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/features/admin/domain/topic_model.dart';
import 'package:dpsg_news_app/features/admin/presentation/widgets/topic_multi_select_dialog.dart';

void main() {
  final topics = [
    const TopicModel(
      id: 1,
      name: 'Stufenaktion',
      layerId: 3,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    ),
    const TopicModel(
      id: 2,
      name: 'Zeltlager',
      layerId: 3,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    ),
  ];

  Future<void> openDialog(
    WidgetTester tester, {
    required List<TopicModel> availableTopics,
    required Set<int> initialSelectedTopicIds,
    required ValueSetter<Set<int>?> onResult,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final result = await showTopicMultiSelectDialog(
              context,
              title: 'Themen auswählen',
              availableTopics: availableTopics,
              initialSelectedTopicIds: initialSelectedTopicIds,
            );
            onResult(result);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the dialog title and all topics with the initial selection checked',
      (tester) async {
    await openDialog(
      tester,
      availableTopics: topics,
      initialSelectedTopicIds: {1},
      onResult: (_) {},
    );

    expect(find.text('Themen auswählen'), findsOneWidget);
    expect(find.text('Stufenaktion'), findsOneWidget);
    expect(find.text('Zeltlager'), findsOneWidget);

    final stufenaktionTile = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Stufenaktion'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(stufenaktionTile.value, isTrue);

    final zeltlagerTile = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Zeltlager'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(zeltlagerTile.value, isFalse);
  });

  testWidgets('shows an empty-state message when no topics are available',
      (tester) async {
    await openDialog(
      tester,
      availableTopics: const [],
      initialSelectedTopicIds: const {},
      onResult: (_) {},
    );

    expect(find.text('Keine Topics verfügbar.'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('checking a topic and confirming returns the updated selection',
      (tester) async {
    Set<int>? result;
    await openDialog(
      tester,
      availableTopics: topics,
      initialSelectedTopicIds: {1},
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Zeltlager'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, {1, 2});
  });

  testWidgets('unchecking a topic and confirming removes it from the selection',
      (tester) async {
    Set<int>? result;
    await openDialog(
      tester,
      availableTopics: topics,
      initialSelectedTopicIds: {1, 2},
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Stufenaktion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, {2});
  });

  testWidgets('canceling returns null without applying any toggles',
      (tester) async {
    Set<int>? result = <int>{};
    await openDialog(
      tester,
      availableTopics: topics,
      initialSelectedTopicIds: {1},
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Zeltlager'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}

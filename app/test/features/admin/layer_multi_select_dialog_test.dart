import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/features/admin/presentation/widgets/layer_multi_select_dialog.dart';
import 'package:dpsg_news_app/features/settings/domain/layer_model.dart';

void main() {
  const layers = [
    LayerModel(id: 1, name: 'Bundesverband', parentId: null),
    LayerModel(id: 2, name: 'Koeln', parentId: 1),
  ];

  Future<Set<int>?> openDialog(
    WidgetTester tester, {
    required Set<int> initialSelectedIds,
    bool disableDescendantsOfSelected = false,
  }) async {
    Set<int>? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showLayerMultiSelectDialog(
              context,
              layers: layers,
              initialSelectedIds: initialSelectedIds,
              disableDescendantsOfSelected: disableDescendantsOfSelected,
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows all layers as checkboxes with the initial selection checked',
      (tester) async {
    await openDialog(tester, initialSelectedIds: {1});

    expect(find.text('Bundesverband'), findsOneWidget);
    expect(find.text('Koeln'), findsOneWidget);

    final bundesverbandTile = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Bundesverband'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(bundesverbandTile.value, isTrue);

    final koelnTile = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Koeln'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(koelnTile.value, isFalse);
  });

  testWidgets('toggling a layer and confirming returns the updated selection',
      (tester) async {
    Set<int>? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showLayerMultiSelectDialog(
              context,
              layers: layers,
              initialSelectedIds: {1},
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koeln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, {1, 2});
  });

  testWidgets('canceling returns null without applying any toggles',
      (tester) async {
    Set<int>? result = <int>{};
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showLayerMultiSelectDialog(
              context,
              layers: layers,
              initialSelectedIds: {1},
            );
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
  });

  testWidgets(
      'disableDescendantsOfSelected shows a descendant of a selected layer as checked and disabled',
      (tester) async {
    await openDialog(
      tester,
      initialSelectedIds: {1},
      disableDescendantsOfSelected: true,
    );

    final koelnTile = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Koeln'),
        matching: find.byType(CheckboxListTile),
      ),
    );

    expect(koelnTile.value, isTrue);
    expect(koelnTile.onChanged, isNull);
  });
}

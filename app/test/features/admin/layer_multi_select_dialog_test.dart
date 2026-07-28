import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/features/admin/presentation/widgets/layer_multi_select_dialog.dart';
import 'package:dpsg_news_app/features/settings/domain/layer_model.dart';

const _layers = [
  LayerModel(id: 1, name: 'Hamburg', parentId: null),
  LayerModel(id: 2, name: 'Köln', parentId: null),
];

void main() {
  testWidgets('returns the toggled selection on save', (tester) async {
    Set<int>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showLayerMultiSelectDialog(
                context,
                layers: _layers,
                initialSelectedIds: const {1},
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Hamburg'))
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Köln'))
          .value,
      isFalse,
    );

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Köln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, {1, 2});
    expect(tester.takeException(), isNull);
  });

  testWidgets('returns null on cancel without changing the caller state',
      (tester) async {
    Set<int>? result = const {99};
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showLayerMultiSelectDialog(
                context,
                layers: _layers,
                initialSelectedIds: const {1},
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Köln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/features/events/presentation/event_list_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the DV chip by default (backwards compatible)',
      (tester) async {
    await tester.pumpWidget(wrap(const EventListTile(
      title: 'Titel',
      location: 'Ort',
      layerName: 'Köln',
    )));

    expect(find.text('Köln'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsNothing);
  });

  testWidgets('hides the DV chip when showDv is false', (tester) async {
    await tester.pumpWidget(wrap(const EventListTile(
      title: 'Titel',
      location: 'Ort',
      layerName: 'Köln',
      showDv: false,
    )));

    expect(find.text('Köln'), findsNothing);
  });

  testWidgets('shows the topic chip when topic is set', (tester) async {
    await tester.pumpWidget(wrap(const EventListTile(
      title: 'Titel',
      location: 'Ort',
      layerName: 'Köln',
      topic: 'Pfadfinder',
    )));

    expect(find.text('Pfadfinder'), findsOneWidget);
  });

  testWidgets('shows a bookmark indicator when isSaved is true',
      (tester) async {
    await tester.pumpWidget(wrap(const EventListTile(
      title: 'Titel',
      location: 'Ort',
      layerName: 'Köln',
      isSaved: true,
    )));

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('shows a NEU label when showNewBadge is true', (tester) async {
    await tester.pumpWidget(wrap(const EventListTile(
      title: 'Titel',
      location: 'Ort',
      layerName: 'Köln',
      showNewBadge: true,
    )));

    expect(find.text('NEU'), findsOneWidget);
  });

  testWidgets('shows a new-update badge when showNewUpdateBadge is true',
      (tester) async {
    await tester.pumpWidget(wrap(const EventListTile(
      title: 'Titel',
      location: 'Ort',
      layerName: 'Köln',
      showNewUpdateBadge: true,
    )));

    expect(find.byType(Badge), findsOneWidget);
  });

  testWidgets('renders a calendar leaf when startDate is set', (tester) async {
    await tester.pumpWidget(wrap(EventListTile(
      title: 'Titel',
      location: 'Ort',
      layerName: 'Köln',
      startDate: DateTime(2026, 8, 16),
    )));

    expect(find.text('16'), findsOneWidget);
  });
}

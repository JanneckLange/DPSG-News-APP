import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/app.dart';

void main() {
  testWidgets('App shows welcome text', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Willkommen zur DPSG News APP'), findsOneWidget);
  });
}

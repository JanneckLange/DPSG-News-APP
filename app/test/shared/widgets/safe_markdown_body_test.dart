import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/shared/widgets/safe_markdown_body.dart';

void main() {
  Future<void> pumpMarkdown(WidgetTester tester, String data) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SafeMarkdownBody(data: data)),
      ),
    );
  }

  testWidgets('renders an Image for http image URLs', (tester) async {
    await pumpMarkdown(tester, '![Alt-Text](https://example.org/bild.png)');

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
  });

  testWidgets('does not load images with a non-http scheme', (tester) async {
    await pumpMarkdown(tester, '![Alt-Text](file:///etc/passwd)');

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.text('Alt-Text'), findsOneWidget);
  });

  testWidgets('does not load images with a javascript scheme', (tester) async {
    await pumpMarkdown(tester, '![](javascript:alert(1))');

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('renders plain markdown text unaffected', (tester) async {
    await pumpMarkdown(tester, '**Wichtig:** Ort geändert.');

    expect(find.textContaining('Wichtig:'), findsOneWidget);
  });
}

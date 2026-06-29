import 'dart:io';

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/app.dart';
import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart';

class FakeRemoteEventSource extends RemoteEventSource {
  FakeRemoteEventSource() : super(baseUrl: Uri.parse('http://localhost'));

  @override
  Future<List<Map<String, dynamic>>> fetchEvents() async {
    return [
      {
        'title': 'Test Event',
        'location': 'Testort',
        'dv': 'Köln',
      },
    ];
  }
}

void main() {
  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    await HiveService.initialize(path: tempDir.path);
  });

  tearDownAll(() async {
    await HiveService.close();
  });

  testWidgets('App shows the events screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteEventSourceProvider.overrideWithValue(FakeRemoteEventSource()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Events'), findsWidgets);
    expect(find.text('Test Event'), findsOneWidget);
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/features/onboarding/presentation/welcome_screen.dart';
import 'package:dpsg_news_app/features/settings/data/settings_repository.dart';

class FakeRemoteEventSource extends RemoteEventSource {
  FakeRemoteEventSource() : super(baseUrl: Uri.parse('http://localhost'));

  @override
  Future<Map<String, dynamic>> fetchDvTree() async {
    return {
      'lastTreeChange': '2026-01-01T00:00:00.000Z',
      'dvs': [
        {
          'name': 'Hamburg',
          'url': 'https://example.com/hamburg',
          'groups': <String>[],
        },
      ],
    };
  }
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder,
    {int maxPumps = 20, Duration step = const Duration(milliseconds: 100)}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (tester.any(finder)) return;
    await tester.pump(step);
  }
}

void main() {
  late SettingsRepository repository;

  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    await HiveService.initialize(path: tempDir.path);
  });

  setUp(() {
    repository = SettingsRepository(HiveService.getSettingsBox());
  });

  tearDown(() async {
    await HiveService.getSettingsBox().clear();
    await HiveService.getEventsBox().clear();
  });

  Future<void> pumpWelcomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sync_service.remoteEventSourceProvider
              .overrideWithValue(FakeRemoteEventSource()),
        ],
        child: const MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await pumpUntilFound(tester, find.text('Hamburg'));
  }

  testWidgets('shows welcome text and DV list directly, no navigation needed',
      (WidgetTester tester) async {
    await pumpWelcomeScreen(tester);

    expect(find.text('Willkommen bei der DPSG News App'), findsOneWidget);
    expect(find.text('Hamburg'), findsOneWidget);
  });

  testWidgets('skip sets the flag without persisting a selection',
      (WidgetTester tester) async {
    await pumpWelcomeScreen(tester);

    await tester.tap(find.text('Später auswählen'));
    await tester.pump();

    expect(repository.getHasSeenWelcome(), isTrue);
    expect(repository.getSelectedDvs(), isEmpty);
  });

  testWidgets('finish persists the checked DV and sets the flag',
      (WidgetTester tester) async {
    await pumpWelcomeScreen(tester);

    await tester.tap(find.text('Hamburg'));
    await tester.pump();
    await tester.tap(find.text('Fertig'));
    await tester.pump();

    expect(repository.getHasSeenWelcome(), isTrue);
    expect(repository.getSelectedDvs(), ['Hamburg']);
  });
}

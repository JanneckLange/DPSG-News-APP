import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/features/onboarding/presentation/welcome_screen.dart';
import 'package:dpsg_news_app/features/settings/data/settings_repository.dart';

const hamburgLayerId = 1;

class FakeRemoteEventSource extends RemoteEventSource {
  FakeRemoteEventSource() : super(baseUrl: Uri.parse('http://localhost'));

  @override
  Future<Map<String, dynamic>> fetchLayers() async {
    return {
      'lastChange': '2026-01-01T00:00:00.000Z',
      'layers': [
        {
          'id': 0,
          'name': 'Bundesverband DPSG',
          'type': 'bundesverband',
          'parentId': null,
        },
        {
          'id': hamburgLayerId,
          'name': 'Hamburg',
          'type': 'dv',
          'parentId': 0,
          'url': 'https://example.com/hamburg',
          'groups': <String>[],
        },
      ],
    };
  }
}

// Nutzt einen echten Future.delayed statt nur tester.pump(step): Der
// Layer-Baum wird ueber einen echten Hive-Schreibzugriff geladen (siehe
// pumpWelcomeScreen), der reale Verstreichzeit braucht, um fortzuschreiten.
// tester.pump(step) allein spult nur die Fake-Clock vor und laesst dem
// echten I/O keine Chance, voranzukommen.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder,
    {int maxPumps = 20,
    Duration step = const Duration(milliseconds: 100)}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (tester.any(finder)) return;
    await Future<void>.delayed(step);
    await tester.pump();
  }
}

// Wie pumpUntilFound: laesst echten Hive-/Notification-I/O (ausgeloest durch
// einen Tap-Callback, den tester.tap() nicht abwartet) reale Zeit zum
// Fortschreiten, bevor der naechste Frame gepumpt wird.
Future<void> settle(WidgetTester tester,
    {Duration duration = const Duration(milliseconds: 200)}) async {
  await Future<void>.delayed(duration);
  await tester.pump();
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

  // WelcomeScreen laedt den Layer-Baum und persistiert die Auswahl ueber
  // echte Hive-Schreibzugriffe (LayerTreeNotifier._loadTree, save(),
  // setHasSeenWelcome). Das muss ausserhalb des Fake-Async-Zeittakts der
  // testWidgets()-Zone laufen, sonst haengt der Test (siehe
  // events_screen_test.dart fuer denselben Fall) - daher laeuft die
  // komplette Interaktion pro Test in einem gemeinsamen runAsync-Block.
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
    await tester.runAsync(() async {
      await pumpWelcomeScreen(tester);

      expect(find.text('Willkommen bei der DPSG News App'), findsOneWidget);
      expect(find.text('Hamburg'), findsOneWidget);
    });
  });

  testWidgets('skip sets the flag without persisting a selection',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await pumpWelcomeScreen(tester);

      await tester.tap(find.text('Später auswählen'));
      await settle(tester);

      expect(repository.getHasSeenWelcome(), isTrue);
      expect(repository.getSelectedLayerIds(), isEmpty);
    });
  });

  testWidgets('finish persists the checked DV and sets the flag',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await pumpWelcomeScreen(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hamburg'));
      await tester.pump();
      await tester.tap(find.text('Fertig'));
      await settle(tester);

      expect(repository.getHasSeenWelcome(), isTrue);
      expect(repository.getSelectedLayerIds(), [hamburgLayerId]);
    });
  });
}

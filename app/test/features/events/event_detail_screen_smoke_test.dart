import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/features/events/domain/event_cta_labels.dart';
import 'package:dpsg_news_app/features/events/presentation/event_detail_screen.dart';
import 'package:dpsg_news_app/features/settings/data/settings_repository.dart'
    as settings_repo;
import 'package:dpsg_news_app/shared/widgets/location_map_view.dart';

import '../../widget_test.dart'
    show FakeSecureStorageService, TestAuthorAuthNotifier;

const _koelnLayerId = 1;
const _pfadfinderTopicId = 5;

class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource() : super(baseUrl: Uri.parse('http://localhost'));

  @override
  Future<List<Map<String, dynamic>>> fetchEventUpdates(
          {required int eventId, String? token}) async =>
      [];

  @override
  Future<Map<String, dynamic>> fetchLayers() async => {
        'lastChange': '2026-01-01T00:00:00.000Z',
        'layers': [
          {
            'id': 0,
            'name': 'Bundesverband DPSG',
            'type': 'bundesverband',
            'parentId': null,
          },
          {
            'id': _koelnLayerId,
            'name': 'Köln',
            'type': 'dv',
            'parentId': 0,
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> fetchTopics({int? layerId}) async => {
        'topics': [
          {
            'id': _pfadfinderTopicId,
            'name': 'Pfadfinder',
            'layerId': _koelnLayerId,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      };
}

// Wartet mit echter Verstreichzeit (statt nur tester.pump()) darauf, dass
// finder etwas findet. Noetig, weil EventDetailScreen den Layer-Namen ueber
// layerNamesByIdProvider aufloest, der seinerseits echten Hive-I/O braucht
// (siehe layerTreeProvider._loadTree), um von "loading" auf "data" zu
// wechseln - ein einzelnes kurzes Future.delayed ist dafuer nicht zuverlaessig
// genug.
Future<void> _pumpUntilFound(WidgetTester tester, Finder finder,
    {int maxAttempts = 20,
    Duration step = const Duration(milliseconds: 100)}) async {
  for (var i = 0; i < maxAttempts; i++) {
    if (tester.any(finder)) return;
    await Future<void>.delayed(step);
    await tester.pump();
  }
}

final _sampleEvent = <String, dynamic>{
  'id': 1,
  'title': 'Sommerlager',
  'locationAddress': 'Zeltplatz',
  'locationLat': 50.9375,
  'locationLng': 6.9603,
  'layerId': _koelnLayerId,
  'topicId': _pfadfinderTopicId,
  'startDate': '2026-08-01T10:00:00Z',
  'endDate': '2026-08-03T15:00:00Z',
  'description': 'Ein tolles Lager.',
  'authorId': 1,
};

// canEdit/canDelete werden serverseitig berechnet (Rechtematrix #1/#16) und
// muessen im Test-Fixture explizit gesetzt werden, sobald der Viewer das
// Event verwalten koennen soll - der Client leitet das nicht mehr lokal her.
final _sampleEventOwned = <String, dynamic>{
  ..._sampleEvent,
  'canEdit': true,
  'canDelete': true,
};

Future<void> _pumpEvent(WidgetTester tester, Map<String, dynamic> event) async {
  final repository =
      settings_repo.SettingsRepository(HiveService.getSettingsBox());
  final secureStorage = FakeSecureStorageService();
  final remote = _FakeRemoteEventSource();

  await tester.runAsync(() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sync_service.remoteEventSourceProvider.overrideWithValue(remote),
          settings_repo.settingsRepositoryProvider
              .overrideWithValue(repository),
          authorAuthProvider.overrideWith(
            (ref) => TestAuthorAuthNotifier(
              repository: repository,
              remote: remote,
              secureStorage: secureStorage,
              ref: ref,
              initialState:
                  const AuthorAuthState(isLoggedIn: false),
            ),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.light(),
          home: EventDetailScreen(event: event),
        ),
      ),
    );
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
}

void main() {
  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    await HiveService.initialize(path: tempDir.path);
    await initializeDateFormatting('de');
  });

  tearDown(() async {
    await HiveService.getSettingsBox().clear();
  });

  testWidgets(
      'renders title in AppBar, DV/Topic chips and location map',
      (tester) async {
    final repository =
        settings_repo.SettingsRepository(HiveService.getSettingsBox());
    final secureStorage = FakeSecureStorageService();
    final remote = _FakeRemoteEventSource();

    // runAsync: EventDetailScreen.initState markiert das Event via echtem
    // Hive-Schreibzugriff als gesehen; das laesst sich nicht allein per
    // pump() abwarten (real I/O ausserhalb des Fake-Async-Zeittakts).
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sync_service.remoteEventSourceProvider.overrideWithValue(remote),
            authorAuthProvider.overrideWith(
              (ref) => TestAuthorAuthNotifier(
                repository: repository,
                remote: remote,
                secureStorage: secureStorage,
                ref: ref,
                initialState:
                    const AuthorAuthState(isLoggedIn: false),
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: EventDetailScreen(event: _sampleEvent),
          ),
        ),
      );
      await tester.pump();
      await _pumpUntilFound(tester, find.text('DV: Köln'));
      await _pumpUntilFound(tester, find.text('Thema: Pfadfinder'));
      // Der markViewed()-Aufruf in initState ist bewusst "fire-and-forget"
      // (blockiert die UI nicht). Kurze reale Wartezeit, damit der Hive-
      // Schreibvorgang abschliesst, bevor Test/Container/Widget-Baum
      // aufgeraeumt werden.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    expect(find.text('Sommerlager'), findsOneWidget);
    expect(find.text('DV: Köln'), findsOneWidget);
    expect(find.text('Thema: Pfadfinder'), findsOneWidget);
    expect(find.text('Zeltplatz'), findsOneWidget);
    expect(find.byType(LocationMapView), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the manage popup menu when the viewer owns the event',
      (tester) async {
    final repository =
        settings_repo.SettingsRepository(HiveService.getSettingsBox());
    final secureStorage = FakeSecureStorageService();
    final remote = _FakeRemoteEventSource();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sync_service.remoteEventSourceProvider.overrideWithValue(remote),
            settings_repo.settingsRepositoryProvider
                .overrideWithValue(repository),
            authorAuthProvider.overrideWith(
              (ref) => TestAuthorAuthNotifier(
                repository: repository,
                remote: remote,
                secureStorage: secureStorage,
                ref: ref,
                initialState: AuthorAuthState(
                  isLoggedIn: true,
                  token: 'test-token',
                  refreshToken: 'test-refresh-token',
                  authorId: 1,
                  username: 'author',
                  isAdmin: false,
                  requiresPasswordChange: false,
                  expiresAt: DateTime.utc(2099, 1, 1),
                  refreshExpiresAt: DateTime.utc(2099, 2, 1),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: EventDetailScreen(event: _sampleEventOwned),
          ),
        ),
      );
      await tester.pump();
      // Der markViewed()-Aufruf in initState ist bewusst "fire-and-forget"
      // (blockiert die UI nicht). Kurze reale Wartezeit, damit der Hive-
      // Schreibvorgang abschliesst, bevor Test/Container/Widget-Baum
      // aufgeraeumt werden.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Bearbeiten'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
  });

  testWidgets('marks the event as viewed when the detail screen opens',
      (tester) async {
    final repository =
        settings_repo.SettingsRepository(HiveService.getSettingsBox());
    final secureStorage = FakeSecureStorageService();
    final remote = _FakeRemoteEventSource();

    final container = ProviderContainer(
      overrides: [
        sync_service.remoteEventSourceProvider.overrideWithValue(remote),
        authorAuthProvider.overrideWith(
          (ref) => TestAuthorAuthNotifier(
            repository: repository,
            remote: remote,
            secureStorage: secureStorage,
            ref: ref,
            initialState:
                const AuthorAuthState(isLoggedIn: false),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.light(),
            home: EventDetailScreen(event: _sampleEvent),
          ),
        ),
      );
      await tester.pump();
      // Der markViewed()-Aufruf in initState ist bewusst "fire-and-forget"
      // (blockiert die UI nicht). Kurze reale Wartezeit, damit der Hive-
      // Schreibvorgang abschliesst, bevor Test/Container/Widget-Baum
      // aufgeraeumt werden.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    expect(container.read(settings_repo.eventViewedAtProvider).containsKey('1'),
        isTrue);
  });

  testWidgets('renders only CTA1 as a FilledButton when CTA2 is absent',
      (tester) async {
    await _pumpEvent(tester, {
      ..._sampleEvent,
      'cta1Url': 'https://example.org/anmeldung',
    });

    expect(find.widgetWithText(FilledButton, kEventCta1Label), findsOneWidget);
    expect(find.text(kEventCta2Label), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders CTA2 as a FilledButton (primary) when CTA1 is absent',
      (tester) async {
    await _pumpEvent(tester, {
      ..._sampleEvent,
      'cta2Url': 'https://example.org/infos',
    });

    expect(find.widgetWithText(FilledButton, kEventCta2Label), findsOneWidget);
    expect(find.text(kEventCta1Label), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'renders CTA1 as primary and CTA2 as secondary when both are set',
      (tester) async {
    await _pumpEvent(tester, {
      ..._sampleEvent,
      'cta1Url': 'https://example.org/anmeldung',
      'cta2Url': 'https://example.org/infos',
    });

    expect(find.widgetWithText(FilledButton, kEventCta1Label), findsOneWidget);
    expect(
        find.widgetWithText(OutlinedButton, kEventCta2Label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shows an email confirmation dialog when CTA1 is a mailto address',
      (tester) async {
    await _pumpEvent(tester, {
      ..._sampleEvent,
      'cta1Url': 'mailto:kontakt@example.org',
    });

    await tester.tap(find.widgetWithText(FilledButton, kEventCta1Label));
    await tester.pumpAndSettle();

    expect(find.text('E-Mail senden'), findsOneWidget);
    expect(find.textContaining('kontakt@example.org'), findsOneWidget);
    expect(find.text('Webseite öffnen'), findsNothing);

    // Dialog ueber "Abbrechen" schliessen, statt launchUrl auszuloesen.
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
  });
}

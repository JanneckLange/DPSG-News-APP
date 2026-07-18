import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/features/events/presentation/event_detail_screen.dart';
import 'package:dpsg_news_app/features/settings/data/settings_repository.dart' as settings_repo;

import '../../widget_test.dart' show FakeSecureStorageService, TestAuthorAuthNotifier;

class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource() : super(baseUrl: Uri.parse('http://localhost'));

  @override
  Future<List<Map<String, dynamic>>> fetchEventUpdates({required int eventId}) async => [];
}

final _sampleEvent = <String, dynamic>{
  'id': 1,
  'title': 'Sommerlager',
  'location': 'Zeltplatz',
  'dv': 'Köln',
  'topic': 'Pfadfinder',
  'startDate': '2026-08-01T10:00:00Z',
  'endDate': '2026-08-03T15:00:00Z',
  'description': 'Ein tolles Lager.',
  'authorId': 1,
};

void main() {
  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    await HiveService.initialize(path: tempDir.path);
    await initializeDateFormatting('de');
  });

  tearDown(() async {
    await HiveService.getSettingsBox().clear();
  });

  testWidgets('renders title in AppBar, DV/Topic chips and location placeholder', (tester) async {
    final repository = settings_repo.SettingsRepository(HiveService.getSettingsBox());
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
                initialState: const AuthorAuthState(isLoggedIn: false, isLocked: false),
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
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the manage popup menu when the viewer owns the event', (tester) async {
    final repository = settings_repo.SettingsRepository(HiveService.getSettingsBox());
    final secureStorage = FakeSecureStorageService();
    final remote = _FakeRemoteEventSource();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sync_service.remoteEventSourceProvider.overrideWithValue(remote),
            settings_repo.settingsRepositoryProvider.overrideWithValue(repository),
            authorAuthProvider.overrideWith(
              (ref) => TestAuthorAuthNotifier(
                repository: repository,
                remote: remote,
                secureStorage: secureStorage,
                initialState: AuthorAuthState(
                  isLoggedIn: true,
                  isLocked: false,
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

    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Bearbeiten'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
  });

  testWidgets('marks the event as viewed when the detail screen opens', (tester) async {
    final repository = settings_repo.SettingsRepository(HiveService.getSettingsBox());
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
            initialState: const AuthorAuthState(isLoggedIn: false, isLocked: false),
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

    expect(container.read(settings_repo.eventViewedAtProvider).containsKey('1'), isTrue);
  });
}

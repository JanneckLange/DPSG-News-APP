import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/author/data/own_events_provider.dart';
import 'package:dpsg_news_app/features/author/presentation/author_screen.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';

import '../../widget_test.dart'
    show
        FakeSecureStorageService,
        FakeSettingsRepository,
        TestAuthorAuthNotifier;

class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource({
    List<Map<String, dynamic>> events = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> drafts = const <Map<String, dynamic>>[],
  })  : _events = List<Map<String, dynamic>>.of(events),
        _drafts = List<Map<String, dynamic>>.of(drafts),
        super(baseUrl: Uri.parse('http://localhost'));

  final List<Map<String, dynamic>> _events;
  final List<Map<String, dynamic>> _drafts;
  int deleteDraftCallCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchOwnEvents(
      {required String token}) async {
    return _events;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOwnDrafts(
      {required String token}) async {
    return _drafts;
  }

  @override
  Future<void> deleteDraft(
      {required String token, required int draftId}) async {
    deleteDraftCallCount++;
    _drafts.removeWhere((d) => (d['id'] as num).toInt() == draftId);
  }
}

AuthorAuthState _loggedInState({
  bool requiresPasswordChange = false,
}) {
  return AuthorAuthState(
    isLoggedIn: true,
    token: 'valid-token',
    refreshToken: 'refresh-token',
    authorId: 1,
    username: 'author',
    requiresPasswordChange: requiresPasswordChange,
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    refreshExpiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
    layerGrantIds: const [1],
  );
}

void main() {
  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    await HiveService.initialize(path: tempDir.path);
  });

  tearDown(() async {
    await HiveService.getSettingsBox().clear();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required _FakeRemoteEventSource remote,
    AuthorAuthState? initialState,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sync_service.remoteEventSourceProvider.overrideWithValue(remote),
          authorAuthProvider.overrideWith(
            (ref) => TestAuthorAuthNotifier(
              repository: FakeSettingsRepository(),
              remote: remote,
              secureStorage: FakeSecureStorageService(),
              ref: ref,
              initialState: initialState ?? _loggedInState(),
            ),
          ),
          ...extraOverrides,
        ],
        child: const MaterialApp(home: AuthorScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
      'shows the change-password button while a password change is required',
      (tester) async {
    final remote = _FakeRemoteEventSource();
    await pumpScreen(tester,
        remote: remote,
        initialState: _loggedInState(requiresPasswordChange: true));

    expect(find.text('Passwort ändern'), findsOneWidget);
    expect(find.byIcon(Icons.password), findsOneWidget);
  });

  testWidgets('shows the events error message when loading own events fails',
      (tester) async {
    final remote = _FakeRemoteEventSource();
    await pumpScreen(
      tester,
      remote: remote,
      extraOverrides: [
        ownEventsProvider.overrideWith((ref) async {
          throw Exception('events boom');
        }),
      ],
    );

    expect(find.textContaining('events boom'), findsOneWidget);
  });

  testWidgets('shows the drafts error message when loading own drafts fails',
      (tester) async {
    final remote = _FakeRemoteEventSource();
    await pumpScreen(
      tester,
      remote: remote,
      extraOverrides: [
        ownDraftsProvider.overrideWith((ref) async {
          throw Exception('drafts boom');
        }),
      ],
    );

    expect(find.textContaining('drafts boom'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no events and no drafts',
      (tester) async {
    final remote = _FakeRemoteEventSource();
    await pumpScreen(tester, remote: remote);

    expect(find.text('Noch keine eigenen Events vorhanden.'), findsOneWidget);
    expect(find.text('Erstes Event erstellen'), findsOneWidget);
  });

  testWidgets(
      'tapping the stale-events stat tile navigates to the stale events screen',
      (tester) async {
    final now = DateTime.now();
    final staleEvent = {
      'id': 1,
      'title': 'Vergessenes Event',
      'locationAddress': 'Zeltplatz',
      'startDate': now.add(const Duration(days: 60)).toUtc().toIso8601String(),
      'lastUpdateAt':
          now.subtract(const Duration(days: 40)).toUtc().toIso8601String(),
    };
    final remote = _FakeRemoteEventSource(events: [staleEvent]);
    await pumpScreen(tester, remote: remote);

    expect(find.text('Lange kein Update'), findsOneWidget);

    await tester.tap(find.text('Lange kein Update'));
    await tester.pumpAndSettle();

    expect(find.text('Vergessenes Event'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'deleting a draft asks for confirmation and removes it from the list on confirm',
      (tester) async {
    final remote = _FakeRemoteEventSource(drafts: [
      {'id': 7, 'title': 'Mein Entwurf', 'locationAddress': 'Zeltplatz'}
    ]);
    await pumpScreen(tester, remote: remote);

    expect(find.text('Entwürfe (1)'), findsOneWidget);
    await tester.tap(find.text('Entwürfe (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.text('Entwurf löschen'), findsOneWidget);
    expect(remote.deleteDraftCallCount, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await tester.pumpAndSettle();

    expect(remote.deleteDraftCallCount, 1);
    expect(find.text('Mein Entwurf'), findsNothing);
  });
}

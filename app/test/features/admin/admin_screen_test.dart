import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/admin/presentation/admin_screen.dart';
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';

import '../../widget_test.dart'
    show
        FakeSettingsRepository,
        FakeSecureStorageService,
        TestAuthorAuthNotifier;

class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource({
    this.users = const <Map<String, dynamic>>[],
    this.fetchAdminUsersError,
  }) : super(baseUrl: Uri.parse('http://localhost'));

  final List<Map<String, dynamic>> users;
  final Object? fetchAdminUsersError;
  int fetchAdminUsersCallCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchAdminUsers(
      {required String token}) async {
    fetchAdminUsersCallCount++;
    if (fetchAdminUsersError != null) {
      // ignore: only_throw_errors
      throw fetchAdminUsersError!;
    }
    return users;
  }

  // LayerAdminTree wird direkt in AdminScreen eingebettet (kein eigener
  // Screen/Navigation mehr, siehe "Layer-Baum direkt anzeigen") und laedt in
  // initState eigene Daten -- leere, aber gueltige Antworten reichen, damit
  // das Einbetten nicht crasht.
  @override
  Future<Map<String, dynamic>> fetchAdminLayers({required String token}) async {
    return {'layers': <Map<String, dynamic>>[]};
  }

  @override
  Future<Map<String, dynamic>> fetchTopics({int? layerId}) async {
    return {'topics': <Map<String, dynamic>>[]};
  }
}

AuthorAuthState _adminState() {
  return AuthorAuthState(
    isLoggedIn: true,
    token: 'valid-token',
    refreshToken: 'refresh-token',
    authorId: 1,
    username: 'admin',
    isAdmin: true,
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    refreshExpiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
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
    WidgetTester tester,
    _FakeRemoteEventSource remote, {
    AuthorAuthState? initialState,
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
              initialState: initialState ?? _adminState(),
            ),
          ),
        ],
        child: const MaterialApp(home: AdminScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the access-denied screen when not logged in',
      (tester) async {
    final remote = _FakeRemoteEventSource();
    await pumpScreen(tester, remote, initialState: AuthorAuthState.signedOut());

    expect(find.text('Kein Zugriff auf den Admin-Bereich.'), findsOneWidget);
    expect(remote.fetchAdminUsersCallCount, 0);
  });

  testWidgets(
      'shows the access-denied screen when logged in but not an admin',
      (tester) async {
    final remote = _FakeRemoteEventSource();
    await pumpScreen(
      tester,
      remote,
      initialState: AuthorAuthState(
        isLoggedIn: true,
        token: 'valid-token',
        refreshToken: 'refresh-token',
        authorId: 1,
        username: 'plain-author',
        isAdmin: false,
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        refreshExpiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
      ),
    );

    expect(find.text('Kein Zugriff auf den Admin-Bereich.'), findsOneWidget);
  });

  testWidgets(
      'shows the user list with Autor/Admin/Deaktiviert/Reset-offen chips after opening "Alle Nutzer"',
      (tester) async {
    final remote = _FakeRemoteEventSource(users: [
      {'username': 'aktiver-autor', 'isActive': true, 'isAdmin': false},
      {
        'username': 'inaktiver-admin',
        'isActive': false,
        'isAdmin': true,
        'requiresPasswordChange': true,
      },
    ]);
    await pumpScreen(tester, remote);
    await tester.tap(find.text('Alle Nutzer'));
    await tester.pumpAndSettle();

    expect(remote.fetchAdminUsersCallCount, 1);
    expect(find.text('aktiver-autor'), findsOneWidget);
    expect(find.text('inaktiver-admin'), findsOneWidget);
    expect(find.text('Autor'), findsNWidgets(2));
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Deaktiviert'), findsOneWidget);
    expect(find.text('Reset offen'), findsOneWidget);
  });

  testWidgets('shows the raw error message when loading users fails',
      (tester) async {
    final remote = _FakeRemoteEventSource(
      fetchAdminUsersError: RemoteEventSourceException('Server down'),
    );
    await pumpScreen(tester, remote);
    await tester.tap(find.text('Alle Nutzer'));
    await tester.pumpAndSettle();

    expect(
      find.text('RemoteEventSourceException: Server down'),
      findsOneWidget,
    );
  });

  testWidgets('the refresh button reloads the user list', (tester) async {
    final remote = _FakeRemoteEventSource(users: const []);
    await pumpScreen(tester, remote);
    await tester.tap(find.text('Alle Nutzer'));
    await tester.pumpAndSettle();

    expect(remote.fetchAdminUsersCallCount, 1);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(remote.fetchAdminUsersCallCount, 2);
  });

  testWidgets(
      'embeds the layer tree directly without a separate navigation step (#71: kein eigener Scaffold mehr)',
      (tester) async {
    final remote = _FakeRemoteEventSource();
    await pumpScreen(tester, remote);

    expect(find.text('Keine Layer vorhanden.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

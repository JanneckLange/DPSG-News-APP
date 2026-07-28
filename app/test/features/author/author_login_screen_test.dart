import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/author/presentation/author_login_screen.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';

import '../../widget_test.dart'
    show
        FakeSettingsRepository,
        FakeSecureStorageService,
        TestAuthorAuthNotifier;

/// Steuerbarer RemoteEventSource-Stub fuer loginAuthor: liefert wahlweise
/// eine Session oder wirft den gegebenen Fehler.
class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource({this.loginResult, this.loginError})
      : super(baseUrl: Uri.parse('http://localhost'));

  final AuthorLoginSession? loginResult;
  final Object? loginError;
  int loginCallCount = 0;
  String? lastUsername;
  String? lastPassword;

  @override
  Future<AuthorLoginSession> loginAuthor({
    required String username,
    required String password,
  }) async {
    loginCallCount++;
    lastUsername = username;
    lastPassword = password;
    if (loginError != null) {
      // ignore: only_throw_errors
      throw loginError!;
    }
    return loginResult!;
  }
}

AuthorLoginSession _session({bool requiresPasswordChange = false}) {
  return AuthorLoginSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    accessExpiresAt:
        DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(),
    refreshExpiresAt:
        DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
    authorId: 1,
    username: 'max',
    isAdmin: false,
    requiresPasswordChange: requiresPasswordChange,
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

  Future<void> pumpLoginScreen(
      WidgetTester tester, _FakeRemoteEventSource remote) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authorAuthProvider.overrideWith(
            (ref) => TestAuthorAuthNotifier(
              repository: FakeSettingsRepository(),
              remote: remote,
              secureStorage: FakeSecureStorageService(),
              ref: ref,
              initialState: AuthorAuthState.signedOut(),
            ),
          ),
        ],
        child: const MaterialApp(home: AuthorLoginScreen()),
      ),
    );
  }

  testWidgets(
      'shows validation errors on empty submit and does not attempt a login',
      (tester) async {
    final remote = _FakeRemoteEventSource(loginResult: _session());
    await pumpLoginScreen(tester, remote);

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Bitte Username eingeben.'), findsOneWidget);
    expect(find.text('Bitte Passwort eingeben.'), findsOneWidget);
    expect(remote.loginCallCount, 0);
  });

  testWidgets(
      'a successful login without a required password change pops the screen with true',
      (tester) async {
    final remote = _FakeRemoteEventSource(loginResult: _session());
    bool? popped;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authorAuthProvider.overrideWith(
            (ref) => TestAuthorAuthNotifier(
              repository: FakeSettingsRepository(),
              remote: remote,
              secureStorage: FakeSecureStorageService(),
              ref: ref,
              initialState: AuthorAuthState.signedOut(),
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const AuthorLoginScreen()),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'max');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Passwort'), 'geheim123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(remote.loginCallCount, 1);
    expect(remote.lastUsername, 'max');
    expect(remote.lastPassword, 'geheim123');
    expect(popped, isTrue);
    expect(find.text('Autoren-Login'), findsNothing);
  });

  testWidgets(
      'a successful login that requires a password change pushes the change-password screen',
      (tester) async {
    final remote =
        _FakeRemoteEventSource(loginResult: _session(requiresPasswordChange: true));
    await pumpLoginScreen(tester, remote);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'max');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Passwort'), 'geheim123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Passwort ändern'), findsOneWidget);
  });

  testWidgets('shows a friendly message for wrong credentials (401)',
      (tester) async {
    final remote = _FakeRemoteEventSource(
      loginError: RemoteEventSourceException('unauthorized', statusCode: 401),
    );
    await pumpLoginScreen(tester, remote);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'max');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Passwort'), 'wrong');
    await tester.tap(find.text('Login'));
    await tester.pump();
    // Der Fehlerzustand blendet sich nach 500ms per Timer wieder aus --
    // muss abgewartet werden, sonst bleibt ein Timer nach Testende pending.
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Benutzername oder Passwort falsch.'), findsOneWidget);
    expect(find.text('Autoren-Login'), findsOneWidget);
  });

  testWidgets('shows the server error message for other failures',
      (tester) async {
    final remote = _FakeRemoteEventSource(
      loginError: RemoteEventSourceException(
        'failed',
        statusCode: 500,
        serverMessage: 'Server ist ueberlastet',
      ),
    );
    await pumpLoginScreen(tester, remote);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'max');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Passwort'), 'geheim123');
    await tester.tap(find.text('Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Server ist ueberlastet'), findsOneWidget);
  });

  testWidgets('the password visibility toggle switches the obscure icon',
      (tester) async {
    final remote = _FakeRemoteEventSource(loginResult: _session());
    await pumpLoginScreen(tester, remote);

    expect(find.byTooltip('Passwort anzeigen'), findsOneWidget);

    await tester.tap(find.byTooltip('Passwort anzeigen'));
    await tester.pump();

    expect(find.byTooltip('Passwort verbergen'), findsOneWidget);
    expect(find.byTooltip('Passwort anzeigen'), findsNothing);
  });
}

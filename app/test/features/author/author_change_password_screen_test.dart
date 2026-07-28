import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/author/presentation/author_change_password_screen.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';

import '../../widget_test.dart'
    show
        FakeSettingsRepository,
        FakeSecureStorageService,
        TestAuthorAuthNotifier;

/// Steuerbarer RemoteEventSource-Stub fuer changeAuthorPassword: liefert
/// wahlweise Erfolg oder wirft den gegebenen Fehler, und zeichnet die
/// uebergebenen Argumente auf.
class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource({this.error})
      : super(baseUrl: Uri.parse('http://localhost'));

  final Object? error;
  int callCount = 0;
  String? lastOldPassword;
  String? lastNewPassword;

  @override
  Future<void> changeAuthorPassword({
    required String token,
    String? oldPassword,
    required String newPassword,
  }) async {
    callCount++;
    lastOldPassword = oldPassword;
    lastNewPassword = newPassword;
    if (error != null) {
      // ignore: only_throw_errors
      throw error!;
    }
  }
}

AuthorAuthState _loggedInState({required bool requiresPasswordChange}) {
  return AuthorAuthState(
    isLoggedIn: true,
    isLocked: false,
    token: 'valid-token',
    refreshToken: 'refresh-token',
    authorId: 1,
    username: 'author',
    requiresPasswordChange: requiresPasswordChange,
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
    WidgetTester tester, {
    required _FakeRemoteEventSource remote,
    required bool requiresPasswordChange,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authorAuthProvider.overrideWith(
            (ref) => TestAuthorAuthNotifier(
              repository: FakeSettingsRepository(),
              remote: remote,
              secureStorage: FakeSecureStorageService(),
              ref: ref,
              initialState:
                  _loggedInState(requiresPasswordChange: requiresPasswordChange),
            ),
          ),
        ],
        child: const MaterialApp(home: AuthorChangePasswordScreen()),
      ),
    );
  }

  testWidgets('shows the old-password field when a change is not required',
      (tester) async {
    await pumpScreen(
      tester,
      remote: _FakeRemoteEventSource(),
      requiresPasswordChange: false,
    );

    expect(find.widgetWithText(TextFormField, 'Altes Passwort'),
        findsOneWidget);
  });

  testWidgets('hides the old-password field when a change is already required',
      (tester) async {
    await pumpScreen(
      tester,
      remote: _FakeRemoteEventSource(),
      requiresPasswordChange: true,
    );

    expect(find.widgetWithText(TextFormField, 'Altes Passwort'), findsNothing);
  });

  testWidgets('rejects a new password shorter than 8 characters',
      (tester) async {
    final remote = _FakeRemoteEventSource();
    await pumpScreen(tester, remote: remote, requiresPasswordChange: true);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Neues Passwort'), 'short');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Neues Passwort wiederholen'),
        'short');
    await tester.tap(find.text('Passwort speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Mindestens 8 Zeichen erforderlich.'), findsOneWidget);
    expect(remote.callCount, 0);
  });

  testWidgets('rejects a confirmation that does not match the new password',
      (tester) async {
    final remote = _FakeRemoteEventSource();
    await pumpScreen(tester, remote: remote, requiresPasswordChange: true);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Neues Passwort'), 'new-password-1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Neues Passwort wiederholen'),
        'does-not-match');
    await tester.tap(find.text('Passwort speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Passwörter stimmen nicht überein.'), findsOneWidget);
    expect(remote.callCount, 0);
  });

  testWidgets(
      'requires the old password when a change is not already required',
      (tester) async {
    final remote = _FakeRemoteEventSource();
    await pumpScreen(tester, remote: remote, requiresPasswordChange: false);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Neues Passwort'), 'new-password-1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Neues Passwort wiederholen'),
        'new-password-1');
    await tester.tap(find.text('Passwort speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Bitte altes Passwort eingeben.'), findsOneWidget);
    expect(remote.callCount, 0);
  });

  testWidgets(
      'saves the new password with the old password and pops with true when a change is not required',
      (tester) async {
    final remote = _FakeRemoteEventSource();
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
              initialState: _loggedInState(requiresPasswordChange: false),
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                      builder: (_) => const AuthorChangePasswordScreen()),
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
        find.widgetWithText(TextFormField, 'Altes Passwort'), 'old-password');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Neues Passwort'), 'new-password-1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Neues Passwort wiederholen'),
        'new-password-1');
    await tester.tap(find.text('Passwort speichern'));
    await tester.pumpAndSettle();

    expect(remote.callCount, 1);
    expect(remote.lastOldPassword, 'old-password');
    expect(remote.lastNewPassword, 'new-password-1');
    expect(popped, isTrue);
  });

  testWidgets(
      'omits the old password when a change is already required (one-time-password flow)',
      (tester) async {
    final remote = _FakeRemoteEventSource();
    await pumpScreen(tester, remote: remote, requiresPasswordChange: true);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Neues Passwort'), 'new-password-1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Neues Passwort wiederholen'),
        'new-password-1');
    await tester.tap(find.text('Passwort speichern'));
    await tester.pumpAndSettle();

    expect(remote.callCount, 1);
    expect(remote.lastOldPassword, isNull);
    expect(remote.lastNewPassword, 'new-password-1');
  });

  testWidgets(
      'keeps the screen open and re-enables the button when the server call fails',
      (tester) async {
    final remote = _FakeRemoteEventSource(
      error: RemoteEventSourceException('failed', statusCode: 500),
    );
    await pumpScreen(tester, remote: remote, requiresPasswordChange: true);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Neues Passwort'), 'new-password-1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Neues Passwort wiederholen'),
        'new-password-1');
    await tester.tap(find.text('Passwort speichern'));
    await tester.pumpAndSettle();

    expect(remote.callCount, 1);
    expect(find.text('Passwort ändern'), findsOneWidget);
    expect(find.text('Passwort speichern'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

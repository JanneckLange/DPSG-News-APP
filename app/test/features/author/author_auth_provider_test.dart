import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';

import '../../widget_test.dart'
    show
        FakeSettingsRepository,
        FakeSecureStorageService,
        TestAuthorAuthNotifier;

/// Steuerbarer RemoteEventSource-Stub fuer refreshAuthorSession: liefert
/// wahlweise Erfolg oder eine RemoteEventSourceException mit gegebenem
/// Statuscode, und zaehlt die Aufrufe.
class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource({this.refreshResult, this.refreshErrorStatusCode})
      : super(baseUrl: Uri.parse('http://localhost'));

  final AuthorLoginSession? refreshResult;
  final int? refreshErrorStatusCode;
  int refreshCallCount = 0;

  @override
  Future<AuthorLoginSession> refreshAuthorSession(
      {required String refreshToken}) async {
    refreshCallCount++;
    if (refreshErrorStatusCode != null) {
      throw RemoteEventSourceException(
        'refresh failed',
        statusCode: refreshErrorStatusCode,
      );
    }
    return refreshResult!;
  }

  @override
  Future<void> logoutAuthor({required String token}) async {}
}

AuthorLoginSession _session({String accessToken = 'refreshed-token'}) {
  return AuthorLoginSession(
    accessToken: accessToken,
    refreshToken: 'new-refresh-token',
    accessExpiresAt:
        DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(),
    refreshExpiresAt:
        DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
    authorId: 1,
    username: 'author',
    isAdmin: false,
    requiresPasswordChange: false,
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

  ProviderContainer buildContainer(_FakeRemoteEventSource remote) {
    final container = ProviderContainer(
      overrides: [
        authorAuthProvider.overrideWith(
          (ref) => TestAuthorAuthNotifier(
            repository: FakeSettingsRepository(),
            remote: remote,
            secureStorage: FakeSecureStorageService(),
            ref: ref,
            initialState: AuthorAuthState(
              isLoggedIn: true,
              token: 'valid-token',
              refreshToken: 'refresh-token',
              authorId: 1,
              username: 'author',
              expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
              refreshExpiresAt:
                  DateTime.now().toUtc().add(const Duration(days: 7)),
            ),
          ),
        ),
      ],
    );
    return container;
  }

  test('callAuthenticated returns the request result when no 401 occurs',
      () async {
    final remote = _FakeRemoteEventSource();
    final container = buildContainer(remote);
    addTearDown(container.dispose);
    final notifier = container.read(authorAuthProvider.notifier);

    final result = await notifier.callAuthenticated((token) async {
      expect(token, 'valid-token');
      return 'ok';
    });

    expect(result, 'ok');
    expect(remote.refreshCallCount, 0);
    expect(container.read(authorAuthProvider).isLoggedIn, isTrue);
  });

  test('callAuthenticated force-refreshes once and retries after a live 401',
      () async {
    final remote = _FakeRemoteEventSource(refreshResult: _session());
    final container = buildContainer(remote);
    addTearDown(container.dispose);
    final notifier = container.read(authorAuthProvider.notifier);

    var attempt = 0;
    final result = await notifier.callAuthenticated((token) async {
      attempt++;
      if (attempt == 1) {
        expect(token, 'valid-token');
        throw RemoteEventSourceException('unauthorized', statusCode: 401);
      }
      expect(token, 'refreshed-token');
      return 'ok-after-retry';
    });

    expect(result, 'ok-after-retry');
    expect(attempt, 2);
    expect(remote.refreshCallCount, 1);
    expect(container.read(authorAuthProvider).isLoggedIn, isTrue);
  });

  test(
      'callAuthenticated logs out and rethrows when the forced refresh itself fails',
      () async {
    final remote = _FakeRemoteEventSource(refreshErrorStatusCode: 401);
    final container = buildContainer(remote);
    addTearDown(container.dispose);
    final notifier = container.read(authorAuthProvider.notifier);

    Object? caught;
    try {
      await notifier.callAuthenticated((token) async {
        throw RemoteEventSourceException('unauthorized', statusCode: 401);
      });
    } catch (error) {
      caught = error;
    }

    expect(caught, isNotNull);
    expect(remote.refreshCallCount, 1);
    expect(container.read(authorAuthProvider).isLoggedIn, isFalse);
  });

  test('callAuthenticated logs out and rethrows when the retry also gets a 401',
      () async {
    final remote = _FakeRemoteEventSource(refreshResult: _session());
    final container = buildContainer(remote);
    addTearDown(container.dispose);
    final notifier = container.read(authorAuthProvider.notifier);

    Object? caught;
    try {
      await notifier.callAuthenticated((token) async {
        throw RemoteEventSourceException('unauthorized', statusCode: 401);
      });
    } catch (error) {
      caught = error;
    }

    expect(caught, isNotNull);
    expect(remote.refreshCallCount, 1);
    expect(container.read(authorAuthProvider).isLoggedIn, isFalse);
  });
}

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/author/data/own_events_provider.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';

import '../../widget_test.dart'
    show
        FakeSettingsRepository,
        FakeSecureStorageService,
        TestAuthorAuthNotifier;

class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource() : super(baseUrl: Uri.parse('http://localhost'));

  int fetchOwnEventsCallCount = 0;
  int fetchOwnDraftsCallCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchOwnEvents(
      {required String token}) async {
    fetchOwnEventsCallCount++;
    return [
      {'id': 1, 'title': 'Sommerlager'}
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOwnDrafts(
      {required String token}) async {
    fetchOwnDraftsCallCount++;
    return [
      {'id': 2, 'title': 'Entwurf'}
    ];
  }
}

AuthorAuthState _loggedInState({
  bool isLocked = false,
  bool requiresPasswordChange = false,
}) {
  return AuthorAuthState(
    isLoggedIn: true,
    isLocked: isLocked,
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

  ProviderContainer buildContainer(_FakeRemoteEventSource remote,
      AuthorAuthState initialState) {
    final container = ProviderContainer(
      overrides: [
        sync_service.remoteEventSourceProvider.overrideWithValue(remote),
        authorAuthProvider.overrideWith(
          (ref) => TestAuthorAuthNotifier(
            repository: FakeSettingsRepository(),
            remote: remote,
            secureStorage: FakeSecureStorageService(),
            ref: ref,
            initialState: initialState,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('ownEventsProvider returns an empty list without calling the remote source when signed out',
      () async {
    final remote = _FakeRemoteEventSource();
    final container =
        buildContainer(remote, AuthorAuthState.signedOut());

    final events = await container.read(ownEventsProvider.future);

    expect(events, isEmpty);
    expect(remote.fetchOwnEventsCallCount, 0);
  });

  test('ownEventsProvider returns an empty list while the author area is locked',
      () async {
    final remote = _FakeRemoteEventSource();
    final container =
        buildContainer(remote, _loggedInState(isLocked: true));

    final events = await container.read(ownEventsProvider.future);

    expect(events, isEmpty);
    expect(remote.fetchOwnEventsCallCount, 0);
  });

  test(
      'ownEventsProvider returns an empty list while a password change is still required',
      () async {
    final remote = _FakeRemoteEventSource();
    final container =
        buildContainer(remote, _loggedInState(requiresPasswordChange: true));

    final events = await container.read(ownEventsProvider.future);

    expect(events, isEmpty);
    expect(remote.fetchOwnEventsCallCount, 0);
  });

  test(
      'ownEventsProvider fetches the author\'s own events via callAuthenticated when fully logged in',
      () async {
    final remote = _FakeRemoteEventSource();
    final container = buildContainer(remote, _loggedInState());

    final events = await container.read(ownEventsProvider.future);

    expect(events, hasLength(1));
    expect(events.first['title'], 'Sommerlager');
    expect(remote.fetchOwnEventsCallCount, 1);
  });

  test('ownDraftsProvider returns an empty list without calling the remote source when signed out',
      () async {
    final remote = _FakeRemoteEventSource();
    final container =
        buildContainer(remote, AuthorAuthState.signedOut());

    final drafts = await container.read(ownDraftsProvider.future);

    expect(drafts, isEmpty);
    expect(remote.fetchOwnDraftsCallCount, 0);
  });

  test(
      'ownDraftsProvider fetches the author\'s own drafts via callAuthenticated when fully logged in',
      () async {
    final remote = _FakeRemoteEventSource();
    final container = buildContainer(remote, _loggedInState());

    final drafts = await container.read(ownDraftsProvider.future);

    expect(drafts, hasLength(1));
    expect(drafts.first['title'], 'Entwurf');
    expect(remote.fetchOwnDraftsCallCount, 1);
  });
}

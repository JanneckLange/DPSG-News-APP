import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/admin/presentation/admin_user_detail_screen.dart';
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/features/settings/data/settings_repository.dart'
    as settings_repo;

import '../../widget_test.dart'
    show FakeSecureStorageService, TestAuthorAuthNotifier;

const _hamburgLayerId = 1;
const _koelnLayerId = 2;

class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource() : super(baseUrl: Uri.parse('http://localhost'));

  @override
  Future<Map<String, dynamic>> fetchAdminLayers({required String token}) async => {
        'layers': [
          {'id': _hamburgLayerId, 'name': 'Hamburg', 'parentId': null},
          {'id': _koelnLayerId, 'name': 'Köln', 'parentId': null},
        ],
      };

  @override
  Future<Map<String, dynamic>> fetchTopics({int? layerId}) async =>
      {'topics': <Map<String, dynamic>>[]};

  @override
  Future<List<Map<String, dynamic>>> fetchEvents({String? token}) async => [];
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder,
    {int maxAttempts = 20, Duration step = const Duration(milliseconds: 100)}) async {
  for (var i = 0; i < maxAttempts; i++) {
    if (tester.any(finder)) return;
    await Future<void>.delayed(step);
    await tester.pump();
  }
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

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Map<String, dynamic> user,
  }) async {
    final repository =
        settings_repo.SettingsRepository(HiveService.getSettingsBox());
    final secureStorage = FakeSecureStorageService();
    final remote = _FakeRemoteEventSource();

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
              ref: ref,
              initialState: AuthorAuthState(
                isLoggedIn: true,
                isLocked: false,
                token: 'test-token',
                authorId: 99,
                username: 'acting-admin',
                isAdmin: true,
                expiresAt: DateTime.utc(2099, 1, 1),
              ),
            ),
          ),
        ],
        child: MaterialApp(home: AdminUserDetailScreen(user: user)),
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'shows admin/author grant chips resolved to layer names and the deactivate/reset actions',
      (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester, user: {
        'id': 42,
        'username': 'Layer-Admin',
        'isAdmin': true,
        'isActive': true,
        'requiresPasswordChange': false,
        'adminLayerIds': [_hamburgLayerId],
        'layerGrantIds': [_koelnLayerId],
        'topicGrantIds': <int>[],
      });
      await _pumpUntilFound(tester, find.text('Hamburg'));
      await _pumpUntilFound(tester, find.text('Köln'));
    });

    expect(find.text('Layer-Admin'), findsWidgets);
    expect(find.text('Hamburg'), findsOneWidget);
    expect(find.text('Köln'), findsOneWidget);
    expect(find.text('Deaktivieren'), findsOneWidget);
    expect(find.text('Passwort resetten'), findsOneWidget);
    // Aktives Konto muss zuerst deaktiviert werden, bevor geloescht werden
    // kann (server: DELETE liefert 409 fuer aktive Konten) - der Button darf
    // fuer ein aktives Konto daher gar nicht erst angeboten werden.
    expect(find.text('Löschen'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the delete action once the account is deactivated',
      (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester, user: {
        'id': 43,
        'username': 'Inactive-Author',
        'isAdmin': false,
        'isActive': false,
        'requiresPasswordChange': false,
        'adminLayerIds': <int>[],
        'layerGrantIds': [_koelnLayerId],
        'topicGrantIds': <int>[],
      });
      await _pumpUntilFound(tester, find.text('Köln'));
    });

    expect(find.text('Aktivieren'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

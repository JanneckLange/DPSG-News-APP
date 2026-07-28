import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/admin/presentation/layer_admin_tree.dart';
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/features/settings/data/settings_repository.dart'
    as settings_repo;

import '../../widget_test.dart'
    show FakeSecureStorageService, TestAuthorAuthNotifier;

const _hamburgLayerId = 1;
const _koelnLayerId = 2;

// Der Baum zeigt genau die von /api/admin/layers gelieferten Layer an - die
// Sichtbarkeitseinschraenkung selbst (nur eigener Layer-Zweig, #18/#112)
// liegt serverseitig und wird dort getestet; hier wird nur geprueft, dass
// der Baum die (bereits gescopten) Daten korrekt rendert, inkl. Autoren-/
// Topic-Zaehler.
class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource() : super(baseUrl: Uri.parse('http://localhost'));

  @override
  Future<Map<String, dynamic>> fetchAdminLayers({required String token}) async => {
        'layers': [
          {
            'id': _hamburgLayerId,
            'name': 'Hamburg',
            'parentId': null,
            'authorCount': 2,
          },
          {
            'id': _koelnLayerId,
            'name': 'Köln',
            'parentId': _hamburgLayerId,
            'authorCount': 0,
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> fetchTopics({int? layerId}) async => {
        'topics': [
          {
            'id': 10,
            'name': 'Wölflinge',
            'layerId': _koelnLayerId,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      };
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

  testWidgets(
      'renders only the layers returned by the (server-scoped) admin layer tree, with author/topic counts',
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
                  isLocked: false,
                  token: 'test-token',
                  authorId: 1,
                  username: 'admin',
                  isAdmin: true,
                  expiresAt: DateTime.utc(2099, 1, 1),
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: LayerAdminTree())),
        ),
      );
      await _pumpUntilFound(tester, find.text('Hamburg'));
      await _pumpUntilFound(tester, find.text('Köln'));
    });

    expect(find.text('Hamburg'), findsOneWidget);
    expect(find.text('Köln'), findsOneWidget);
    expect(find.textContaining('2 Autoren, 1 Sub-Layer, 0 Topics'),
        findsOneWidget);
    expect(
        find.textContaining('0 Autoren, 0 Sub-Layer, 1 Topics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

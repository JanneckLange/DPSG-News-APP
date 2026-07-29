import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/theme/app_theme.dart';
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/author/data/own_events_provider.dart';
import 'package:dpsg_news_app/features/author/presentation/author_screen.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/features/events/presentation/event_list_tile.dart';
import 'package:dpsg_news_app/features/settings/data/settings_repository.dart'
    as settings_repo;

import '../../widget_test.dart'
    show FakeSecureStorageService, TestAuthorAuthNotifier;

void main() {
  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    await HiveService.initialize(path: tempDir.path);
    await initializeDateFormatting('de');
  });

  tearDown(() async {
    await HiveService.getSettingsBox().clear();
  });

  testWidgets('shows a login button when not logged in', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthorScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Autoren-Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shows dashboard stats and own events without edit/delete buttons',
      (tester) async {
    final repository =
        settings_repo.SettingsRepository(HiveService.getSettingsBox());
    final secureStorage = FakeSecureStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settings_repo.settingsRepositoryProvider
              .overrideWithValue(repository),
          authorAuthProvider.overrideWith(
            (ref) => TestAuthorAuthNotifier(
              repository: repository,
              remote: RemoteEventSourceStub(),
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
          ownEventsProvider.overrideWith((ref) async => [
                {
                  'id': 1,
                  'title': 'Sommerlager',
                  'locationAddress': 'Zeltplatz',
                  'dv': 'Köln',
                  'startDate': DateTime.now().toUtc().toIso8601String(),
                },
              ]),
          ownDraftsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AuthorScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Events online'), findsOneWidget);
    expect(find.text('Diesen Monat'), findsOneWidget);
    expect(find.text('Lange kein Update'), findsOneWidget);
    expect(find.text('Eigene Events (1)'), findsOneWidget);

    await tester.tap(find.text('Eigene Events (1)'));
    await tester.pumpAndSettle();

    final tile = tester.widget<EventListTile>(find.byType(EventListTile));
    expect(tile.onEdit, isNull);
    expect(tile.onDelete, isNull);
    expect(tile.onTap, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

class RemoteEventSourceStub extends RemoteEventSource {
  RemoteEventSourceStub() : super(baseUrl: Uri.parse('http://localhost'));
}

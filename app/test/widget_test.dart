import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/admin/presentation/admin_screen.dart';
import 'package:dpsg_news_app/features/profile/presentation/profile_screen.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/features/settings/data/settings_repository.dart' as settings_repo;
import 'package:dpsg_news_app/features/settings/presentation/settings_screen.dart';

class FakeRemoteEventSource extends RemoteEventSource {
  FakeRemoteEventSource() : super(baseUrl: Uri.parse('http://localhost'));

  @override
  Future<List<Map<String, dynamic>>> fetchEvents({String? token}) async {
    return [
      {
        'title': 'Test Event',
        'location': 'Testort',
        'dv': 'Köln',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchDvTree() async {
    return {
      'lastTreeChange': '2026-01-01T00:00:00.000Z',
      'dvs': [
        {
          'name': 'Hamburg',
          'url': 'https://example.com/hamburg',
          'groups': ['Rover', 'Leitung'],
        },
      ],
    };
  }
}

class FakeAdminRemoteEventSource extends FakeRemoteEventSource {
  @override
  Future<List<Map<String, dynamic>>> fetchAdminUsers({required String token}) async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, dynamic>> createAdminUser({
    required String token,
    required String username,
    bool isAdmin = false,
  }) async {
    return {
      'author': {'username': username},
      'oneTimePassword': 'temp-12345',
    };
  }
}

class FakeSettingsRepository extends settings_repo.SettingsRepository {
  FakeSettingsRepository() : super(HiveService.getSettingsBox());

  String? _token;
  int? _authorId;
  String? _username;
  bool _isAdmin = false;
  bool _requiresPasswordChange = false;

  @override
  String? getAuthorAuthToken() => _token;

  @override
  int? getAuthorId() => _authorId;

  @override
  String? getAuthorUsername() => _username;

  @override
  bool getAuthorIsAdmin() => _isAdmin;

  @override
  bool getAuthorRequiresPasswordChange() => _requiresPasswordChange;

  @override
  Future<void> saveAuthorSession({
    required String token,
    required int authorId,
    required String username,
    required bool isAdmin,
    required bool requiresPasswordChange,
  }) async {
    _token = token;
    _authorId = authorId;
    _username = username;
    _isAdmin = isAdmin;
    _requiresPasswordChange = requiresPasswordChange;
  }

  @override
  Future<void> clearAuthorSession() async {
    _token = null;
    _authorId = null;
    _username = null;
    _isAdmin = false;
    _requiresPasswordChange = false;
  }

  @override
  Future<void> setAuthorRequiresPasswordChange(bool value) async {
    _requiresPasswordChange = value;
  }

  @override
  Future<void> setAuthorIsAdmin(bool value) async {
    _isAdmin = value;
  }
}

void main() {
  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 20,
    Duration step = const Duration(milliseconds: 100),
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      await tester.pump(step);
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  Future<void> expectEventuallyFound(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 20,
    Duration step = const Duration(milliseconds: 100),
  }) async {
    await pumpUntilFound(tester, finder, maxPumps: maxPumps, step: step);
    expect(finder, findsOneWidget);
  }

  Future<void> openSettingsOverview(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sync_service.remoteEventSourceProvider.overrideWithValue(FakeRemoteEventSource()),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await expectEventuallyFound(tester, find.text('Profil'));
  }

  Future<void> openProfileScreen(
    WidgetTester tester, {
    required AuthorAuthState state,
  }) async {
    final repository = FakeSettingsRepository();
    if (state.isLoggedIn) {
      await repository.saveAuthorSession(
        token: 'test-token',
        authorId: 1,
        username: state.username ?? 'author',
        isAdmin: state.isAdmin,
        requiresPasswordChange: state.requiresPasswordChange,
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sync_service.remoteEventSourceProvider.overrideWithValue(FakeRemoteEventSource()),
          settings_repo.settingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    await HiveService.initialize(path: tempDir.path);
  });

  tearDown(() async {
    await HiveService.getSettingsBox().clear();
    await HiveService.getEventsBox().clear();
  });

  testWidgets('Settings overview shows the new sections', (WidgetTester tester) async {
    await openSettingsOverview(tester);

    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('App-Einstellungen'), findsOneWidget);
    expect(find.text('Benachrichtigungen'), findsOneWidget);
    expect(find.text('DV-Auswahl'), findsOneWidget);
  });

  testWidgets('Profile card opens the profile screen', (WidgetTester tester) async {
    await openSettingsOverview(tester);

    await tester.ensureVisible(find.text('Profil'));
    await tester.tap(find.text('Profil'));
    await tester.pump();
    await expectEventuallyFound(tester, find.text('Passwort ändern'));

    expect(find.text('Admin-Bereich'), findsNothing);
    expect(find.text('Passwort ändern'), findsOneWidget);
    expect(find.text('Autoren-Login'), findsOneWidget);
  });

  testWidgets('Profile screen shows admin entry for admins only', (WidgetTester tester) async {
    await openProfileScreen(
      tester,
      state: const AuthorAuthState(
        isLoggedIn: true,
        isLocked: false,
        username: 'admin',
        isAdmin: true,
      ),
    );

    expect(find.text('Admin-Bereich'), findsOneWidget);
    expect(find.text('DV-Auswahl'), findsNothing);
  });

  testWidgets('Profile screen hides admin entry for regular users', (WidgetTester tester) async {
    await openProfileScreen(
      tester,
      state: const AuthorAuthState(
        isLoggedIn: true,
        isLocked: false,
        username: 'author',
        isAdmin: false,
      ),
    );

    expect(find.text('Admin-Bereich'), findsNothing);
  });

  testWidgets('Admin screen shows the user management action', (WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    final repository = FakeSettingsRepository();
    await repository.saveAuthorSession(
      token: 'test-token',
      authorId: 1,
      username: 'admin',
      isAdmin: true,
      requiresPasswordChange: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sync_service.remoteEventSourceProvider.overrideWithValue(FakeAdminRemoteEventSource()),
          settings_repo.settingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: AdminScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Admin-Bereich'), findsOneWidget);
    expect(find.text('Nutzer anlegen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('App settings entry opens app settings screen', (WidgetTester tester) async {
    await openSettingsOverview(tester);

    await tester.ensureVisible(find.text('App-Einstellungen'));
    await tester.tap(find.text('App-Einstellungen'));
    await tester.pump();
    await expectEventuallyFound(tester, find.text('Nutzungs-/Analyse-Tracking'));

    expect(find.text('Nutzungs-/Analyse-Tracking'), findsOneWidget);
    expect(find.text('Darstellung'), findsOneWidget);
  });

  testWidgets('Notification settings show toggles and DV selector action', (WidgetTester tester) async {
    await openSettingsOverview(tester);

    await tester.ensureVisible(find.text('Benachrichtigungen'));
    await tester.tap(find.text('Benachrichtigungen'));
    await tester.pump();
    await expectEventuallyFound(tester, find.text('Benachrichtigungen aktiv'));

    expect(find.text('Benachrichtigungen aktiv'), findsOneWidget);
    expect(find.text('Neue Veranstaltungen'), findsOneWidget);
    expect(find.text('Erinnerung für zugesagte Veranstaltungen'), findsOneWidget);
    expect(find.text('Erinnerung vor Anmeldeschluss'), findsOneWidget);
    expect(find.text('Wochenübersicht'), findsOneWidget);
    expect(find.text('Tage vorher'), findsNWidgets(2));
    expect(find.text('Auswählen'), findsOneWidget);
  });

  testWidgets('Debug & Tools page opens and App Logs card shows direct controls', (WidgetTester tester) async {
    await openSettingsOverview(tester);

    final settingsScrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 8 && find.text('Debug & Tools').evaluate().isEmpty; i++) {
      await tester.drag(settingsScrollable, const Offset(0, -300), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
    }

    final debugTileSubtitle = find.text('Logs, Diagnose und Referenzen');
    await expectEventuallyFound(tester, debugTileSubtitle);
    await tester.ensureVisible(debugTileSubtitle);
    await tester.tap(debugTileSubtitle);
    await tester.pump();
    await expectEventuallyFound(tester, find.text('System'));

    final debugScrollable = find.byType(Scrollable).first;

    for (var i = 0; i < 8 && find.text('App Logs').evaluate().isEmpty; i++) {
      await tester.drag(debugScrollable, const Offset(0, -250), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectEventuallyFound(tester, find.text('App Logs'));
    expect(find.text('App Logs'), findsOneWidget);
    expect(find.text('Quelle'), findsOneWidget);
    expect(find.text('Datei'), findsOneWidget);
    expect(find.text('Logs anzeigen'), findsOneWidget);

    for (var i = 0; i < 8 && find.text('Feedback und Bewertung').evaluate().isEmpty; i++) {
      await tester.drag(debugScrollable, const Offset(0, -300), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (var i = 0; i < 8 && find.text('Changelog').evaluate().isEmpty; i++) {
      await tester.drag(debugScrollable, const Offset(0, -300), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Feedback und Bewertung'), findsOneWidget);
    expect(find.text('Changelog'), findsOneWidget);
    expect(find.text('Externe Benachrichtigungen'), findsOneWidget);
  });
}

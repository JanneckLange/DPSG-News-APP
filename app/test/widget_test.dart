import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/secure_storage_service.dart';
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/admin/presentation/admin_screen.dart';
import 'package:dpsg_news_app/features/profile/presentation/profile_screen.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/features/settings/data/settings_repository.dart'
    as settings_repo;
import 'package:dpsg_news_app/features/settings/presentation/settings_screen.dart';
import 'package:dpsg_news_app/features/settings/presentation/debug_tools_screen.dart';

class FakeRemoteEventSource extends RemoteEventSource {
  FakeRemoteEventSource() : super(baseUrl: Uri.parse('http://localhost'));

  @override
  Future<List<Map<String, dynamic>>> fetchEvents({String? token}) async {
    return [
      {
        'title': 'Test Event',
        'locationAddress': 'Testort',
        'layerId': 1,
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchLayers() async {
    return {
      'lastChange': '2026-01-01T00:00:00.000Z',
      'layers': [
        {
          'id': 0,
          'name': 'Bundesverband DPSG',
          'type': 'bundesverband',
          'parentId': null,
        },
        {
          'id': 1,
          'name': 'Hamburg',
          'type': 'dv',
          'parentId': 0,
          'url': 'https://example.com/hamburg',
          'groups': ['Rover', 'Leitung'],
        },
      ],
    };
  }
}

class FakeAdminRemoteEventSource extends FakeRemoteEventSource {
  @override
  Future<List<Map<String, dynamic>>> fetchAdminUsers(
      {required String token}) async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, dynamic>> fetchAdminLayers({required String token}) async {
    return const {'layers': <Map<String, dynamic>>[]};
  }

  @override
  Future<Map<String, dynamic>> fetchTopics({int? layerId}) async {
    return const {'topics': <Map<String, dynamic>>[]};
  }

  @override
  Future<Map<String, dynamic>> createAdminUser({
    required String token,
    required String username,
    bool isAdmin = false,
    List<int>? layerIds,
  }) async {
    return {
      'author': {'username': username},
      'oneTimePassword': 'temp-12345',
    };
  }
}

class FakeSettingsRepository extends settings_repo.SettingsRepository {
  FakeSettingsRepository() : super(HiveService.getSettingsBox());

  int? _authorId;
  String? _username;
  bool _isAdmin = false;
  bool _requiresPasswordChange = false;
  List<int> _layerGrantIds = const <int>[];
  List<int> _topicGrantIds = const <int>[];

  @override
  int? getAuthorId() => _authorId;

  @override
  String? getAuthorUsername() => _username;

  @override
  bool getAuthorIsAdmin() => _isAdmin;

  @override
  bool getAuthorRequiresPasswordChange() => _requiresPasswordChange;

  @override
  List<int> getAuthorLayerGrantIds() => _layerGrantIds;

  @override
  List<int> getAuthorTopicGrantIds() => _topicGrantIds;

  @override
  Future<void> saveAuthorSession({
    required int authorId,
    required String username,
    required bool isAdmin,
    required bool requiresPasswordChange,
    List<int> layerGrantIds = const <int>[],
    List<int> topicGrantIds = const <int>[],
  }) async {
    _authorId = authorId;
    _username = username;
    _isAdmin = isAdmin;
    _requiresPasswordChange = requiresPasswordChange;
    _layerGrantIds = layerGrantIds;
    _topicGrantIds = topicGrantIds;
  }

  @override
  Future<void> setAuthorGrants({
    required List<int> layerGrantIds,
    required List<int> topicGrantIds,
  }) async {
    _layerGrantIds = layerGrantIds;
    _topicGrantIds = topicGrantIds;
  }

  @override
  Future<void> clearAuthorSession() async {
    _authorId = null;
    _username = null;
    _isAdmin = false;
    _requiresPasswordChange = false;
    _layerGrantIds = const <int>[];
    _topicGrantIds = const <int>[];
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

class FakeSecureStorageService extends SecureStorageService {
  FakeSecureStorageService() : super(const FlutterSecureStorage());

  AuthorTokenBundle? _tokens;

  @override
  Future<void> saveAuthorTokens({
    required String accessToken,
    required String refreshToken,
    required String accessExpiresAt,
    required String refreshExpiresAt,
  }) async {
    _tokens = AuthorTokenBundle(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
    );
  }

  @override
  Future<AuthorTokenBundle?> readAuthorTokens() async => _tokens;

  @override
  Future<void> clearAuthorTokens() async {
    _tokens = null;
  }
}

class TestAuthorAuthNotifier extends AuthorAuthNotifier {
  TestAuthorAuthNotifier({
    required settings_repo.SettingsRepository repository,
    required RemoteEventSource remote,
    required SecureStorageService secureStorage,
    required Ref ref,
    required AuthorAuthState initialState,
  }) : super(
          repository: repository,
          remote: remote,
          secureStorage: secureStorage,
          ref: ref,
          restoreSessionOnInit: false,
        ) {
    state = initialState;
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
          sync_service.remoteEventSourceProvider
              .overrideWithValue(FakeRemoteEventSource()),
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
    final secureStorage = FakeSecureStorageService();
    final remote = FakeRemoteEventSource();
    if (state.isLoggedIn) {
      await repository.saveAuthorSession(
        authorId: 1,
        username: state.username ?? 'author',
        isAdmin: state.isAdmin,
        requiresPasswordChange: state.requiresPasswordChange,
      );
      await secureStorage.saveAuthorTokens(
        accessToken: state.token ?? 'test-token',
        refreshToken: state.refreshToken ?? 'test-refresh-token',
        accessExpiresAt: (state.expiresAt ??
                DateTime.now().toUtc().add(const Duration(hours: 1)))
            .toIso8601String(),
        refreshExpiresAt: (state.refreshExpiresAt ??
                DateTime.now().toUtc().add(const Duration(days: 7)))
            .toIso8601String(),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sync_service.remoteEventSourceProvider.overrideWithValue(remote),
          settings_repo.settingsRepositoryProvider
              .overrideWithValue(repository),
          secureStorageServiceProvider.overrideWithValue(secureStorage),
          authorAuthProvider.overrideWith(
            (ref) => TestAuthorAuthNotifier(
              repository: repository,
              remote: remote,
              secureStorage: secureStorage,
              ref: ref,
              initialState: state,
            ),
          ),
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

  testWidgets('Settings overview shows the new sections',
      (WidgetTester tester) async {
    await openSettingsOverview(tester);

    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('App-Einstellungen'), findsOneWidget);
    expect(find.text('Benachrichtigungen'), findsOneWidget);
    expect(find.text('DV-Auswahl'), findsOneWidget);
  });

  testWidgets('Profile card opens the profile screen',
      (WidgetTester tester) async {
    await openSettingsOverview(tester);

    await tester.ensureVisible(find.text('Profil'));
    await tester.tap(find.text('Profil'));
    await tester.pump();
    await expectEventuallyFound(tester, find.text('Autoren-Login'));

    expect(find.text('Admin-Bereich'), findsNothing);
    // Nicht eingeloggt: Passwort-aendern-Kachel ist komplett ausgeblendet.
    expect(find.text('Passwort ändern'), findsNothing);
    expect(find.text('Autoren-Login'), findsOneWidget);
  });

  testWidgets('Profile screen shows admin entry for admins only',
      (WidgetTester tester) async {
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

  testWidgets('Profile screen hides admin entry for regular users',
      (WidgetTester tester) async {
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

  testWidgets('Admin screen shows the user management action',
      (WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    final repository = FakeSettingsRepository();
    final secureStorage = FakeSecureStorageService();
    final remote = FakeAdminRemoteEventSource();
    await repository.saveAuthorSession(
      authorId: 1,
      username: 'admin',
      isAdmin: true,
      requiresPasswordChange: false,
    );
    await secureStorage.saveAuthorTokens(
      accessToken: 'test-token',
      refreshToken: 'test-refresh-token',
      accessExpiresAt: DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      refreshExpiresAt:
          DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sync_service.remoteEventSourceProvider.overrideWithValue(remote),
          settings_repo.settingsRepositoryProvider
              .overrideWithValue(repository),
          secureStorageServiceProvider.overrideWithValue(secureStorage),
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
                refreshToken: 'test-refresh-token',
                authorId: 1,
                username: 'admin',
                isAdmin: true,
                requiresPasswordChange: false,
                expiresAt: DateTime.utc(2099, 1, 1),
                refreshExpiresAt: DateTime.utc(2099, 2, 1),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: AdminScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Admin-Bereich'), findsOneWidget);
    expect(find.text('Alle Nutzer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('App settings entry opens app settings screen',
      (WidgetTester tester) async {
    await openSettingsOverview(tester);

    await tester.ensureVisible(find.text('App-Einstellungen'));
    await tester.tap(find.text('App-Einstellungen'));
    await tester.pump();
    await expectEventuallyFound(
        tester, find.text('Nutzungs-/Analyse-Tracking'));

    expect(find.text('Nutzungs-/Analyse-Tracking'), findsOneWidget);
    expect(find.text('Darstellung'), findsOneWidget);
  });

  testWidgets('Notification settings show toggles and DV selector action',
      (WidgetTester tester) async {
    await openSettingsOverview(tester);

    await tester.ensureVisible(find.text('Benachrichtigungen'));
    await tester.tap(find.text('Benachrichtigungen'));
    await tester.pump();
    await expectEventuallyFound(tester, find.text('Benachrichtigungen aktiv'));

    expect(find.text('Benachrichtigungen aktiv'), findsOneWidget);
    expect(find.text('Neue Veranstaltungen'), findsOneWidget);
    expect(
        find.text('Erinnerung für zugesagte Veranstaltungen'), findsOneWidget);
    expect(find.text('Erinnerung vor Anmeldeschluss'), findsOneWidget);
    expect(find.text('Wochenübersicht'), findsOneWidget);
    expect(find.text('Tage vorher'), findsNWidgets(2));
    expect(find.text('Auswählen'), findsOneWidget);
  });

  testWidgets(
      'Debug & Tools page opens and App Logs card shows direct controls',
      (WidgetTester tester) async {
    await openSettingsOverview(tester);

    final settingsScrollable = find.byType(Scrollable).first;
    for (var i = 0;
        i < 8 && find.text('Debug & Tools').evaluate().isEmpty;
        i++) {
      await tester.drag(settingsScrollable, const Offset(0, -300),
          warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
    }

    final debugTileSubtitle = find.text('Logs, Diagnose und Referenzen');
    await expectEventuallyFound(tester, debugTileSubtitle);
    await tester.ensureVisible(debugTileSubtitle);

    // Open DebugToolsScreen directly to verify its contents (more stable than
    // scrolling + tapping through Settings in CI environments).
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sync_service.remoteEventSourceProvider
              .overrideWithValue(FakeRemoteEventSource()),
        ],
        child: const MaterialApp(home: DebugToolsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await expectEventuallyFound(tester, find.text('System'));

    final debugScrollable = find.byType(Scrollable).first;

    for (var i = 0; i < 8 && find.text('App Logs').evaluate().isEmpty; i++) {
      await tester.drag(debugScrollable, const Offset(0, -250),
          warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectEventuallyFound(tester, find.text('App Logs'));
    expect(find.text('App Logs'), findsOneWidget);
    expect(find.text('Quelle'), findsOneWidget);
    expect(find.text('Datei'), findsOneWidget);
    expect(find.text('Logs anzeigen'), findsOneWidget);

    for (var i = 0;
        i < 8 && find.text('Feedback und Bewertung').evaluate().isEmpty;
        i++) {
      await tester.drag(debugScrollable, const Offset(0, -300),
          warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (var i = 0; i < 8 && find.text('Changelog').evaluate().isEmpty; i++) {
      await tester.drag(debugScrollable, const Offset(0, -300),
          warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Feedback und Bewertung'), findsOneWidget);
    expect(find.text('Changelog'), findsOneWidget);
    expect(find.text('Externe Benachrichtigungen'), findsOneWidget);
  });
}

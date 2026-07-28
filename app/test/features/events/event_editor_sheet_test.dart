import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/features/events/presentation/event_editor_sheet.dart';
import 'package:dpsg_news_app/features/settings/data/settings_repository.dart'
    as settings_repo;

import '../../widget_test.dart'
    show FakeSecureStorageService, TestAuthorAuthNotifier;

const _hamburgLayerId = 1;
const _koelnLayerId = 2;
const _berlinLayerId = 3;
const _woelflingeTopicId = 10;
const _jungpfadfinderTopicId = 11;

// Rechtematrix aus #1/#19: Ein Autor sieht beim Erstellen nur Layer/Topics,
// fuer die er einen expliziten Grant hat - der Fake liefert bewusst mehr
// Layer/Topics zurueck, als jeweils granted werden, um die Filterung im
// Editor zu pruefen (nicht nur den Happy-Path mit ohnehin passenden Daten).
class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource({
    required this.grantedLayerIds,
    required this.grantedTopicIds,
  }) : super(baseUrl: Uri.parse('http://localhost'));

  final List<int> grantedLayerIds;
  final List<int> grantedTopicIds;

  @override
  Future<Map<String, dynamic>> fetchLayers() async => {
        'lastChange': '2026-01-01T00:00:00.000Z',
        'layers': [
          {'id': 0, 'name': 'Bundesverband DPSG', 'parentId': null},
          {'id': _hamburgLayerId, 'name': 'Hamburg', 'parentId': 0},
          {'id': _koelnLayerId, 'name': 'Köln', 'parentId': 0},
          {'id': _berlinLayerId, 'name': 'Berlin', 'parentId': 0},
        ],
      };

  @override
  Future<Map<String, dynamic>> fetchTopics({int? layerId}) async => {
        'topics': [
          {
            'id': _woelflingeTopicId,
            'name': 'Wölflinge',
            'layerId': _hamburgLayerId,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
          {
            'id': _jungpfadfinderTopicId,
            'name': 'Jungpfadfinder',
            'layerId': _hamburgLayerId,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ]
            .where((topic) => layerId == null || topic['layerId'] == layerId)
            .toList(),
      };

  // refreshSession() (Editor-initState) haengt aus Sicht des Widgets nur von
  // den in AuthorAuthState gesetzten Grants ab - hier auf dieselben Werte
  // gespiegelt, damit der fire-and-forget-Refresh die Test-Fixture nicht
  // stillschweigend mit leeren Grants ueberschreibt.
  @override
  Future<AuthorSessionState> fetchAuthorSession({required String token}) async =>
      AuthorSessionState(
        requiresPasswordChange: false,
        isAdmin: false,
        layerGrantIds: grantedLayerIds,
        topicGrantIds: grantedTopicIds,
      );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder,
    {int maxAttempts = 20, Duration step = const Duration(milliseconds: 100)}) async {
  for (var i = 0; i < maxAttempts; i++) {
    if (tester.any(finder)) return;
    await Future<void>.delayed(step);
    await tester.pump();
  }
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required List<int> grantedLayerIds,
  required List<int> grantedTopicIds,
}) async {
  final repository =
      settings_repo.SettingsRepository(HiveService.getSettingsBox());
  final secureStorage = FakeSecureStorageService();
  final remote = _FakeRemoteEventSource(
    grantedLayerIds: grantedLayerIds,
    grantedTopicIds: grantedTopicIds,
  );

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
              authorId: 1,
              username: 'author',
              layerGrantIds: grantedLayerIds,
              topicGrantIds: grantedTopicIds,
              expiresAt: DateTime.utc(2099, 1, 1),
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: EventEditorPage()),
    ),
  );
  await tester.pump();
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
      'auto-selects and locks the single authorized layer/topic, hides unauthorized ones',
      (tester) async {
    await tester.runAsync(() async {
      await _pumpEditor(
        tester,
        grantedLayerIds: const [_hamburgLayerId],
        grantedTopicIds: const [_woelflingeTopicId],
      );
      await _pumpUntilFound(tester, find.text('Hamburg'));
      await _pumpUntilFound(tester, find.text('Wölflinge'));
    });

    expect(find.text('Hamburg'), findsOneWidget);
    expect(find.text('Köln'), findsNothing);
    expect(find.text('Berlin'), findsNothing);
    final layerDropdown = tester.widget<DropdownButtonFormField<int>>(
      find.byType(DropdownButtonFormField<int>),
    );
    expect(layerDropdown.onChanged, isNull);

    expect(find.text('Wölflinge'), findsOneWidget);
    expect(find.text('Jungpfadfinder'), findsNothing);
    final topicDropdown = tester.widget<DropdownButtonFormField<int?>>(
      find.byType(DropdownButtonFormField<int?>),
    );
    expect(topicDropdown.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'offers only the granted layers for selection when authorized for several',
      (tester) async {
    await tester.runAsync(() async {
      await _pumpEditor(
        tester,
        grantedLayerIds: const [_hamburgLayerId, _koelnLayerId],
        grantedTopicIds: const [],
      );
      await _pumpUntilFound(
        tester,
        find.byType(DropdownButtonFormField<int>),
      );
    });

    final layerDropdown = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    );
    expect(layerDropdown.onChanged, isNotNull);
    final optionValues = layerDropdown.items!.map((item) => item.value).toSet();
    expect(optionValues, {_hamburgLayerId, _koelnLayerId});
    expect(optionValues.contains(_berlinLayerId), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a hint instead of a dropdown when no layer is authorized',
      (tester) async {
    await tester.runAsync(() async {
      await _pumpEditor(tester, grantedLayerIds: const [], grantedTopicIds: const []);
      await _pumpUntilFound(
        tester,
        find.text('Keine berechtigten Layer vorhanden. Bitte an einen Admin wenden.'),
      );
    });

    expect(
      find.text('Keine berechtigten Layer vorhanden. Bitte an einen Admin wenden.'),
      findsOneWidget,
    );
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

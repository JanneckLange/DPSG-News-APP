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
  Future<AuthorSessionState> fetchAuthorSession(
          {required String token}) async =>
      AuthorSessionState(
        requiresPasswordChange: false,
        isAdmin: false,
        layerGrantIds: grantedLayerIds,
        topicGrantIds: grantedTopicIds,
      );
}

// Zeichnet Aufrufe an createDraft/createOwnEvent auf, statt echte HTTP-
// Requests auszuloesen (die im Widget-Test ohnehin mit Status 400
// fehlschlagen wuerden) - so laesst sich das gesendete Payload pruefen.
class _CapturingFakeRemoteEventSource extends _FakeRemoteEventSource {
  _CapturingFakeRemoteEventSource({
    required super.grantedLayerIds,
    required super.grantedTopicIds,
  });

  Map<String, dynamic>? capturedDraft;
  Map<String, dynamic>? capturedEvent;

  @override
  Future<Map<String, dynamic>> createDraft({
    required String token,
    required Map<String, dynamic> draft,
  }) async {
    capturedDraft = draft;
    return <String, dynamic>{'id': 1};
  }

  @override
  Future<Map<String, dynamic>> createOwnEvent({
    required String token,
    required Map<String, dynamic> event,
  }) async {
    capturedEvent = event;
    return <String, dynamic>{'id': 1};
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder,
    {int maxAttempts = 20,
    Duration step = const Duration(milliseconds: 100)}) async {
  for (var i = 0; i < maxAttempts; i++) {
    if (tester.any(finder)) return;
    await Future<void>.delayed(step);
    await tester.pump();
  }
}

// Die Fire-and-forget-Refreshes aus EventEditorPage.initState() (Layer-Baum,
// Autoren-Session) laufen unabhaengig vom Widget-Rebuild weiter. Die
// bestehenden Tests lassen ihnen ueber _pumpUntilFound's Wartezyklen genug
// Realzeit zum Abschliessen; neue, kuerzere Interaktionsketten brauchen
// diesen expliziten Puffer, damit sie nicht erst nach Testende (und damit
// nach dispose()) fertig werden ("used after dispose").
Future<void> _settleBackgroundRefreshes(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

// Der Stepper rendert seine Schritte in einer shrinkWrap-ListView ohne
// eigenes Scroll-Viewport - bei den neuen, inhaltlich groesseren Schritten
// (v. a. "Einstellungen") ragt das ueber die winzige Standard-Testfenster-
// groesse (800x600) hinaus, sodass spaetere Schritte/Buttons sonst nicht
// antippbar waeren. Das Testfenster wird daher fuer diese Faelle vergroessert.
void _useTallTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required List<int> grantedLayerIds,
  required List<int> grantedTopicIds,
  _FakeRemoteEventSource? remote,
  Map<String, dynamic>? existingDraft,
  Map<String, dynamic>? existingEvent,
}) async {
  final repository =
      settings_repo.SettingsRepository(HiveService.getSettingsBox());
  final secureStorage = FakeSecureStorageService();
  final effectiveRemote = remote ??
      _FakeRemoteEventSource(
        grantedLayerIds: grantedLayerIds,
        grantedTopicIds: grantedTopicIds,
      );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sync_service.remoteEventSourceProvider
            .overrideWithValue(effectiveRemote),
        settings_repo.settingsRepositoryProvider.overrideWithValue(repository),
        authorAuthProvider.overrideWith(
          (ref) => TestAuthorAuthNotifier(
            repository: repository,
            remote: effectiveRemote,
            secureStorage: secureStorage,
            ref: ref,
            initialState: AuthorAuthState(
              isLoggedIn: true,
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
      child: MaterialApp(
        home: EventEditorPage(
          existingDraft: existingDraft,
          existingEvent: existingEvent,
        ),
      ),
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

    // Hamburg erscheint sowohl im gesperrten Layer-Dropdown ("Einstellungen")
    // als auch als Chip in der Vorschau (Schritt 4) - beide Stellen sind im
    // vertikalen Stepper gleichzeitig im Widget-Baum vorhanden. Der Check
    // wird daher gezielt auf das Dropdown eingeschraenkt.
    expect(
      find.descendant(
        of: find.byType(DropdownButtonFormField<int>),
        matching: find.text('Hamburg'),
      ),
      findsOneWidget,
    );
    expect(find.text('Köln'), findsNothing);
    expect(find.text('Berlin'), findsNothing);
    final layerDropdown = tester.widget<DropdownButtonFormField<int>>(
      find.byType(DropdownButtonFormField<int>),
    );
    expect(layerDropdown.onChanged, isNull);

    expect(
      find.descendant(
        of: find.byType(DropdownButtonFormField<int?>),
        matching: find.text('Wölflinge'),
      ),
      findsOneWidget,
    );
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
      await _pumpEditor(tester,
          grantedLayerIds: const [], grantedTopicIds: const []);
      await _pumpUntilFound(
        tester,
        find.text(
            'Keine berechtigten Layer vorhanden. Bitte an einen Admin wenden.'),
      );
    });

    expect(
      find.text(
          'Keine berechtigten Layer vorhanden. Bitte an einen Admin wenden.'),
      findsOneWidget,
    );
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('speichert einen Entwurf mit nur ausgefuelltem Titel',
      (tester) async {
    _useTallTestViewport(tester);
    final remote = _CapturingFakeRemoteEventSource(
      grantedLayerIds: const [_hamburgLayerId],
      grantedTopicIds: const [_woelflingeTopicId],
    );

    await tester.runAsync(() async {
      await _pumpEditor(
        tester,
        grantedLayerIds: const [_hamburgLayerId],
        grantedTopicIds: const [_woelflingeTopicId],
        remote: remote,
      );
      await _pumpUntilFound(tester, find.text('Titel'));
      await _settleBackgroundRefreshes(tester);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Titel'), 'Sommerlager 2026');
      await tester.pump();

      // Direkt zur Vorschau springen, ohne die Zwischenschritte
      // durchzunavigieren - der Stepper erlaubt freies Springen per Tap.
      // Die Stepper-Liste ist laenger als das Test-Viewport, daher muss der
      // jeweilige Schritt/Button erst in den sichtbaren Bereich gescrollt
      // werden (ensureVisible), bevor er antippbar ist.
      await tester.ensureVisible(find.text('Vorschau'));
      await tester.tap(find.text('Vorschau'));
      await tester.pumpAndSettle();
      final draftButton =
          find.widgetWithText(FilledButton, 'Entwurf speichern');
      await tester.ensureVisible(draftButton);
      await tester.tap(draftButton);
      await tester.pump();
    });

    expect(
      find.text('Bitte Fehler in den markierten Schritten beheben.'),
      findsNothing,
    );
    expect(remote.capturedDraft, isNotNull);
    expect(remote.capturedDraft!['title'], 'Sommerlager 2026');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'blockiert Veroeffentlichen bei fehlendem Startdatum unabhaengig vom neuen Schrittzuschnitt',
      (tester) async {
    _useTallTestViewport(tester);
    final remote = _CapturingFakeRemoteEventSource(
      grantedLayerIds: const [_hamburgLayerId, _koelnLayerId],
      grantedTopicIds: const [],
    );

    await tester.runAsync(() async {
      await _pumpEditor(
        tester,
        grantedLayerIds: const [_hamburgLayerId, _koelnLayerId],
        grantedTopicIds: const [],
        remote: remote,
      );
      await _pumpUntilFound(tester, find.text('Titel'));
      await _settleBackgroundRefreshes(tester);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Titel'), 'Sommerlager 2026');
      await tester.enterText(find.widgetWithText(TextFormField, 'Beschreibung'),
          'Eine Woche im Zeltlager.');
      await tester.pump();

      // Layer bewusst nicht ausgewaehlt (mehrere Grants -> keine
      // Autoselektion) und Startdatum bewusst nicht gesetzt.
      await tester.ensureVisible(find.text('Vorschau'));
      await tester.tap(find.text('Vorschau'));
      await tester.pumpAndSettle();
      final publishButton =
          find.widgetWithText(FilledButton, 'Jetzt veröffentlichen');
      await tester.ensureVisible(publishButton);
      await tester.tap(publishButton);
      await tester.pump();
    });

    expect(
      find.text('Bitte Fehler in den markierten Schritten beheben.'),
      findsOneWidget,
    );
    expect(remote.capturedEvent, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'zeigt Veroeffentlichungsdatum und Anmeldeschluss aus einem bestehenden Entwurf an',
      (tester) async {
    _useTallTestViewport(tester);
    await tester.runAsync(() async {
      await _pumpEditor(
        tester,
        grantedLayerIds: const [_hamburgLayerId],
        grantedTopicIds: const [_woelflingeTopicId],
        existingDraft: const {
          'id': 42,
          'title': 'Sommerlager 2026',
          'description': 'Eine Woche im Zeltlager.',
          'layerId': _hamburgLayerId,
          'startDate': '2026-08-01T10:00:00.000Z',
          'publishAt': '2026-07-01T08:00:00.000Z',
          'registrationDeadline': '2026-07-20T23:59:00.000Z',
        },
      );
      await _pumpUntilFound(tester, find.text('Einstellungen'));
      await _settleBackgroundRefreshes(tester);
      await tester.ensureVisible(find.text('Einstellungen'));
      await tester.tap(find.text('Einstellungen'));
      await tester.pumpAndSettle();
    });

    expect(find.text('Veröffentlichung ab'), findsOneWidget);
    expect(find.text('Anmeldeschluss'), findsOneWidget);
    // Beide Felder sind gesetzt -> Clear-Button muss angeboten werden.
    expect(find.byIcon(Icons.clear), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'blockiert Veroeffentlichen bei ungueltigem CTA1-Format, Entwurf mit demselben Wert bleibt moeglich',
      (tester) async {
    _useTallTestViewport(tester);
    final remote = _CapturingFakeRemoteEventSource(
      grantedLayerIds: const [_hamburgLayerId],
      grantedTopicIds: const [_woelflingeTopicId],
    );

    await tester.runAsync(() async {
      await _pumpEditor(
        tester,
        grantedLayerIds: const [_hamburgLayerId],
        grantedTopicIds: const [_woelflingeTopicId],
        remote: remote,
        existingDraft: const {
          'id': 42,
          'title': 'Sommerlager 2026',
          'description': 'Eine Woche im Zeltlager.',
          'layerId': _hamburgLayerId,
          'startDate': '2026-08-01T10:00:00.000Z',
        },
      );
      await _pumpUntilFound(tester, find.text('Einstellungen'));
      await _settleBackgroundRefreshes(tester);
      await tester.ensureVisible(find.text('Einstellungen'));
      await tester.tap(find.text('Einstellungen'));
      await tester.pumpAndSettle();
      final cta1Field =
          find.widgetWithText(TextFormField, 'Link oder E-Mail-Adresse').first;
      await tester.ensureVisible(cta1Field);
      await tester.enterText(cta1Field, 'nicht-gueltig');
      await tester.pump();

      await tester.ensureVisible(find.text('Vorschau'));
      await tester.tap(find.text('Vorschau'));
      await tester.pumpAndSettle();
      final publishButton =
          find.widgetWithText(FilledButton, 'Jetzt veröffentlichen');
      await tester.ensureVisible(publishButton);
      await tester.tap(publishButton);
      await tester.pump();
    });

    expect(
      find.text('Bitte Fehler in den markierten Schritten beheben.'),
      findsOneWidget,
    );
    expect(remote.capturedEvent, isNull);
    expect(tester.takeException(), isNull);
  });
}

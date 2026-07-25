import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/features/events/presentation/events_screen.dart';
import 'package:dpsg_news_app/features/settings/data/settings_repository.dart'
    as settings_repo;

import '../../widget_test.dart'
    show FakeSecureStorageService, TestAuthorAuthNotifier;

const koelnLayerId = 1;
const hamburgLayerId = 2;

class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource(this._events)
      : super(baseUrl: Uri.parse('http://localhost'));

  final List<Map<String, dynamic>> _events;

  @override
  Future<List<Map<String, dynamic>>> fetchEvents({String? token}) async =>
      _events;

  @override
  Future<Map<String, dynamic>> fetchLayers() async => {
        'lastChange': '2026-01-01T00:00:00.000Z',
        'layers': [
          {
            'id': 0,
            'name': 'Bundesverband DPSG',
            'type': 'bundesverband',
            'parentId': null,
          },
          {
            'id': koelnLayerId,
            'name': 'Köln',
            'type': 'dv',
            'parentId': 0,
          },
          {
            'id': hamburgLayerId,
            'name': 'Hamburg',
            'type': 'dv',
            'parentId': 0,
          },
        ],
      };
}

// runAsync: EventsScreen.initState synchronisiert Events (echter
// Hive-Schreibzugriff) und die Vorbereitung setzt DV-/Merken-Einstellungen
// ebenfalls per echtem Hive-Schreibzugriff. Beides muss ausserhalb des
// Fake-Async-Zeittakts der testWidgets()-Zone laufen, sonst haengt der Test.
Future<void> _pumpEventsScreen(
  WidgetTester tester, {
  required List<Map<String, dynamic>> events,
  required List<int> selectedLayerIds,
  Set<String> savedEventIds = const {},
}) async {
  final repository =
      settings_repo.SettingsRepository(HiveService.getSettingsBox());
  final secureStorage = FakeSecureStorageService();
  final remote = _FakeRemoteEventSource(events);

  await tester.runAsync(() async {
    await repository.setSelectedLayerIds(selectedLayerIds);
    await repository.setSavedEventIds(savedEventIds.toList());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sync_service.remoteEventSourceProvider.overrideWithValue(remote),
          authorAuthProvider.overrideWith(
            (ref) => TestAuthorAuthNotifier(
              repository: repository,
              remote: remote,
              secureStorage: secureStorage,
              ref: ref,
              initialState:
                  const AuthorAuthState(isLoggedIn: false, isLocked: false),
            ),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.light(),
          home: const EventsScreen(),
        ),
      ),
    );
    await tester.pump();
    // EventsScreen.initState stoesst syncEvents() unthrottled, aber
    // fire-and-forget an. Kurze reale Wartezeit, damit der Hive-
    // Schreibvorgang abschliesst, danach erneut pumpen, damit der
    // eventsProvider-Stream (box.watch()) den Widget-Baum aktualisiert.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  });
}

void main() {
  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    await HiveService.initialize(path: tempDir.path);
    await initializeDateFormatting('de');
  });

  tearDown(() async {
    await HiveService.getSettingsBox().clear();
    await HiveService.getEventsBox().clear();
  });

  testWidgets(
      'shows saved events first, then remaining events grouped by month',
      (tester) async {
    await _pumpEventsScreen(
      tester,
      selectedLayerIds: [koelnLayerId, hamburgLayerId],
      savedEventIds: {'1'},
      events: [
        {
          'id': 1,
          'title': 'Gemerktes Event',
          'location': 'Ort A',
          'layerId': koelnLayerId,
          'startDate': '2026-12-01T10:00:00Z',
        },
        {
          'id': 2,
          'title': 'Event August',
          'location': 'Ort B',
          'layerId': hamburgLayerId,
          'startDate': '2026-08-05T10:00:00Z',
        },
        {
          'id': 3,
          'title': 'Event September',
          'location': 'Ort C',
          'layerId': hamburgLayerId,
          'startDate': '2026-09-10T10:00:00Z',
        },
      ],
    );

    expect(tester.takeException(), isNull);

    final savedY = tester.getTopLeft(find.text('Gemerktes Event')).dy;
    final augustHeaderY = tester.getTopLeft(find.text('August 2026')).dy;
    final augustEventY = tester.getTopLeft(find.text('Event August')).dy;
    final septemberHeaderY = tester.getTopLeft(find.text('September 2026')).dy;
    final septemberEventY = tester.getTopLeft(find.text('Event September')).dy;

    expect(savedY, lessThan(augustHeaderY));
    expect(augustHeaderY, lessThan(augustEventY));
    expect(augustEventY, lessThan(septemberHeaderY));
    expect(septemberHeaderY, lessThan(septemberEventY));
  });

  testWidgets('hides the DV chip when only one DV is subscribed',
      (tester) async {
    await _pumpEventsScreen(
      tester,
      selectedLayerIds: [koelnLayerId],
      events: [
        {
          'id': 1,
          'title': 'Solo-DV-Event',
          'location': 'Ort A',
          'layerId': koelnLayerId,
          'startDate': '2026-08-05T10:00:00Z',
        },
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Köln'), findsNothing);
  });

  testWidgets('shows the DV chip when multiple DVs are subscribed',
      (tester) async {
    await _pumpEventsScreen(
      tester,
      selectedLayerIds: [koelnLayerId, hamburgLayerId],
      events: [
        {
          'id': 1,
          'title': 'Multi-DV-Event',
          'location': 'Ort A',
          'layerId': koelnLayerId,
          'startDate': '2026-08-05T10:00:00Z',
        },
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Köln'), findsOneWidget);
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/core/services/hive_service.dart';
import 'package:dpsg_news_app/core/services/sync_service.dart' as sync_service;
import 'package:dpsg_news_app/features/admin/domain/topic_model.dart';
import 'package:dpsg_news_app/features/admin/presentation/layer_admin_tree.dart';
import 'package:dpsg_news_app/features/author/data/author_auth_provider.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';
import 'package:dpsg_news_app/features/settings/domain/layer_model.dart';

import '../../widget_test.dart'
    show
        FakeSettingsRepository,
        FakeSecureStorageService,
        TestAuthorAuthNotifier;

class _FakeRemoteEventSource extends RemoteEventSource {
  _FakeRemoteEventSource({
    this.layers = const <LayerModel>[],
    this.topics = const <TopicModel>[],
    this.fetchAdminLayersError,
    this.createLayerError,
    this.updateLayerError,
    this.deleteLayerError,
  }) : super(baseUrl: Uri.parse('http://localhost'));

  final List<LayerModel> layers;
  final List<TopicModel> topics;
  final Object? fetchAdminLayersError;
  final Object? createLayerError;
  final Object? updateLayerError;
  final Object? deleteLayerError;

  int createLayerCallCount = 0;
  int updateLayerCallCount = 0;
  int deleteLayerCallCount = 0;
  String? lastCreatedName;
  int? lastCreatedParentId;
  String? lastUpdatedName;
  int? lastUpdatedLayerId;
  int? lastDeletedLayerId;

  @override
  Future<Map<String, dynamic>> fetchAdminLayers({required String token}) async {
    if (fetchAdminLayersError != null) {
      // ignore: only_throw_errors
      throw fetchAdminLayersError!;
    }
    return {'layers': layers.map((l) => l.toJson()).toList()};
  }

  @override
  Future<Map<String, dynamic>> fetchTopics({int? layerId}) async {
    return {
      'topics': topics
          .map((t) => {
                'id': t.id,
                'name': t.name,
                'layerId': t.layerId,
                'createdAt': t.createdAt,
                'updatedAt': t.updatedAt,
              })
          .toList(),
    };
  }

  @override
  Future<Map<String, dynamic>> createLayer({
    required String token,
    required String name,
    int? parentId,
  }) async {
    createLayerCallCount++;
    lastCreatedName = name;
    lastCreatedParentId = parentId;
    if (createLayerError != null) {
      // ignore: only_throw_errors
      throw createLayerError!;
    }
    return {
      'layer': {'id': 99, 'name': name, 'parentId': parentId}
    };
  }

  @override
  Future<Map<String, dynamic>> updateLayer({
    required String token,
    required int layerId,
    required String name,
  }) async {
    updateLayerCallCount++;
    lastUpdatedLayerId = layerId;
    lastUpdatedName = name;
    if (updateLayerError != null) {
      // ignore: only_throw_errors
      throw updateLayerError!;
    }
    return {
      'layer': {'id': layerId, 'name': name}
    };
  }

  @override
  Future<void> deleteLayer({
    required String token,
    required int layerId,
  }) async {
    deleteLayerCallCount++;
    lastDeletedLayerId = layerId;
    if (deleteLayerError != null) {
      // ignore: only_throw_errors
      throw deleteLayerError!;
    }
  }
}

AuthorAuthState _loggedInState() {
  return AuthorAuthState(
    isLoggedIn: true,
    token: 'valid-token',
    refreshToken: 'refresh-token',
    authorId: 1,
    username: 'author',
    isAdmin: true,
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

  Future<void> pumpScreen(
    WidgetTester tester,
    _FakeRemoteEventSource remote, {
    AuthorAuthState? initialState,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sync_service.remoteEventSourceProvider.overrideWithValue(remote),
          authorAuthProvider.overrideWith(
            (ref) => TestAuthorAuthNotifier(
              repository: FakeSettingsRepository(),
              remote: remote,
              secureStorage: FakeSecureStorageService(),
              ref: ref,
              initialState: initialState ?? _loggedInState(),
            ),
          ),
        ],
        // LayerAdminTree hat (anders als der ehemalige LayerAdminScreen) keinen
        // eigenen Scaffold mehr - der Baum wird direkt im Admin-Bereich
        // eingebettet angezeigt (siehe Umbenennung layer_admin_screen.dart ->
        // layer_admin_tree.dart, "kein eigener Scaffold").
        child: const MaterialApp(home: Scaffold(body: LayerAdminTree())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder popupMenuFor(String layerName) => find.descendant(
        of: find.ancestor(of: find.text(layerName), matching: find.byType(Row)),
        matching: find.byType(PopupMenuButton<String>),
      );

  const bundesverband =
      LayerModel(id: 1, name: 'Bundesverband', parentId: null);
  const koeln = LayerModel(id: 2, name: 'Köln', parentId: 1);
  const stufenaktion = TopicModel(
    id: 5,
    name: 'Stufenaktion',
    layerId: 1,
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  );

  testWidgets(
      'renders the layer tree with author/sub-layer/topic counts after loading (server-scoped data, #18/#112)',
      (tester) async {
    final remote = _FakeRemoteEventSource(
      layers: const [bundesverband, koeln],
      topics: [stufenaktion],
    );
    await pumpScreen(tester, remote);

    expect(find.text('Bundesverband'), findsOneWidget);
    expect(find.text('0 Autoren, 1 Sub-Layer, 1 Topics'), findsOneWidget);
    expect(find.text('Köln'), findsOneWidget);
    expect(find.text('0 Autoren, 0 Sub-Layer, 0 Topics'), findsOneWidget);
  });

  testWidgets('shows the author count returned by the admin layer endpoint',
      (tester) async {
    final remote = _FakeRemoteEventSource(
      layers: const [
        LayerModel(id: 1, name: 'Hamburg', parentId: null, authorCount: 2),
        LayerModel(id: 2, name: 'Köln', parentId: 1, authorCount: 0),
      ],
      topics: [
        const TopicModel(
          id: 10,
          name: 'Wölflinge',
          layerId: 2,
          createdAt: '2026-01-01T00:00:00.000Z',
          updatedAt: '2026-01-01T00:00:00.000Z',
        ),
      ],
    );
    await pumpScreen(tester, remote);

    expect(find.text('2 Autoren, 1 Sub-Layer, 0 Topics'), findsOneWidget);
    expect(find.text('0 Autoren, 0 Sub-Layer, 1 Topics'), findsOneWidget);
  });

  testWidgets('shows an empty-state message when there are no layers',
      (tester) async {
    final remote = _FakeRemoteEventSource();
    await pumpScreen(tester, remote);

    expect(find.text('Keine Layer vorhanden.'), findsOneWidget);
  });

  testWidgets(
      'shows a friendly "Kein Zugriff" message when the author is not logged in',
      (tester) async {
    final remote = _FakeRemoteEventSource(layers: const [bundesverband]);
    await pumpScreen(tester, remote, initialState: AuthorAuthState.signedOut());

    expect(find.text('Layer konnten nicht geladen werden: Kein Zugriff'),
        findsOneWidget);
  });

  testWidgets('shows the raw error message for other load failures',
      (tester) async {
    final remote = _FakeRemoteEventSource(
      fetchAdminLayersError: RemoteEventSourceException('Server down'),
    );
    await pumpScreen(tester, remote);

    expect(
      find.text(
          'Layer konnten nicht geladen werden: RemoteEventSourceException: Server down'),
      findsOneWidget,
    );
  });

  testWidgets('only shows the delete action for non-root layers',
      (tester) async {
    final remote = _FakeRemoteEventSource(layers: const [bundesverband, koeln]);
    await pumpScreen(tester, remote);

    await tester.tap(popupMenuFor('Bundesverband'));
    await tester.pumpAndSettle();
    expect(find.text('Löschen'), findsNothing);
    await tester.tap(find.text('Umbenennen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    await tester.tap(popupMenuFor('Köln'));
    await tester.pumpAndSettle();
    expect(find.text('Löschen'), findsOneWidget);
    await tester.tapAt(const Offset(0, 0)); // close the menu
    await tester.pumpAndSettle();
  });

  testWidgets('renaming a layer calls updateLayer with the new name',
      (tester) async {
    final remote = _FakeRemoteEventSource(layers: const [bundesverband]);
    await pumpScreen(tester, remote);

    await tester.tap(popupMenuFor('Bundesverband'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Umbenennen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Neuer Name');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(remote.updateLayerCallCount, 1);
    expect(remote.lastUpdatedLayerId, 1);
    expect(remote.lastUpdatedName, 'Neuer Name');
  });

  testWidgets('adding a sub-layer calls createLayer with the parent id',
      (tester) async {
    final remote = _FakeRemoteEventSource(layers: const [bundesverband]);
    await pumpScreen(tester, remote);

    await tester.tap(popupMenuFor('Bundesverband'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub-Layer hinzufügen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Meute');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    expect(remote.createLayerCallCount, 1);
    expect(remote.lastCreatedParentId, 1);
    expect(remote.lastCreatedName, 'Meute');
  });

  testWidgets('canceling the delete confirmation does not call deleteLayer',
      (tester) async {
    final remote = _FakeRemoteEventSource(layers: const [bundesverband, koeln]);
    await pumpScreen(tester, remote);

    await tester.tap(popupMenuFor('Köln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(find.text('Möchtest du den Layer "Köln" löschen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(remote.deleteLayerCallCount, 0);
  });

  testWidgets(
      'confirming the delete dialog calls deleteLayer with the layer id',
      (tester) async {
    final remote = _FakeRemoteEventSource(layers: const [bundesverband, koeln]);
    await pumpScreen(tester, remote);

    await tester.tap(popupMenuFor('Köln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await tester.pumpAndSettle();

    expect(remote.deleteLayerCallCount, 1);
    expect(remote.lastDeletedLayerId, 2);
  });

  testWidgets(
      'a failed rename keeps the screen open without crashing the widget tree',
      (tester) async {
    final remote = _FakeRemoteEventSource(
      layers: const [bundesverband],
      updateLayerError: RemoteEventSourceException('boom'),
    );
    await pumpScreen(tester, remote);

    await tester.tap(popupMenuFor('Bundesverband'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Umbenennen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Neuer Name');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(remote.updateLayerCallCount, 1);
    expect(find.text('Bundesverband'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a failed create-sub-layer keeps the screen open without crashing the widget tree',
      (tester) async {
    final remote = _FakeRemoteEventSource(
      layers: const [bundesverband],
      createLayerError: RemoteEventSourceException('boom'),
    );
    await pumpScreen(tester, remote);

    await tester.tap(popupMenuFor('Bundesverband'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub-Layer hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Meute');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    expect(remote.createLayerCallCount, 1);
    expect(find.text('Bundesverband'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a failed delete keeps the screen open without crashing the widget tree',
      (tester) async {
    final remote = _FakeRemoteEventSource(
      layers: const [bundesverband, koeln],
      deleteLayerError: RemoteEventSourceException('boom'),
    );
    await pumpScreen(tester, remote);

    await tester.tap(popupMenuFor('Köln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await tester.pumpAndSettle();

    expect(remote.deleteLayerCallCount, 1);
    expect(find.text('Köln'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

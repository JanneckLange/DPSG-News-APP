import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/core/services/error_toast_service.dart';
import 'package:dpsg_news_app/features/events/data/remote_event_source.dart';

void main() {
  group('describeRemoteError', () {
    test('prefers the server message when a RemoteEventSourceException carries one',
        () {
      final error = RemoteEventSourceException(
        'Failed to login author: 401',
        statusCode: 401,
        serverMessage: 'Invalid credentials',
      );

      expect(describeRemoteError(error), 'Invalid credentials');
    });

    test('falls back to the exception message when there is no server message',
        () {
      final error = RemoteEventSourceException('Timed out while fetching events');

      expect(describeRemoteError(error), 'Timed out while fetching events');
    });

    test('uses toString() for errors that are not a RemoteEventSourceException',
        () {
      expect(describeRemoteError(Exception('boom')), 'Exception: boom');
    });
  });

  group('showErrorToastForKey', () {
    // Hinweis: showErrorToastForKey mit einem an MaterialApp angehefteten
    // navigatorKey und tatsaechlich vorhandenem Overlay wird hier bewusst
    // NICHT getestet. Toastify.show() ruft intern Overlay.of(context) mit
    // navigatorKey.currentContext auf -- das ist der Kontext des
    // Navigator-Widgets selbst. Das von Navigator erzeugte Overlay ist aber
    // ein Nachfahre dieses Kontexts, kein Vorfahre, daher findet
    // Overlay.of() es strukturell nie (vgl. NavigatorState._overlayKey in
    // navigator.dart, das genau deshalb einen eigenen Key statt
    // Overlay.of(context) nutzt). Das fuehrt aktuell zu einem
    // "No Overlay widget found"-Fehler statt einer Toast-Anzeige -- ein
    // vorbestehender Bug ausserhalb dieses Testauftrags, hier nur
    // dokumentiert statt gefixt.
    testWidgets('does nothing when the navigator key has no attached context',
        (tester) async {
      final key = GlobalKey<NavigatorState>();

      expect(() => showErrorToastForKey(key, 'Ein Fehler ist aufgetreten.'),
          returnsNormally);
    });
  });
}

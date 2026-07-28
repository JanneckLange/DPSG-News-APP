import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpsg_news_app/features/admin/presentation/admin_otp_dialog.dart';

void main() {
  final clipboardCalls = <MethodCall>[];

  setUp(() {
    clipboardCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        clipboardCalls.add(methodCall);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> openDialog(
    WidgetTester tester, {
    required String otp,
    String? username,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showAdminOtpDialog(
            context,
            otp: otp,
            title: 'Einmalpasswort',
            message: 'Bitte notieren und weitergeben.',
            username: username,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows title, message, username and the one-time password',
      (tester) async {
    await openDialog(tester, otp: 'temp-abc-123', username: 'new-admin');

    expect(find.text('Einmalpasswort'), findsOneWidget);
    expect(find.text('Bitte notieren und weitergeben.'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('new-admin'), findsOneWidget);
    expect(find.text('temp-abc-123'), findsOneWidget);
  });

  testWidgets('omits the username row when no username is provided',
      (tester) async {
    await openDialog(tester, otp: 'temp-abc-123');

    expect(find.text('User'), findsNothing);
    expect(find.text('temp-abc-123'), findsOneWidget);
  });

  testWidgets('Schließen closes the dialog without copying anything',
      (tester) async {
    await openDialog(tester, otp: 'temp-abc-123', username: 'new-admin');

    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    expect(find.text('Einmalpasswort'), findsNothing);
    expect(clipboardCalls, isEmpty);
  });

  testWidgets(
      'Kopieren copies username and password together and closes the dialog',
      (tester) async {
    await openDialog(tester, otp: 'temp-abc-123', username: 'new-admin');

    await tester.tap(find.text('Kopieren'));
    await tester.pumpAndSettle();

    expect(clipboardCalls, hasLength(1));
    expect(clipboardCalls.single.arguments['text'], 'new-admin\ntemp-abc-123');
    expect(find.text('Einmalpasswort'), findsNothing);
  });

  testWidgets('Kopieren copies only the password when no username is set',
      (tester) async {
    await openDialog(tester, otp: 'temp-abc-123');

    await tester.tap(find.text('Kopieren'));
    await tester.pumpAndSettle();

    expect(clipboardCalls.single.arguments['text'], 'temp-abc-123');
  });

  testWidgets(
      'the inline copy icon on the password row copies only the password and keeps the dialog open',
      (tester) async {
    await openDialog(tester, otp: 'temp-abc-123', username: 'new-admin');

    await tester.tap(find.widgetWithIcon(IconButton, Icons.copy));
    await tester.pumpAndSettle();

    expect(clipboardCalls, hasLength(1));
    expect(clipboardCalls.single.arguments['text'], 'temp-abc-123');
    expect(find.text('Einmalpasswort'), findsOneWidget);
  });
}

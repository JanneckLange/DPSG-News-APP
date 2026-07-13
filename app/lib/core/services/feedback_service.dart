import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wiredash/wiredash.dart';

import '../config/app_config.dart';
import 'analytics_service.dart';

Future<void> openFeedbackFlow(
  BuildContext context,
  WidgetRef ref, {
  required String screen,
  String target = 'wiredash',
}) async {
  unawaited(
    ref.read(analyticsServiceProvider).trackUiClick(
      'feedback',
      screen: screen,
      action: 'open',
      target: target,
    ),
  );

  if (!AppConfig.hasWiredashConfig) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback ist derzeit nicht verfügbar. Bitte prüfe die Wiredash-Konfiguration.')),
      );
    }
    return;
  }

  try {
    final navigatorContext = Navigator.of(context, rootNavigator: true).context;
    if (navigatorContext.mounted) {
      Wiredash.of(navigatorContext).show(inheritMaterialTheme: true);
      return;
    }
  } catch (_) {}

  try {
    Wiredash.of(context).show(inheritMaterialTheme: true);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback ist derzeit nicht verfügbar.')),
      );
    }
  }
}

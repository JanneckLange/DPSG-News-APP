import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/dv_selection_screen.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _editorKey = GlobalKey<DvSelectionEditorState>();

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(analyticsServiceProvider).trackScreenView('welcome'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                children: [
                  const Icon(Icons.groups, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    'Willkommen bei der DPSG News App',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Wähle deinen Diözesanverband aus, damit wir dir passende Termine anzeigen. '
                    'Du kannst das jederzeit in den Einstellungen ändern.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
                child: DvSelectionEditor(key: _editorKey, autosave: false)),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: _finish,
                    child: const Text('Fertig'),
                  ),
                  TextButton(
                    onPressed: _skip,
                    child: const Text('Später auswählen'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    unawaited(
      ref.read(analyticsServiceProvider).trackFeatureEvent(
            'welcome_completed',
            screen: 'welcome',
            action: 'tap',
            target: 'finish',
          ),
    );
    await _editorKey.currentState?.save();
    await ref.read(hasSeenWelcomeProvider.notifier).setHasSeenWelcome(true);
  }

  Future<void> _skip() async {
    unawaited(
      ref.read(analyticsServiceProvider).trackFeatureEvent(
            'welcome_skipped',
            screen: 'welcome',
            action: 'tap',
            target: 'skip',
          ),
    );
    await ref.read(hasSeenWelcomeProvider.notifier).setHasSeenWelcome(true);
  }
}

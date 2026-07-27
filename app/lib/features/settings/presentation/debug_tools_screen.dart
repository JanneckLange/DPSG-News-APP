import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/services/logging_service.dart';
import '../../../core/services/notification_service.dart';
import '../data/api_health_provider.dart';
import '../data/settings_repository.dart';
import 'changelog_screen.dart';
import 'debug_logs_screen.dart';
import 'external_notifications_placeholder_screen.dart';
import 'widgets/debug_ui_atoms.dart';

class DebugToolsScreen extends ConsumerStatefulWidget {
  const DebugToolsScreen({super.key});

  @override
  ConsumerState<DebugToolsScreen> createState() => _DebugToolsScreenState();
}

class _DebugToolsScreenState extends ConsumerState<DebugToolsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug & Tools')),
      body: const DebugToolsBody(),
    );
  }
}

class DebugToolsBody extends ConsumerStatefulWidget {
  const DebugToolsBody({super.key, this.inline = false});

  final bool inline;

  @override
  ConsumerState<DebugToolsBody> createState() => _DebugToolsBodyState();
}

class _DebugToolsBodyState extends ConsumerState<DebugToolsBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(settingsRepositoryProvider);
    final configuredUrl = repository.getApiBaseUrl();
    final effectiveUrl = configuredUrl ?? AppConfig.defaultApiBaseUrl;
    final apnsToken = ref.watch(apnsTokenProvider);
    final healthStatus = ref.watch(apiHealthProvider);

    final colorScheme = Theme.of(context).colorScheme;

    final sections = <Widget>[
      DebugSectionCard(
        icon: Icons.developer_mode,
        title: 'System',
        subtitle: 'Bestehende Entwicklerwerte und Verbindungsstatus',
        child: Column(
          children: [
            if (!kReleaseMode)
              _debugNavTile(
                context,
                icon: Icons.language,
                title: 'API-URL',
                subtitle: effectiveUrl,
                onTap: () async {
                  await _showApiUrlDialog(context, repository);
                },
              ),
            _debugNavTile(
              context,
              icon: Icons.network_check,
              title: 'API-Status',
              subtitle: healthStatus?.message ?? 'Nicht geprüft',
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  unawaited(
                    ref.read(analyticsServiceProvider).trackUiClick(
                      'refresh_api_status',
                      screen: 'debug_tools',
                      action: 'press',
                      target: 'api_health',
                    ),
                  );
                  await ref
                      .read(apiHealthProvider.notifier)
                      .refresh(effectiveUrl);
                },
              ),
              onTap: () async {
                await ref
                    .read(apiHealthProvider.notifier)
                    .refresh(effectiveUrl);
              },
            ),
            _debugNavTile(
              context,
              icon: Icons.fingerprint,
              title: 'APNS-Token',
              subtitle: apnsToken ?? 'Noch nicht verfügbar',
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: apnsToken == null || apnsToken.isEmpty
                    ? null
                    : () async {
                        unawaited(
                          ref.read(analyticsServiceProvider).trackUiClick(
                            'copy_apns_token',
                            screen: 'debug_tools',
                            action: 'press',
                            target: 'apns_token',
                          ),
                        );
                        await Clipboard.setData(ClipboardData(text: apnsToken));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('APNS-Token kopiert')),
                          );
                        }
                      },
              ),
              onTap: () {},
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const DebugSectionCard(
        icon: Icons.article_outlined,
        title: 'App Logs',
        subtitle: 'App-Logs und Request-Logs',
        child: InlineLogsControls(),
      ),
      const SizedBox(height: 16),
      DebugSectionCard(
        icon: Icons.feedback_outlined,
        title: 'Feedback und Bewertung',
        subtitle: 'Zwei getrennte Aktionen wie in der NamiApp',
        child: DebugButtonGroup(
          children: [
            DebugActionButton(
              icon: Icons.feedback_outlined,
              label: 'Feedback senden',
              onPressed: () async {
                ref.read(loggingServiceProvider).trackAndLog(
                  'debug_tools',
                  'debug_action',
                  const <String, Object?>{'action': 'open_feedback'},
                );
                await openFeedbackFlow(context, ref, screen: 'debug_tools');
              },
            ),
            DebugActionButton(
              icon: Icons.star_outline,
              label: 'App bewerten',
              onPressed: () {
                ref.read(loggingServiceProvider).trackAndLog(
                  'debug_tools',
                  'debug_action',
                  const <String, Object?>{'action': 'open_app_rating'},
                );
                unawaited(
                  ref.read(analyticsServiceProvider).trackUiClick(
                    'app_rating',
                    screen: 'debug_tools',
                    action: 'open',
                    target: 'store',
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Bewertung wird später mit Store-Ziel ergänzt.')),
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      DebugSectionCard(
        icon: Icons.library_books_outlined,
        title: 'Referenzen',
        subtitle: 'Changelog und externe Benachrichtigungen',
        child: Column(
          children: [
            _debugNavTile(
              context,
              icon: Icons.list_alt,
              title: 'Changelog',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const ChangelogScreen()),
                );
              },
            ),
            _debugNavTile(
              context,
              icon: Icons.campaign_outlined,
              title: 'Externe Benachrichtigungen',
              subtitle: 'Platzhalter',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        const ExternalNotificationsPlaceholderScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ];

    if (widget.inline) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: sections);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
            colorScheme.surface,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: sections,
          ),
        ),
      ),
    );
  }

  Future<void> _showApiUrlDialog(
      BuildContext context, SettingsRepository repository) async {
    final controller = TextEditingController(
        text: repository.getApiBaseUrl() ?? AppConfig.defaultApiBaseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('API-URL ändern'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'https://example.com'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                final value = controller.text.trim();
                await repository.setApiBaseUrl(value.isEmpty ? null : value);
                if (context.mounted) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API-URL gespeichert.')),
      );
    }
  }

  Widget _debugNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
      ),
    );
  }
}

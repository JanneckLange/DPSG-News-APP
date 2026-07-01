import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wiredash/wiredash.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/logging_service.dart';
import '../../../core/services/notification_service.dart';
import '../../events/data/remote_event_source.dart';
import '../data/settings_repository.dart';

final apiHealthProvider = StateNotifierProvider<ApiHealthNotifier, ApiHealthStatus?>((ref) {
  return ApiHealthNotifier(ref.read(loggingServiceProvider));
});

class ApiHealthNotifier extends StateNotifier<ApiHealthStatus?> {
  ApiHealthNotifier(this._logger) : super(null);

  final LoggingService _logger;

  Future<void> refresh(String baseUrl) async {
    state = ApiHealthStatus(false, 'Prüfe Verbindung...');
    try {
      final uri = Uri.parse(baseUrl);
      final status = await RemoteEventSource(baseUrl: uri, logger: _logger).checkHealth();
      state = status;
    } catch (error) {
      state = ApiHealthStatus(false, 'Server nicht erreichbar');
    }
  }
}

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
      _DebugSectionCard(
        icon: Icons.developer_mode,
        title: 'System',
        subtitle: 'Bestehende Entwicklerwerte und Verbindungsstatus',
        child: Column(
          children: [
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
                  await ref.read(apiHealthProvider.notifier).refresh(effectiveUrl);
                },
              ),
              onTap: () async {
                await ref.read(apiHealthProvider.notifier).refresh(effectiveUrl);
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
      const _DebugSectionCard(
        icon: Icons.article_outlined,
        title: 'App Logs',
        subtitle: 'App-Logs und Request-Logs',
        child: _InlineLogsControls(),
      ),
      const SizedBox(height: 16),
      _DebugSectionCard(
        icon: Icons.feedback_outlined,
        title: 'Feedback und Bewertung',
        subtitle: 'Zwei getrennte Aktionen wie in der NamiApp',
        child: _DebugButtonGroup(
          children: [
            _DebugActionButton(
              icon: Icons.feedback_outlined,
              label: 'Feedback senden',
              onPressed: () {
                ref.read(loggingServiceProvider).trackAndLog(
                  'debug_tools',
                  'debug_action',
                  const <String, Object?>{'action': 'open_feedback'},
                );
                try {
                  Wiredash.of(context).show(inheritMaterialTheme: true);
                } catch (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feedback derzeit nicht verfügbar.')),
                  );
                }
              },
            ),
            _DebugActionButton(
              icon: Icons.star_outline,
              label: 'App bewerten',
              onPressed: () {
                ref.read(loggingServiceProvider).trackAndLog(
                  'debug_tools',
                  'debug_action',
                  const <String, Object?>{'action': 'open_app_rating'},
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bewertung wird später mit Store-Ziel ergänzt.')),
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _DebugSectionCard(
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
                  MaterialPageRoute(builder: (context) => const ChangelogScreen()),
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
                    builder: (context) => const ExternalNotificationsPlaceholderScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ];

    if (widget.inline) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections);
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

  Future<void> _showApiUrlDialog(BuildContext context, SettingsRepository repository) async {
    final controller = TextEditingController(text: repository.getApiBaseUrl() ?? AppConfig.defaultApiBaseUrl);
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _DebugSectionCard extends StatelessWidget {
  const _DebugSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = colorScheme.primary;
    final containerColor = colorScheme.surfaceContainerLow;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _DebugButtonGroup extends StatelessWidget {
  const _DebugButtonGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DebugActionButton extends StatelessWidget {
  const _DebugActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = isDestructive
        ? FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            disabledBackgroundColor: colorScheme.error.withValues(alpha: 0.26),
            disabledForegroundColor: colorScheme.onError.withValues(alpha: 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          )
        : FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          );

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      ),
    );
  }
}

class _InlineLogsControls extends ConsumerStatefulWidget {
  const _InlineLogsControls();

  @override
  ConsumerState<_InlineLogsControls> createState() => _InlineLogsControlsState();
}

class _InlineLogsControlsState extends ConsumerState<_InlineLogsControls> {
  LogSource _source = LogSource.app;
  String _selectionId = LoggingService.allLogsSelectionId;
  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    final logger = ref.read(loggingServiceProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<List<String>>(
      key: ValueKey(_revision),
      future: logger.listLogFileNames(source: _source),
      builder: (context, snapshot) {
        final names = snapshot.data ?? const <String>[];
        final selectedId = names.contains(_selectionId)
            ? _selectionId
            : LoggingService.allLogsSelectionId;
        final hasLogs = names.isNotEmpty;

        if (_selectionId != selectedId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _selectionId = LoggingService.allLogsSelectionId;
            });
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasLogs
                  ? '${names.length} Log-Datei${names.length == 1 ? '' : 'en'} verfuegbar'
                  : 'Noch keine Logs vorhanden.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LogSource>(
              initialValue: _source,
              decoration: const InputDecoration(
                labelText: 'Quelle',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: LogSource.app, child: Text('App-Logs')),
                DropdownMenuItem(value: LogSource.request, child: Text('Request-Logs')),
              ],
              onChanged: (value) {
                if (value == null || value == _source) {
                  return;
                }
                setState(() {
                  _source = value;
                  _selectionId = LoggingService.allLogsSelectionId;
                  _revision++;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Datei',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: LoggingService.allLogsSelectionId,
                  child: Text('Alle Dateien'),
                ),
                ...names.map(
                  (name) => DropdownMenuItem<String>(
                    value: name,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectionId = value ?? LoggingService.allLogsSelectionId;
                });
              },
            ),
            const SizedBox(height: 12),
            _DebugButtonGroup(
              children: [
                _DebugActionButton(
                  icon: Icons.article_outlined,
                  label: selectedId == LoggingService.allLogsSelectionId
                      ? 'Logs anzeigen'
                      : 'Auswahl anzeigen',
                  onPressed: !hasLogs
                      ? null
                      : () async {
                          await logger.trackAndLog(
                            'debug_tools',
                            'debug_action',
                            <String, Object?>{
                              'action': 'view_logs',
                              'source': _source.name,
                              'selection': selectedId,
                            },
                          );
                          final content = await logger.readLogs(
                            source: _source,
                            selectionId: selectedId,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          final title = selectedId == LoggingService.allLogsSelectionId
                              ? 'Logs'
                              : 'Logs: $selectedId';
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _LogViewerPage(
                                title: title,
                                content: content,
                                reverseLines: false,
                              ),
                            ),
                          );
                        },
                ),
                _DebugActionButton(
                  icon: Icons.mail_outline,
                  label: selectedId == LoggingService.allLogsSelectionId
                      ? 'Logs per Mail senden'
                      : 'Auswahl per Mail senden',
                  onPressed: !hasLogs
                      ? null
                      : () async {
                          await logger.trackAndLog(
                            'debug_tools',
                            'debug_action',
                            <String, Object?>{
                              'action': 'send_logs_email',
                              'source': _source.name,
                              'selection': selectedId,
                            },
                          );
                          if (!context.mounted) {
                            return;
                          }
                          await _sendLogsEmail(context, logger, _source, selectedId);
                        },
                ),
                _DebugActionButton(
                  icon: Icons.delete_outline,
                  label: 'Logs loeschen',
                  isDestructive: true,
                  onPressed: !hasLogs
                      ? null
                      : () async {
                          await logger.trackAndLog(
                            'debug_tools',
                            'debug_action',
                            <String, Object?>{
                              'action': 'delete_logs',
                              'source': _source.name,
                            },
                          );
                          await logger.clearAllLogs(source: _source);
                          if (!context.mounted) {
                            return;
                          }
                          setState(() {
                            _selectionId = LoggingService.allLogsSelectionId;
                            _revision++;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logs geloescht.')),
                          );
                        },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class LogsViewScreen extends ConsumerStatefulWidget {
  const LogsViewScreen({super.key, required this.initialSource});

  final LogSource initialSource;

  @override
  ConsumerState<LogsViewScreen> createState() => _LogsViewScreenState();
}

class _LogsViewScreenState extends ConsumerState<LogsViewScreen> {
  LogSource? _source;
  String _selectionId = LoggingService.allLogsSelectionId;
  int _revision = 0;

  LogSource get _selectedSource => _source ?? widget.initialSource;

  @override
  void initState() {
    super.initState();
    _source = widget.initialSource;
  }

  @override
  Widget build(BuildContext context) {
    final logger = ref.read(loggingServiceProvider);
    final source = _selectedSource;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: DecoratedBox(
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<List<String>>(
              key: ValueKey(_revision),
              future: logger.listLogFileNames(source: source),
              builder: (context, snapshot) {
                final names = snapshot.data ?? const <String>[];
                final selectedId = names.contains(_selectionId)
                    ? _selectionId
                    : LoggingService.allLogsSelectionId;
                final hasLogs = names.isNotEmpty;

                if (_selectionId != selectedId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _selectionId = LoggingService.allLogsSelectionId;
                    });
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dateiauswahl', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            hasLogs
                                ? '${names.length} Log-Datei${names.length == 1 ? '' : 'en'} verfügbar'
                                : 'Noch keine Logs vorhanden.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<LogSource>(
                            initialValue: source,
                            decoration: const InputDecoration(
                              labelText: 'Quelle',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: LogSource.app, child: Text('App-Logs')),
                              DropdownMenuItem(value: LogSource.request, child: Text('Request-Logs')),
                            ],
                            onChanged: (value) {
                              if (value == null || value == _selectedSource) {
                                return;
                              }
                              setState(() {
                                _source = value;
                                _selectionId = LoggingService.allLogsSelectionId;
                                _revision++;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Datei',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: LoggingService.allLogsSelectionId,
                                child: Text('Alle Dateien'),
                              ),
                              ...names.map(
                                (name) => DropdownMenuItem<String>(
                                  value: name,
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectionId = value ?? LoggingService.allLogsSelectionId;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DebugButtonGroup(
                      children: [
                        _DebugActionButton(
                          icon: Icons.mail_outline,
                          label: selectedId == LoggingService.allLogsSelectionId
                              ? 'Logs per Mail senden'
                              : 'Auswahl per Mail senden',
                          onPressed: !hasLogs
                              ? null
                              : () async {
                                  await logger.trackAndLog(
                                    'debug_tools',
                                    'debug_action',
                                    <String, Object?>{
                                      'action': 'send_logs_email',
                                      'source': source.name,
                                      'selection': selectedId,
                                    },
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  await _sendLogsEmail(context, logger, source, selectedId);
                                },
                        ),
                        _DebugActionButton(
                          icon: Icons.article_outlined,
                          label: selectedId == LoggingService.allLogsSelectionId
                              ? 'Logs anzeigen'
                              : 'Auswahl anzeigen',
                          onPressed: !hasLogs
                              ? null
                              : () async {
                                  await logger.trackAndLog(
                                    'debug_tools',
                                    'debug_action',
                                    <String, Object?>{
                                      'action': 'view_logs',
                                      'source': source.name,
                                      'selection': selectedId,
                                    },
                                  );
                                  final content = await logger.readLogs(
                                    source: source,
                                    selectionId: selectedId,
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  final title = selectedId == LoggingService.allLogsSelectionId
                                      ? 'Logs'
                                      : 'Logs: $selectedId';
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => _LogViewerPage(
                                        title: title,
                                        content: content,
                                        reverseLines: false,
                                      ),
                                    ),
                                  );
                                },
                        ),
                        _DebugActionButton(
                          icon: Icons.delete_outline,
                          label: 'Logs loeschen',
                          isDestructive: true,
                          onPressed: !hasLogs
                              ? null
                              : () async {
                                  await logger.trackAndLog(
                                    'debug_tools',
                                    'debug_action',
                                    <String, Object?>{
                                      'action': 'delete_logs',
                                      'source': source.name,
                                    },
                                  );
                                  await logger.clearAllLogs(source: source);
                                  if (!context.mounted) {
                                    return;
                                  }
                                  setState(() {
                                    _selectionId = LoggingService.allLogsSelectionId;
                                    _revision++;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Logs geloescht.')),
                                  );
                                },
                        ),
                      ],
                    ),
                    if (!hasLogs)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text('Noch keine Logs vorhanden.'),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

}

Future<void> _sendLogsEmail(
  BuildContext context,
  LoggingService logger,
  LogSource source,
  String selectionId,
) async {
  final result = await logger.sendLogsByEmail(source: source, selectionId: selectionId);
  if (!context.mounted) {
    return;
  }

  final message = switch (result) {
    LogEmailSendResult.sent => 'Mail-Entwurf geoeffnet.',
    LogEmailSendResult.noFiles => 'Keine Log-Dateien vorhanden.',
    LogEmailSendResult.unavailable => 'Mailversand derzeit nicht verfuegbar.',
  };

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _LogViewerPage extends StatefulWidget {
  const _LogViewerPage({
    required this.title,
    required this.content,
    this.reverseLines = true,
  });

  final String title;
  final String content;
  final bool reverseLines;

  @override
  State<_LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<_LogViewerPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showJumpToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateJumpButtonVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToBottom();
      _updateJumpButtonVisibility();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateJumpButtonVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _animateToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _updateJumpButtonVisibility() {
    if (!_scrollController.hasClients) {
      return;
    }
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final shouldShow = max > 0 && current < (max - 48);
    if (shouldShow == _showJumpToBottom) {
      return;
    }
    setState(() {
      _showJumpToBottom = shouldShow;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: _ColoredLogView(
                content: widget.content,
                reverseLines: widget.reverseLines,
              ),
            ),
          ),
          if (_showJumpToBottom)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                onPressed: _animateToBottom,
                child: const Icon(Icons.arrow_downward),
              ),
            ),
        ],
      ),
    );
  }
}

class _ColoredLogView extends StatelessWidget {
  const _ColoredLogView({required this.content, this.reverseLines = true});

  final String content;
  final bool reverseLines;

  TextSpan _spanForLine(
    String line,
    TextStyle base, {
    required TextStyle tsStyle,
    required TextStyle levelInfoStyle,
    required TextStyle levelWarnStyle,
    required TextStyle levelErrorStyle,
    required TextStyle levelDebugStyle,
    required TextStyle serviceStyle,
    required TextStyle msgStyle,
  }) {
    final regex = RegExp(r'^\[(.*?)\]\s*(\[\w+\])?\s*(\[[^\]]+\])?\s*(.*)$');
    final match = regex.firstMatch(line);
    if (match == null) {
      return TextSpan(text: line, style: msgStyle);
    }

    final ts = match.group(1) ?? '';
    final level = match.group(2) ?? '';
    final service = match.group(3) ?? '';
    final msg = match.group(4) ?? '';

    final levelStyle = switch (level.toLowerCase()) {
      '[info]' => levelInfoStyle,
      '[warn]' => levelWarnStyle,
      '[error]' => levelErrorStyle,
      '[debug]' => levelDebugStyle,
      _ => serviceStyle,
    };

    return TextSpan(
      children: [
        TextSpan(text: '[$ts] ', style: tsStyle),
        if (level.isNotEmpty) TextSpan(text: '$level ', style: levelStyle),
        if (service.isNotEmpty) TextSpan(text: '$service ', style: serviceStyle),
        TextSpan(text: msg, style: msgStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = content.isEmpty ? const <String>[] : content.split('\n');
    final ordered = reverseLines ? lines.reversed.toList() : lines;
    const base = TextStyle(fontFamily: 'monospace', fontSize: 13);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tsStyle = base.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey);
    final levelInfoStyle = base.copyWith(color: Colors.green);
    final levelWarnStyle = base.copyWith(color: Colors.orange);
    final levelErrorStyle = base.copyWith(color: Colors.red);
    final levelDebugStyle = base.copyWith(color: Colors.purple);
    final serviceStyle = base.copyWith(color: Colors.blue);
    final msgStyle = base.copyWith(color: isDark ? Colors.white : Colors.black);

    return SelectableText.rich(
      TextSpan(
        children: ordered
            .expand((line) => <TextSpan>[
                  _spanForLine(
                    line,
                    base,
                    tsStyle: tsStyle,
                    levelInfoStyle: levelInfoStyle,
                    levelWarnStyle: levelWarnStyle,
                    levelErrorStyle: levelErrorStyle,
                    levelDebugStyle: levelDebugStyle,
                    serviceStyle: serviceStyle,
                    msgStyle: msgStyle,
                  ),
                  const TextSpan(text: '\n'),
                ])
            .toList(),
        style: base,
      ),
    );
  }
}

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Changelog')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              title: Text('Version 0.1.0'),
              subtitle: Text('Initiale Struktur der Einstellungen mit Debug-&-Tools-Unterseite.'),
            ),
          ),
        ],
      ),
    );
  }
}

class ExternalNotificationsPlaceholderScreen extends StatelessWidget {
  const ExternalNotificationsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Externe Benachrichtigungen')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Dieser Bereich ist als Platzhalter angelegt und wird im nächsten Schritt funktional angebunden.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

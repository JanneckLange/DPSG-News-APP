import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/logging_service.dart';
import 'widgets/debug_ui_atoms.dart';

class InlineLogsControls extends ConsumerStatefulWidget {
  const InlineLogsControls({super.key});

  @override
  ConsumerState<InlineLogsControls> createState() => _InlineLogsControlsState();
}

class _InlineLogsControlsState extends ConsumerState<InlineLogsControls> {
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
                DropdownMenuItem(
                    value: LogSource.request, child: Text('Request-Logs')),
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
            DebugButtonGroup(
              children: [
                DebugActionButton(
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
                          final title =
                              selectedId == LoggingService.allLogsSelectionId
                                  ? 'Logs'
                                  : 'Logs: $selectedId';
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              settings:
                                  const RouteSettings(name: 'LogViewerPage'),
                              builder: (_) => _LogViewerPage(
                                title: title,
                                content: content,
                                reverseLines: false,
                              ),
                            ),
                          );
                        },
                ),
                DebugActionButton(
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
                          await _sendLogsEmail(
                              context, logger, _source, selectedId);
                        },
                ),
                DebugActionButton(
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
                          Text('Dateiauswahl',
                              style: theme.textTheme.titleMedium),
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
                              DropdownMenuItem(
                                  value: LogSource.app,
                                  child: Text('App-Logs')),
                              DropdownMenuItem(
                                  value: LogSource.request,
                                  child: Text('Request-Logs')),
                            ],
                            onChanged: (value) {
                              if (value == null || value == _selectedSource) {
                                return;
                              }
                              setState(() {
                                _source = value;
                                _selectionId =
                                    LoggingService.allLogsSelectionId;
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
                                _selectionId =
                                    value ?? LoggingService.allLogsSelectionId;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DebugButtonGroup(
                      children: [
                        DebugActionButton(
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
                                  await _sendLogsEmail(
                                      context, logger, source, selectedId);
                                },
                        ),
                        DebugActionButton(
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
                                  final title = selectedId ==
                                          LoggingService.allLogsSelectionId
                                      ? 'Logs'
                                      : 'Logs: $selectedId';
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      settings: const RouteSettings(
                                          name: 'LogViewerPage'),
                                      builder: (_) => _LogViewerPage(
                                        title: title,
                                        content: content,
                                        reverseLines: false,
                                      ),
                                    ),
                                  );
                                },
                        ),
                        DebugActionButton(
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
                                    _selectionId =
                                        LoggingService.allLogsSelectionId;
                                    _revision++;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Logs geloescht.')),
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
  final result =
      await logger.sendLogsByEmail(source: source, selectionId: selectionId);
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
        if (service.isNotEmpty)
          TextSpan(text: '$service ', style: serviceStyle),
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
    final tsStyle =
        base.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey);
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

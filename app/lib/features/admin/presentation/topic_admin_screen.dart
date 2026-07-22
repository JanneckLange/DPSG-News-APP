import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../author/data/author_auth_provider.dart';
import '../../settings/data/dv_tree_provider.dart';
import '../../../core/services/error_toast_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../domain/topic_model.dart';

class TopicAdminScreen extends ConsumerStatefulWidget {
  const TopicAdminScreen({super.key});

  @override
  ConsumerState<TopicAdminScreen> createState() => _TopicAdminScreenState();
}

class _TopicAdminScreenState extends ConsumerState<TopicAdminScreen> {
  int? _selectedLayerId;
  List<TopicModel> _topics = <TopicModel>[];
  bool _loadingTopics = false;
  String? _topicsError;
  int _topicsRequestId = 0;

  Future<void> _onLayerSelected(int layerId) async {
    setState(() => _selectedLayerId = layerId);
    await _loadTopics(layerId);
  }

  Future<void> _loadTopics(int layerId) async {
    final requestId = ++_topicsRequestId;
    setState(() {
      _loadingTopics = true;
      _topicsError = null;
    });

    try {
      final remote = ref.read(sync_service.remoteEventSourceProvider);
      final response = await remote.fetchTopics(layerId: layerId);
      final topics =
          List<Map<String, dynamic>>.from(response['topics'] as List<dynamic>)
              .map(TopicModel.fromJson)
              .toList();
      if (!mounted || requestId != _topicsRequestId) return;
      setState(() => _topics = topics);
    } catch (error) {
      if (!mounted || requestId != _topicsRequestId) return;
      setState(() => _topicsError = error.toString());
    } finally {
      if (mounted && requestId == _topicsRequestId) {
        setState(() => _loadingTopics = false);
      }
    }
  }

  Future<void> _createTopic() async {
    final layerId = _selectedLayerId;
    if (layerId == null) return;

    final name = await _showNameDialog(
      title: 'Thema anlegen',
      confirmLabel: 'Anlegen',
    );
    if (name == null) return;

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;

    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      await remote.createTopic(token: token, name: name, layerId: layerId);
      await _loadTopics(layerId);
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Thema konnte nicht angelegt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _renameTopic(TopicModel topic) async {
    final name = await _showNameDialog(
      title: 'Thema umbenennen',
      confirmLabel: 'Speichern',
      initialValue: topic.name,
    );
    if (name == null) return;

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;

    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      await remote.updateTopic(token: token, topicId: topic.id, name: name);
      if (_selectedLayerId != null) {
        await _loadTopics(_selectedLayerId!);
      }
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Thema konnte nicht umbenannt werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<void> _deleteTopic(TopicModel topic) async {
    final confirmed = await _confirm(
      'Thema löschen',
      'Möchtest du das Thema "${topic.name}" löschen?',
      'Löschen',
    );
    if (!confirmed) return;

    final token =
        await ref.read(authorAuthProvider.notifier).getValidAccessToken();
    if (token == null) return;

    final remote = ref.read(sync_service.remoteEventSourceProvider);
    try {
      await remote.deleteTopic(token: token, topicId: topic.id);
      if (_selectedLayerId != null) {
        await _loadTopics(_selectedLayerId!);
      }
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        ref,
        'Thema konnte nicht gelöscht werden: ${describeRemoteError(error)}',
      );
    }
  }

  Future<bool> _confirm(
      String title, String message, String confirmLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<String?> _showNameDialog({
    required String title,
    required String confirmLabel,
    String? initialValue,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _TopicNameDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialValue: initialValue,
      ),
    );
  }

  Widget _buildTopicList() {
    if (_loadingTopics) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_topicsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Themen konnten nicht geladen werden: $_topicsError'),
        ),
      );
    }
    if (_topics.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Keine Themen für diesen Layer.'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadTopics(_selectedLayerId!),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _topics.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final topic = _topics[index];
          return Card(
            child: ListTile(
              title: Text(topic.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Umbenennen',
                    icon: const Icon(Icons.edit),
                    onPressed: () => _renameTopic(topic),
                  ),
                  IconButton(
                    tooltip: 'Löschen',
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteTopic(topic),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layerTreeAsync = ref.watch(layerTreeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Themen verwalten')),
      floatingActionButton: _selectedLayerId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _createTopic,
              icon: const Icon(Icons.add),
              label: const Text('Thema anlegen'),
            ),
      body: layerTreeAsync.when(
        data: (layers) {
          if (layers.isEmpty) {
            return const Center(child: Text('Keine Layer vorhanden.'));
          }
          if (_selectedLayerId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedLayerId == null) {
                _onLayerSelected(layers.first.id);
              }
            });
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedLayerId,
                  decoration: const InputDecoration(labelText: 'Layer'),
                  items: layers
                      .map((layer) => DropdownMenuItem(
                          value: layer.id, child: Text(layer.name)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _onLayerSelected(value);
                  },
                ),
              ),
              Expanded(child: _buildTopicList()),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Layer konnten nicht geladen werden: $error'),
          ),
        ),
      ),
    );
  }
}

class _TopicNameDialog extends StatefulWidget {
  const _TopicNameDialog({
    required this.title,
    required this.confirmLabel,
    this.initialValue,
  });

  final String title;
  final String confirmLabel;
  final String? initialValue;

  @override
  State<_TopicNameDialog> createState() => _TopicNameDialogState();
}

class _TopicNameDialogState extends State<_TopicNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Bitte einen Namen eingeben.'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

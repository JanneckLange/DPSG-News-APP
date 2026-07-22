import 'package:flutter/material.dart';

import '../../domain/topic_model.dart';

/// Zeigt einen Dialog mit einer flachen Checkbox-Liste von Topics (ID-basiert)
/// und liefert die gewaehlten Topic-IDs zurueck (null bei Abbruch).
Future<Set<int>?> showTopicMultiSelectDialog(
  BuildContext context, {
  required String title,
  required List<TopicModel> availableTopics,
  required Set<int> initialSelectedTopicIds,
}) {
  return showDialog<Set<int>>(
    context: context,
    builder: (context) => _TopicMultiSelectDialog(
      title: title,
      availableTopics: availableTopics,
      initialSelectedTopicIds: initialSelectedTopicIds,
    ),
  );
}

class _TopicMultiSelectDialog extends StatefulWidget {
  const _TopicMultiSelectDialog({
    required this.title,
    required this.availableTopics,
    required this.initialSelectedTopicIds,
  });

  final String title;
  final List<TopicModel> availableTopics;
  final Set<int> initialSelectedTopicIds;

  @override
  State<_TopicMultiSelectDialog> createState() =>
      _TopicMultiSelectDialogState();
}

class _TopicMultiSelectDialogState extends State<_TopicMultiSelectDialog> {
  late final Set<int> _selected = Set<int>.from(widget.initialSelectedTopicIds);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.availableTopics.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Keine Topics verfügbar.'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.availableTopics.length,
                itemBuilder: (context, index) {
                  final topic = widget.availableTopics[index];
                  final isSelected = _selected.contains(topic.id);
                  return CheckboxListTile(
                    title: Text(topic.name),
                    value: isSelected,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selected.add(topic.id);
                        } else {
                          _selected.remove(topic.id);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

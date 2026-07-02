import 'package:flutter/material.dart';

class EventListTile extends StatelessWidget {
  const EventListTile({
    super.key,
    required this.title,
    required this.location,
    required this.dv,
    this.createdBy,
    this.modifiedAt,
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String location;
  final String dv;
  final String? createdBy;
  final String? modifiedAt;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      Text(dv),
      if (onEdit != null)
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onEdit,
        ),
      if (onDelete != null)
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: onDelete,
        ),
    ];

    return ListTile(
      title: Text(title),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(location),
          if (createdBy != null) Text('Erstellt von: $createdBy'),
          if (modifiedAt != null) Text(modifiedAt!),
        ],
      ),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      ),
    );
  }
}

import 'package:flutter/material.dart';

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
              subtitle: Text(
                  'Initiale Struktur der Einstellungen mit Debug-&-Tools-Unterseite.'),
            ),
          ),
        ],
      ),
    );
  }
}

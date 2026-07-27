import 'package:flutter/material.dart';

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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> showAdminOtpDialog(
  BuildContext context, {
  required String otp,
  required String title,
  required String message,
  String? username,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      Widget credentialRow({
        required String label,
        required String value,
        bool withCopyButton = false,
      }) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(dialogContext).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: SelectableText(
                      value,
                      style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (withCopyButton)
                    IconButton(
                      tooltip: 'Passwort kopieren',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: value));
                      },
                      icon: const Icon(Icons.copy),
                    ),
                ],
              ),
            ],
          ),
        );
      }

      return AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (username != null) ...[
                  const SizedBox(height: 16),
                  credentialRow(label: 'User', value: username),
                ],
                const SizedBox(height: 12),
                credentialRow(label: 'Passwort', value: otp, withCopyButton: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final copyText = username == null ? otp : '$username\n$otp';
              await Clipboard.setData(ClipboardData(text: copyText));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Kopieren'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Schließen'),
          ),
        ],
      );
    },
  );
}

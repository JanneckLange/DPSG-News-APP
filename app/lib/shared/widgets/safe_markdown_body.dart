import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../utils/url_utils.dart';

/// Rendert nutzergenerierten Markdown-Text (Event-Beschreibung, Update-
/// Nachrichten). Bilder mit einem anderen Schema als http/https (z.B.
/// `file:`, `data:`, Custom-Schemes) werden nicht automatisch nachgeladen,
/// um unkontrollierte Requests an beliebige URLs zu verhindern.
class SafeMarkdownBody extends StatelessWidget {
  const SafeMarkdownBody({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      sizedImageBuilder: (config) {
        if (!isHttpOrHttpsUri(config.uri)) {
          return _BlockedImagePlaceholder(alt: config.alt);
        }
        return Image.network(
          config.uri.toString(),
          width: config.width,
          height: config.height,
          errorBuilder: (context, error, stackTrace) =>
              _BlockedImagePlaceholder(alt: config.alt),
        );
      },
    );
  }
}

class _BlockedImagePlaceholder extends StatelessWidget {
  const _BlockedImagePlaceholder({this.alt});

  final String? alt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported_outlined),
          const SizedBox(width: 8),
          Flexible(
            child: Text((alt != null && alt!.isNotEmpty) ? alt! : 'Bild nicht verfügbar'),
          ),
        ],
      ),
    );
  }
}

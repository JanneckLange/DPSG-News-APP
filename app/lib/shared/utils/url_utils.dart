/// Prueft, ob [uri] ein http- oder https-Schema verwendet.
///
/// Wird als Gate verwendet, bevor eine nutzergenerierte URL (CTA-Buttons,
/// Markdown-Bilder) automatisch geoeffnet oder nachgeladen wird, um Schemes
/// wie `javascript:`, `file:` oder `intent:` auszuschliessen.
bool isHttpOrHttpsUri(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

/// Prueft, ob [raw] eine mailto-Adresse ist: entweder mit explizitem
/// `mailto:`-Schema oder eine nackte E-Mail-Adresse ohne http(s)-Schema.
/// Spiegelt die Server-Logik in `eventValidation.ts` (isMailtoCandidate).
bool looksLikeMailto(String raw) {
  final trimmed = raw.trim();
  if (trimmed.toLowerCase().startsWith('mailto:')) return true;
  return trimmed.contains('@') &&
      !RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed);
}

/// Extrahiert die reine E-Mail-Adresse aus einem CTA1-Feldwert, unabhaengig
/// davon, ob ein `mailto:`-Schema oder Query-Parameter vorhanden sind.
String extractMailtoAddress(String raw) {
  final trimmed = raw.trim();
  final withoutScheme = trimmed.toLowerCase().startsWith('mailto:')
      ? trimmed.substring('mailto:'.length)
      : trimmed;
  return withoutScheme.split('?').first;
}

/// Prueft, ob [uri] ein http- oder https-Schema verwendet.
///
/// Wird als Gate verwendet, bevor eine nutzergenerierte URL (CTA-Buttons,
/// Markdown-Bilder) automatisch geoeffnet oder nachgeladen wird, um Schemes
/// wie `javascript:`, `file:` oder `intent:` auszuschliessen.
bool isHttpOrHttpsUri(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

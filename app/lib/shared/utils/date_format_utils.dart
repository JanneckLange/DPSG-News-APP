import 'package:intl/intl.dart';

/// Formatiert einen ISO-8601-String fuer die Anzeige (voller Wochentag,
/// Datum, Uhrzeit). Das Jahr wird nur angezeigt, wenn es vom aktuellen Jahr
/// abweicht. Sekunden werden nie angezeigt, auch nicht im Fehlerfall.
String formatEventDateTime(String? value) {
  if (value == null) return 'Nicht gesetzt';
  final dateTime = DateTime.tryParse(value);
  if (dateTime == null) return value;
  final local = dateTime.toLocal();
  final now = DateTime.now();
  final showYear = local.year != now.year;
  final pattern = showYear ? 'EEEE, d. MMMM yyyy HH:mm' : 'EEEE, d. MMMM HH:mm';
  try {
    return DateFormat(pattern, 'de').format(local);
  } catch (_) {
    return DateFormat('EEEE, d. MMMM HH:mm', 'de').format(local);
  }
}

/// Kompakte relative Darstellung fuer Dashboard-Kontexte und Update-
/// Zeitstempel, z.B. "vor 3 Tagen", "vor 2 Std.", "gerade eben". Faellt bei
/// Zeitraeumen ab 7 Tagen auf [formatEventDateTime] zurueck.
String formatRelativeTime(String? value) {
  if (value == null) return 'Nicht gesetzt';
  final dateTime = DateTime.tryParse(value);
  if (dateTime == null) return value;
  final local = dateTime.toLocal();
  final diff = DateTime.now().difference(local);

  if (diff.inMinutes < 1) return 'gerade eben';
  if (diff.inHours < 1) return 'vor ${diff.inMinutes} Min.';
  if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
  if (diff.inDays < 7) return 'vor ${diff.inDays} ${diff.inDays == 1 ? 'Tag' : 'Tagen'}';
  return formatEventDateTime(value);
}

/// Deutsches Monats-Kuerzel fuer das Kalenderblatt in der Event-Liste,
/// z.B. "Aug." fuer August.
String formatMonthAbbreviation(DateTime date) {
  final local = date.toLocal();
  try {
    return DateFormat('MMM', 'de').format(local);
  } catch (_) {
    return DateFormat('MMM').format(local);
  }
}

/// Voller Monatsname + Jahr als Section-Header fuer gruppierte Event-Listen,
/// z.B. "August 2026".
String formatMonthYearHeader(DateTime date) {
  final local = date.toLocal();
  try {
    return DateFormat('MMMM yyyy', 'de').format(local);
  } catch (_) {
    return DateFormat('MMMM yyyy').format(local);
  }
}

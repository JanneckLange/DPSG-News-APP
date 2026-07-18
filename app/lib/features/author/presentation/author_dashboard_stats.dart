/// Reine Aggregationslogik fuer das Autor-Dashboard (Kopfbereich des
/// Autor-Bereichs). Keine Widget-/Provider-Abhaengigkeiten.
class AuthorDashboardStats {
  const AuthorDashboardStats({
    required this.onlineCount,
    required this.thisMonthCount,
    required this.staleEvents,
  });

  final int onlineCount;
  final int thisMonthCount;

  /// Eigene Events, deren letztes Update laenger als [staleThreshold] her ist
  /// und die noch in der Zukunft stattfinden.
  final List<Map<String, dynamic>> staleEvents;

  int get staleCount => staleEvents.length;

  static const staleThreshold = Duration(days: 30);

  factory AuthorDashboardStats.fromEvents(List<Map<String, dynamic>> events) {
    final now = DateTime.now();

    var thisMonthCount = 0;
    final staleEvents = <Map<String, dynamic>>[];

    for (final event in events) {
      final startDate = DateTime.tryParse(event['startDate']?.toString() ?? '');
      if (startDate != null) {
        final localStart = startDate.toLocal();
        if (localStart.year == now.year && localStart.month == now.month) {
          thisMonthCount++;
        }
      }

      final referenceRaw = event['lastUpdateAt']?.toString() ?? event['createdAt']?.toString();
      final reference = DateTime.tryParse(referenceRaw ?? '');
      final isFuture = startDate != null && startDate.isAfter(now);
      if (reference != null && isFuture && now.difference(reference) > staleThreshold) {
        staleEvents.add(event);
      }
    }

    return AuthorDashboardStats(
      onlineCount: events.length,
      thisMonthCount: thisMonthCount,
      staleEvents: staleEvents,
    );
  }
}

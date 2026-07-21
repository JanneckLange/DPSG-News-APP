/// Reine Aggregationslogik fuer das Events-Dashboard (Kopfbereich der
/// Events-Liste). Keine Widget-/Provider-Abhaengigkeiten, damit sie ohne
/// Widget-Pump testbar ist.
class EventsDashboardStats {
  const EventsDashboardStats({
    required this.nextMonthCount,
    required this.newUpdatesCount,
    required this.newEventsCount,
  });

  final int nextMonthCount;
  final int newUpdatesCount;
  final int newEventsCount;

  static const _nextMonthWindow = Duration(days: 31);
  static const _newEventsWindow = Duration(days: 30);

  factory EventsDashboardStats.fromEvents(
    List<Map<String, dynamic>> events,
    Set<String> savedEventIds,
    Map<String, DateTime> viewedAt,
  ) {
    final now = DateTime.now();
    final nextMonthEnd = now.add(_nextMonthWindow);

    var nextMonthCount = 0;
    var newUpdatesCount = 0;
    var newEventsCount = 0;

    for (final event in events) {
      final id = event['id']?.toString() ?? '';

      final startDate = DateTime.tryParse(event['startDate']?.toString() ?? '')?.toLocal();
      if (startDate != null && startDate.isAfter(now) && startDate.isBefore(nextMonthEnd)) {
        nextMonthCount++;
      }

      if (savedEventIds.contains(id)) {
        final lastUpdateAt = DateTime.tryParse(event['lastUpdateAt']?.toString() ?? '');
        if (lastUpdateAt != null) {
          final viewed = viewedAt[id];
          if (viewed == null || lastUpdateAt.isAfter(viewed)) {
            newUpdatesCount++;
          }
        }
      }

      final createdAt = DateTime.tryParse(event['createdAt']?.toString() ?? '');
      if (createdAt != null &&
          now.difference(createdAt) < _newEventsWindow &&
          !viewedAt.containsKey(id)) {
        newEventsCount++;
      }
    }

    return EventsDashboardStats(
      nextMonthCount: nextMonthCount,
      newUpdatesCount: newUpdatesCount,
      newEventsCount: newEventsCount,
    );
  }
}

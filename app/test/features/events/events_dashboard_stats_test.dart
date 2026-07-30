import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/features/events/presentation/events_dashboard_stats.dart';

void main() {
  group('EventsDashboardStats.fromEvents', () {
    test('counts events starting within the next 30 days', () {
      final now = DateTime.now();
      final withinWindow =
          now.add(const Duration(days: 10)).toUtc().toIso8601String();
      final justBeyondWindow =
          now.add(const Duration(days: 31)).toUtc().toIso8601String();
      final beyondWindow =
          now.add(const Duration(days: 40)).toUtc().toIso8601String();
      final inThePast =
          now.subtract(const Duration(days: 1)).toUtc().toIso8601String();

      final stats = EventsDashboardStats.fromEvents([
        {'startDate': withinWindow},
        {'startDate': withinWindow},
        {'startDate': justBeyondWindow},
        {'startDate': beyondWindow},
        {'startDate': inThePast},
      ], {}, {});

      expect(stats.nextMonthCount, 2);
      expect(stats.nextMonthEvents.length, 2);
    });

    test('newUpdatesCount only counts saved events with an unseen update', () {
      final now = DateTime.now();
      final updateAfterViewed =
          now.subtract(const Duration(hours: 1)).toUtc().toIso8601String();
      final updateBeforeViewed =
          now.subtract(const Duration(days: 5)).toUtc().toIso8601String();
      final viewedAt = now.subtract(const Duration(days: 2));

      final stats = EventsDashboardStats.fromEvents([
        {
          'id': 1,
          'lastUpdateAt': updateAfterViewed
        }, // saved, nie gesehen -> zaehlt
        {
          'id': 2,
          'lastUpdateAt': updateAfterViewed
        }, // saved, update nach dem Ansehen -> zaehlt
        {
          'id': 3,
          'lastUpdateAt': updateBeforeViewed
        }, // saved, update vor dem Ansehen -> zaehlt nicht
        {
          'id': 4,
          'lastUpdateAt': updateAfterViewed
        }, // nicht gemerkt -> zaehlt nicht
      ], {
        '1',
        '2',
        '3'
      }, {
        '2': viewedAt,
        '3': viewedAt
      });

      expect(stats.newUpdatesCount, 2);
    });

    test('newEventsCount only counts recently created, never-viewed events',
        () {
      final now = DateTime.now();
      final recent =
          now.subtract(const Duration(days: 1)).toUtc().toIso8601String();
      final old =
          now.subtract(const Duration(days: 40)).toUtc().toIso8601String();

      final stats = EventsDashboardStats.fromEvents([
        {'id': 1, 'createdAt': recent}, // neu, ungesehen -> zaehlt
        {
          'id': 2,
          'createdAt': recent
        }, // neu, aber bereits gesehen -> zaehlt nicht
        {'id': 3, 'createdAt': old}, // ungesehen, aber zu alt -> zaehlt nicht
      ], {}, {
        '2': now
      });

      expect(stats.newEventsCount, 1);
    });

    test('handles missing or unparsable date fields gracefully', () {
      final stats = EventsDashboardStats.fromEvents([
        <String, dynamic>{},
        {
          'startDate': 'not-a-date',
          'createdAt': 'also-not-a-date',
          'lastUpdateAt': 'nope'
        },
      ], {
        '1'
      }, {});

      expect(stats.nextMonthCount, 0);
      expect(stats.newUpdatesCount, 0);
      expect(stats.newEventsCount, 0);
    });
  });
}

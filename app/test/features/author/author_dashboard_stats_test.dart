import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/features/author/presentation/author_dashboard_stats.dart';

void main() {
  group('AuthorDashboardStats.fromEvents', () {
    test('counts all own events as online', () {
      final stats = AuthorDashboardStats.fromEvents([
        <String, dynamic>{},
        <String, dynamic>{},
        <String, dynamic>{},
      ]);
      expect(stats.onlineCount, 3);
    });

    test('counts events happening in the current calendar month', () {
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 10).toUtc().toIso8601String();
      final lastMonth = DateTime(now.year, now.month - 1, 10).toUtc().toIso8601String();

      final stats = AuthorDashboardStats.fromEvents([
        {'startDate': thisMonth},
        {'startDate': lastMonth},
      ]);

      expect(stats.thisMonthCount, 1);
    });

    test('flags a future event as stale when lastUpdateAt is older than 30 days', () {
      final future = DateTime.now().add(const Duration(days: 10)).toUtc().toIso8601String();
      final staleUpdate = DateTime.now().subtract(const Duration(days: 40)).toUtc().toIso8601String();

      final stats = AuthorDashboardStats.fromEvents([
        {'startDate': future, 'lastUpdateAt': staleUpdate, 'title': 'Stale Event'},
      ]);

      expect(stats.staleCount, 1);
      expect(stats.staleEvents.single['title'], 'Stale Event');
    });

    test('does not flag a future event with a recent update as stale', () {
      final future = DateTime.now().add(const Duration(days: 10)).toUtc().toIso8601String();
      final recentUpdate = DateTime.now().subtract(const Duration(days: 5)).toUtc().toIso8601String();

      final stats = AuthorDashboardStats.fromEvents([
        {'startDate': future, 'lastUpdateAt': recentUpdate},
      ]);

      expect(stats.staleCount, 0);
    });

    test('does not flag a past event as stale even without recent updates', () {
      final past = DateTime.now().subtract(const Duration(days: 10)).toUtc().toIso8601String();
      final staleUpdate = DateTime.now().subtract(const Duration(days: 90)).toUtc().toIso8601String();

      final stats = AuthorDashboardStats.fromEvents([
        {'startDate': past, 'lastUpdateAt': staleUpdate},
      ]);

      expect(stats.staleCount, 0);
    });

    test('falls back to createdAt when lastUpdateAt is absent', () {
      final future = DateTime.now().add(const Duration(days: 10)).toUtc().toIso8601String();
      final staleCreatedAt = DateTime.now().subtract(const Duration(days: 45)).toUtc().toIso8601String();

      final stats = AuthorDashboardStats.fromEvents([
        {'startDate': future, 'createdAt': staleCreatedAt},
      ]);

      expect(stats.staleCount, 1);
    });
  });
}

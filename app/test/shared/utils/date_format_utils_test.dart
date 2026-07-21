import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dpsg_news_app/shared/utils/date_format_utils.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  group('formatEventDateTime', () {
    test('returns placeholder for null', () {
      expect(formatEventDateTime(null), 'Nicht gesetzt');
    });

    test('returns raw value for unparsable string', () {
      expect(formatEventDateTime('not-a-date'), 'not-a-date');
    });

    test('does not include seconds', () {
      final result = formatEventDateTime('2026-07-16T14:30:45Z');
      expect(result, isNot(contains(':45')));
    });

    test('includes year only when different from current year', () {
      final nextYear = DateTime.now().year + 1;
      final result = formatEventDateTime('$nextYear-07-16T14:30:00Z');
      expect(result, contains('$nextYear'));
    });
  });

  group('formatRelativeTime', () {
    test('returns placeholder for null', () {
      expect(formatRelativeTime(null), 'Nicht gesetzt');
    });

    test('returns "gerade eben" for very recent timestamps', () {
      final now = DateTime.now().toUtc().toIso8601String();
      expect(formatRelativeTime(now), 'gerade eben');
    });

    test('returns minutes for recent timestamps', () {
      final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10)).toUtc().toIso8601String();
      expect(formatRelativeTime(tenMinutesAgo), 'vor 10 Min.');
    });

    test('returns hours for timestamps within a day', () {
      final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String();
      expect(formatRelativeTime(threeHoursAgo), 'vor 3 Std.');
    });

    test('returns days for timestamps within a week', () {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2)).toUtc().toIso8601String();
      expect(formatRelativeTime(twoDaysAgo), 'vor 2 Tagen');
    });

    test('singular day form', () {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String();
      expect(formatRelativeTime(oneDayAgo), 'vor 1 Tag');
    });

    test('falls back to formatEventDateTime beyond a week', () {
      final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
      final result = formatRelativeTime(eightDaysAgo.toUtc().toIso8601String());
      expect(result, formatEventDateTime(eightDaysAgo.toUtc().toIso8601String()));
    });
  });

  group('formatMonthAbbreviation', () {
    test('returns German month abbreviation', () {
      expect(formatMonthAbbreviation(DateTime(2026, 8, 16)), 'Aug');
    });

    test('handles the local timezone conversion', () {
      expect(formatMonthAbbreviation(DateTime(2026, 1, 16)), 'Jan');
    });
  });

  group('formatMonthYearHeader', () {
    test('returns full German month name and year', () {
      expect(formatMonthYearHeader(DateTime(2026, 8, 16)), 'August 2026');
    });
  });
}

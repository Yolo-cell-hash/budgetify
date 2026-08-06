import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/services/background_service.dart';

void main() {
  group('weekend nudge alternation', () {
    test('consecutive Sundays flip between tagging and review', () {
      // 2026-08-09 is a Sunday.
      var sunday = DateTime(2026, 8, 9);
      expect(sunday.weekday, DateTime.sunday);
      var previous = BackgroundService.isTaggingWeek(sunday);
      for (var i = 0; i < 26; i++) {
        sunday = DateTime(sunday.year, sunday.month, sunday.day + 7);
        final current = BackgroundService.isTaggingWeek(sunday);
        expect(current, isNot(previous),
            reason: 'no two consecutive Sundays share a nudge: $sunday');
        previous = current;
      }
    });

    test('every day of one calendar week resolves to the same nudge', () {
      // Monday 2026-08-03 through Sunday 2026-08-09. A run deferred from
      // Sunday morning to Monday night must not switch nudges mid-week.
      final monday = DateTime(2026, 8, 3);
      expect(monday.weekday, DateTime.monday);
      final expected = BackgroundService.isTaggingWeek(monday);
      for (var i = 1; i < 7; i++) {
        final day = DateTime(monday.year, monday.month, monday.day + i);
        expect(BackgroundService.isTaggingWeek(day), expected,
            reason: '$day should stay in the same parity window as $monday');
      }
    });

    test('the week index advances by exactly one per week, across a year end',
        () {
      // The reason this isn't the ISO week number: that resets each January
      // and would repeat or skip a nudge at the boundary.
      var sunday = DateTime(2026, 12, 6);
      expect(sunday.weekday, DateTime.sunday);
      var previous = BackgroundService.weekIndexFor(sunday);
      for (var i = 0; i < 10; i++) {
        sunday = DateTime(sunday.year, sunday.month, sunday.day + 7);
        final current = BackgroundService.weekIndexFor(sunday);
        expect(current - previous, 1, reason: 'at $sunday');
        previous = current;
      }
    });

    test('both nudges come up over any four-week stretch', () {
      var sunday = DateTime(2026, 8, 9);
      final seen = <bool>{};
      for (var i = 0; i < 4; i++) {
        seen.add(BackgroundService.isTaggingWeek(sunday));
        sunday = DateTime(sunday.year, sunday.month, sunday.day + 7);
      }
      expect(seen, {true, false});
    });
  });

  group('review nudge floor', () {
    test('stays silent on an empty queue', () {
      expect(
        BackgroundService.reviewNudgeClears(count: 0, unconfirmedSpend: 0),
        isFalse,
      );
      // Nothing flagged, so an amount alone can't fire it.
      expect(
        BackgroundService.reviewNudgeClears(count: 0, unconfirmedSpend: 99999),
        isFalse,
      );
    });

    test('stays silent for one or two small uncertainties', () {
      expect(
        BackgroundService.reviewNudgeClears(count: 1, unconfirmedSpend: 40),
        isFalse,
      );
      expect(
        BackgroundService.reviewNudgeClears(count: 2, unconfirmedSpend: 150),
        isFalse,
      );
    });

    test('fires on a handful of entries even when they are small', () {
      expect(
        BackgroundService.reviewNudgeClears(count: 3, unconfirmedSpend: 120),
        isTrue,
      );
    });

    // The case the whole feature came from: a single phantom worth real money.
    test('fires on one flagged entry carrying real money', () {
      expect(
        BackgroundService.reviewNudgeClears(count: 1, unconfirmedSpend: 10000),
        isTrue,
      );
    });

    test('a flagged credit-only backlog still fires on count', () {
      // unconfirmedSpend covers debits only, so a queue full of uncertain
      // credits reports zero spend — the count is what must carry it.
      expect(
        BackgroundService.reviewNudgeClears(count: 4, unconfirmedSpend: 0),
        isTrue,
      );
    });
  });
}

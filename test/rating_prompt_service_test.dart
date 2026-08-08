import 'package:budget_tracker/services/rating_prompt_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The platform call can't be exercised in a unit test — and can't be
/// exercised on a sideloaded build either, since Play only shows the card for
/// installs it made. So the decision is deliberately pure, and this is where
/// the four-week rule is actually pinned down.
void main() {
  final install = DateTime(2026, 1, 1, 9, 30);

  bool ask({
    DateTime? now,
    DateTime? firstLaunch = _unset,
    DateTime? lastAsked,
    int askCount = 0,
    int transactionCount = 50,
  }) =>
      RatingPromptService.shouldAsk(
        now: now ?? install.add(const Duration(days: 28)),
        firstLaunch: identical(firstLaunch, _unset) ? install : firstLaunch,
        lastAsked: lastAsked,
        askCount: askCount,
        transactionCount: transactionCount,
      );

  group('four-week window', () {
    test('does not ask a day early', () {
      expect(ask(now: install.add(const Duration(days: 27, hours: 23))), isFalse);
    });

    test('asks once four weeks have elapsed', () {
      expect(ask(now: install.add(const Duration(days: 28))), isTrue);
    });

    test('still asks long afterwards', () {
      expect(ask(now: install.add(const Duration(days: 400))), isTrue);
    });

    test('waitAfterInstall is four weeks', () {
      expect(RatingPromptService.waitAfterInstall, const Duration(days: 28));
    });
  });

  group('anchor', () {
    test('stays silent with no anchor yet', () {
      expect(ask(firstLaunch: null), isFalse);
    });

    test('a clock moved back reads as not-yet, never as overdue', () {
      // now < firstLaunch gives a negative difference; it must not compare as
      // "past the window".
      expect(ask(now: install.subtract(const Duration(days: 10))), isFalse);
    });

    test('counts from install across a DST boundary', () {
      // Instants, not local midnights, so the 23-hour day that breaks
      // difference().inDays elsewhere in this codebase cannot shift the gate.
      final beforeDst = DateTime(2026, 3, 15, 12);
      expect(
        ask(firstLaunch: beforeDst, now: beforeDst.add(const Duration(days: 28))),
        isTrue,
      );
      expect(
        ask(
          firstLaunch: beforeDst,
          now: beforeDst.add(const Duration(days: 27, hours: 23))),
        isFalse,
      );
    });
  });

  group('engagement floor', () {
    test('does not ask a user with almost nothing logged', () {
      expect(ask(transactionCount: RatingPromptService.minTransactions - 1),
          isFalse);
    });

    test('asks at the floor', () {
      expect(
          ask(transactionCount: RatingPromptService.minTransactions), isTrue);
    });
  });

  group('not nagging', () {
    test('waits out the retry gap after asking', () {
      final now = install.add(const Duration(days: 100));
      expect(
        ask(now: now, askCount: 1, lastAsked: now.subtract(const Duration(days: 59))),
        isFalse,
      );
    });

    test('may ask again once the gap has passed', () {
      final now = install.add(const Duration(days: 100));
      expect(
        ask(now: now, askCount: 1, lastAsked: now.subtract(const Duration(days: 61))),
        isTrue,
      );
    });

    test('stops for good after maxAsks', () {
      final now = install.add(const Duration(days: 900));
      expect(
        ask(
          now: now,
          askCount: RatingPromptService.maxAsks,
          lastAsked: now.subtract(const Duration(days: 365)),
        ),
        isFalse,
      );
    });

    test('three attempts spread over more than a year', () {
      // maxAsks x retryAfter is the worst case a user can experience; keep it
      // obviously infrequent so nobody has to do the arithmetic in review.
      final span = RatingPromptService.retryAfter *
          (RatingPromptService.maxAsks - 1);
      expect(span.inDays, greaterThanOrEqualTo(120));
    });
  });
}

/// Sentinel so a test can pass an explicit `null` firstLaunch and still get the
/// default when it says nothing.
const DateTime _unset = _UnsetDate();

class _UnsetDate implements DateTime {
  const _UnsetDate();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

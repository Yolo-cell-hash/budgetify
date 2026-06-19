import 'dart:math' as math;

/// Pure statistics and decision rules behind the on-device "money coach".
///
/// This class holds **no state, no I/O and no Flutter** — just numbers in,
/// booleans/numbers out — so every guard rail against false alarms can be
/// unit-tested in isolation (see `test/coach_service_test.dart`). The nudge
/// *text* and database queries live in [InsightsService]; only the maths lives
/// here.
///
/// Why so much guarding? A budgeting app that cries wolf gets its
/// notifications muted and then gets uninstalled. Every threshold below exists
/// to keep the coach quiet unless it has something genuinely worth saying:
///
///  1. **Robust statistics.** Spend is heavily right-skewed and a single big
///     purchase wrecks the mean and standard deviation. We use the *median*
///     and the *median absolute deviation* (MAD), which a lone outlier cannot
///     drag around.
///  2. **Dual thresholds.** A nudge needs BOTH a meaningful *percentage* change
///     and a meaningful *rupee* change, so "₹20 → ₹80 (+300%)" never fires.
///  3. **Minimum history.** Detectors stay silent until there is enough data
///     to be confident (≥ [minBaselineMonths] comparable months, ≥
///     [minOutlierSamples] samples for an outlier).
///  4. **Absolute floors.** Small categories and small amounts are ignored
///     outright ([catFloor], [outlierFloor]).
///
/// Day-aligned comparison (comparing days 1..d of this month against days 1..d
/// of prior months) is handled by the caller; this class only decides, given a
/// baseline and a current value, whether the movement is worth surfacing.
class CoachStats {
  CoachStats._();

  // ── History / baseline ──────────────────────────────────────────────
  /// How many prior months to use when building a personal baseline.
  static const int historyMonths = 3;

  /// Minimum number of comparable prior months before any baseline is trusted.
  /// Two is the floor: with one month we cannot tell signal from a fluke.
  static const int minBaselineMonths = 2;

  // ── Category-spike detector (rupee values are ₹) ─────────────────────
  /// Categories whose baseline spend is below this are ignored — a swing in a
  /// ₹300 category is noise, not a story.
  static const double catFloor = 1000;

  /// A category must be at least this multiple of its baseline to flag "up".
  static const double spikeRatio = 1.40; // +40%

  /// …and at most this multiple of its baseline to praise "down".
  static const double dropRatio = 0.60; // −40%

  /// …and the rupee change must clear this floor in either direction, so a
  /// small-but-large-% wobble can't trigger an alert.
  static const double spikeAbsFloor = 750;

  // ── Large-transaction outlier detector ───────────────────────────────
  /// Need at least this many historical transactions in a category before its
  /// median/MAD are stable enough to call something an outlier.
  static const int minOutlierSamples = 8;

  /// How many robust-sigma above the median a transaction must sit.
  static const double madK = 4.0;

  /// Absolute rupee floor — never flag a "large" transaction below this.
  static const double outlierFloor = 2000;

  /// …and it must be at least this multiple of the median. This also rescues
  /// the degenerate case where every historical amount is identical (MAD = 0,
  /// e.g. a fixed ₹199 subscription): without a ratio guard a ₹200 charge
  /// would "spike".
  static const double outlierRatio = 2.5;

  /// Consistency constant converting MAD to an estimate of the standard
  /// deviation for roughly-normal data. (For a normal distribution,
  /// σ ≈ 1.4826 × MAD.)
  static const double madScale = 1.4826;

  // ── Pace detector ────────────────────────────────────────────────────
  /// Before this day of the month a month-end projection is too noisy to act
  /// on (a single early purchase dominates the run-rate), so the pace nudge
  /// stays silent.
  static const int paceMinDay = 7;

  /// Projected month total must exceed the typical month by this ratio…
  static const double paceOverRatio = 1.15;

  /// …or fall short of it by this ratio…
  static const double paceUnderRatio = 0.90;

  /// …and the rupee gap must clear this floor either way.
  static const double paceFloor = 1500;

  // ── Robust estimators ────────────────────────────────────────────────

  /// Median of [xs] (0 for an empty list). Does not mutate the input.
  static double median(List<double> xs) {
    if (xs.isEmpty) return 0;
    final s = [...xs]..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }

  /// Median absolute deviation: median(|xᵢ − [med]|). A robust measure of
  /// spread that, unlike the standard deviation, is unmoved by a few extreme
  /// values.
  static double mad(List<double> xs, double med) {
    if (xs.isEmpty) return 0;
    return median(xs.map((x) => (x - med).abs()).toList());
  }

  // ── Decision rules (the false-alarm guards live here) ────────────────

  /// Whether [current] is a genuine *upward* spike against [baseline]:
  /// baseline is material, the rise clears the ratio, and the rupee change is
  /// meaningful.
  static bool spikeUp({required double current, required double baseline}) =>
      baseline >= catFloor &&
      current >= baseline * spikeRatio &&
      (current - baseline) >= spikeAbsFloor;

  /// Whether [current] is a genuine *downward* move against [baseline] (the
  /// encouraging case). Mirrors [spikeUp].
  static bool spikeDown({required double current, required double baseline}) =>
      baseline >= catFloor &&
      current <= baseline * dropRatio &&
      (baseline - current) >= spikeAbsFloor;

  /// Whether [amount] is a robust outlier against a category's [history].
  /// Returns false unless every guard passes: enough samples, a positive
  /// median, the absolute floor, the ratio floor, and (when MAD > 0) the
  /// robust-sigma test. When MAD = 0 the ratio + floor guards carry the
  /// decision.
  static bool isLargeOutlier({
    required double amount,
    required List<double> history,
  }) {
    if (history.length < minOutlierSamples) return false;
    final med = median(history);
    if (med <= 0) return false;
    if (amount < outlierFloor) return false;
    if (amount < med * outlierRatio) return false;
    final sigma = madScale * mad(history, med);
    if (sigma > 0 && amount < med + madK * sigma) return false;
    return true;
  }

  /// Whether the [projected] month total is meaningfully *above* the
  /// [typical] month (both ratio and rupee gap).
  static bool pacesOver({required double projected, required double typical}) =>
      typical > 0 &&
      projected >= typical * paceOverRatio &&
      (projected - typical) >= paceFloor;

  /// Whether the [projected] month total is meaningfully *below* the
  /// [typical] month.
  static bool pacesUnder({required double projected, required double typical}) =>
      typical > 0 &&
      projected <= typical * paceUnderRatio &&
      (typical - projected) >= paceFloor;

  /// Clamp a day-of-month [d] to the last valid day of a month that has
  /// [lastDayOfMonth] days, so a "by day 31" window still works in February.
  static int alignDay(int d, int lastDayOfMonth) => math.min(d, lastDayOfMonth);
}

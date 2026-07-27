/// When Budgetify Plus goes on offer, and for how long.
///
/// The prices in [PlusPlan] are the REAL, everyday prices — they are what a
/// user pays on any ordinary day of the year. An offer is a genuine, time-boxed
/// discount off that price, which is what makes showing the base price struck
/// through honest rather than a fabricated "was" price.
///
/// Two things open an offer:
///   * the **welcome week** — the seven days right after a user's free window
///     ends (owned by EntitlementService, since it needs the trial anchor), and
///   * a **festive window** — the Indian festival seasons below.
///
/// Together these run ~40 days a year, so the base price is what applies for
/// roughly 89% of the calendar. If that ratio ever inverts, the base price
/// stops being the real price and the strikethrough stops being true.
///
/// IMPORTANT — these windows are a DISPLAY layer. Once Play Billing is wired,
/// Google charges whatever the Play Console has configured, so every window
/// here MUST mirror a real Play offer (an introductory/promotional offer on the
/// subscription base plans, a sale price on the lifetime product). If the two
/// ever disagree, the app would advertise a discount Play doesn't honour.
/// [BillingGateway.queryPrices] exists so the displayed price can come from
/// Play itself rather than from these constants.
library;

/// How far either side of a festival's anchor date the offer runs.
///
/// Lunar festival dates shift year to year and vary by a day or two between
/// almanacs and regions. We deliberately do not chase that precision — a
/// window this wide contains the festival however the panchang lands, so the
/// anchors below only ever need to be approximately right.
const int kFestiveBufferDays = 7;

/// Why an offer is running. Only changes the label the paywall shows; the
/// discount is identical either way.
enum PlusOfferKind {
  /// The one-shot week that follows a user's free window ending.
  welcome,

  /// A seasonal campaign — Diwali, Holi, Christmas through New Year.
  festive,
}

/// A live discount window.
class PlusOffer {
  const PlusOffer({
    required this.id,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
  });

  /// Stable id ('welcome', 'diwali', 'holi', 'newyear'). Used for the Play
  /// offer mapping and for tests — never shown to the user.
  final String id;
  final PlusOfferKind kind;

  /// Inclusive start, local midnight.
  final DateTime startsAt;

  /// Exclusive end, local midnight.
  final DateTime endsAt;

  bool contains(DateTime t) => !t.isBefore(startsAt) && t.isBefore(endsAt);

  /// Whole days remaining, floored at 0. 0 means "ends today".
  int daysLeftFrom(DateTime now) {
    final left = endsAt.difference(now);
    return left.isNegative ? 0 : left.inDays;
  }
}

/// Approximate Diwali (Kartika Amavasya) dates, by year.
///
/// Lunar, so it cannot be derived from a rule — it drifts between mid-October
/// and mid-November. Being a few days out is fine: [kFestiveBufferDays] opens
/// the window well before and closes it well after.
///
/// A year that is absent simply runs no Diwali window — the offer fails CLOSED
/// to the base price, which is the safe direction (the app can never advertise
/// a discount that Play isn't running). Extend before the last year lapses.
const Map<int, (int month, int day)> _diwaliAnchors = {
  2026: (11, 8),
  2027: (10, 29),
  2028: (10, 17),
  2029: (11, 5),
  2030: (10, 26),
};

/// Approximate Holi (Phalguna Purnima) dates, by year. Same rules as
/// [_diwaliAnchors] — approximate is enough, absent means no window.
const Map<int, (int month, int day)> _holiAnchors = {
  2027: (3, 23),
  2028: (3, 11),
  2029: (3, 1),
  2030: (3, 20),
  2031: (3, 9),
};

/// Christmas through New Year's Day — fixed every year, so it needs no table.
/// Dec 24 → Jan 1 inclusive.
PlusOffer _newYearOffer(int year) => PlusOffer(
      id: 'newyear',
      kind: PlusOfferKind.festive,
      startsAt: DateTime(year, 12, 24),
      endsAt: DateTime(year + 1, 1, 2),
    );

PlusOffer _buffered(String id, DateTime anchor) => PlusOffer(
      id: id,
      kind: PlusOfferKind.festive,
      startsAt: anchor.subtract(const Duration(days: kFestiveBufferDays)),
      endsAt: anchor.add(const Duration(days: kFestiveBufferDays + 1)),
    );

/// Every festive window anchored in [year]. The New Year window is anchored in
/// the year it opens, so it can spill into January of the next one.
List<PlusOffer> festiveOffersAnchoredIn(int year) {
  final out = <PlusOffer>[];
  final diwali = _diwaliAnchors[year];
  if (diwali != null) {
    out.add(_buffered('diwali', DateTime(year, diwali.$1, diwali.$2)));
  }
  final holi = _holiAnchors[year];
  if (holi != null) {
    out.add(_buffered('holi', DateTime(year, holi.$1, holi.$2)));
  }
  out.add(_newYearOffer(year));
  return out;
}

/// The festive window covering [now], or null at base price. Checks the
/// previous year too, so a January date still finds the Christmas window that
/// opened in December.
PlusOffer? activeFestiveOffer(DateTime now) {
  for (final year in [now.year - 1, now.year]) {
    for (final offer in festiveOffersAnchoredIn(year)) {
      if (offer.contains(now)) return offer;
    }
  }
  return null;
}

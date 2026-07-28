/// When Budgetify Plus goes on offer, and for how long.
///
/// The prices in [PlusPlan] are the REAL, everyday prices — they are what a
/// user pays on any ordinary day of the year. An offer is a genuine, time-boxed
/// discount off that price, which is what makes showing the base price struck
/// through honest rather than a fabricated "was" price.
///
/// Three things open an offer:
///   * the **welcome week** — the seven days right after a user's free window
///     ends (owned by EntitlementService, since it needs the trial anchor),
///   * a **festive week** — Holi, Eid al-Fitr, Dussehra, Diwali and the week
///     to New Year's Day, seven days each, and
///   * a **national long weekend** — Republic Day and Independence Day, three
///     days each, since a fixed date needs no tolerance for an almanac.
///
/// Together the recurring ones run 41 days a year, so the base price is what
/// applies for roughly 89% of the calendar. If that ratio ever inverts, the
/// base price stops being the real price and the strikethrough stops being
/// true — which is why `plus_offers_test.dart` counts the days and fails on a
/// year that creeps past that budget.
///
/// IMPORTANT — these windows are a DISPLAY layer. Once Play Billing is wired,
/// Google charges whatever the Play Console has configured, so every window
/// here MUST mirror a real Play offer (an introductory/promotional offer on the
/// subscription base plans, a sale price on the lifetime product). If the two
/// ever disagree, the app would advertise a discount Play doesn't honour.
/// [BillingGateway.queryPrices] exists so the displayed price can come from
/// Play itself rather than from these constants.
library;

/// How long a festive offer runs. One week, matching the welcome week — a
/// festival sale that outlasts the festival stops reading as a festival sale.
const Duration kFestiveOfferDuration = Duration(days: 7);

/// How many days BEFORE the anchor date a festive window opens. The remaining
/// [kFestiveOfferDuration] days fall on and after it, so a 7-day window spans
/// anchor−4 … anchor+2 inclusive.
///
/// Weighted towards the run-up because that is when festival shopping actually
/// happens, while still leaving two days on the far side: lunar dates vary by
/// a day or two between almanacs and regions, and the window has to contain
/// the festival however the panchang lands.
const int kFestiveLeadDays = 4;

/// The days-before-anchor of the New Year window, chosen so its seven days run
/// 26 Dec → 1 Jan inclusive: the week between Christmas and New Year's Day.
const int _newYearLeadDays = 6;

/// How long a national-holiday offer runs. Republic Day and Independence Day
/// sit on a fixed Gregorian date that cannot drift, so these windows need no
/// tolerance for an almanac — three days is the eve, the day, and the day
/// after, which is the whole of the long weekend people actually shop in.
const Duration kNationalOfferDuration = Duration(days: 3);

/// One day of run-up for a national holiday, per [kNationalOfferDuration].
const int kNationalLeadDays = 1;

/// Why an offer is running. Only changes the label the paywall shows; the
/// discount is identical either way.
enum PlusOfferKind {
  /// The one-shot week that follows a user's free window ending.
  welcome,

  /// A seasonal campaign — a festival week, or a national long weekend.
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

  /// Stable id ('welcome', 'holi', 'eid', 'dussehra', 'diwali', 'republic',
  /// 'independence', 'newyear'). Used for the Play offer mapping and for
  /// tests — never shown to the user.
  final String id;
  final PlusOfferKind kind;

  /// Inclusive start. Local midnight for a festive window; for the welcome
  /// week, the exact moment the free window closed.
  final DateTime startsAt;

  /// Exclusive end — seven days after [startsAt], or three for a national
  /// holiday.
  final DateTime endsAt;

  bool contains(DateTime t) => !t.isBefore(startsAt) && t.isBefore(endsAt);

  /// Whole days remaining, floored at 0. 0 means "ends today".
  int daysLeftFrom(DateTime now) {
    final left = endsAt.difference(now);
    return left.isNegative ? 0 : left.inDays;
  }
}

/// Diwali (Lakshmi Puja / Kartika Amavasya) dates, by year.
///
/// Lunar, so it cannot be derived from a rule — it drifts between mid-October
/// and mid-November, and a leap month shunts it ~19 days later every third
/// year or so. Hence a table, PRELOADED SIX YEARS DEEP (2026-2032) so the app
/// never needs a network call, an update, or a clever almanac to know when its
/// own sale runs.
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
  2031: (11, 14),
  2032: (11, 2),
};

/// Holi (Rangwali Holi, the day after Phalguna Purnima) dates, by year. Same
/// rules and the same six-year horizon as [_diwaliAnchors]; absent means no
/// window. Holi 2026 is deliberately missing — it fell in March 2026, before
/// this table shipped.
const Map<int, (int month, int day)> _holiAnchors = {
  2027: (3, 22),
  2028: (3, 11),
  2029: (3, 1),
  2030: (3, 20),
  2031: (3, 9),
  2032: (3, 27),
};

/// Dussehra (Vijayadashami) dates, by year. Locked twenty days ahead of
/// Diwali by the same lunar month, so the two windows can never touch.
const Map<int, (int month, int day)> _dussehraAnchors = {
  2026: (10, 20),
  2027: (10, 9),
  2028: (9, 27),
  2029: (10, 16),
  2030: (10, 6),
  2031: (10, 25),
  2032: (10, 14),
};

/// Eid al-Fitr (Ramzan Eid) dates, by year — the day India observes, which is
/// usually one behind the Gulf because it waits on its own moon sighting.
///
/// Purely lunar, with no intercalary month, so it walks ~11 days earlier every
/// Gregorian year: March in 2027, January by 2031. That drift is exactly why
/// the table has to be explicit. The window absorbs the sighting itself, which
/// can move the day by one in either direction.
///
/// Eid al-Fitr 2026 is absent for the same reason as Holi 2026: it fell in
/// March 2026, before any of this shipped. Eid al-Adha (Bakrid) runs no window
/// today — adding one is a table and a line in [festiveOffersAnchoredIn].
const Map<int, (int month, int day)> _eidAlFitrAnchors = {
  2027: (3, 10),
  2028: (2, 28),
  2029: (2, 15),
  2030: (2, 5),
  2031: (1, 26),
  2032: (1, 15),
};

/// The week between Christmas and New Year's Day — fixed every year, so it
/// needs no table. 26 Dec → 1 Jan inclusive.
PlusOffer _newYearOffer(int year) =>
    _window('newyear', DateTime(year + 1, 1, 1), lead: _newYearLeadDays);

/// A window of [runs] positioned [lead] days before [anchor].
PlusOffer _window(
  String id,
  DateTime anchor, {
  int lead = kFestiveLeadDays,
  Duration runs = kFestiveOfferDuration,
}) {
  final startsAt = anchor.subtract(Duration(days: lead));
  return PlusOffer(
    id: id,
    kind: PlusOfferKind.festive,
    startsAt: startsAt,
    endsAt: startsAt.add(runs),
  );
}

/// A three-day window around a fixed-date national holiday.
PlusOffer _nationalWindow(String id, DateTime anchor) => _window(
      id,
      anchor,
      lead: kNationalLeadDays,
      runs: kNationalOfferDuration,
    );

/// Every festive window anchored in [year]. The New Year window is keyed to
/// the year it OPENS in (December), so it spills into January of the next one.
/// Ordered so that a named festival wins the label over a national holiday
/// when the two collide — Eid al-Fitr lands on Republic Day in 2031, and
/// "festive offer" is the truer story of that week. The prices are identical
/// either way, so overlap only ever decides which campaign id is reported.
List<PlusOffer> festiveOffersAnchoredIn(int year) {
  final out = <PlusOffer>[];
  for (final (id, anchors) in <(String, Map<int, (int, int)>)>[
    ('holi', _holiAnchors),
    ('eid', _eidAlFitrAnchors),
    ('dussehra', _dussehraAnchors),
    ('diwali', _diwaliAnchors),
  ]) {
    final anchor = anchors[year];
    if (anchor != null) {
      out.add(_window(id, DateTime(year, anchor.$1, anchor.$2)));
    }
  }
  out.add(_nationalWindow('republic', DateTime(year, 1, 26)));
  out.add(_nationalWindow('independence', DateTime(year, 8, 15)));
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

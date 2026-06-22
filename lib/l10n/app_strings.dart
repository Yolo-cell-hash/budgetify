/// Supported in-app languages. English is the default; Hindi is the first
/// regional language. More can be added by extending [AppStrings].
enum AppLanguage { english, hindi }

extension AppLanguageInfo on AppLanguage {
  /// BCP-47 code used for `MaterialApp.locale`.
  String get code => this == AppLanguage.hindi ? 'hi' : 'en';

  /// The language's own name, for the picker.
  String get nativeName => this == AppLanguage.hindi ? 'हिन्दी' : 'English';

  /// English name, for accessibility / fallback.
  String get englishName => this == AppLanguage.hindi ? 'Hindi' : 'English';
}

/// A lightweight, dependency-free string table. Each member returns the English
/// or Hindi text for the active [lang]. Extend by adding members; a string that
/// isn't translated yet can simply pass the same text for both languages.
///
/// This is intentionally a hand-rolled table (not ARB/gen_l10n) so a partial
/// translation can ship incrementally without a build step — untranslated
/// screens keep showing English until their strings are added here.
class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  String _t(String en, String hi) => lang == AppLanguage.hindi ? hi : en;

  // ── Bottom navigation ──────────────────────────────────────────────────
  String get navHome => _t('Home', 'होम');
  String get navBudgets => _t('Budgets', 'बजट');
  String get navNetWorth => _t('Net Worth', 'नेट वर्थ');
  String get navSettings => _t('Settings', 'सेटिंग्स');

  // ── Settings · Appearance ──────────────────────────────────────────────
  String get appearance => _t('Appearance', 'दिखावट');
  String get theme => _t('Theme', 'थीम');
  String get language => _t('Language', 'भाषा');
  String get streakRewards => _t('Streak Rewards', 'स्ट्रीक रिवॉर्ड');
  String themesUnlocked(int n, int total) => _t(
        '$n of $total themes unlocked',
        '$total में से $n थीम अनलॉक',
      );
  String lockedThemeNudge(int days) => _t(
        'Reach a $days-day streak to unlock this theme',
        'यह थीम अनलॉक करने के लिए $days-दिन की स्ट्रीक बनाएँ',
      );

  // ── Net worth projection ───────────────────────────────────────────────
  String get netWorthProjection => _t('Net worth projection', 'नेट वर्थ का अनुमान');
  String get projectedNetWorth => _t('Projected net worth', 'अनुमानित नेट वर्थ');
  String basedOnSaving(String perMonth) => _t(
        'Based on saving about $perMonth/month',
        'लगभग $perMonth/माह की बचत के आधार पर',
      );
  String get savingsOnly => _t('savings only', 'केवल बचत');
  String get withGrowth => _t('with ~8% yearly growth', 'लगभग 8% वार्षिक वृद्धि के साथ');
  String get assumeReturns => _t('Assume 8% growth', '8% वृद्धि मानें');
  String reachMilestoneIn(String milestone, String duration) => _t(
        "On this path, you'd reach $milestone in about $duration.",
        'इस राह पर, आप लगभग $duration में $milestone तक पहुँच जाएँगे।',
      );
  String get projectionDisclaimer => _t(
        'An estimate from your recent savings — not financial advice.',
        'आपकी हाल की बचत पर आधारित अनुमान — वित्तीय सलाह नहीं।',
      );
  String yearsShort(int y) => _t('${y}y', '$y वर्ष');
  String aboutYears(double years) {
    final rounded = years < 10 ? years.toStringAsFixed(1) : years.round().toString();
    return _t('$rounded years', '$rounded वर्ष');
  }

  // ── You vs Past You ────────────────────────────────────────────────────
  String get youVsPastYou => _t('You vs Past You', 'आप बनाम पुराने आप');
  String get periodMonth => _t('Month', 'महीना');
  String get periodQuarter => _t('Quarter', 'तिमाही');
  String get lastMonth => _t('Last month', 'पिछला महीना');
  String get priorMonth => _t('Prior month', 'उससे पहले');
  String get lastQuarter => _t('Last quarter', 'पिछली तिमाही');
  String get priorQuarter => _t('Prior quarter', 'उससे पहले');
  String get mSpending => _t('Spending', 'खर्च');
  String get mIncome => _t('Income', 'आय');
  String get mSavings => _t('Savings', 'बचत');
  String get mSavingsRate => _t('Savings rate', 'बचत दर');
  String get notEnoughHistory =>
      _t('Not enough history yet — check back after another month.',
          'अभी पर्याप्त इतिहास नहीं — एक और महीने बाद देखें।');
  String savedMoreVerdict(String amount) => _t(
        'You kept $amount more than the period before. Nice work!',
        'आपने पिछली अवधि से $amount अधिक बचाया। बढ़िया!',
      );
  String savedLessVerdict(String amount) => _t(
        'You kept $amount less than the period before.',
        'आपने पिछली अवधि से $amount कम बचाया।',
      );
  String get savedSameVerdict =>
      _t('About the same as the period before.', 'पिछली अवधि के लगभग बराबर।');
}

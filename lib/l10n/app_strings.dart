import 'package:intl/intl.dart';

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

  // ── Date helpers ────────────────────────────────────────────────────────
  // Hindi date data is hand-rolled so it works without initializing intl's
  // locale data. English falls back to DateFormat.
  static const List<String> _hiMonths = [
    'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
    'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर',
  ];
  static const List<String> _hiWeekdays = [
    'सोमवार', 'मंगलवार', 'बुधवार', 'गुरुवार', 'शुक्रवार', 'शनिवार', 'रविवार',
  ];

  static const List<String> _hiMonthsShort = [
    'जन', 'फ़र', 'मार्च', 'अप्रै', 'मई', 'जून',
    'जुल', 'अग', 'सित', 'अक्तू', 'नव', 'दिस',
  ];

  String _enMonth(int m) => DateFormat('MMMM').format(DateTime(2000, m, 1));
  String _hiMonth(int m) => _hiMonths[m - 1];

  /// Full month name for the given month number (1–12).
  String monthName(int m) => _t(_enMonth(m), _hiMonth(m));

  /// Full month name for a date's month.
  String monthOf(DateTime d) => monthName(d.month);

  /// Short month abbreviation (e.g. "Jun" / "जून").
  String monthAbbr(int m) =>
      _t(DateFormat('MMM').format(DateTime(2000, m, 1)), _hiMonthsShort[m - 1]);

  /// "June 2025" / "जून 2025".
  String monthYear(DateTime d) => _t(
        DateFormat('MMMM yyyy').format(d),
        '${_hiMonths[d.month - 1]} ${d.year}',
      );

  /// "Jun 2025" / "जून 2025".
  String monthYearShort(DateTime d) => _t(
        DateFormat('MMM yyyy').format(d),
        '${_hiMonthsShort[d.month - 1]} ${d.year}',
      );

  /// Long date like "Monday, June 23" / "सोमवार, 23 जून".
  String fullDate(DateTime d) => _t(
        DateFormat('EEEE, MMMM d').format(d),
        '${_hiWeekdays[d.weekday - 1]}, ${d.day} ${_hiMonths[d.month - 1]}',
      );

  /// Medium date like "Jun 23, 2025" / "23 जून 2025".
  String mediumDate(DateTime d) => _t(
        DateFormat('MMM d, yyyy').format(d),
        '${d.day} ${_hiMonthsShort[d.month - 1]} ${d.year}',
      );

  /// Short day+month like "Jun 23" / "23 जून".
  String dayMonth(DateTime d) => _t(
        DateFormat('MMM d').format(d),
        '${d.day} ${_hiMonthsShort[d.month - 1]}',
      );

  String get thisMonth => _t('This Month', 'इस महीने');

  // ── Common / shared ─────────────────────────────────────────────────────
  String get commonCancel => _t('Cancel', 'रद्द करें');
  String get commonSave => _t('Save', 'सहेजें');
  String get commonDelete => _t('Delete', 'हटाएँ');
  String get commonEdit => _t('Edit', 'संपादित करें');
  String get commonContinue => _t('Continue', 'जारी रखें');
  String get commonDone => _t('Done', 'हो गया');
  String get commonClose => _t('Close', 'बंद करें');
  String get commonView => _t('View', 'देखें');
  String get commonSeeAll => _t('See All', 'सभी देखें');
  String get commonRetry => _t('Retry', 'फिर से');
  String get commonIncome => _t('Income', 'आय');
  String get commonExpenses => _t('Expenses', 'खर्च');

  // ── Home ────────────────────────────────────────────────────────────────
  String get smsActive => _t('SMS Active', 'SMS चालू');
  String get showHideAmounts =>
      _t('Show/hide amounts', 'राशि दिखाएँ/छिपाएँ');
  String monthExpenses(int month) =>
      _t('${_enMonth(month)} Expenses'.toUpperCase(), '${_hiMonth(month)} का खर्च');
  String get spent => _t('Spent', 'खर्च');
  String monthWrapped(int month) =>
      _t('${_enMonth(month)} Wrapped', '${_hiMonth(month)} रैप्ड');
  String get wrappedSubtitle =>
      _t('Your shareable month in review', 'आपका महीना, साझा करने योग्य');
  String get splits => _t('Splits', 'स्प्लिट्स');
  String get splitsSubtitle => _t(
        'Track shared bills & who owes whom',
        'साझा बिल और किसका कितना बकाया, ट्रैक करें',
      );
  String get transactions => _t('Transactions', 'लेन-देन');
  String get unclassified => _t('Unclassified', 'अवर्गीकृत');
  String get scanSms => _t('Scan SMS', 'SMS स्कैन');
  String get scan => _t('Scan', 'स्कैन');
  String get recentTransactions =>
      _t('Recent Transactions', 'हाल के लेन-देन');
  String get cashTransactions => _t('Cash Transactions', 'नकद लेन-देन');
  String cashConversions(int n) =>
      _t('$n Cash Conversion${n == 1 ? '' : 's'}', '$n नकद रूपांतरण');
  String get investmentAlert => _t('Investment Alert', 'निवेश अलर्ट');
  String investmentsToConfirm(int n) => _t(
        n == 1
            ? 'You have an investment to confirm today'
            : '$n investments to confirm today',
        n == 1
            ? 'आज पुष्टि के लिए एक निवेश है'
            : 'आज पुष्टि के लिए $n निवेश हैं',
      );
  String get exitTitle => _t('Exit Budgetify?', 'Budgetify से बाहर निकलें?');
  String get exitSubtitle => _t(
        'Your data stays safely on your device. See you soon.',
        'आपका डेटा आपके डिवाइस पर सुरक्षित रहता है। फिर मिलेंगे।',
      );
  String get stay => _t('Stay', 'रुकें');
  String get exit => _t('Exit', 'बाहर निकलें');
  String txnCredited(String amount) => _t('Credited: $amount', 'जमा: $amount');
  String txnDebited(String amount) => _t('Debited: $amount', 'निकासी: $amount');
  String get smsReadFailed => _t(
        "Couldn't read messages on this device just now — your data is up to date",
        'अभी इस डिवाइस पर संदेश नहीं पढ़ सके — आपका डेटा अद्यतित है',
      );
  String get noNewTransactions =>
      _t('No new transactions found', 'कोई नया लेन-देन नहीं मिला');
  String foundTransactions(int n) =>
      _t('Found $n transaction${n == 1 ? '' : 's'}', '$n लेन-देन मिले');
  String foundTransactionsFromSms(int n) =>
      _t('Found $n transactions from your SMS', 'आपके SMS से $n लेन-देन मिले');
  String newTransactionsFound(int n) => _t(
        '$n new transaction${n == 1 ? '' : 's'} found',
        '$n नए लेन-देन मिले',
      );

  // ── Settings · section headers ────────────────────────────────────────────
  String get settingsTitle => _t('Settings', 'सेटिंग्स');
  String get autoScanSection => _t('Auto-Scan', 'ऑटो-स्कैन');
  String get securitySection => _t('Security', 'सुरक्षा');
  String get intelligenceSection => _t('Intelligence', 'इंटेलिजेंस');
  String get backupSection => _t('Backup', 'बैकअप');
  String get dataSection => _t('Data', 'डेटा');
  String get exportSection => _t('Export', 'एक्सपोर्ट');
  String get privacySection => _t('Privacy', 'गोपनीयता');
  String get aboutSection => _t('About', 'परिचय');

  // ── Settings · Auto-Scan ──────────────────────────────────────────────────
  String get autoScanTitle =>
      _t('Automatic SMS Scanning', 'स्वचालित SMS स्कैनिंग');
  String get autoScanOnDesc =>
      _t('Transactions are scanned automatically', 'लेन-देन स्वतः स्कैन होते हैं');
  String get autoScanOffDesc => _t(
        'Enable to auto-detect transactions in background',
        'बैकग्राउंड में लेन-देन पहचानने के लिए चालू करें',
      );
  String get scanFrequency => _t('Scan Frequency', 'स्कैन आवृत्ति');
  String get hourly => _t('Hourly', 'हर घंटे');
  String everyHours(int h) => _t('Every ${h}h', 'हर $h घंटे');
  String get lastScan => _t('Last Scan', 'अंतिम स्कैन');
  String get autoScanEnabledToast => _t('Auto-scan enabled', 'ऑटो-स्कैन चालू');
  String get autoScanDisabledToast => _t('Auto-scan disabled', 'ऑटो-स्कैन बंद');

  // ── Settings · Security ───────────────────────────────────────────────────
  String get appLock => _t('App Lock', 'ऐप लॉक');
  String get appLockOnDesc => _t(
        'Unlock with fingerprint, face, or device PIN',
        'फ़िंगरप्रिंट, चेहरे या डिवाइस पिन से अनलॉक करें',
      );
  String get appLockOffDesc => _t(
        'Require authentication to open the app',
        'ऐप खोलने के लिए प्रमाणीकरण आवश्यक करें',
      );
  String get noScreenLock => _t(
        'No screen lock or biometrics set up on this device',
        'इस डिवाइस पर कोई स्क्रीन लॉक या बायोमेट्रिक्स सेट नहीं है',
      );
  String get hideAmounts => _t('Hide Amounts', 'राशि छिपाएँ');
  String get hideAmountsDesc => _t(
        'Blur all figures until you tap to reveal',
        'जब तक आप दिखाने के लिए टैप न करें, सभी आँकड़े धुंधले रहेंगे',
      );

  // ── Settings · Intelligence ───────────────────────────────────────────────
  String get aiPredictionMode => _t('AI Prediction Mode', 'AI पूर्वानुमान मोड');
  String get aiPredictionModeDesc => _t(
        'Show a spending forecast and insights on your dashboard. '
            'Computed entirely on your device — nothing is uploaded.',
        'अपने डैशबोर्ड पर खर्च का पूर्वानुमान और जानकारी देखें। '
            'पूरी गणना आपके डिवाइस पर होती है — कुछ भी अपलोड नहीं होता।',
      );
  String get detailedFinancialHealth =>
      _t('Detailed Financial Health', 'विस्तृत वित्तीय स्वास्थ्य');
  String get detailedFinancialHealthDesc => _t(
        'Show the full Financial Health card with a per-pillar breakdown. '
            'When off, just the score appears on your balance card.',
        'प्रत्येक स्तंभ के विवरण के साथ पूरा वित्तीय स्वास्थ्य कार्ड दिखाएँ। '
            'बंद होने पर, केवल स्कोर आपके बैलेंस कार्ड पर दिखता है।',
      );
  String get gamifiedBudgets => _t('Gamified Budgets', 'गेमिफाइड बजट');
  String get gamifiedBudgetsDesc => _t(
        'Earn achievement badges, titles and a shareable profile from '
            'your spending. Opens a separate Rewards hub from your Home '
            'avatar — everything stays on your device.',
        'अपने खर्च से उपलब्धि बैज, खिताब और साझा करने योग्य प्रोफ़ाइल कमाएँ। '
            'होम अवतार से एक अलग रिवॉर्ड हब खुलता है — सब कुछ आपके डिवाइस पर रहता है।',
      );

  // ── Settings · Backup / Data / Export / Privacy / About ───────────────────
  String get createBackup =>
      _t('Create Encrypted Backup', 'एन्क्रिप्टेड बैकअप बनाएँ');
  String get createBackupDesc => _t(
        'All transactions, budgets, rules & tags (AES-256)',
        'सभी लेन-देन, बजट, नियम और टैग (AES-256)',
      );
  String get restoreBackup =>
      _t('Restore from Backup', 'बैकअप से पुनर्स्थापित करें');
  String get restoreBackupDesc => _t(
        'Merge a backup file into this device',
        'बैकअप फ़ाइल को इस डिवाइस में मर्ज करें',
      );
  String get manageTags => _t('Manage Tags', 'टैग प्रबंधित करें');
  String get manageTagsDesc =>
      _t("Delete tags you don't use", 'जो टैग आप उपयोग नहीं करते उन्हें हटाएँ');
  String get exportData => _t('Export Data', 'डेटा एक्सपोर्ट करें');
  String get exportDataDesc => _t(
        'Excel, CSV, or text — filter by date, type, tag or payee',
        'Excel, CSV या टेक्स्ट — तिथि, प्रकार, टैग या प्राप्तकर्ता से फ़िल्टर करें',
      );
  String get dataPrivateTitle => _t('Your Data is Private', 'आपका डेटा निजी है');
  String get dataPrivateDesc => _t(
        'All data stays on your device. We do not collect or upload any information.',
        'सारा डेटा आपके डिवाइस पर रहता है। हम कोई जानकारी एकत्र या अपलोड नहीं करते।',
      );
  String versionLabel(String v) => _t('Version $v', 'संस्करण $v');

  // ── Settings · Backup / restore / export flow ─────────────────────────────
  String get setBackupPassphrase =>
      _t('Set Backup Passphrase', 'बैकअप पासफ़्रेज़ सेट करें');
  String get enterPassphrase => _t('Enter Passphrase', 'पासफ़्रेज़ दर्ज करें');
  String get setPassphraseDesc => _t(
        'Your backup is encrypted with this passphrase. Without it the '
            'backup cannot be restored — there is no recovery.',
        'आपका बैकअप इस पासफ़्रेज़ से एन्क्रिप्ट होता है। इसके बिना बैकअप '
            'पुनर्स्थापित नहीं किया जा सकता — कोई रिकवरी नहीं है।',
      );
  String get enterPassphraseDesc => _t(
        'Enter the passphrase this backup was created with.',
        'वह पासफ़्रेज़ दर्ज करें जिससे यह बैकअप बनाया गया था।',
      );
  String get passphrase => _t('Passphrase', 'पासफ़्रेज़');
  String get atLeast6Chars => _t('At least 6 characters', 'कम से कम 6 अक्षर');
  String get confirmPassphrase =>
      _t('Confirm passphrase', 'पासफ़्रेज़ की पुष्टि करें');
  String get passphrasesDontMatch =>
      _t("Passphrases don't match", 'पासफ़्रेज़ मेल नहीं खाते');
  String get encryptingBackup =>
      _t('Encrypting backup…', 'बैकअप एन्क्रिप्ट हो रहा है…');
  String get encryptedBackupSaved =>
      _t('Encrypted backup saved', 'एन्क्रिप्टेड बैकअप सहेजा गया');
  String get open => _t('Open', 'खोलें');
  String backupFailed(String e) => _t('Backup failed: $e', 'बैकअप विफल: $e');
  String get decryptingRestoring =>
      _t('Decrypting and restoring…', 'डिक्रिप्ट और पुनर्स्थापित हो रहा है…');
  String get backupRestoredNothing => _t(
        'Backup restored — everything was already on this device',
        'बैकअप पुनर्स्थापित — सब कुछ पहले से इस डिवाइस पर था',
      );
  String restoredSummary(
    int transactions,
    int budgets,
    int rules,
    int holdings,
    int sips,
  ) =>
      _t(
        'Restored $transactions transactions, $budgets budgets, $rules rules, '
            '$holdings holdings, $sips SIPs',
        'पुनर्स्थापित: $transactions लेन-देन, $budgets बजट, $rules नियम, '
            '$holdings होल्डिंग्स, $sips SIP',
      );
  String restoreFailed(String e) =>
      _t('Restore failed: $e', 'पुनर्स्थापना विफल: $e');
  String get noTxnMatchFilters => _t(
        'No transactions match those filters',
        'उन फ़िल्टर से कोई लेन-देन मेल नहीं खाता',
      );
  String get exporting => _t('Exporting…', 'एक्सपोर्ट हो रहा है…');
  String savedToDownloads(String file) =>
      _t('Saved to Downloads/$file', 'Downloads/$file में सहेजा गया');
  String exportFailed(String e) =>
      _t('Export failed: $e', 'एक्सपोर्ट विफल: $e');
  String get storagePermissionRequired => _t(
        'Storage permission is required to export data',
        'डेटा एक्सपोर्ट करने के लिए स्टोरेज अनुमति आवश्यक है',
      );

  // ── Budgets & Analytics ───────────────────────────────────────────────────
  String get budgetAndAnalytics => _t('Budget & Analytics', 'बजट और विश्लेषण');
  String get tabOverview => _t('Overview', 'अवलोकन');
  String get tabCalendar => _t('Calendar', 'कैलेंडर');
  String get tabCategories => _t('Categories', 'श्रेणियाँ');
  String get tabTrends => _t('Trends', 'रुझान');
  String get setBudget => _t('Set Budget', 'बजट सेट करें');
  String get swipeForOtherMonths =>
      _t('Swipe for other months', 'अन्य महीनों के लिए स्वाइप करें');
  String noActivityIn(String monthYear) =>
      _t('No activity in $monthYear', '$monthYear में कोई गतिविधि नहीं');
  String get whereItWent => _t('Where it went', 'पैसा कहाँ गया');
  String budgetOf(String amount) => _t('of $amount', '$amount में से');
  String amountLeft(String amount) => _t('$amount left', '$amount बचे');
  String amountOver(String amount) => _t('$amount over!', '$amount अधिक!');
  String get topMerchants => _t('Top merchants', 'शीर्ष व्यापारी');
  String get seeAllLower => _t('See all', 'सभी देखें');
  String get dailySpending => _t('Daily Spending', 'दैनिक खर्च');
  String get noDataYet => _t('No data yet', 'अभी कोई डेटा नहीं');
  String get noSpendingThisMonth =>
      _t('No spending data for this month', 'इस महीने का कोई खर्च डेटा नहीं');
  String get noHistoricalData =>
      _t('No historical data available', 'कोई ऐतिहासिक डेटा उपलब्ध नहीं');
  String get monthlySpendingTrend =>
      _t('Monthly Spending Trend', 'मासिक खर्च का रुझान');
  String get nowBadge => _t('NOW', 'अभी');
  String get categoryBudgets => _t('Category Budgets', 'श्रेणी बजट');
  String get add => _t('Add', 'जोड़ें');
  String get categoryBudgetsEmptyDesc => _t(
        'Set a monthly limit for individual categories like Food or Shopping, '
            'and track exactly where the money goes.',
        'भोजन या खरीदारी जैसी अलग-अलग श्रेणियों के लिए मासिक सीमा तय करें, '
            'और देखें कि पैसा कहाँ जाता है।',
      );
  String setBudgetForCategory(String category) =>
      _t('Set a budget for $category?', '$category के लिए बजट सेट करें?');
  String suggestionMostTagged(int count) => _t(
        "It's your most-tagged spend this month ($count transactions). "
            'A monthly limit keeps it in check.',
        'इस महीने इसी पर सबसे ज़्यादा खर्च हुआ ($count लेन-देन)। '
            'मासिक सीमा इसे नियंत्रण में रखती है।',
      );
  String get setBudgetLower => _t('Set budget', 'बजट सेट करें');
  String get notNow => _t('Not now', 'अभी नहीं');
  String budgetSpentOf(String spent, String total) =>
      _t('$spent of $total', '$total में से $spent');
  String get over => _t('over', 'अधिक');
  String get everyCategoryHasBudget => _t(
        'Every category already has a budget',
        'हर श्रेणी का पहले से बजट है',
      );
  String get newCategoryBudget => _t('New category budget', 'नया श्रेणी बजट');
  String get newCategoryBudgetDesc => _t(
        'Set a monthly limit for one category. Alerts fire at 50, 75, 90 and 100%+.',
        'एक श्रेणी के लिए मासिक सीमा तय करें। 50, 75, 90 और 100%+ पर अलर्ट मिलते हैं।',
      );
  String get monthlyAmount => _t('Monthly amount', 'मासिक राशि');
  String get category => _t('Category', 'श्रेणी');
  String categoryBudgetSet(String category) =>
      _t('$category budget set', '$category बजट सेट हुआ');
  String get editBudget => _t('Edit Budget', 'बजट संपादित करें');
  String get budgetDialogDesc => _t(
        'Track spending against a monthly limit. Self-transfers and '
            'investments are excluded automatically.',
        'मासिक सीमा के सापेक्ष खर्च ट्रैक करें। स्वयं-स्थानांतरण और '
            'निवेश स्वतः बाहर रखे जाते हैं।',
      );
  String get name => _t('Name', 'नाम');

  // ── Net Worth ─────────────────────────────────────────────────────────────
  String get addLabel => _t('Add', 'जोड़ें');
  String get netWorthLabel => _t('NET WORTH', 'नेट वर्थ');
  String get assets => _t('Assets', 'संपत्ति');
  String get liabilities => _t('Liabilities', 'देनदारियाँ');
  String get otherAssets => _t('Other assets', 'अन्य संपत्ति');
  String get allocation => _t('Allocation', 'आवंटन');
  String get investments => _t('Investments', 'निवेश');
  String instalmentsProgress(int completed, int total) => _t(
        '$completed of $total instalments',
        '$total में से $completed किस्तें',
      );
  String get statusCompleted => _t('Completed', 'पूर्ण');
  String get statusDue => _t('Due', 'बकाया');
  String nextDue(DateTime d) => _t(
        'Next ${DateFormat('d MMM').format(d)}',
        'अगला ${d.day} ${_hiMonthsShort[d.month - 1]}',
      );
  String get statusLogged => _t('Logged ✓', 'दर्ज ✓');
  String didYouInvestThisMonth(String amountPrefix) => _t(
        'Did you make your ${amountPrefix}investment this month?',
        'क्या आपने इस महीने अपना $amountPrefixनिवेश किया?',
      );
  String get no => _t('No', 'नहीं');
  String get yesIDid => _t('Yes, I did', 'हाँ, किया');
  String get trackYourNetWorth =>
      _t('Track your net worth', 'अपनी नेट वर्थ ट्रैक करें');
  String get netWorthEmptyDesc => _t(
        'Add your FDs, mutual funds, stocks, gold, savings and loans to see '
            "your complete picture. For SIPs & RDs, add a monthly schedule and "
            "we'll prompt you to log each instalment.",
        'अपनी FD, म्यूचुअल फंड, स्टॉक, सोना, बचत और ऋण जोड़ें ताकि आपकी '
            'पूरी तस्वीर दिखे। SIP और RD के लिए मासिक शेड्यूल जोड़ें और हम '
            'आपको हर किस्त दर्ज करने की याद दिलाएँगे।',
      );
  String get addFirstHolding =>
      _t('Add your first holding', 'अपनी पहली होल्डिंग जोड़ें');
  String investedViaSmsNote(String amount) => _t(
        '$amount detected from your Investments-tagged transactions',
        'आपके Investments-टैग किए लेन-देन से $amount पाया गया',
      );
  String get variableAmount => _t('Variable', 'परिवर्तनीय');
  String scheduleMonthly(String amount, int day) => _t(
        '$amount · ${_enOrdinal(day)} monthly',
        '$amount · हर महीने $day तारीख',
      );
  String scheduleRange(String amount, int day, DateTime start, DateTime end) {
    final s = _monthYy(start);
    final e = _monthYy(end);
    return _t(
      '$amount · ${_enOrdinal(day)} · $s – $e',
      '$amount · $day तारीख · $s – $e',
    );
  }
  String _monthYy(DateTime d) => _t(
        DateFormat("MMM ''yy").format(d),
        "${_hiMonthsShort[d.month - 1]} '${(d.year % 100).toString().padLeft(2, '0')}",
      );
  static String _enOrdinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
  String didYouInvestIn(String name) =>
      _t('Did you invest in $name?', 'क्या आपने $name में निवेश किया?');
  String get confirmInstalmentDesc => _t(
        "Confirm this month's instalment and we'll add it to your net worth.",
        'इस महीने की किस्त की पुष्टि करें और हम इसे आपकी नेट वर्थ में जोड़ देंगे।',
      );
  String get amount => _t('Amount', 'राशि');
  String get amountInvested => _t('Amount invested', 'निवेश की गई राशि');
  String get enterValidAmount =>
      _t('Enter a valid amount', 'मान्य राशि दर्ज करें');
  String addedToNetWorth(String amount) =>
      _t('Added $amount to net worth', 'नेट वर्थ में $amount जोड़ा');
  String get markedNotDone =>
      _t('Marked as not done this month', 'इस महीने नहीं किया, चिह्नित किया');
  String get savedToast => _t('Saved', 'सहेजा गया');
  String get addedToast => _t('Added', 'जोड़ा गया');
}

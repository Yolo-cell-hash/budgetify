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

  // ── Categories (DISPLAY names only) ───────────────────────────────────────
  // The stored category value stays the canonical English key (DB rows, color
  // & icon maps, expense-matching all key off it). This maps a key to its
  // Hindi label purely for display. Unknown keys (user custom tags) pass
  // through unchanged — they are the user's own text.
  String categoryName(String key) {
    switch (key) {
      case 'Food & Dining':
        return _t('Food & Dining', 'खान-पान');
      case 'Groceries':
        return _t('Groceries', 'किराना');
      case 'Shopping':
        return _t('Shopping', 'खरीदारी');
      case 'Transportation':
        return _t('Transportation', 'परिवहन');
      case 'Bills & Utilities':
        return _t('Bills & Utilities', 'बिल और यूटिलिटी');
      case 'Entertainment':
        return _t('Entertainment', 'मनोरंजन');
      case 'Health & Medical':
        return _t('Health & Medical', 'स्वास्थ्य और चिकित्सा');
      case 'Travel':
        return _t('Travel', 'यात्रा');
      case 'Education':
        return _t('Education', 'शिक्षा');
      case 'Salary':
        return _t('Salary', 'वेतन');
      case 'Transfer':
        return _t('Transfer', 'ट्रांसफर');
      case 'Self Transfer':
        return _t('Self Transfer', 'स्वयं ट्रांसफर');
      case 'Investments':
        return _t('Investments', 'निवेश');
      case 'Refund':
        return _t('Refund', 'रिफंड');
      case 'Cash':
        return _t('Cash', 'नकद');
      case 'Cash Conversion':
        return _t('Cash Conversion', 'नकद रूपांतरण');
      case 'Other':
        return _t('Other', 'अन्य');
      case 'Uncategorized':
        return _t('Uncategorized', 'अवर्गीकृत');
      default:
        return key;
    }
  }

  /// Display label for a credit/debit transaction type. `isCredit` true → the
  /// "Credit" label. Stored value is the enum index, so this is display-only.
  String txnTypeName(bool isCredit) =>
      isCredit ? _t('Credit', 'क्रेडिट') : _t('Debit', 'डेबिट');

  // ── Transactions ──────────────────────────────────────────────────────────
  String get addTransactionTitle => _t('Add Transaction', 'लेन-देन जोड़ें');
  String get deleteTransactionTitle => _t('Delete Transaction', 'लेन-देन हटाएँ');
  String get deleteTransactionConfirm => _t(
        "This won't return on the next scan. Are you sure?",
        'यह अगली स्कैन में वापस नहीं आएगा। क्या आप निश्चित हैं?',
      );
  String get manualEntry => _t('Manual Entry', 'मैनुअल एंट्री');
  String get manuallyAddedTxn =>
      _t('Manually added transaction', 'हाथ से जोड़ा गया लेन-देन');
  String get expenseWord => _t('Expense', 'खर्च');
  String get enterAmount => _t('Enter amount', 'राशि दर्ज करें');
  String get invalidAmount => _t('Invalid amount', 'अमान्य राशि');
  String get dateLabel => _t('Date', 'तारीख');
  String get notesOptional => _t('Notes (Optional)', 'नोट्स (वैकल्पिक)');
  String get addDescriptionHint =>
      _t('Add a description...', 'विवरण जोड़ें...');
  String saveTxnLabel(bool isExpense) => isExpense
      ? _t('Save Expense', 'खर्च सहेजें')
      : _t('Save Income', 'आय सहेजें');
  // Transactions list · filters & empty states
  String get selectDateOrRange =>
      _t('Select a date or range', 'तारीख या अवधि चुनें');
  String get customRange => _t('Custom', 'कस्टम');
  String get filterType => _t('Type', 'प्रकार');
  String get filterStatus => _t('Status', 'स्थिति');
  String get filterAll => _t('All', 'सभी');
  String get credits => _t('Credits', 'क्रेडिट');
  String get debits => _t('Debits', 'डेबिट');
  String get classified => _t('Classified', 'वर्गीकृत');
  String get searchTxnHint =>
      _t('Search by payee, amount, or date', 'प्राप्तकर्ता, राशि या तारीख से खोजें');
  String get netLabel => _t('Net', 'नेट');
  String get noMatchingTransactions =>
      _t('No matching transactions', 'कोई मेल खाता लेन-देन नहीं');
  String get noTransactionsYet =>
      _t('No transactions yet', 'अभी कोई लेन-देन नहीं');
  String get tryAdjustingFilters =>
      _t('Try adjusting your filters', 'अपने फ़िल्टर बदलकर देखें');
  String get txnsFromSmsAppearHere => _t(
        'Transactions from bank SMS will appear here',
        'बैंक SMS से लेन-देन यहाँ दिखेंगे',
      );
  String get clearFilters => _t('Clear Filters', 'फ़िल्टर साफ़ करें');
  String lastNDays(int n) => _t('Last $n days', 'पिछले $n दिन');
  String get summaryWord => _t('Summary', 'सारांश');
  String get txnDeletedToast => _t(
        "Transaction deleted — it won't return on the next scan",
        'लेन-देन हटाया गया — यह अगली स्कैन में वापस नहीं आएगा',
      );
  String allOfFilter(String hint) => _t('All $hint', 'सभी $hint');

  // ── Transaction detail ────────────────────────────────────────────────────
  String get transactionDetailsTitle =>
      _t('Transaction Details', 'लेन-देन विवरण');
  String get detailsLabel => _t('Details', 'विवरण');
  String get fromLabel => _t('From', 'भेजने वाला');
  String get payeeLabel => _t('Payee', 'प्राप्तकर्ता');
  String get accountLabel => _t('Account', 'खाता');
  String get originalMessage => _t('Original Message', 'मूल संदेश');
  String get notesLabel => _t('Notes', 'नोट्स');
  String get addNotesHint => _t(
      'Add notes about this transaction...', 'इस लेन-देन के बारे में नोट्स जोड़ें...');
  String get removeTag => _t('Remove Tag', 'टैग हटाएँ');
  String get saveClassification => _t('Save Classification', 'वर्गीकरण सहेजें');
  String get newTag => _t('New Tag', 'नया टैग');
  String get tagRemoved => _t('Tag removed', 'टैग हटाया गया');
  String errorSaving(Object e) => _t('Error saving: $e', 'सहेजने में त्रुटि: $e');
  String errorGeneric(Object e) => _t('Error: $e', 'त्रुटि: $e');
  String get applyToSimilarTitle =>
      _t('Apply to Similar Transactions?', 'समान लेन-देन पर लागू करें?');
  String foundTxnsForMerchant(String name) => _t(
        'Found transactions for "$name". How would you like to classify them?',
        '"$name" के लिए लेन-देन मिले। इन्हें कैसे वर्गीकृत करना चाहेंगे?',
      );
  String get applyToAll => _t('Apply to All', 'सभी पर लागू करें');
  String get applyToAllDesc => _t(
        'Classify all existing & auto-flag future transactions',
        'सभी मौजूदा वर्गीकृत करें और भविष्य के लेन-देन स्वतः चिह्नित करें',
      );
  String get applyToExisting =>
      _t('Apply to Existing Only', 'केवल मौजूदा पर लागू करें');
  String get applyToExistingDesc => _t(
        'Classify existing transactions, flag future ones manually',
        'मौजूदा लेन-देन वर्गीकृत करें, भविष्य के लिए मैन्युअल रूप से चिह्नित करें',
      );
  String get onlyThisOne => _t('Only This One', 'केवल यही');
  String get onlyThisOneDesc => _t(
        'Tag only this transaction, handle others manually',
        'केवल इसी लेन-देन को टैग करें, बाकी मैन्युअल रूप से संभालें',
      );
  String get txnSaved => _t('Transaction saved', 'लेन-देन सहेजा गया');
  String get txnSavedNoMerchant => _t(
        'Transaction saved (no merchant to match)',
        'लेन-देन सहेजा गया (मिलान के लिए कोई व्यापारी नहीं)',
      );
  String updatedSimilarTxns(int count, bool isDebit) => _t(
        'Updated $count similar ${isDebit ? 'debits' : 'credits'}',
        '$count समान ${isDebit ? 'डेबिट' : 'क्रेडिट'} अपडेट किए',
      );
  String futureTxnsAutoClassified(bool isDebit, String merchant) => _t(
        ' • Future ${isDebit ? 'debits' : 'credits'} from "$merchant" will be auto-classified',
        ' • "$merchant" से भविष्य के ${isDebit ? 'डेबिट' : 'क्रेडिट'} स्वतः वर्गीकृत होंगे',
      );
  String emojiForTag(String name) =>
      _t('Emoji for "$name"', '"$name" के लिए इमोजी');
  String get createCustomTag => _t('Create Custom Tag', 'कस्टम टैग बनाएँ');
  String get createTagDesc => _t(
      'Choose an emoji and name for your tag', 'अपने टैग के लिए इमोजी और नाम चुनें');
  String get tagNameHint =>
      _t('Tag name (e.g. Rent, Gym)', 'टैग नाम (जैसे किराया, जिम)');
  String get pickAnEmoji => _t('Pick an emoji', 'इमोजी चुनें');
  String get enterTagName =>
      _t('Please enter a tag name', 'कृपया टैग नाम दर्ज करें');
  String get tagExists => _t(
      'A tag with this name already exists', 'इस नाम का टैग पहले से मौजूद है');
  String get createTag => _t('Create Tag', 'टैग बनाएँ');

  // ── Merchants ─────────────────────────────────────────────────────────────
  String get noMerchantSpending => _t(
      'No merchant spending this month', 'इस महीने कोई व्यापारी खर्च नहीं');
  String get topMerchantLabel => _t('Top merchant', 'शीर्ष व्यापारी');
  String pctOfMerchantSpend(int pct) =>
      _t('$pct% of merchant spend', 'व्यापारी खर्च का $pct%');
  String get ofSpending => _t('of spending', 'खर्च का');
  String get ofCategory => _t('of category', 'श्रेणी का');
  String get topBadge => _t('TOP', 'शीर्ष');
  String txnCountCaption(int n) =>
      _t('$n transaction${n == 1 ? '' : 's'}', '$n लेन-देन');
  String get avgPerTxn => _t('Avg / txn', 'औसत / लेन-देन');
  String get largestLabel => _t('Largest', 'सबसे बड़ा');
  String get vsLastMonth => _t('vs last month', 'पिछले महीने से');
  String get noTxnsThisMonth =>
      _t('No transactions this month', 'इस महीने कोई लेन-देन नहीं');

  // ── Splits / Ledger ───────────────────────────────────────────────────────
  String get addToLedger => _t('Add to ledger', 'खाते में जोड़ें');
  String get splitAnExpense => _t('Split an expense', 'खर्च बाँटें');
  String get splitAnExpenseDesc => _t(
        'You paid or split a bill — others owe you their share',
        'आपने भुगतान किया या बिल बाँटा — दूसरों पर आपका हिस्सा बकाया है',
      );
  String get someoneOwesMe => _t('Someone owes me', 'किसी पर मेरा बकाया है');
  String get someoneOwesMeDesc => _t(
        'You paid for or lent them — expect the cash back',
        'आपने उनके लिए भुगतान किया या उधार दिया — पैसे वापस मिलेंगे',
      );
  String get iOweSomeone => _t('I owe someone', 'मुझ पर किसी का बकाया है');
  String get iOweSomeoneDesc => _t(
        'Someone covered you — record what you owe them',
        'किसी ने आपके लिए भुगतान किया — जो आप पर बकाया है दर्ज करें',
      );
  String get peopleLabel => _t('People', 'लोग');
  String get allSettled => _t('ALL SETTLED', 'सब निपट गया');
  String get owedOverall =>
      _t("YOU'RE OWED OVERALL", 'कुल मिलाकर आपका बकाया है');
  String get youOweOverall => _t('YOU OWE OVERALL', 'कुल मिलाकर आप पर बकाया है');
  String get owedToYou => _t('Owed to you', 'आपको मिलना है');
  String get youOwe => _t('You owe', 'आप पर बकाया');
  String get owesYouStatus => _t('owes you', 'का आप पर बकाया');
  String get youOweStatus => _t('you owe', 'आप पर बकाया');
  String get settledUp => _t('settled up', 'निपट गया');
  String get settledFromPayments =>
      _t('Settled from payments', 'भुगतान से निपटा');
  String get noSplitsYet => _t('No splits yet', 'अभी कोई स्प्लिट नहीं');
  String get noSplitsDesc => _t(
        'Split a bill, or record what you owe someone — all on your device. '
            'Tap Add to get started. When you pay for a group, only your share '
            'counts as your spending.',
        'बिल बाँटें, या किसी का आप पर बकाया दर्ज करें — सब आपके डिवाइस पर। '
            'शुरू करने के लिए जोड़ें टैप करें। जब आप समूह के लिए भुगतान करते हैं, '
            'तो केवल आपका हिस्सा आपके खर्च में गिना जाता है।',
      );

  // ── Split editor ──────────────────────────────────────────────────────────
  String get youLabel => _t('You', 'आप');
  String get whoPaid => _t('Who paid?', 'किसने भुगतान किया?');
  String get whoOwesYou => _t('Who owes you?', 'किस पर आपका बकाया है?');
  String get addAPerson => _t('Add a person', 'व्यक्ति जोड़ें');
  String get giveItATitle => _t('Give it a title', 'एक शीर्षक दें');
  String get enterAmountAbove0 =>
      _t('Enter an amount above ₹0', '₹0 से अधिक राशि दर्ज करें');
  String get addOtherPerson =>
      _t('Add the other person involved', 'शामिल दूसरे व्यक्ति को जोड़ें');
  String get pickWhoSplit => _t(
      'Pick who the expense is split between', 'चुनें कि खर्च किन-किन में बँटा है');
  String sharesMustAddUp(String amount) =>
      _t('Shares must add up to $amount', 'हिस्सों का योग $amount होना चाहिए');
  String get whatFor => _t('What for', 'किसलिए');
  String get splitTitleHint => _t(
      'e.g. Dinner at Barbeque Nation', 'जैसे बारबेक्यू नेशन में डिनर');
  String get totalAmount => _t('Total amount', 'कुल राशि');
  String get paidBy => _t('Paid by', 'भुगतानकर्ता');
  String get splitBetween => _t('Split between', 'किनमें बँटा');
  String get recordWhatYouOwe =>
      _t('Record what you owe', 'जो आप पर बकाया है दर्ज करें');
  String get recordWhatYoureOwed =>
      _t("Record what you're owed", 'जो आपको मिलना है दर्ज करें');
  String get editSplit => _t('Edit split', 'स्प्लिट संपादित करें');
  String get newSplit => _t('New split', 'नया स्प्लिट');
  String get equallyLabel => _t('Equally', 'बराबर');
  String get exactLabel => _t('Exact ₹', 'सटीक ₹');
  String get someoneElse => _t('Someone else', 'कोई और');
  String get notInSplit => _t('not in split', 'स्प्लिट में नहीं');
  String get addPersonToSplit =>
      _t('Add person to the split', 'स्प्लिट में व्यक्ति जोड़ें');
  String get resultLabel => _t('Result', 'परिणाम');
  String get fillToSeeResult => _t(
        'Fill in the amount and who paid to see the result.',
        'परिणाम देखने के लिए राशि और भुगतानकर्ता भरें।',
      );
  String get addSplit => _t('Add split', 'स्प्लिट जोड़ें');
  String get linkedTxnFallback => _t('Transaction', 'लेन-देन');
  String linkedToTxn(String label) => _t(
        'Linked to $label — only your share counts as spending',
        '$label से जुड़ा — केवल आपका हिस्सा खर्च में गिना जाता है',
      );
  // Outcome-card sentence fragments (composed around bold name + amount spans;
  // word order differs in Hindi, hence the lead/mid/trail split).
  String get owesYouMid => _t(' owes you ', ' पर आपका ');
  String get owesYouTrail => _t('', ' बकाया है');
  String get youOweLead => _t('You owe ', 'आपको ');
  String get youOweMid => _t(' ', ' को ');
  String get youOweTrail => _t('', ' देना है');

  // ── Person detail / settle up ─────────────────────────────────────────────
  String get shareSummary => _t('Share summary', 'सारांश साझा करें');
  String get activityLabel => _t('Activity', 'गतिविधि');
  String get allSettledUp => _t('ALL SETTLED UP', 'सब निपट गया');
  String personOwesYou(String name) =>
      _t('${name.toUpperCase()} OWES YOU', '$name पर आपका बकाया');
  String youOwePerson(String name) =>
      _t('YOU OWE ${name.toUpperCase()}', 'आप पर $name का बकाया');
  String get settleUp => _t('Settle up', 'निपटाएँ');
  String get shareLabel => _t('Share', 'साझा करें');
  String personPaidMe(String name) =>
      _t('$name paid me', '$name ने मुझे भुगतान किया');
  String iPaidPerson(String name) =>
      _t('I paid $name', 'मैंने $name को भुगतान किया');
  String get recordSettlement => _t('Record settlement', 'निपटान दर्ज करें');

  // ── Savings goals ─────────────────────────────────────────────────────────
  String get savingsGoalsTitle => _t('Savings Goals', 'बचत लक्ष्य');
  String get goalsSubtitle => _t(
      'Set a target and watch the jar fill up', 'लक्ष्य तय करें और जार को भरते देखें');
  String get newGoal => _t('New goal', 'नया लक्ष्य');
  String get setFirstGoal =>
      _t('Set your first savings goal', 'अपना पहला बचत लक्ष्य तय करें');
  String get setFirstGoalDesc => _t(
        'Name a target like "Goa trip ₹40k by December", then chip away at '
            'it. Add to it whenever you set money aside.',
        '"दिसंबर तक गोवा ट्रिप ₹40k" जैसा लक्ष्य रखें, फिर धीरे-धीरे जोड़ें। '
            'जब भी पैसे अलग रखें, इसमें डालें।',
      );
  String get goalReachedTitle => _t('Goal reached! 🎉', 'लक्ष्य पूरा! 🎉');
  String goalReachedMsg(String amount, String name) => _t(
        'You saved $amount for $name. Incredible work!',
        'आपने $name के लिए $amount बचाए। शानदार काम!',
      );
  String get niceExclaim => _t('Nice!', 'बढ़िया!');
  String get deleteGoalTitle => _t('Delete goal?', 'लक्ष्य हटाएँ?');
  String get deleteGoalConfirm => _t(
        "This removes the goal and all its contributions. It can't be undone.",
        'यह लक्ष्य और इसके सभी योगदान हटा देगा। इसे पूर्ववत नहीं किया जा सकता।',
      );
  String get goalLabel => _t('Goal', 'लक्ष्य');
  String get goalComplete => _t('Goal complete', 'लक्ष्य पूरा');
  String get addToGoal => _t('Add to goal', 'लक्ष्य में जोड़ें');
  String get contributionsLabel => _t('Contributions', 'योगदान');
  String get noContributionsYet => _t(
        'No contributions yet — add your first deposit above.',
        'अभी कोई योगदान नहीं — ऊपर अपनी पहली जमा जोड़ें।',
      );
  String get progressLabel => _t('Progress', 'प्रगति');
  String get remainingLabel => _t('Remaining', 'शेष');
  String get deadlineLabel => _t('Deadline', 'समयसीमा');
  String get toStayOnTrack => _t('To stay on track', 'राह पर बने रहने के लिए');
  String perMonthValue(String amount) => _t('$amount/month', '$amount/माह');
  String get statusLabel => _t('Status', 'स्थिति');
  String get completedStatus => _t('Completed 🎉', 'पूर्ण 🎉');
  String get newSavingsGoal => _t('New savings goal', 'नया बचत लक्ष्य');
  String get editGoal => _t('Edit goal', 'लक्ष्य संपादित करें');
  String get goalNameLabel => _t('Goal name', 'लक्ष्य का नाम');
  String get goalNameHint => _t('e.g. Goa trip', 'जैसे गोवा ट्रिप');
  String get targetAmount => _t('Target amount', 'लक्ष्य राशि');
  String get iconLabel => _t('ICON', 'आइकन');
  String get colourLabel => _t('COLOUR', 'रंग');
  String get deadlineOptionalLabel =>
      _t('DEADLINE (OPTIONAL)', 'समयसीमा (वैकल्पिक)');
  String get pickADate => _t('Pick a date', 'तारीख चुनें');
  String get createGoal => _t('Create goal', 'लक्ष्य बनाएँ');
  String completeAmount(String amount) =>
      _t('Complete ($amount)', 'पूरा करें ($amount)');
  String get noteOptional => _t('Note (optional)', 'नोट (वैकल्पिक)');

  // ── Insights / analytics ──────────────────────────────────────────────────
  String get insightsTitle => _t('Insights', 'अंतर्दृष्टि');
  String get spendingTrend => _t('Spending trend', 'खर्च का रुझान');
  String get last6Months => _t('Last 6 months', 'पिछले 6 महीने');
  String get highlights => _t('Highlights', 'मुख्य बातें');
  String get projectedThisMonth =>
      _t('PROJECTED THIS MONTH', 'इस महीने का अनुमान');
  String get notEnoughHistoryYet =>
      _t('Not enough history yet', 'अभी पर्याप्त इतिहास नहीं');
  String get buildingBaselineTrends => _t(
        'Building your baseline. Trends and forecasts sharpen after a few '
            'weeks of activity.',
        'आपका आधार बन रहा है। कुछ हफ़्तों की गतिविधि के बाद रुझान और अनुमान '
            'और साफ़ होंगे।',
      );
  String get buildingBaselineInsights => _t(
        'Building your baseline. Insights and forecasts sharpen after a '
            'few weeks of activity.',
        'आपका आधार बन रहा है। कुछ हफ़्तों की गतिविधि के बाद जानकारी और अनुमान '
            'और साफ़ होंगे।',
      );
  String get safeToSpendPrefix =>
      _t('Safe to spend: ', 'खर्च के लिए सुरक्षित: ');
  String get noSpendingYetInsights => _t(
        'No spending yet this month — insights will appear as you spend.',
        'इस महीने अभी कोई खर्च नहीं — जैसे-जैसे खर्च करेंगे, जानकारी दिखेगी।',
      );
  // Daily analysis
  String get dailyAnalysisTitle => _t('Daily Analysis', 'दैनिक विश्लेषण');
  String get noTransactions => _t('No transactions', 'कोई लेन-देन नहीं');
  String get received => _t('Received', 'प्राप्त');
  String get spendingBreakdown => _t('Spending Breakdown', 'खर्च का विवरण');
  // Category budget insights
  String get categoryBudgetUpper => _t('CATEGORY BUDGET', 'श्रेणी बजट');
  String get whereItGoes => _t('Where it goes', 'पैसा कहाँ जाता है');
  String topMerchantsIn(String cat) =>
      _t('Top merchants in $cat this month', 'इस महीने $cat में शीर्ष व्यापारी');
  String get noSpendingInCategory =>
      _t('No spending in this category yet', 'इस श्रेणी में अभी कोई खर्च नहीं');
  String editCategoryBudget(String cat) =>
      _t('Edit $cat budget', '$cat बजट संपादित करें');
  String get setCategoryLimitDesc => _t(
        'Set the monthly limit for this category. Alerts fire at '
            '50, 75, 90 and 100%+.',
        'इस श्रेणी के लिए मासिक सीमा तय करें। 50, 75, 90 और 100%+ पर अलर्ट मिलते हैं।',
      );
  String get budgetUpdated => _t('Budget updated', 'बजट अपडेट हुआ');
  // Safe to spend
  String get budgetWord => _t('budget', 'बजट');
  String get typicalMonth => _t('typical month', 'सामान्य महीना');
  String get safeToSpend => _t('Safe to spend', 'खर्च के लिए सुरक्षित');
  String get vsBudget => _t('vs budget', 'बजट बनाम');
  String get vsTypical => _t('vs typical', 'सामान्य बनाम');
  String passedTarget(String target, String month, String amount) => _t(
        "You've passed your $target for $month by $amount.",
        'आपने $month के लिए अपना $target $amount से पार कर लिया।',
      );
  String amountLeftDays(String amount, int days) => _t(
        '$amount left · $days day${days == 1 ? '' : 's'} to go',
        '$amount शेष · $days दिन बाकी',
      );
  String overTargetMsg(String target, String month) => _t(
        'Over your $target — go easy for the rest of $month.',
        'आपका $target पार — $month के बाकी दिन संभलकर खर्च करें।',
      );
  String get aheadOfPaceMsg => _t(
        'A little ahead of pace — ease up to stay comfortable.',
        'गति से थोड़ा आगे — सहज रहने के लिए थोड़ा धीमे चलें।',
      );
  String get onTrackMsg => _t(
        'On track. Spending evenly keeps you within plan.',
        'सही राह पर। समान रूप से खर्च आपको योजना में रखता है।',
      );
  // Financial health
  String get financialHealth => _t('Financial Health', 'वित्तीय स्वास्थ्य');
  String get financialHealthUpper =>
      _t('FINANCIAL HEALTH', 'वित्तीय स्वास्थ्य');
  String get howScoreCalculated =>
      _t('How your score is calculated', 'आपका स्कोर कैसे निकाला जाता है');
  String get budgetAdherence => _t('Budget adherence', 'बजट पालन');
  String get recurringLoad => _t('Recurring load', 'आवर्ती भार');
  String get netWorthWord => _t('Net worth', 'नेट वर्थ');
  String get healthEmptyDesc => _t(
        'Add some income, a budget, or holdings and your Financial Health '
            'Score will appear here.',
        'कुछ आय, बजट या होल्डिंग जोड़ें और आपका वित्तीय स्वास्थ्य स्कोर यहाँ दिखेगा।',
      );
  String get howScoreWorks =>
      _t('How your score works', 'आपका स्कोर कैसे काम करता है');
  String get howScoreWorksDesc => _t(
        'A single 0–100 number (100 is healthy, 0 is poor) blended from up '
            'to four pillars. Pillars without data yet are skipped and the rest '
            'reweighted, so the score always reflects what we can see.',
        'एक ही 0–100 अंक (100 स्वस्थ, 0 कमज़ोर) जो चार स्तंभों से बनता है। '
            'जिन स्तंभों का डेटा नहीं, उन्हें छोड़ दिया जाता है और बाकी का भार '
            'पुनः समायोजित होता है, ताकि स्कोर हमेशा उपलब्ध डेटा दर्शाए।',
      );
  String get savingsRateExplain => _t(
        'How much of your income you keep. 20% or more earns full marks.',
        'आप अपनी आय का कितना हिस्सा रखते हैं। 20% या अधिक पर पूरे अंक।',
      );
  String get budgetAdherenceExplain => _t(
        'Staying within the budgets you set. Going over costs points.',
        'अपने तय बजट में रहना। पार करने पर अंक घटते हैं।',
      );
  String get recurringLoadExplain => _t(
        'Recurring commitments (SIPs/RDs) versus income — more headroom scores higher.',
        'आवर्ती प्रतिबद्धताएँ (SIP/RD) बनाम आय — ज़्यादा गुंजाइश पर अधिक अंक।',
      );
  String get netWorthExplain => _t(
        'Your equity — assets versus debts. Counts only if you track holdings.',
        'आपकी इक्विटी — संपत्ति बनाम ऋण। केवल तभी गिना जाता है जब आप होल्डिंग ट्रैक करें।',
      );
  String get computedOnDevice =>
      _t('Everything is computed on your device.', 'सब कुछ आपके डिवाइस पर गणना होता है।');
  String get gotIt => _t('Got it', 'समझ गया');
  // Spending calendar
  List<String> get weekdayInitials => lang == AppLanguage.hindi
      ? const ['सो', 'मं', 'बु', 'गु', 'शु', 'श', 'र']
      : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  String get lessLabel => _t('Less', 'कम');
  String get moreLabel => _t('More', 'ज़्यादा');
  // Expense chart
  String get expenseTrend => _t('Expense Trend', 'खर्च का रुझान');
  String get last7Days => _t('Last 7 Days', 'पिछले 7 दिन');
  String get tapForAnalysis => _t(
      'Tap a day for detailed analysis', 'विस्तृत विश्लेषण के लिए किसी दिन पर टैप करें');
  String get tapForDetails => _t('Tap for details', 'विवरण के लिए टैप करें');
  String get noExpenseData => _t('No expense data yet', 'अभी कोई खर्च डेटा नहीं');
  String get todayLabel => _t('Today', 'आज');
  // Savings summary
  String get savingsRateUpper => _t('SAVINGS RATE', 'बचत दर');
  String get noIncomeThisMonth =>
      _t('No income recorded this month', 'इस महीने कोई आय दर्ज नहीं');
  String get noActivityThisMonth =>
      _t('No activity yet this month', 'इस महीने अभी कोई गतिविधि नहीं');

  // ── Rewards hub / gamification ────────────────────────────────────────────
  String get rewardsTitle => _t('Rewards', 'रिवॉर्ड');
  String get profileTab => _t('Profile', 'प्रोफ़ाइल');
  String get trophiesTab => _t('Trophies', 'ट्रॉफी');
  String get streaksTab => _t('Streaks', 'स्ट्रीक');
  // Wrapped
  String get monthlyWrappedTitle => _t('Monthly Wrapped', 'मासिक रैप्ड');
  String get couldNotShareCard =>
      _t('Could not share the card', 'कार्ड साझा नहीं हो सका');
  String get showActualAmountsTitle =>
      _t('Show actual amounts?', 'वास्तविक राशि दिखाएँ?');
  String get showAmountsDesc => _t(
        "Your Wrapped normally shows only percentages, so it's safe to "
            'share. Revealing amounts displays your real ₹ figures — and any '
            'card you share will include them.',
        'आपका Wrapped आम तौर पर केवल प्रतिशत दिखाता है, इसलिए साझा करना सुरक्षित है। '
            'राशि दिखाने पर आपके असली ₹ आँकड़े दिखेंगे — और जो भी कार्ड आप साझा करेंगे '
            'उसमें वे शामिल होंगे।',
      );
  String get showAmounts => _t('Show amounts', 'राशि दिखाएँ');
  String get showActualAmounts =>
      _t('Show actual amounts', 'वास्तविक राशि दिखाएँ');
  String get notEnoughDataYet => _t('Not enough data yet', 'अभी पर्याप्त डेटा नहीं');
  String get preparing => _t('Preparing…', 'तैयार हो रहा है…');
  String get shareMyWrapped =>
      _t('Share my Wrapped', 'मेरा Wrapped साझा करें');
  String wrappedShareText(String month) => _t(
        'My $month on Budgetify ✨ — private, on-device money tracking.',
        '$month — Budgetify पर ✨ निजी, ऑन-डिवाइस मनी ट्रैकिंग।',
      );
  String wrappedWarmingUp(String month, int minDays, int days) => _t(
        '$month is still warming up. A Wrapped needs at least $minDays days '
            'of activity — there ${days == 1 ? 'is' : 'are'} $days '
            'day${days == 1 ? '' : 's'} so far. Check back later in the month.',
        '$month अभी तैयार हो रहा है। Wrapped के लिए कम से कम $minDays दिन की '
            'गतिविधि चाहिए — अब तक $days दिन हैं। महीने में बाद में देखें।',
      );
  String wrappedNotEnoughData(String month, int minDays) => _t(
        'Not enough data for $month — a Wrapped needs at least $minDays days '
            'of recorded activity in the month.',
        '$month के लिए पर्याप्त डेटा नहीं — Wrapped के लिए महीने में कम से कम '
            '$minDays दिन की दर्ज गतिविधि चाहिए।',
      );
  // Profile
  String get sharingProgress => _t('Sharing…', 'साझा हो रहा है…');
  String get showcase => _t('Showcase', 'शोकेस');
  String get earnBadgesDesc => _t(
        'Earn badges in the Trophies tab to feature them here.',
        'यहाँ दिखाने के लिए Trophies टैब में बैज कमाएँ।',
      );
  String get chooseBadgesToFeature =>
      _t('Choose up to 5 badges to feature', 'दिखाने के लिए 5 बैज तक चुनें');
  String get tapToChangeBadges => _t(
      'Tap to change your featured badges', 'अपने चुने बैज बदलने के लिए टैप करें');
  String get titlesLabel => _t('Titles', 'खिताब');
  String get titlesIntro => _t(
        'Titles reflect where your money goes — each shows your progress. '
            'Tap one for details.',
        'खिताब दर्शाते हैं कि आपका पैसा कहाँ जाता है — हर एक आपकी प्रगति दिखाता है। '
            'विवरण के लिए टैप करें।',
      );
  String get tapTitleDesc => _t(
        'Tap a title for details. Earned titles can be featured on your profile.',
        'विवरण के लिए किसी खिताब पर टैप करें। कमाए खिताब आपकी प्रोफ़ाइल पर दिखाए जा सकते हैं।',
      );
  String get earned => _t('Earned', 'अर्जित');
  String get inProgress => _t('In progress', 'प्रगति में');
  String get removeFromProfile =>
      _t('Remove from profile', 'प्रोफ़ाइल से हटाएँ');
  String get featureOnProfile => _t('Feature on profile', 'प्रोफ़ाइल पर दिखाएँ');
  String get featuredBadges => _t('Featured badges', 'चुने हुए बैज');
  String get couldntCreateShareImage => _t(
      "Couldn't create the share image just now", 'अभी साझा छवि नहीं बना सके');
  String get profileShareText =>
      _t('My Budgetify rewards 🏆', 'मेरे Budgetify रिवॉर्ड 🏆');
  String earnedOn(String date) => _t('Earned $date', '$date को अर्जित');
  // Avatar picker
  String get usernameLabel => _t('Username', 'उपयोगकर्ता नाम');
  String get pickAName => _t('Pick a name', 'एक नाम चुनें');
  String get styleLabel => _t('STYLE', 'शैली');
  String get emojiStyle => _t('Emoji', 'इमोजी');
  String get pixelStyle => _t('Pixel', 'पिक्सेल');
  String get avatarLabel => _t('AVATAR', 'अवतार');
  String get pixelAvatarLabel => _t('PIXEL AVATAR', 'पिक्सेल अवतार');
  String get accentLabel => _t('ACCENT', 'रंग');
  // Badges / achievements
  String tierName(String key) {
    switch (key) {
      case 'Copper':
        return _t('Copper', 'कॉपर');
      case 'Bronze':
        return _t('Bronze', 'ब्रॉन्ज़');
      case 'Silver':
        return _t('Silver', 'सिल्वर');
      case 'Gold':
        return _t('Gold', 'गोल्ड');
      case 'Platinum':
        return _t('Platinum', 'प्लैटिनम');
      case 'Ruby':
        return _t('Ruby', 'रूबी');
      case 'Diamond':
        return _t('Diamond', 'डायमंड');
      default:
        return key;
    }
  }
  String tierLabel(String name) => _t('$name tier', '$name टियर');
  String get achievementUnlocked =>
      _t('ACHIEVEMENT UNLOCKED', 'उपलब्धि अनलॉक');
  String get awesomeBtn => _t('Awesome', 'बढ़िया');
  // Streak reward road
  String bestStreak(int days) =>
      _t('Best: $days ${days == 1 ? 'day' : 'days'}', 'सर्वश्रेष्ठ: $days दिन');
  String get allStreakRewardsUnlocked => _t(
      'Every streak reward unlocked — more on the way!',
      'सभी स्ट्रीक रिवॉर्ड अनलॉक — और आ रहे हैं!');
  String openToUnlock(String daysAway, String name) => _t(
        'Open Budgetify $daysAway to unlock “$name”.',
        '“$name” अनलॉक करने के लिए $daysAway Budgetify खोलें।',
      );
  String get todayWord => _t('today', 'आज');
  String daysMore(int n) =>
      _t('$n more ${n == 1 ? 'day' : 'days'}', '$n दिन और');
  String reachStreakStatus(int days, int current) => _t(
        'Reach a $days-day streak · $current/$days',
        '$days-दिन की स्ट्रीक · $current/$days',
      );
  String get unlockingSoon => _t('Unlocking soon…', 'जल्द अनलॉक हो रहा है…');
  String get currentlyApplied => _t('Currently applied', 'अभी लागू है');
  String get applyTheme => _t('Apply theme', 'थीम लागू करें');
  String get unlockedLabel => _t('Unlocked', 'अनलॉक');
  String get activeBadge => _t('ACTIVE', 'सक्रिय');
  String get moreStreakRewards =>
      _t('More streak rewards on the way.', 'और स्ट्रीक रिवॉर्ड आ रहे हैं।');
  String lockedProgress(String progress, String threshold) =>
      _t('Locked · $progress / $threshold', 'लॉक · $progress / $threshold');

  // ── Budget defaults ───────────────────────────────────────────────────────
  String get defaultBudgetName => _t('Monthly Budget', 'मासिक बजट');

  // ── Theme variant names (display labels; stored as enum) ──────────────────
  String get themeNameLight => _t('Light', 'हल्का');
  String get themeNameDark => _t('Dark', 'गहरा');
  String get themeNameSmoky => _t('Smoky', 'स्मोकी');
  String get themeNameSeashell => _t('Seashell', 'सीशेल');
}

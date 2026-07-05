import 'package:intl/intl.dart';

/// Supported in-app languages. English is the default; Hindi, Marathi,
/// Bengali, Telugu and Tamil are the regional languages. Add more by
/// extending [AppLanguage] and [_t].
enum AppLanguage { english, hindi, marathi, bengali, telugu, tamil }

extension AppLanguageInfo on AppLanguage {
  /// BCP-47 code used for `MaterialApp.locale`.
  String get code => switch (this) {
        AppLanguage.hindi => 'hi',
        AppLanguage.marathi => 'mr',
        AppLanguage.bengali => 'bn',
        AppLanguage.telugu => 'te',
        AppLanguage.tamil => 'ta',
        AppLanguage.english => 'en',
      };

  /// The language's own name, for the picker.
  String get nativeName => switch (this) {
        AppLanguage.hindi => 'हिन्दी',
        AppLanguage.marathi => 'मराठी',
        AppLanguage.bengali => 'বাংলা',
        AppLanguage.telugu => 'తెలుగు',
        AppLanguage.tamil => 'தமிழ்',
        AppLanguage.english => 'English',
      };

  /// English name, for accessibility / fallback.
  String get englishName => switch (this) {
        AppLanguage.hindi => 'Hindi',
        AppLanguage.marathi => 'Marathi',
        AppLanguage.bengali => 'Bengali',
        AppLanguage.telugu => 'Telugu',
        AppLanguage.tamil => 'Tamil',
        AppLanguage.english => 'English',
      };
}

/// A lightweight, dependency-free string table. Each member returns the
/// English, Hindi, Marathi, Bengali, Telugu or Tamil text for the active
/// [lang]. Extend by adding members; every member passes all six languages
/// (untranslated text can repeat the English).
///
/// This is intentionally a hand-rolled table (not ARB/gen_l10n) so a partial
/// translation can ship incrementally without a build step.
class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  String _t(String en, String hi, String mr, String bn, String te, String ta) => switch (lang) {
        AppLanguage.hindi => hi,
        AppLanguage.marathi => mr,
        AppLanguage.bengali => bn,
        AppLanguage.telugu => te,
        AppLanguage.tamil => ta,
        AppLanguage.english => en,
      };

  // ── Bottom navigation ──────────────────────────────────────────────────
  String get navHome => _t('Home', 'होम', 'होम', 'হোম', 'హోమ్', 'முகப்பு');
  String get navBudgets => _t('Budgets', 'बजट', 'बजेट', 'বাজেট', 'బడ్జెట్లు', 'பட்ஜெட்டுகள்');
  String get navRecurring => _t('Recurring', 'आवर्ती', 'आवर्ती', 'পুনরাবৃত্ত', 'పునరావృతం', 'தொடர்');
  String get navNetWorth => _t('Net Worth', 'नेट वर्थ', 'नेट वर्थ', 'নেট ওয়ার্থ', 'నెట్ వర్త్', 'நிகர மதிப்பு');
  String get navSettings => _t('Settings', 'सेटिंग्स', 'सेटिंग्ज', 'সেটিংস', 'సెట్టింగ్స్', 'அமைப்புகள்');

  // ── Settings · Appearance ──────────────────────────────────────────────
  String get appearance => _t('Appearance', 'दिखावट', 'स्वरूप', 'চেহারা', 'రూపం', 'தோற்றம்');
  String get theme => _t('Theme', 'थीम', 'थीम', 'থিম', 'థీమ్', 'தீம்');
  String get language => _t('Language', 'भाषा', 'भाषा', 'ভাষা', 'భాష', 'மொழி');
  String get streakRewards => _t('Streak Rewards', 'स्ट्रीक रिवॉर्ड', 'स्ट्रीक रिवॉर्ड', 'স্ট্রিক রিওয়ার্ড', 'స్ట్రీక్ రివార్డ్స్', 'ஸ்ட்ரீக் வெகுமதிகள்');
  String themesUnlocked(int n, int total) => _t(
        '$n of $total themes unlocked',
        '$total में से $n थीम अनलॉक',
        '$total पैकी $n थीम अनलॉक',
        '$total টির মধ্যে $n থিম আনলক',
        '$total లో $n థీమ్‌లు అన్‌లాక్ అయ్యాయి',
        '$total இல் $n தீம்கள் திறக்கப்பட்டன',
      );
  String lockedThemeNudge(int days) => _t(
        'Reach a $days-day streak to unlock this theme',
        'यह थीम अनलॉक करने के लिए $days-दिन की स्ट्रीक बनाएँ',
        'ही थीम अनलॉक करण्यासाठी $days-दिवसांची स्ट्रीक करा',
        'এই থিম আনলক করতে $days-দিনের স্ট্রিক গড়ুন',
        'ఈ థీమ్‌ను అన్‌లాక్ చేయడానికి $days-రోజుల స్ట్రీక్ చేరుకోండి',
        'இந்த தீமை திறக்க $days-நாள் ஸ்ட்ரீக்கை அடையுங்கள்',
      );

  // ── Net worth projection ───────────────────────────────────────────────
  String get netWorthProjection =>
      _t('Net worth projection', 'नेट वर्थ का अनुमान', 'नेट वर्थचा अंदाज', 'নেট ওয়ার্থের পূর্বাভাস', 'నెట్ వర్త్ అంచనా', 'நிகர மதிப்பு முன்கணிப்பு');
  String get projectedNetWorth =>
      _t('Projected net worth', 'अनुमानित नेट वर्थ', 'अंदाजित नेट वर्थ', 'প্রত্যাশিত নেট ওয়ার্থ', 'అంచనా వేసిన నెట్ వర్త్', 'கணிக்கப்பட்ட நிகர மதிப்பு');
  String basedOnSaving(String perMonth) => _t(
        'Based on saving about $perMonth/month',
        'लगभग $perMonth/माह की बचत के आधार पर',
        'दरमहा सुमारे $perMonth बचतीच्या आधारे',
        'প্রতি মাসে প্রায় $perMonth সঞ্চয়ের ভিত্তিতে',
        'నెలకు సుమారు $perMonth ఆదా ఆధారంగా',
        'மாதம் சுமார் $perMonth சேமிப்பின் அடிப்படையில்',
      );
  String get savingsOnly => _t('savings only', 'केवल बचत', 'फक्त बचत', 'শুধু সঞ্চয়', 'పొదుపు మాత్రమే', 'சேமிப்பு மட்டும்');
  String get withGrowth => _t(
      'with ~8% yearly growth', 'लगभग 8% वार्षिक वृद्धि के साथ', 'सुमारे 8% वार्षिक वाढीसह', 'বার্ষিক ~8% বৃদ্ধি সহ', 'వార్షిక ~8% వృద్ధితో', 'ஆண்டுக்கு ~8% வளர்ச்சியுடன்');
  String get assumeReturns =>
      _t('Assume 8% growth', '8% वृद्धि मानें', '8% वाढ गृहीत धरा', '8% বৃদ্ধি ধরে নিন', '8% వృద్ధి అనుకోండి', '8% வளர்ச்சி எனக் கொள்ளுங்கள்');
  String reachMilestoneIn(String milestone, String duration) => _t(
        "On this path, you'd reach $milestone in about $duration.",
        'इस राह पर, आप लगभग $duration में $milestone तक पहुँच जाएँगे।',
        'या वाटेवर, तुम्ही सुमारे $duration मध्ये $milestone पर्यंत पोहोचाल.',
        'এই পথে, আপনি প্রায় $duration-এ $milestone-এ পৌঁছে যাবেন।',
        'ఈ మార్గంలో, మీరు సుమారు $duration లో $milestone చేరుకుంటారు.',
        'இந்தப் பாதையில், நீங்கள் சுமார் $duration இல் $milestone ஐ அடைவீர்கள்.',
      );
  String get projectionDisclaimer => _t(
        'An estimate from your recent savings — not financial advice.',
        'आपकी हाल की बचत पर आधारित अनुमान — वित्तीय सलाह नहीं।',
        'तुमच्या अलीकडील बचतीवर आधारित अंदाज — आर्थिक सल्ला नाही.',
        'আপনার সাম্প্রতিক সঞ্চয় থেকে একটি অনুমান — আর্থিক পরামর্শ নয়।',
        'మీ ఇటీవలి పొదుపు ఆధారంగా ఒక అంచనా — ఆర్థిక సలహా కాదు.',
        'உங்கள் சமீபத்திய சேமிப்பின் அடிப்படையில் ஒரு மதிப்பீடு — நிதி ஆலோசனை அல்ல.',
      );
  String yearsShort(int y) => _t('${y}y', '$y वर्ष', '$y वर्षे', '$y বছর', '$y సం', '$y ஆ');
  String aboutYears(double years) {
    final rounded = years < 10 ? years.toStringAsFixed(1) : years.round().toString();
    return _t('$rounded years', '$rounded वर्ष', '$rounded वर्षे', '$rounded বছর', '$rounded సంవత్సరాలు', '$rounded ஆண்டுகள்');
  }

  // ── You vs Past You ────────────────────────────────────────────────────
  String get youVsPastYou =>
      _t('You vs Past You', 'आप बनाम पुराने आप', 'तुम्ही विरुद्ध पूर्वीचे तुम्ही', 'আপনি বনাম অতীতের আপনি', 'మీరు vs నాటి మీరు', 'நீங்கள் vs முந்தைய நீங்கள்');
  String get periodMonth => _t('Month', 'महीना', 'महिना', 'মাস', 'నెల', 'மாதம்');
  String get periodQuarter => _t('Quarter', 'तिमाही', 'तिमाही', 'ত্রৈমাসিক', 'త్రైమాసికం', 'காலாண்டு');
  String get lastMonth => _t('Last month', 'पिछला महीना', 'मागील महिना', 'গত মাস', 'గత నెల', 'கடந்த மாதம்');
  String get priorMonth => _t('Prior month', 'उससे पहले', 'त्याआधी', 'তার আগের মাস', 'అంతకు ముందు నెల', 'அதற்கு முந்தைய மாதம்');
  String get lastQuarter => _t('Last quarter', 'पिछली तिमाही', 'मागील तिमाही', 'গত ত্রৈমাসিক', 'గత త్రైమాసికం', 'கடந்த காலாண்டு');
  String get priorQuarter => _t('Prior quarter', 'उससे पहले', 'त्याआधी', 'তার আগের ত্রৈমাসিক', 'అంతకు ముందు త్రైమాసికం', 'அதற்கு முந்தைய காலாண்டு');
  String get mSpending => _t('Spending', 'खर्च', 'खर्च', 'খরচ', 'ఖర్చు', 'செலவு');
  String get mIncome => _t('Income', 'आय', 'उत्पन्न', 'আয়', 'ఆదాయం', 'வருமானம்');
  String get mSavings => _t('Savings', 'बचत', 'बचत', 'সঞ্চয়', 'పొదుపు', 'சேமிப்பு');
  String get mSavingsRate => _t('Savings rate', 'बचत दर', 'बचत दर', 'সঞ্চয় হার', 'పొదుపు రేటు', 'சேமிப்பு விகிதம்');
  String get notEnoughHistory =>
      _t('Not enough history yet — check back after another month.',
          'अभी पर्याप्त इतिहास नहीं — एक और महीने बाद देखें।',
          'अजून पुरेसा इतिहास नाही — आणखी एका महिन्यानंतर पाहा.',
          'এখনও পর্যাপ্ত ইতিহাস নেই — আরও এক মাস পরে আবার দেখুন।',
          'ఇంకా తగినంత చరిత్ర లేదు — మరో నెల తర్వాత మళ్లీ చూడండి.',
          'இன்னும் போதிய வரலாறு இல்லை — மற்றொரு மாதத்திற்குப் பிறகு மீண்டும் பாருங்கள்.');
  String savedMoreVerdict(String amount) => _t(
        'You kept $amount more than the period before. Nice work!',
        'आपने पिछली अवधि से $amount अधिक बचाया। बढ़िया!',
        'तुम्ही मागील कालावधीपेक्षा $amount जास्त बचत केली. छान काम!',
        'আপনি আগের সময়ের চেয়ে $amount বেশি রেখেছেন। দারুণ!',
        'మీరు గత కాలం కంటే $amount ఎక్కువ ఆదా చేశారు. బాగుంది!',
        'முந்தைய காலத்தை விட நீங்கள் $amount அதிகம் சேமித்தீர்கள். அருமை!',
      );
  String savedLessVerdict(String amount) => _t(
        'You kept $amount less than the period before.',
        'आपने पिछली अवधि से $amount कम बचाया।',
        'तुम्ही मागील कालावधीपेक्षा $amount कमी बचत केली.',
        'আপনি আগের সময়ের চেয়ে $amount কম রেখেছেন।',
        'మీరు గత కాలం కంటే $amount తక్కువ ఆదా చేశారు.',
        'முந்தைய காலத்தை விட நீங்கள் $amount குறைவாக சேமித்தீர்கள்.',
      );
  String get savedSameVerdict =>
      _t('About the same as the period before.', 'पिछली अवधि के लगभग बराबर।',
          'मागील कालावधीच्या जवळपास सारखेच.', 'আগের সময়ের প্রায় সমান।', 'గత కాలంతో దాదాపు సమానం.', 'முந்தைய காலத்தை போலவே ஏறக்குறைய.');

  // ── Date helpers ────────────────────────────────────────────────────────
  // Hindi/Marathi date data is hand-rolled so it works without initializing
  // intl's locale data. English falls back to DateFormat.
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

  static const List<String> _mrMonths = [
    'जानेवारी', 'फेब्रुवारी', 'मार्च', 'एप्रिल', 'मे', 'जून',
    'जुलै', 'ऑगस्ट', 'सप्टेंबर', 'ऑक्टोबर', 'नोव्हेंबर', 'डिसेंबर',
  ];
  static const List<String> _mrWeekdays = [
    'सोमवार', 'मंगळवार', 'बुधवार', 'गुरुवार', 'शुक्रवार', 'शनिवार', 'रविवार',
  ];
  static const List<String> _mrMonthsShort = [
    'जाने', 'फेब्रु', 'मार्च', 'एप्रि', 'मे', 'जून',
    'जुलै', 'ऑग', 'सप्टें', 'ऑक्टो', 'नोव्हें', 'डिसें',
  ];

  static const List<String> _bnMonths = [
    'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
    'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
  ];
  static const List<String> _bnWeekdays = [
    'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার',
  ];
  static const List<String> _bnMonthsShort = [
    'জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
    'জুলাই', 'আগ', 'সেপ্ট', 'অক্টো', 'নভে', 'ডিসে',
  ];

  static const List<String> _teMonths = [
    'జనవరి', 'ఫిబ్రవరి', 'మార్చి', 'ఏప్రిల్', 'మే', 'జూన్',
    'జూలై', 'ఆగస్టు', 'సెప్టెంబర్', 'అక్టోబర్', 'నవంబర్', 'డిసెంబర్',
  ];
  static const List<String> _teWeekdays = [
    'సోమవారం', 'మంగళవారం', 'బుధవారం', 'గురువారం', 'శుక్రవారం', 'శనివారం', 'ఆదివారం',
  ];
  static const List<String> _teMonthsShort = [
    'జన', 'ఫిబ్ర', 'మార్చి', 'ఏప్రి', 'మే', 'జూన్',
    'జూలై', 'ఆగ', 'సెప్టెం', 'అక్టో', 'నవం', 'డిసెం',
  ];

  static const List<String> _taMonths = [
    'ஜனவரி', 'பிப்ரவரி', 'மார்ச்', 'ஏப்ரல்', 'மே', 'ஜூன்',
    'ஜூலை', 'ஆகஸ்ட்', 'செப்டம்பர்', 'அக்டோபர்', 'நவம்பர்', 'டிசம்பர்',
  ];
  static const List<String> _taWeekdays = [
    'திங்கட்கிழமை', 'செவ்வாய்க்கிழமை', 'புதன்கிழமை', 'வியாழக்கிழமை', 'வெள்ளிக்கிழமை', 'சனிக்கிழமை', 'ஞாயிற்றுக்கிழமை',
  ];
  static const List<String> _taMonthsShort = [
    'ஜன', 'பிப்', 'மார்', 'ஏப்', 'மே', 'ஜூன்',
    'ஜூலை', 'ஆக', 'செப்', 'அக்', 'நவ', 'டிச',
  ];

  String _enMonth(int m) => DateFormat('MMMM').format(DateTime(2000, m, 1));
  String _hiMonth(int m) => _hiMonths[m - 1];
  String _mrMonth(int m) => _mrMonths[m - 1];
  String _bnMonth(int m) => _bnMonths[m - 1];
  String _teMonth(int m) => _teMonths[m - 1];
  String _taMonth(int m) => _taMonths[m - 1];

  /// Full month name for the given month number (1–12).
  String monthName(int m) => _t(_enMonth(m), _hiMonth(m), _mrMonth(m), _bnMonth(m), _teMonth(m), _taMonth(m));

  /// Full month name for a date's month.
  String monthOf(DateTime d) => monthName(d.month);

  /// Short month abbreviation (e.g. "Jun" / "जून").
  String monthAbbr(int m) => _t(
        DateFormat('MMM').format(DateTime(2000, m, 1)),
        _hiMonthsShort[m - 1],
        _mrMonthsShort[m - 1],
        _bnMonthsShort[m - 1],
        _teMonthsShort[m - 1],
        _taMonthsShort[m - 1],
      );

  /// "June 2025" / "जून 2025".
  String monthYear(DateTime d) => _t(
        DateFormat('MMMM yyyy').format(d),
        '${_hiMonths[d.month - 1]} ${d.year}',
        '${_mrMonths[d.month - 1]} ${d.year}',
        '${_bnMonths[d.month - 1]} ${d.year}',
        '${_teMonths[d.month - 1]} ${d.year}',
        '${_taMonths[d.month - 1]} ${d.year}',
      );

  /// "Jun 2025" / "जून 2025".
  String monthYearShort(DateTime d) => _t(
        DateFormat('MMM yyyy').format(d),
        '${_hiMonthsShort[d.month - 1]} ${d.year}',
        '${_mrMonthsShort[d.month - 1]} ${d.year}',
        '${_bnMonthsShort[d.month - 1]} ${d.year}',
        '${_teMonthsShort[d.month - 1]} ${d.year}',
        '${_taMonthsShort[d.month - 1]} ${d.year}',
      );

  /// Long date like "Monday, June 23" / "सोमवार, 23 जून".
  String fullDate(DateTime d) => _t(
        DateFormat('EEEE, MMMM d').format(d),
        '${_hiWeekdays[d.weekday - 1]}, ${d.day} ${_hiMonths[d.month - 1]}',
        '${_mrWeekdays[d.weekday - 1]}, ${d.day} ${_mrMonths[d.month - 1]}',
        '${_bnWeekdays[d.weekday - 1]}, ${d.day} ${_bnMonths[d.month - 1]}',
        '${_teWeekdays[d.weekday - 1]}, ${d.day} ${_teMonths[d.month - 1]}',
        '${_taWeekdays[d.weekday - 1]}, ${d.day} ${_taMonths[d.month - 1]}',
      );

  /// Medium date like "Jun 23, 2025" / "23 जून 2025".
  String mediumDate(DateTime d) => _t(
        DateFormat('MMM d, yyyy').format(d),
        '${d.day} ${_hiMonthsShort[d.month - 1]} ${d.year}',
        '${d.day} ${_mrMonthsShort[d.month - 1]} ${d.year}',
        '${d.day} ${_bnMonthsShort[d.month - 1]} ${d.year}',
        '${d.day} ${_teMonthsShort[d.month - 1]} ${d.year}',
        '${d.day} ${_taMonthsShort[d.month - 1]} ${d.year}',
      );

  /// Short day+month like "Jun 23" / "23 जून".
  String dayMonth(DateTime d) => _t(
        DateFormat('MMM d').format(d),
        '${d.day} ${_hiMonthsShort[d.month - 1]}',
        '${d.day} ${_mrMonthsShort[d.month - 1]}',
        '${d.day} ${_bnMonthsShort[d.month - 1]}',
        '${d.day} ${_teMonthsShort[d.month - 1]}',
        '${d.day} ${_taMonthsShort[d.month - 1]}',
      );

  String get thisMonth => _t('This Month', 'इस महीने', 'या महिन्यात', 'এই মাসে', 'ఈ నెల', 'இந்த மாதம்');

  // ── Common / shared ─────────────────────────────────────────────────────
  String get commonCancel => _t('Cancel', 'रद्द करें', 'रद्द करा', 'বাতিল করুন', 'రద్దు చేయి', 'ரத்து செய்');
  String get commonSave => _t('Save', 'सहेजें', 'जतन करा', 'সেভ করুন', 'సేవ్ చేయి', 'சேமி');
  String get commonDelete => _t('Delete', 'हटाएँ', 'हटवा', 'মুছুন', 'తొలగించు', 'நீக்கு');
  String get commonEdit => _t('Edit', 'संपादित करें', 'संपादित करा', 'সম্পাদনা করুন', 'సవరించు', 'திருத்து');
  String get commonContinue => _t('Continue', 'जारी रखें', 'सुरू ठेवा', 'চালিয়ে যান', 'కొనసాగించు', 'தொடரவும்');
  String get commonDone => _t('Done', 'हो गया', 'झाले', 'হয়ে গেছে', 'పూర్తయింది', 'முடிந்தது');
  String get commonClose => _t('Close', 'बंद करें', 'बंद करा', 'বন্ধ করুন', 'మూసివేయి', 'மூடு');
  String get commonAmount => _t('Amount', 'राशि', 'रक्कम', 'পরিমাণ', 'మొత్తం', 'தொகை');
  String get commonView => _t('View', 'देखें', 'पाहा', 'দেখুন', 'చూడు', 'காண்க');
  String get commonSeeAll => _t('See All', 'सभी देखें', 'सर्व पाहा', 'সব দেখুন', 'అన్నీ చూడు', 'அனைத்தையும் காண்க');
  String get commonRetry => _t('Retry', 'फिर से', 'पुन्हा', 'আবার', 'మళ్లీ ప్రయత్నించు', 'மீண்டும் முயற்சி');
  String get commonIncome => _t('Income', 'आय', 'उत्पन्न', 'আয়', 'ఆదాయం', 'வருமானம்');
  String get commonExpenses => _t('Expenses', 'खर्च', 'खर्च', 'খরচ', 'ఖర్చులు', 'செலவுகள்');

  // ── Home ────────────────────────────────────────────────────────────────
  String get smsActive => _t('SMS Active', 'SMS चालू', 'SMS सुरू', 'SMS সক্রিয়', 'SMS యాక్టివ్', 'SMS செயலில்');
  String get showHideAmounts =>
      _t('Show/hide amounts', 'राशि दिखाएँ/छिपाएँ', 'रक्कम दाखवा/लपवा', 'পরিমাণ দেখান/লুকান', 'మొత్తాలను చూపు/దాచు', 'தொகைகளைக் காட்டு/மறை');
  String monthExpenses(int month) => _t(
        '${_enMonth(month)} Expenses'.toUpperCase(),
        '${_hiMonth(month)} का खर्च',
        '${_mrMonth(month)} चा खर्च',
        '${_bnMonth(month)} মাসের খরচ',
        '${_teMonth(month)} నెల ఖర్చులు',
        '${_taMonth(month)} மாத செலவுகள்',
      );
  String get spent => _t('Spent', 'खर्च', 'खर्च', 'খরচ হয়েছে', 'ఖర్చు చేసింది', 'செலவழித்தது');
  String monthWrapped(int month) => _t(
        '${_enMonth(month)} Wrapped',
        '${_hiMonth(month)} रैप्ड',
        '${_mrMonth(month)} रॅप्ड',
        '${_bnMonth(month)} Wrapped',
        '${_teMonth(month)} Wrapped',
        '${_taMonth(month)} Wrapped',
      );
  String get wrappedSubtitle => _t('Your shareable month in review',
      'आपका महीना, साझा करने योग्य', 'तुमचा महिना, शेअर करण्याजोगा', 'আপনার মাস, শেয়ার করার মতো', 'మీ నెల సమీక్ష, షేర్ చేయదగినది', 'உங்கள் மாத மதிப்பாய்வு, பகிரக்கூடியது');
  String get splits => _t('Splits', 'स्प्लिट्स', 'स्प्लिट्स', 'স্প্লিট', 'స్ప్లిట్స్', 'பிரிப்புகள்');
  String get splitsSubtitle => _t(
        'Track shared bills & who owes whom',
        'साझा बिल और किसका कितना बकाया, ट्रैक करें',
        'शेअर केलेली बिले व कोणाचे किती येणे, ट्रॅक करा',
        'ভাগ করা বিল ও কে কার কাছে পাওনা, ট্র্যাক করুন',
        'షేర్ చేసిన బిల్లులు & ఎవరు ఎవరికి బాకీ ఉన్నారో ట్రాక్ చేయండి',
        'பகிரப்பட்ட பில்களை & யார் யாருக்குக் கடன்பட்டுள்ளனர் என்பதைக் கண்காணியுங்கள்',
      );
  String get transactions => _t('Transactions', 'लेन-देन', 'व्यवहार', 'লেনদেন', 'లావాదేవీలు', 'பரிவர்த்தனைகள்');
  String get unclassified => _t('Unclassified', 'अवर्गीकृत', 'अवर्गीकृत', 'অশ্রেণীবদ্ধ', 'వర్గీకరించని', 'வகைப்படுத்தப்படாதவை');
  String get scanSms => _t('Scan SMS', 'SMS स्कैन', 'SMS स्कॅन', 'SMS স্ক্যান', 'SMS స్కాన్', 'SMS ஸ்கேன்');
  String get scan => _t('Scan', 'स्कैन', 'स्कॅन', 'স্ক্যান', 'స్కాన్', 'ஸ்கேன்');
  String get recentTransactions =>
      _t('Recent Transactions', 'हाल के लेन-देन', 'अलीकडील व्यवहार', 'সাম্প্রতিক লেনদেন', 'ఇటీవలి లావాదేవీలు', 'சமீபத்திய பரிவர்த்தனைகள்');
  String get cashTransactions =>
      _t('Cash Transactions', 'नकद लेन-देन', 'रोख व्यवहार', 'নগদ লেনদেন', 'నగదు లావాదేవీలు', 'ரொக்கப் பரிவர்த்தனைகள்');
  String cashConversions(int n) => _t(
        '$n Cash Conversion${n == 1 ? '' : 's'}',
        '$n नकद रूपांतरण',
        '$n रोख रूपांतरण',
        '$n নগদ রূপান্তর',
        '$n నగదు మార్పిడులు',
        '$n ரொக்க மாற்றங்கள்',
      );
  String get investmentAlert =>
      _t('Investment Alert', 'निवेश अलर्ट', 'गुंतवणूक सूचना', 'বিনিয়োগ সতর্কতা', 'పెట్టుబడి హెచ్చరిక', 'முதலீட்டு எச்சரிக்கை');
  String investmentsToConfirm(int n) => _t(
        n == 1
            ? 'You have an investment to confirm today'
            : '$n investments to confirm today',
        n == 1
            ? 'आज पुष्टि के लिए एक निवेश है'
            : 'आज पुष्टि के लिए $n निवेश हैं',
        n == 1
            ? 'आज पुष्टीसाठी एक गुंतवणूक आहे'
            : 'आज पुष्टीसाठी $n गुंतवणुका आहेत',
        n == 1
            ? 'আজ নিশ্চিত করার জন্য একটি বিনিয়োগ আছে'
            : 'আজ নিশ্চিত করার জন্য $n টি বিনিয়োগ আছে',
        n == 1 ? 'ఈ రోజు నిర్ధారించాల్సిన పెట్టుబడి ఒకటి ఉంది' : 'ఈ రోజు నిర్ధారించాల్సిన $n పెట్టుబడులు ఉన్నాయి',
        n == 1 ? 'இன்று உறுதிப்படுத்த ஒரு முதலீடு உள்ளது' : 'இன்று உறுதிப்படுத்த $n முதலீடுகள் உள்ளன',
      );
  String get exitTitle => _t('Exit Budgetify?', 'Budgetify से बाहर निकलें?',
      'Budgetify मधून बाहेर पडायचे?', 'Budgetify থেকে বের হবেন?', 'Budgetify నుండి నిష్క్రమించాలా?', 'Budgetify இலிருந்து வெளியேறவா?');
  String get exitSubtitle => _t(
        'Your data stays safely on your device. See you soon.',
        'आपका डेटा आपके डिवाइस पर सुरक्षित रहता है। फिर मिलेंगे।',
        'तुमचा डेटा तुमच्या डिव्हाइसवर सुरक्षित राहतो. पुन्हा भेटू.',
        'আপনার ডেটা আপনার ডিভাইসে নিরাপদে থাকে। শীঘ্রই দেখা হবে।',
        'మీ డేటా మీ పరికరంలో సురక్షితంగా ఉంటుంది. త్వరలో కలుద్దాం.',
        'உங்கள் தரவு உங்கள் சாதனத்தில் பாதுகாப்பாக இருக்கும். விரைவில் சந்திப்போம்.',
      );
  String get stay => _t('Stay', 'रुकें', 'थांबा', 'থাকুন', 'ఉండు', 'இரு');
  String get exit => _t('Exit', 'बाहर निकलें', 'बाहेर पडा', 'বের হন', 'నిష్క్రమించు', 'வெளியேறு');
  String txnCredited(String amount) =>
      _t('Credited: $amount', 'जमा: $amount', 'जमा: $amount', 'জমা: $amount', 'జమ: $amount', 'வரவு: $amount');
  String txnDebited(String amount) =>
      _t('Debited: $amount', 'निकासी: $amount', 'नावे: $amount', 'নামে: $amount', 'డెబిట్: $amount', 'பற்று: $amount');
  String get smsReadFailed => _t(
        "Couldn't read messages on this device just now — your data is up to date",
        'अभी इस डिवाइस पर संदेश नहीं पढ़ सके — आपका डेटा अद्यतित है',
        'सध्या या डिव्हाइसवरील संदेश वाचता आले नाहीत — तुमचा डेटा अद्ययावत आहे',
        'এই মুহূর্তে এই ডিভাইসে বার্তা পড়া যায়নি — আপনার ডেটা হালনাগাদ আছে',
        'ప్రస్తుతం ఈ పరికరంలో సందేశాలు చదవలేకపోయాం — మీ డేటా తాజాగా ఉంది',
        'இப்போது இந்த சாதனத்தில் செய்திகளைப் படிக்க முடியவில்லை — உங்கள் தரவு புதுப்பித்த நிலையில் உள்ளது',
      );
  String get noNewTransactions =>
      _t('No new transactions found', 'कोई नया लेन-देन नहीं मिला',
          'कोणताही नवीन व्यवहार आढळला नाही', 'কোনো নতুন লেনদেন পাওয়া যায়নি', 'కొత్త లావాదేవీలు ఏవీ కనబడలేదు', 'புதிய பரிவர்த்தனைகள் எதுவும் கிடைக்கவில்லை');
  String foundTransactions(int n) =>
      _t('Found $n transaction${n == 1 ? '' : 's'}', '$n लेन-देन मिले',
          '$n व्यवहार आढळले', '$n টি লেনদেন পাওয়া গেছে', '$n లావాదేవీలు కనుగొనబడ్డాయి', '$n பரிவர்த்தனைகள் கண்டறியப்பட்டன');
  String foundTransactionsFromSms(int n) => _t(
        'Found $n transactions from your SMS',
        'आपके SMS से $n लेन-देन मिले',
        'तुमच्या SMS मधून $n व्यवहार आढळले',
        'আপনার SMS থেকে $n টি লেনদেন পাওয়া গেছে',
        'మీ SMS నుండి $n లావాదేవీలు కనుగొనబడ్డాయి',
        'உங்கள் SMS இலிருந்து $n பரிவர்த்தனைகள் கண்டறியப்பட்டன',
      );
  String newTransactionsFound(int n) => _t(
        '$n new transaction${n == 1 ? '' : 's'} found',
        '$n नए लेन-देन मिले',
        '$n नवीन व्यवहार आढळले',
        '$n টি নতুন লেনদেন পাওয়া গেছে',
        '$n కొత్త లావాదేవీలు కనుగొనబడ్డాయి',
        '$n புதிய பரிவர்த்தனைகள் கண்டறியப்பட்டன',
      );

  // ── Settings · section headers ────────────────────────────────────────────
  String get settingsTitle => _t('Settings', 'सेटिंग्स', 'सेटिंग्ज', 'সেটিংস', 'సెట్టింగ్స్', 'அமைப்புகள்');
  String get autoScanSection => _t('Auto-Scan', 'ऑटो-स्कैन', 'ऑटो-स्कॅन', 'অটো-স্ক্যান', 'ఆటో-స్కాన్', 'தானியங்கி ஸ்கேன்');
  String get securitySection => _t('Security', 'सुरक्षा', 'सुरक्षा', 'নিরাপত্তা', 'భద్రత', 'பாதுகாப்பு');
  String get intelligenceSection =>
      _t('Intelligence', 'इंटेलिजेंस', 'इंटेलिजन्स', 'ইন্টেলিজেন্স', 'ఇంటెలిజెన్స్', 'நுண்ணறிவு');
  String get backupSection => _t('Backup', 'बैकअप', 'बॅकअप', 'ব্যাকআপ', 'బ్యాకప్', 'காப்புப்பிரதி');
  String get dataSection => _t('Data', 'डेटा', 'डेटा', 'ডেটা', 'డేటా', 'தரவு');
  String get exportSection => _t('Export', 'एक्सपोर्ट', 'एक्सपोर्ट', 'এক্সপোর্ট', 'ఎగుమతి', 'ஏற்றுமதி');
  String get importExportSection => _t('Import & Export', 'इंपोर्ट और एक्सपोर्ट',
      'इंपोर्ट व एक्सपोर्ट', 'ইম্পোর্ট ও এক্সপোর্ট', 'దిగుమతి & ఎగుమతి', 'இறக்குமதி & ஏற்றுமதி');
  String get privacySection => _t('Privacy', 'गोपनीयता', 'गोपनीयता', 'গোপনীয়তা', 'గోప్యత', 'தனியுரிமை');
  String get aboutSection => _t('About', 'परिचय', 'परिचय', 'পরিচিতি', 'గురించి', 'பற்றி');

  // ── Settings · Auto-Scan ──────────────────────────────────────────────────
  String get autoScanTitle =>
      _t('Automatic SMS Scanning', 'स्वचालित SMS स्कैनिंग', 'स्वयंचलित SMS स्कॅनिंग', 'স্বয়ংক্রিয় SMS স্ক্যানিং', 'ఆటోమేటిక్ SMS స్కానింగ్', 'தானியங்கி SMS ஸ்கேனிங்');
  String get autoScanOnDesc => _t('Transactions are scanned automatically',
      'लेन-देन स्वतः स्कैन होते हैं', 'व्यवहार आपोआप स्कॅन होतात', 'লেনদেন স্বয়ংক্রিয়ভাবে স্ক্যান হয়', 'లావాదేవీలు ఆటోమేటిక్‌గా స్కాన్ అవుతాయి', 'பரிவர்த்தனைகள் தானாகவே ஸ்கேன் செய்யப்படுகின்றன');
  String get autoScanOffDesc => _t(
        'Enable to auto-detect transactions in background',
        'बैकग्राउंड में लेन-देन पहचानने के लिए चालू करें',
        'बॅकग्राउंडमध्ये व्यवहार ओळखण्यासाठी सुरू करा',
        'ব্যাকগ্রাউন্ডে লেনদেন স্বয়ংক্রিয়ভাবে শনাক্ত করতে চালু করুন',
        'బ్యాక్‌గ్రౌండ్‌లో లావాదేవీలను ఆటోమేటిక్‌గా గుర్తించడానికి ప్రారంభించండి',
        'பின்னணியில் பரிவர்த்தனைகளைத் தானாகக் கண்டறிய இயக்கவும்',
      );
  String get scanFrequency => _t('Scan Frequency', 'स्कैन आवृत्ति', 'स्कॅन वारंवारता', 'স্ক্যান ফ্রিকোয়েন্সি', 'స్కాన్ ఫ్రీక్వెన్సీ', 'ஸ்கேன் அதிர்வெண்');
  String get hourly => _t('Hourly', 'हर घंटे', 'दर तासाला', 'প্রতি ঘণ্টায়', 'ప్రతి గంటకు', 'மணிநேரம் தோறும்');
  String everyHours(int h) => _t('Every ${h}h', 'हर $h घंटे', 'दर $h तासांनी', 'প্রতি $h ঘণ্টায়', 'ప్రతి $h గం', 'ஒவ்வொரு $h மணி');
  String get lastScan => _t('Last Scan', 'अंतिम स्कैन', 'शेवटचे स्कॅन', 'শেষ স্ক্যান', 'చివరి స్కాన్', 'கடைசி ஸ்கேன்');
  String get autoScanEnabledToast =>
      _t('Auto-scan enabled', 'ऑटो-स्कैन चालू', 'ऑटो-स्कॅन सुरू', 'অটো-স্ক্যান চালু', 'ఆటో-స్కాన్ ప్రారంభించబడింది', 'தானியங்கி ஸ்கேன் இயக்கப்பட்டது');
  String get autoScanDisabledToast =>
      _t('Auto-scan disabled', 'ऑटो-स्कैन बंद', 'ऑटो-स्कॅन बंद', 'অটো-স্ক্যান বন্ধ', 'ఆటో-స్కాన్ నిలిపివేయబడింది', 'தானியங்கி ஸ்கேன் முடக்கப்பட்டது');

  // ── Settings · Security ───────────────────────────────────────────────────
  String get appLock => _t('App Lock', 'ऐप लॉक', 'अॅप लॉक', 'অ্যাপ লক', 'యాప్ లాక్', 'ஆப் பூட்டு');
  String get appLockOnDesc => _t(
        'Unlock with fingerprint, face, or device PIN',
        'फ़िंगरप्रिंट, चेहरे या डिवाइस पिन से अनलॉक करें',
        'फिंगरप्रिंट, चेहरा किंवा डिव्हाइस पिनने अनलॉक करा',
        'ফিঙ্গারপ্রিন্ট, ফেস বা ডিভাইস পিন দিয়ে আনলক করুন',
        'వేలిముద్ర, ముఖం లేదా పరికర PINతో అన్‌లాక్ చేయండి',
        'கைரேகை, முகம் அல்லது சாதன PIN மூலம் திறக்கவும்',
      );
  String get appLockOffDesc => _t(
        'Require authentication to open the app',
        'ऐप खोलने के लिए प्रमाणीकरण आवश्यक करें',
        'अॅप उघडण्यासाठी प्रमाणीकरण आवश्यक करा',
        'অ্যাপ খুলতে প্রমাণীকরণ আবশ্যক করুন',
        'యాప్ తెరవడానికి ప్రామాణీకరణ అవసరం',
        'ஆப்பைத் திறக்க அங்கீகாரம் தேவை',
      );
  String get noScreenLock => _t(
        'No screen lock or biometrics set up on this device',
        'इस डिवाइस पर कोई स्क्रीन लॉक या बायोमेट्रिक्स सेट नहीं है',
        'या डिव्हाइसवर कोणतेही स्क्रीन लॉक किंवा बायोमेट्रिक्स सेट केलेले नाही',
        'এই ডিভাইসে কোনো স্ক্রিন লক বা বায়োমেট্রিক্স সেট করা নেই',
        'ఈ పరికరంలో స్క్రీన్ లాక్ లేదా బయోమెట్రిక్స్ సెటప్ చేయలేదు',
        'இந்த சாதனத்தில் திரைப் பூட்டு அல்லது பயோமெட்ரிக்ஸ் அமைக்கப்படவில்லை',
      );
  String get hideAmounts => _t('Hide Amounts', 'राशि छिपाएँ', 'रक्कम लपवा', 'পরিমাণ লুকান', 'మొత్తాలను దాచు', 'தொகைகளை மறை');
  String get hideAmountsDesc => _t(
        'Blur all figures until you tap to reveal',
        'जब तक आप दिखाने के लिए टैप न करें, सभी आँकड़े धुंधले रहेंगे',
        'दाखवण्यासाठी टॅप करेपर्यंत सर्व आकडे अस्पष्ट राहतील',
        'প্রকাশ করতে ট্যাপ না করা পর্যন্ত সব সংখ্যা ঝাপসা থাকবে',
        'చూపడానికి ట్యాప్ చేసేవరకు అన్ని సంఖ్యలను అస్పష్టం చేయి',
        'வெளிப்படுத்த தட்டும் வரை அனைத்து எண்களையும் மங்கலாக்கு',
      );

  // ── Settings · Intelligence ───────────────────────────────────────────────
  String get aiPredictionMode =>
      _t('AI Prediction Mode', 'AI पूर्वानुमान मोड', 'AI अंदाज मोड', 'AI পূর্বাভাস মোড', 'AI అంచనా మోడ్', 'AI முன்கணிப்பு பயன்முறை');
  String get aiPredictionModeDesc => _t(
        'Show a spending forecast and insights on your dashboard. '
            'Computed entirely on your device — nothing is uploaded.',
        'अपने डैशबोर्ड पर खर्च का पूर्वानुमान और जानकारी देखें। '
            'पूरी गणना आपके डिवाइस पर होती है — कुछ भी अपलोड नहीं होता।',
        'तुमच्या डॅशबोर्डवर खर्चाचा अंदाज आणि माहिती पाहा. '
            'संपूर्ण गणना तुमच्या डिव्हाइसवर होते — काहीही अपलोड होत नाही.',
        'আপনার ড্যাশবোর্ডে খরচের পূর্বাভাস ও অন্তর্দৃষ্টি দেখুন। '
            'পুরো হিসাব আপনার ডিভাইসেই হয় — কিছুই আপলোড করা হয় না।',
        'మీ డాష్‌బోర్డ్‌లో ఖర్చు అంచనా మరియు అంతర్దృష్టులను చూపండి. పూర్తిగా మీ పరికరంలోనే లెక్కించబడుతుంది — ఏదీ అప్‌లోడ్ చేయబడదు.',
        'உங்கள் டாஷ்போர்டில் செலவு முன்கணிப்பு மற்றும் நுண்ணறிவுகளைக் காட்டுங்கள். முழுவதும் உங்கள் சாதனத்திலேயே கணக்கிடப்படுகிறது — எதுவும் பதிவேற்றப்படாது.',
      );
  String get detailedFinancialHealth =>
      _t('Detailed Financial Health', 'विस्तृत वित्तीय स्वास्थ्य', 'सविस्तर आर्थिक आरोग्य', 'বিস্তারিত আর্থিক স্বাস্থ্য', 'వివరణాత్మక ఆర్థిక ఆరోగ్యం', 'விரிவான நிதி ஆரோக்கியம்');
  String get detailedFinancialHealthDesc => _t(
        'Show the full Financial Health card with a per-pillar breakdown. '
            'When off, just the score appears on your balance card.',
        'प्रत्येक स्तंभ के विवरण के साथ पूरा वित्तीय स्वास्थ्य कार्ड दिखाएँ। '
            'बंद होने पर, केवल स्कोर आपके बैलेंस कार्ड पर दिखता है।',
        'प्रत्येक स्तंभाच्या तपशिलासह संपूर्ण आर्थिक आरोग्य कार्ड दाखवा. '
            'बंद असताना, फक्त स्कोअर तुमच्या बॅलन्स कार्डवर दिसतो.',
        'প্রতিটি স্তম্ভের বিশ্লেষণ সহ সম্পূর্ণ আর্থিক স্বাস্থ্য কার্ড দেখান। '
            'বন্ধ থাকলে, শুধু স্কোর আপনার ব্যালেন্স কার্ডে দেখা যায়।',
        'ప్రతి స్తంభం విభజనతో పూర్తి ఆర్థిక ఆరోగ్య కార్డును చూపండి. ఆఫ్ చేసినప్పుడు, మీ బ్యాలెన్స్ కార్డ్‌లో స్కోర్ మాత్రమే కనిపిస్తుంది.',
        'ஒவ்வொரு தூணின் விவரத்துடன் முழு நிதி ஆரோக்கிய அட்டையைக் காட்டுங்கள். ஆஃப் செய்யும்போது, உங்கள் இருப்பு அட்டையில் மதிப்பெண் மட்டும் தோன்றும்.',
      );
  String get gamifiedBudgets =>
      _t('Gamified Budgets', 'गेमिफाइड बजट', 'गेमिफाइड बजेट', 'গেমিফাইড বাজেট', 'గేమిఫైడ్ బడ్జెట్లు', 'கேமிஃபைட் பட்ஜெட்கள்');
  String get gamifiedBudgetsDesc => _t(
        'Earn achievement badges, titles and a shareable profile from '
            'your spending. Opens a separate Rewards hub from your Home '
            'avatar — everything stays on your device.',
        'अपने खर्च से उपलब्धि बैज, खिताब और साझा करने योग्य प्रोफ़ाइल कमाएँ। '
            'होम अवतार से एक अलग रिवॉर्ड हब खुलता है — सब कुछ आपके डिवाइस पर रहता है।',
        'तुमच्या खर्चातून अचिव्हमेंट बॅजेस, किताब आणि शेअर करण्याजोगे प्रोफाइल मिळवा. '
            'होम अवतारवरून वेगळा रिवॉर्ड हब उघडतो — सर्व काही तुमच्या डिव्हाइसवर राहते.',
        'আপনার খরচ থেকে অ্যাচিভমেন্ট ব্যাজ, খেতাব ও শেয়ার করার মতো প্রোফাইল অর্জন করুন। '
            'হোম অবতার থেকে একটি আলাদা রিওয়ার্ড হাব খোলে — সবকিছু আপনার ডিভাইসে থাকে।',
        'మీ ఖర్చు నుండి అచీవ్‌మెంట్ బ్యాడ్జ్‌లు, టైటిల్స్ మరియు షేర్ చేయదగిన ప్రొఫైల్‌ను సంపాదించండి. మీ హోమ్ అవతార్ నుండి ప్రత్యేక Rewards హబ్‌ను తెరుస్తుంది — అంతా మీ పరికరంలోనే ఉంటుంది.',
        'உங்கள் செலவிலிருந்து சாதனை பேட்ஜ்கள், டைட்டில்கள் மற்றும் பகிரக்கூடிய சுயவிவரத்தைப் பெறுங்கள். உங்கள் முகப்பு அவதாரத்திலிருந்து தனி Rewards ஹப்பைத் திறக்கிறது — அனைத்தும் உங்கள் சாதனத்திலேயே இருக்கும்.',
      );

  // ── Settings · Backup / Data / Export / Privacy / About ───────────────────
  String get createBackup => _t(
      'Create Encrypted Backup', 'एन्क्रिप्टेड बैकअप बनाएँ', 'एन्क्रिप्टेड बॅकअप तयार करा', 'এনক্রিপ্ট করা ব্যাকআপ তৈরি করুন', 'ఎన్‌క్రిప్టెడ్ బ్యాకప్ సృష్టించు', 'மறையாக்கப்பட்ட காப்புப்பிரதியை உருவாக்கு');
  String get createBackupDesc => _t(
        'All transactions, budgets, rules & tags (AES-256)',
        'सभी लेन-देन, बजट, नियम और टैग (AES-256)',
        'सर्व व्यवहार, बजेट, नियम व टॅग (AES-256)',
        'সব লেনদেন, বাজেট, নিয়ম ও ট্যাগ (AES-256)',
        'అన్ని లావాదేవీలు, బడ్జెట్లు, రూల్స్ & ట్యాగ్‌లు (AES-256)',
        'அனைத்து பரிவர்த்தனைகள், பட்ஜெட்கள், விதிகள் & குறிச்சொற்கள் (AES-256)',
      );
  String get restoreBackup =>
      _t('Restore from Backup', 'बैकअप से पुनर्स्थापित करें', 'बॅकअपमधून पुनर्संचयित करा', 'ব্যাকআপ থেকে পুনরুদ্ধার করুন', 'బ్యాకప్ నుండి పునరుద్ధరించు', 'காப்புப்பிரதியிலிருந்து மீட்டமை');
  String get restoreBackupDesc => _t(
        'Merge a backup file into this device',
        'बैकअप फ़ाइल को इस डिवाइस में मर्ज करें',
        'बॅकअप फाइल या डिव्हाइसमध्ये विलीन करा',
        'একটি ব্যাকআপ ফাইল এই ডিভাইসে মার্জ করুন',
        'ఈ పరికరంలోకి బ్యాకప్ ఫైల్‌ను విలీనం చేయి',
        'ஒரு காப்புப்பிரதி கோப்பை இந்த சாதனத்தில் இணைக்கவும்',
      );
  String get manageTags => _t('Manage Tags', 'टैग प्रबंधित करें', 'टॅग व्यवस्थापित करा', 'ট্যাগ পরিচালনা করুন', 'ట్యాగ్‌లను నిర్వహించు', 'குறிச்சொற்களை நிர்வகி');
  String get manageTagsDesc => _t("Delete tags you don't use",
      'जो टैग आप उपयोग नहीं करते उन्हें हटाएँ', 'तुम्ही वापरत नसलेले टॅग हटवा', 'আপনি যে ট্যাগ ব্যবহার করেন না সেগুলো মুছুন', 'మీరు ఉపయోగించని ట్యాగ్‌లను తొలగించండి', 'நீங்கள் பயன்படுத்தாத குறிச்சொற்களை நீக்கவும்');
  String get exportData => _t('Export Data', 'डेटा एक्सपोर्ट करें', 'डेटा एक्सपोर्ट करा', 'ডেটা এক্সপোর্ট করুন', 'డేటాను ఎగుమతి చేయి', 'தரவை ஏற்றுமதி செய்');
  String get exportDataDesc => _t(
        'Excel, CSV, PDF or text — filter by date, type, tag or payee',
        'Excel, CSV, PDF या टेक्स्ट — तिथि, प्रकार, टैग या प्राप्तकर्ता से फ़िल्टर करें',
        'Excel, CSV, PDF किंवा मजकूर — तारीख, प्रकार, टॅग किंवा प्राप्तकर्त्यानुसार फिल्टर करा',
        'Excel, CSV, PDF বা টেক্সট — তারিখ, ধরন, ট্যাগ বা প্রাপকের ভিত্তিতে ফিল্টার করুন',
        'Excel, CSV, PDF లేదా టెక్స్ట్ — తేదీ, రకం, ట్యాగ్ లేదా చెల్లింపుదారు ఆధారంగా ఫిల్టర్ చేయండి',
        'Excel, CSV, PDF அல்லது உரை — தேதி, வகை, குறிச்சொல் அல்லது பணம் பெறுநர் மூலம் வடிகட்டவும்',
      );

  // ── Settings · Import from another app ────────────────────────────────────
  String get importData =>
      _t('Import Data', 'डेटा इंपोर्ट करें', 'डेटा इंपोर्ट करा', 'ডেটা ইম্পোর্ট করুন', 'డేటాను దిగుమతి చేయి', 'தரவை இறக்குமதி செய்');
  String get importDataDesc => _t(
        'Bank statements, or tags from another app',
        'बैंक स्टेटमेंट, या किसी और ऐप से अपने टैग',
        'बँक स्टेटमेंट, किंवा दुसऱ्या अ‍ॅपमधून तुमचे टॅग',
        'ব্যাংক স্টেটমেন্ট, বা অন্য অ্যাপ থেকে আপনার ট্যাগ',
        'బ్యాంక్ స్టేట్‌మెంట్‌లు, లేదా మరో యాప్ నుండి ట్యాగ్‌లు',
        'வங்கி அறிக்கைகள், அல்லது மற்றொரு ஆப்பிலிருந்து குறிச்சொற்கள்',
      );
  String get importFromTitle => _t(
        'Import your data',
        'अपना डेटा इंपोर्ट करें',
        'तुमचा डेटा इंपोर्ट करा',
        'আপনার ডেটা ইম্পোর্ট করুন',
        'మీ డేటాను దిగుమతి చేయండి',
        'உங்கள் தரவை இறக்குமதி செய்யுங்கள்',
      );
  String get importFromDesc => _t(
        'Bring your history in from a bank statement, or your tags from '
            'another app. Everything is read on this device — nothing is '
            'uploaded.',
        'बैंक स्टेटमेंट से अपना इतिहास, या किसी और ऐप से अपने टैग लाएँ। '
            'सब कुछ इसी डिवाइस पर पढ़ा जाता है — कुछ भी अपलोड नहीं होता।',
        'बँक स्टेटमेंटमधून तुमचा इतिहास, किंवा दुसऱ्या अ‍ॅपमधून तुमचे टॅग आणा. '
            'सर्व काही याच डिव्हाइसवर वाचले जाते — काहीही अपलोड होत नाही.',
        'ব্যাংক স্টেটমেন্ট থেকে আপনার ইতিহাস, বা অন্য অ্যাপ থেকে আপনার ট্যাগ '
            'আনুন। সবকিছু এই ডিভাইসেই পড়া হয় — কিছুই আপলোড হয় না।',
        'బ్యాంక్ స్టేట్‌మెంట్ నుండి మీ చరిత్రను, లేదా మరో యాప్ నుండి మీ ట్యాగ్‌లను తీసుకురండి. అంతా ఈ పరికరంలోనే చదవబడుతుంది — ఏదీ అప్‌లోడ్ చేయబడదు.',
        'வங்கி அறிக்கையிலிருந்து உங்கள் வரலாற்றை, அல்லது மற்றொரு ஆப்பிலிருந்து உங்கள் குறிச்சொற்களைக் கொண்டு வாருங்கள். அனைத்தும் இந்த சாதனத்திலேயே படிக்கப்படுகிறது — எதுவும் பதிவேற்றப்படாது.',
      );
  String get importSourceAxioDesc => _t(
        'From an axio expense report (.csv)',
        'axio खर्च रिपोर्ट (.csv) से',
        'axio खर्च अहवाल (.csv) मधून',
        'axio খরচ রিপোর্ট (.csv) থেকে',
        'axio ఖర్చు నివేదిక (.csv) నుండి',
        'axio செலவு அறிக்கை (.csv) இலிருந்து',
      );
  String get importReviewTitle =>
      _t('Review import', 'इंपोर्ट की समीक्षा', 'इंपोर्टचे पुनरावलोकन', 'ইম্পোর্ট পর্যালোচনা', 'దిగుమతిని సమీక్షించు', 'இறக்குமதியை மதிப்பாய்வு செய்');
  String importFoundMerchants(int count) => _t(
        'Found $count tagged ${count == 1 ? 'merchant' : 'merchants'} in your axio export',
        'आपके axio एक्सपोर्ट में $count टैग किए गए मर्चेंट मिले',
        'तुमच्या axio एक्सपोर्टमध्ये $count टॅग केलेले विक्रेते सापडले',
        'আপনার axio এক্সপোর্টে $count টি ট্যাগ করা মার্চেন্ট পাওয়া গেছে',
        'మీ axio ఎగుమతిలో $count ట్యాగ్ చేసిన మర్చెంట్‌లు కనుగొనబడ్డాయి',
        'உங்கள் axio ஏற்றுமதியில் $count குறிச்சொல் இட்ட வணிகர்கள் கண்டறியப்பட்டனர்',
      );
  String importAutoRulesTitle(int count) => _t(
        'Auto-tag rules · $count',
        'ऑटो-टैग नियम · $count',
        'ऑटो-टॅग नियम · $count',
        'অটো-ট্যাগ নিয়ম · $count',
        'ఆటో-ట్యాగ్ రూల్స్ · $count',
        'தானியங்கி-குறிச்சொல் விதிகள் · $count',
      );
  String get importAutoRulesDesc => _t(
        'Seen often, so these are tagged everywhere — past and future.',
        'अक्सर दिखते हैं, इसलिए इन्हें हर जगह टैग किया जाता है — पहले और आगे भी।',
        'वारंवार दिसतात, म्हणून हे सर्वत्र टॅग होतात — मागील व पुढील दोन्ही.',
        'প্রায়ই দেখা যায়, তাই এগুলো সর্বত্র ট্যাগ হয় — অতীত ও ভবিষ্যৎ উভয়ই।',
        'తరచుగా కనిపిస్తాయి, కాబట్టి ఇవి ప్రతిచోటా ట్యాగ్ అవుతాయి — గతం మరియు భవిష్యత్తు.',
        'அடிக்கடி காணப்படுகின்றன, எனவே இவை எல்லா இடங்களிலும் குறிச்சொல் இடப்படுகின்றன — கடந்த காலம் மற்றும் எதிர்காலம்.',
      );
  String importOneTimeTitle(int count) => _t(
        'One-time tags · $count',
        'एक-बार टैग · $count',
        'एक-वेळ टॅग · $count',
        'একবারের ট্যাগ · $count',
        'ఒక్కసారి ట్యాగ్‌లు · $count',
        'ஒரு முறை குறிச்சொற்கள் · $count',
      );
  String get importOneTimeDesc => _t(
        'Applied only to your matching transactions, no rule created.',
        'केवल आपके मिलते-जुलते लेन-देन पर लागू, कोई नियम नहीं बनाया गया।',
        'फक्त तुमच्या जुळणाऱ्या व्यवहारांना लागू, नियम तयार केला नाही.',
        'শুধু আপনার মিলে যাওয়া লেনদেনে প্রয়োগ, কোনো নিয়ম তৈরি হয়নি।',
        'మీ సరిపోలే లావాదేవీలకు మాత్రమే వర్తింపజేయబడింది, ఏ రూల్ సృష్టించబడలేదు.',
        'உங்கள் பொருந்தும் பரிவர்த்தனைகளுக்கு மட்டுமே பயன்படுத்தப்பட்டது, எந்த விதியும் உருவாக்கப்படவில்லை.',
      );
  String importTimesSeen(int count) => _t(
        '$count×',
        '$count×',
        '$count×',
        '$count×',
        '$count×',
        '$count×',
      );
  String get importButton =>
      _t('Import Tags', 'टैग इंपोर्ट करें', 'टॅग इंपोर्ट करा', 'ট্যাগ ইম্পোর্ট করুন', 'ట్యాగ్‌లను దిగుమతి చేయి', 'குறிச்சொற்களை இறக்குமதி செய்');
  String get importing =>
      _t('Importing…', 'इंपोर्ट हो रहा है…', 'इंपोर्ट होत आहे…', 'ইম্পোর্ট হচ্ছে…', 'దిగుమతి అవుతోంది…', 'இறக்குமதி செய்கிறது…');
  String get importNoTags => _t(
        'No tags found to import from this file.',
        'इस फ़ाइल से इंपोर्ट करने के लिए कोई टैग नहीं मिला।',
        'या फाइलमधून इंपोर्ट करण्यासाठी कोणतेही टॅग सापडले नाहीत.',
        'এই ফাইল থেকে ইম্পোর্ট করার জন্য কোনো ট্যাগ পাওয়া যায়নি।',
        'ఈ ఫైల్ నుండి దిగుమతి చేయడానికి ట్యాగ్‌లు ఏవీ కనబడలేదు.',
        'இந்த கோப்பிலிருந்து இறக்குமதி செய்ய குறிச்சொற்கள் எதுவும் கிடைக்கவில்லை.',
      );
  String get importInvalidFile => _t(
        "This doesn't look like an axio export. Pick the .csv you downloaded "
            'from axio.',
        'यह axio एक्सपोर्ट जैसा नहीं लगता। axio से डाउनलोड की गई .csv चुनें।',
        'हे axio एक्सपोर्टसारखे दिसत नाही. axio वरून डाउनलोड केलेली .csv निवडा.',
        'এটি axio এক্সপোর্টের মতো নয়। axio থেকে ডাউনলোড করা .csv বেছে নিন।',
        'ఇది axio ఎగుమతిలా కనిపించడం లేదు. మీరు axio నుండి డౌన్‌లోడ్ చేసిన .csv ను ఎంచుకోండి.',
        'இது axio ஏற்றுமதி போல் தெரியவில்லை. நீங்கள் axio இலிருந்து பதிவிறக்கிய .csv ஐத் தேர்ந்தெடுக்கவும்.',
      );
  String importDone(int rules, int txns) => _t(
        'Imported $rules auto-tag ${rules == 1 ? 'rule' : 'rules'} and tagged '
            '$txns ${txns == 1 ? 'transaction' : 'transactions'}.',
        '$rules ऑटो-टैग नियम इंपोर्ट किए और $txns लेन-देन टैग किए।',
        '$rules ऑटो-टॅग नियम इंपोर्ट केले आणि $txns व्यवहार टॅग केले.',
        '$rules টি অটো-ট্যাগ নিয়ম ইম্পোর্ট এবং $txns টি লেনদেন ট্যাগ করা হয়েছে।',
        '$rules ఆటో-ట్యాగ్ రూల్స్ దిగుమతి చేయబడ్డాయి మరియు $txns లావాదేవీలు ట్యాగ్ చేయబడ్డాయి.',
        '$rules தானியங்கி-குறிச்சொல் விதிகள் இறக்குமதி செய்யப்பட்டன மற்றும் $txns பரிவர்த்தனைகள் குறிச்சொல் இடப்பட்டன.',
      );
  String importFailed(String error) => _t(
        'Import failed: $error',
        'इंपोर्ट विफल: $error',
        'इंपोर्ट अयशस्वी: $error',
        'ইম্পোর্ট ব্যর্থ: $error',
        'దిగుమతి విఫలమైంది: $error',
        'இறக்குமதி தோல்வியடைந்தது: $error',
      );

  // ── Settings · Bank-statement import ──────────────────────────────────────
  String get importSourceStatementTitle => _t(
      'Bank statement', 'बैंक स्टेटमेंट', 'बँक स्टेटमेंट', 'ব্যাংক স্টেটমেন্ট', 'బ్యాంక్ స్టేట్‌మెంట్', 'வங்கி அறிக்கை');
  String get importSourceStatementDesc => _t(
        'CSV or Excel statement from any bank',
        'किसी भी बैंक की CSV या Excel स्टेटमेंट से',
        'कोणत्याही बँकेच्या CSV किंवा Excel स्टेटमेंटमधून',
        'যেকোনো ব্যাংকের CSV বা Excel স্টেটমেন্ট থেকে',
        'ఏ బ్యాంక్ నుండైనా CSV లేదా Excel స్టేట్‌మెంట్',
        'எந்த வங்கியிலிருந்தும் CSV அல்லது Excel அறிக்கை',
      );
  String get stImportTitle => _t(
        'Import bank statement',
        'बैंक स्टेटमेंट इंपोर्ट करें',
        'बँक स्टेटमेंट इंपोर्ट करा',
        'ব্যাংক স্টেটমেন্ট ইম্পোর্ট করুন',
        'బ్యాంక్ స్టేట్‌మెంట్‌ను దిగుమతి చేయి',
        'வங்கி அறிக்கையை இறக்குமதி செய்',
      );
  String get stStepMapTitle =>
      _t('Match the columns', 'कॉलम मिलाएँ', 'कॉलम जुळवा', 'কলামগুলো মেলান', 'కాలమ్‌లను సరిపోల్చండి', 'நெடுவரிசைகளைப் பொருத்தவும்');
  String get stStepMapDesc => _t(
        "We've guessed what each column means — fix anything that looks "
            "wrong. Confirmed once, it's remembered for this bank.",
        'हर कॉलम का मतलब हमने अनुमान से भरा है — जो गलत लगे उसे ठीक करें। '
            'एक बार पुष्टि के बाद यह इस बैंक के लिए याद रहेगा।',
        'प्रत्येक कॉलमचा अर्थ आम्ही अंदाजाने भरला आहे — चुकीचे वाटेल ते '
            'दुरुस्त करा. एकदा निश्चित केल्यावर ते या बँकेसाठी लक्षात राहील.',
        'প্রতিটি কলামের অর্থ আমরা অনুমান করেছি — ভুল মনে হলে ঠিক করুন। '
            'একবার নিশ্চিত করলে এই ব্যাংকের জন্য মনে থাকবে।',
        'ప్రతి కాలమ్ అర్థం ఏమిటో మేము ఊహించాం — తప్పుగా అనిపించేదాన్ని సరిచేయండి. ఒకసారి నిర్ధారిస్తే, ఈ బ్యాంక్ కోసం గుర్తుంచుకోబడుతుంది.',
        'ஒவ்வொரு நெடுவரிசையின் அர்த்தத்தை நாங்கள் யூகித்துள்ளோம் — தவறாகத் தோன்றும் எதையும் சரிசெய்யுங்கள். ஒருமுறை உறுதிப்படுத்தினால், இந்த வங்கிக்காக நினைவில் வைக்கப்படும்.',
      );
  String get stSourceLabel =>
      _t('Source name', 'स्रोत का नाम', 'स्रोताचे नाव', 'উৎসের নাম', 'మూలం పేరు', 'மூல பெயர்');
  String get stSourceHint => _t(
      'e.g. HDFC Savings', 'जैसे HDFC Savings', 'उदा. HDFC Savings', 'যেমন HDFC Savings', 'ఉదా. HDFC Savings', 'எ.கா. HDFC Savings');
  String get stRoleDate => _t('Date', 'तारीख़', 'तारीख', 'তারিখ', 'తేదీ', 'தேதி');
  String get stRoleDescription =>
      _t('Description', 'विवरण', 'तपशील', 'বিবরণ', 'వివరణ', 'விளக்கம்');
  String get stRoleDebit => _t(
      'Debit (money out)', 'डेबिट (पैसा गया)', 'डेबिट (पैसे गेले)', 'ডেবিট (টাকা গেছে)', 'డెబిట్ (డబ్బు వెళ్లింది)', 'பற்று (பணம் வெளியே)');
  String get stRoleCredit => _t(
      'Credit (money in)', 'क्रेडिट (पैसा आया)', 'क्रेडिट (पैसे आले)', 'ক্রেডিট (টাকা এসেছে)', 'క్రెడిట్ (డబ్బు వచ్చింది)', 'வரவு (பணம் உள்ளே)');
  String get stRoleAmount => _t('Amount', 'राशि', 'रक्कम', 'পরিমাণ', 'మొత్తం', 'தொகை');
  String get stRoleDrCr => _t(
        'Debit/credit marker',
        'डेबिट/क्रेडिट चिह्न',
        'डेबिट/क्रेडिट खूण',
        'ডেবিট/ক্রেডিট চিহ্ন',
        'డెబిట్/క్రెడిట్ గుర్తు',
        'பற்று/வரவு குறி',
      );
  String get stRoleRefNo =>
      _t('Reference no.', 'संदर्भ सं.', 'संदर्भ क्र.', 'রেফারেন্স নং', 'రిఫరెన్స్ నం.', 'குறிப்பு எண்.');
  String get stRoleBalance => _t(
        'Balance (not stored)',
        'बैलेंस (सहेजा नहीं जाता)',
        'बॅलन्स (जतन होत नाही)',
        'ব্যালেন্স (সংরক্ষিত হয় না)',
        'బ్యాలెన్స్ (నిల్వ చేయబడదు)',
        'இருப்பு (சேமிக்கப்படவில்லை)',
      );
  String get stRoleIgnore => _t('Ignore', 'छोड़ें', 'वगळा', 'বাদ দিন', 'విస్మరించు', 'புறக்கணி');
  String get stMappingIncomplete => _t(
        'Pick a date column and at least one amount column to continue.',
        'आगे बढ़ने के लिए एक तारीख़ कॉलम और कम से कम एक राशि कॉलम चुनें।',
        'पुढे जाण्यासाठी एक तारीख कॉलम आणि किमान एक रक्कम कॉलम निवडा.',
        'এগোতে একটি তারিখ কলাম এবং অন্তত একটি পরিমাণ কলাম বেছে নিন।',
        'కొనసాగించడానికి ఒక తేదీ కాలమ్ మరియు కనీసం ఒక మొత్తం కాలమ్ ఎంచుకోండి.',
        'தொடர, ஒரு தேதி நெடுவரிசையையும் குறைந்தது ஒரு தொகை நெடுவரிசையையும் தேர்ந்தெடுக்கவும்.',
      );
  String get stNoDateFormat => _t(
        "Couldn't read the dates in this file — check which column is the "
            'date.',
        'इस फ़ाइल की तारीख़ें पढ़ी नहीं जा सकीं — देखें कि तारीख़ कौन-सा कॉलम है।',
        'या फाइलमधील तारखा वाचता आल्या नाहीत — तारीख कोणता कॉलम आहे ते तपासा.',
        'এই ফাইলের তারিখগুলো পড়া যায়নি — কোন কলামটি তারিখ তা দেখুন।',
        'ఈ ఫైల్‌లోని తేదీలను చదవలేకపోయాం — ఏ కాలమ్ తేదీయో తనిఖీ చేయండి.',
        'இந்த கோப்பில் உள்ள தேதிகளைப் படிக்க முடியவில்லை — எந்த நெடுவரிசை தேதி என்பதைச் சரிபார்க்கவும்.',
      );
  String get stSampleTitle =>
      _t('Preview', 'पूर्वावलोकन', 'पूर्वावलोकन', 'প্রিভিউ', 'ప్రివ్యూ', 'முன்னோட்டம்');
  String get stContinue =>
      _t('Continue', 'जारी रखें', 'पुढे चला', 'চালিয়ে যান', 'కొనసాగించు', 'தொடரவும்');
  String stReadyCount(int n) =>
      _t('$n new', '$n नए', '$n नवीन', '$n টি নতুন', '$n కొత్తవి', '$n புதியவை');
  String stDupCount(int n) => _t(
        '$n possible duplicates',
        '$n संभावित डुप्लिकेट',
        '$n संभाव्य डुप्लिकेट',
        '$n টি সম্ভাব্য ডুপ্লিকেট',
        '$n సాధ్యమైన నకిలీలు',
        '$n சாத்தியமான நகல்கள்',
      );
  String stInvalidCount(int n) => _t(
      '$n unreadable', '$n अपठनीय', '$n न वाचता येणारे', '$n টি অপাঠ্য', '$n చదవలేనివి', '$n படிக்க முடியாதவை');
  String get stDateRangeTitle =>
      _t('Import between', 'इस अवधि में', 'या कालावधीत', 'এই সময়ের মধ্যে', 'ఈ కాలంలో దిగుమతి', 'இந்தக் காலத்தில் இறக்குமதி');
  String stSmsEraNote(String date) => _t(
        'SMS tracking on this phone began $date. Statement rows after that '
            'are usually already tracked, so they start unticked.',
        'इस फ़ोन पर SMS ट्रैकिंग $date से शुरू हुई। उसके बाद की पंक्तियाँ '
            'आमतौर पर पहले से दर्ज हैं, इसलिए वे बिना टिक के हैं।',
        'या फोनवर SMS ट्रॅकिंग $date पासून सुरू झाले. त्यानंतरच्या ओळी सहसा '
            'आधीच नोंदलेल्या असतात, म्हणून त्या टिक न करता आहेत.',
        'এই ফোনে SMS ট্র্যাকিং $date থেকে শুরু হয়েছে। তার পরের সারিগুলো '
            'সাধারণত আগে থেকেই আছে, তাই সেগুলো টিক ছাড়া আছে।',
        'ఈ ఫోన్‌లో SMS ట్రాకింగ్ $date నుండి ప్రారంభమైంది. ఆ తర్వాతి స్టేట్‌మెంట్ వరుసలు సాధారణంగా ఇప్పటికే ట్రాక్ అయి ఉంటాయి, కాబట్టి అవి టిక్ లేకుండా మొదలవుతాయి.',
        'இந்த ஃபோனில் SMS கண்காணிப்பு $date இல் தொடங்கியது. அதற்குப் பிறகான அறிக்கை வரிசைகள் பொதுவாக ஏற்கனவே கண்காணிக்கப்படுகின்றன, எனவே அவை டிக் இல்லாமல் தொடங்குகின்றன.',
      );
  String get stNewRowsTitle =>
      _t('Will import', 'इंपोर्ट होंगे', 'इंपोर्ट होतील', 'ইম্পোর্ট হবে', 'దిగుమతి అవుతుంది', 'இறக்குமதி செய்யப்படும்');
  String stDebitsCredits(int d, int c) => _t(
        '$d debits · $c credits',
        '$d डेबिट · $c क्रेडिट',
        '$d डेबिट · $c क्रेडिट',
        '$d ডেবিট · $c ক্রেডিট',
        '$d డెబిట్‌లు · $c క్రెడిట్‌లు',
        '$d பற்றுகள் · $c வரவுகள்',
      );
  String get stDuplicatesTitle => _t(
      'Possible duplicates', 'संभावित डुप्लिकेट', 'संभाव्य डुप्लिकेट', 'সম্ভাব্য ডুপ্লিকেট', 'సాధ్యమైన నకిలీలు', 'சாத்தியமான நகல்கள்');
  String get stDuplicatesDesc => _t(
        'These match the amount and date of transactions already on this '
            'device — usually the SMS copy of the same spend. Tick any that '
            'are genuinely new.',
        'ये राशि और तारीख़ में इस डिवाइस पर पहले से मौजूद लेन-देन से मिलते हैं — '
            'आमतौर पर उसी खर्च की SMS प्रति। जो वाकई नए हों उन्हें टिक करें।',
        'हे रक्कम व तारखेत या डिव्हाइसवर आधीच असलेल्या व्यवहारांशी जुळतात — '
            'सहसा त्याच खर्चाची SMS प्रत. खरोखर नवीन असतील ते टिक करा.',
        'এগুলো পরিমাণ ও তারিখে এই ডিভাইসে আগে থেকে থাকা লেনদেনের সাথে মেলে — '
            'সাধারণত একই খরচের SMS কপি। যেগুলো সত্যিই নতুন সেগুলোতে টিক দিন।',
        'ఇవి ఈ పరికరంలో ఇప్పటికే ఉన్న లావాదేవీల మొత్తం మరియు తేదీతో సరిపోలతాయి — సాధారణంగా అదే ఖర్చు యొక్క SMS కాపీ. నిజంగా కొత్తవి ఏవైనా ఉంటే వాటికి టిక్ చేయండి.',
        'இவை இந்த சாதனத்தில் ஏற்கனவே உள்ள பரிவர்த்தனைகளின் தொகை மற்றும் தேதியுடன் பொருந்துகின்றன — பொதுவாக அதே செலவின் SMS நகல். உண்மையிலேயே புதியவை எவையேனும் இருந்தால் அவற்றைத் டிக் செய்யுங்கள்.',
      );
  String get stInvalidTitle => _t(
      'Unreadable rows', 'अपठनीय पंक्तियाँ', 'न वाचता येणाऱ्या ओळी', 'অপাঠ্য সারি', 'చదవలేని వరుసలు', 'படிக்க முடியாத வரிசைகள்');
  String get stInvalidDateReason => _t(
        'No readable date',
        'तारीख़ नहीं पढ़ी जा सकी',
        'तारीख वाचता आली नाही',
        'তারিখ পড়া যায়নি',
        'చదవగలిగే తేదీ లేదు',
        'படிக்கக்கூடிய தேதி இல்லை',
      );
  String get stInvalidAmountReason => _t(
        'No readable amount',
        'राशि नहीं पढ़ी जा सकी',
        'रक्कम वाचता आली नाही',
        'পরিমাণ পড়া যায়নি',
        'చదవగలిగే మొత్తం లేదు',
        'படிக்கக்கூடிய தொகை இல்லை',
      );
  String stMoreRows(int n) =>
      _t('…and $n more', '…और $n', '…आणखी $n', '…আরও $n টি', '…మరో $n', '…மேலும் $n');
  String stImportButton(int n) => _t(
        'Import $n ${n == 1 ? 'transaction' : 'transactions'}',
        '$n लेन-देन इंपोर्ट करें',
        '$n व्यवहार इंपोर्ट करा',
        '$n টি লেনদেন ইম্পোর্ট করুন',
        '$n లావాదేవీలను దిగుమతి చేయి',
        '$n பரிவர்த்தனைகளை இறக்குமதி செய்',
      );
  String get stResultTitle => _t(
      'Import complete', 'इंपोर्ट पूरा हुआ', 'इंपोर्ट पूर्ण झाले', 'ইম্পোর্ট সম্পন্ন', 'దిగుమతి పూర్తయింది', 'இறக்குமதி முடிந்தது');
  String stResultInserted(int n) => _t(
        '$n ${n == 1 ? 'transaction' : 'transactions'} imported',
        '$n लेन-देन इंपोर्ट हुए',
        '$n व्यवहार इंपोर्ट झाले',
        '$n টি লেনদেন ইম্পোর্ট হয়েছে',
        '$n లావాదేవీలు దిగుమతి చేయబడ్డాయి',
        '$n பரிவர்த்தனைகள் இறக்குமதி செய்யப்பட்டன',
      );
  String stResultSkipped(int n) => _t(
        '$n already existed — skipped',
        '$n पहले से मौजूद थे — छोड़े गए',
        '$n आधीच होते — वगळले',
        '$n টি আগে থেকেই ছিল — বাদ গেছে',
        '$n ఇప్పటికే ఉన్నాయి — దాటవేయబడ్డాయి',
        '$n ஏற்கனவே இருந்தன — தவிர்க்கப்பட்டன',
      );
  String stResultTagged(int n) => _t(
        '$n auto-tagged by your rules',
        '$n आपके नियमों से ऑटो-टैग हुए',
        '$n तुमच्या नियमांनी ऑटो-टॅग झाले',
        '$n টি আপনার নিয়মে অটো-ট্যাগ হয়েছে',
        '$n మీ రూల్స్ ద్వారా ఆటో-ట్యాగ్ చేయబడ్డాయి',
        '$n உங்கள் விதிகளால் தானாகக் குறிச்சொல் இடப்பட்டன',
      );
  String get stDone => _t('Done', 'हो गया', 'झाले', 'সম্পন্ন', 'పూర్తయింది', 'முடிந்தது');
  String stImportedToast(int inserted, int tagged) => tagged > 0
      ? _t(
          'Imported $inserted ${inserted == 1 ? 'transaction' : 'transactions'} · $tagged auto-tagged',
          '$inserted लेन-देन इंपोर्ट हुए · $tagged ऑटो-टैग',
          '$inserted व्यवहार इंपोर्ट झाले · $tagged ऑटो-टॅग',
          '$inserted টি লেনদেন ইম্পোর্ট · $tagged টি অটো-ট্যাগ',
          '$inserted లావాదేవీలు దిగుమతి · $tagged ఆటో-ట్యాగ్',
          '$inserted பரிவர்த்தனைகள் இறக்குமதி · $tagged தானாகக் குறிச்சொல்',
        )
      : _t(
          'Imported $inserted ${inserted == 1 ? 'transaction' : 'transactions'}',
          '$inserted लेन-देन इंपोर्ट हुए',
          '$inserted व्यवहार इंपोर्ट झाले',
          '$inserted টি লেনদেন ইম্পোর্ট হয়েছে',
          '$inserted లావాదేవీలు దిగుమతి చేయబడ్డాయి',
          '$inserted பரிவர்த்தனைகள் இறக்குமதி செய்யப்பட்டன',
        );
  String get stPdfComingSoon => _t(
        'PDF import is coming soon — download the CSV or Excel statement '
            'from your bank instead.',
        'PDF इंपोर्ट जल्द आ रहा है — फ़िलहाल बैंक से CSV या Excel स्टेटमेंट '
            'डाउनलोड करें।',
        'PDF इंपोर्ट लवकरच येत आहे — सध्या बँकेकडून CSV किंवा Excel स्टेटमेंट '
            'डाउनलोड करा.',
        'PDF ইম্পোর্ট শীঘ্রই আসছে — আপাতত ব্যাংক থেকে CSV বা Excel স্টেটমেন্ট '
            'ডাউনলোড করুন।',
        'PDF దిగుమతి త్వరలో వస్తోంది — ప్రస్తుతానికి మీ బ్యాంక్ నుండి CSV లేదా Excel స్టేట్‌మెంట్ డౌన్‌లోడ్ చేయండి.',
        'PDF இறக்குமதி விரைவில் வருகிறது — தற்போதைக்கு உங்கள் வங்கியிலிருந்து CSV அல்லது Excel அறிக்கையைப் பதிவிறக்கவும்.',
      );
  String get stXlsUnsupported => _t(
        "Old Excel (.xls) files can't be read — export the statement as CSV "
            'or .xlsx instead.',
        'पुरानी Excel (.xls) फ़ाइलें नहीं पढ़ी जा सकतीं — स्टेटमेंट CSV या '
            '.xlsx में एक्सपोर्ट करें।',
        'जुन्या Excel (.xls) फाइली वाचता येत नाहीत — स्टेटमेंट CSV किंवा '
            '.xlsx मध्ये एक्सपोर्ट करा.',
        'পুরনো Excel (.xls) ফাইল পড়া যায় না — স্টেটমেন্ট CSV বা .xlsx '
            'হিসেবে এক্সপোর্ট করুন।',
        'పాత Excel (.xls) ఫైల్‌లను చదవలేము — బదులుగా స్టేట్‌మెంట్‌ను CSV లేదా .xlsx గా ఎగుమతి చేయండి.',
        'பழைய Excel (.xls) கோப்புகளைப் படிக்க முடியாது — அதற்குப் பதிலாக அறிக்கையை CSV அல்லது .xlsx ஆக ஏற்றுமதி செய்யுங்கள்.',
      );
  String get stNoTable => _t(
        "Couldn't find a transaction table in this file. Export the "
            'statement as CSV or Excel and try again.',
        'इस फ़ाइल में लेन-देन की तालिका नहीं मिली। स्टेटमेंट CSV या Excel में '
            'एक्सपोर्ट करके फिर कोशिश करें।',
        'या फाइलमध्ये व्यवहारांची सारणी सापडली नाही. स्टेटमेंट CSV किंवा '
            'Excel मध्ये एक्सपोर्ट करून पुन्हा प्रयत्न करा.',
        'এই ফাইলে লেনদেনের টেবিল পাওয়া যায়নি। স্টেটমেন্ট CSV বা Excel '
            'হিসেবে এক্সপোর্ট করে আবার চেষ্টা করুন।',
        'ఈ ఫైల్‌లో లావాదేవీ పట్టిక కనబడలేదు. స్టేట్‌మెంట్‌ను CSV లేదా Excel గా ఎగుమతి చేసి మళ్లీ ప్రయత్నించండి.',
        'இந்த கோப்பில் பரிவர்த்தனை அட்டவணை கிடைக்கவில்லை. அறிக்கையை CSV அல்லது Excel ஆக ஏற்றுமதி செய்து மீண்டும் முயற்சிக்கவும்.',
      );
  String get dataPrivateTitle =>
      _t('Your Data is Private', 'आपका डेटा निजी है', 'तुमचा डेटा खाजगी आहे', 'আপনার ডেটা ব্যক্তিগত', 'మీ డేటా గోప్యం', 'உங்கள் தரவு தனிப்பட்டது');
  String get dataPrivateDesc => _t(
        'All data stays on your device. We do not collect or upload any information.',
        'सारा डेटा आपके डिवाइस पर रहता है। हम कोई जानकारी एकत्र या अपलोड नहीं करते।',
        'सर्व डेटा तुमच्या डिव्हाइसवर राहतो. आम्ही कोणतीही माहिती गोळा किंवा अपलोड करत नाही.',
        'সব ডেটা আপনার ডিভাইসে থাকে। আমরা কোনো তথ্য সংগ্রহ বা আপলোড করি না।',
        'అన్ని డేటా మీ పరికరంలోనే ఉంటుంది. మేము ఏ సమాచారాన్ని సేకరించము లేదా అప్‌లోడ్ చేయము.',
        'அனைத்து தரவும் உங்கள் சாதனத்தில் இருக்கும். நாங்கள் எந்தத் தகவலையும் சேகரிக்கவோ பதிவேற்றவோ இல்லை.',
      );
  String versionLabel(String v) => _t('Version $v', 'संस्करण $v', 'आवृत्ती $v', 'সংস্করণ $v', 'వెర్షన్ $v', 'பதிப்பு $v');

  // ── Settings · Backup / restore / export flow ─────────────────────────────
  String get setBackupPassphrase =>
      _t('Set Backup Passphrase', 'बैकअप पासफ़्रेज़ सेट करें', 'बॅकअप पासफ्रेज सेट करा', 'ব্যাকআপ পাসফ্রেজ সেট করুন', 'బ్యాకప్ పాస్‌ఫ్రేజ్ సెట్ చేయి', 'காப்புப்பிரதி கடவுச்சொற்றொடரை அமை');
  String get enterPassphrase =>
      _t('Enter Passphrase', 'पासफ़्रेज़ दर्ज करें', 'पासफ्रेज प्रविष्ट करा', 'পাসফ্রেজ লিখুন', 'పాస్‌ఫ్రేజ్ నమోదు చేయి', 'கடவுச்சொற்றொடரை உள்ளிடு');
  String get setPassphraseDesc => _t(
        'Your backup is encrypted with this passphrase. Without it the '
            'backup cannot be restored — there is no recovery.',
        'आपका बैकअप इस पासफ़्रेज़ से एन्क्रिप्ट होता है। इसके बिना बैकअप '
            'पुनर्स्थापित नहीं किया जा सकता — कोई रिकवरी नहीं है।',
        'तुमचा बॅकअप या पासफ्रेजने एन्क्रिप्ट होतो. याशिवाय बॅकअप '
            'पुनर्संचयित करता येत नाही — रिकव्हरी नाही.',
        'আপনার ব্যাকআপ এই পাসফ্রেজ দিয়ে এনক্রিপ্ট করা হয়। এটি ছাড়া ব্যাকআপ '
            'পুনরুদ্ধার করা যায় না — কোনো রিকভারি নেই।',
        'మీ బ్యాకప్ ఈ పాస్‌ఫ్రేజ్‌తో ఎన్‌క్రిప్ట్ చేయబడుతుంది. ఇది లేకుండా బ్యాకప్‌ను పునరుద్ధరించలేము — రికవరీ లేదు.',
        'உங்கள் காப்புப்பிரதி இந்தக் கடவுச்சொற்றொடர் மூலம் மறையாக்கப்படுகிறது. இது இல்லாமல் காப்புப்பிரதியை மீட்டமைக்க முடியாது — மீட்பு இல்லை.',
      );
  String get enterPassphraseDesc => _t(
        'Enter the passphrase this backup was created with.',
        'वह पासफ़्रेज़ दर्ज करें जिससे यह बैकअप बनाया गया था।',
        'हा बॅकअप ज्या पासफ्रेजने तयार केला तो प्रविष्ट करा.',
        'এই ব্যাকআপ যে পাসফ্রেজ দিয়ে তৈরি হয়েছিল তা লিখুন।',
        'ఈ బ్యాకప్ ఏ పాస్‌ఫ్రేజ్‌తో సృష్టించబడిందో దాన్ని నమోదు చేయండి.',
        'இந்த காப்புப்பிரதி எந்தக் கடவுச்சொற்றொடருடன் உருவாக்கப்பட்டதோ அதை உள்ளிடுங்கள்.',
      );
  String get passphrase => _t('Passphrase', 'पासफ़्रेज़', 'पासफ्रेज', 'পাসফ্রেজ', 'పాస్‌ఫ్రేజ్', 'கடவுச்சொற்றொடர்');
  String get atLeast6Chars =>
      _t('At least 6 characters', 'कम से कम 6 अक्षर', 'किमान 6 अक्षरे', 'কমপক্ষে 6টি অক্ষর', 'కనీసం 6 అక్షరాలు', 'குறைந்தது 6 எழுத்துகள்');
  String get confirmPassphrase =>
      _t('Confirm passphrase', 'पासफ़्रेज़ की पुष्टि करें', 'पासफ्रेजची पुष्टी करा', 'পাসফ্রেজ নিশ্চিত করুন', 'పాస్‌ఫ్రేజ్ నిర్ధారించండి', 'கடவுச்சொற்றொடரை உறுதிப்படுத்து');
  String get passphrasesDontMatch =>
      _t("Passphrases don't match", 'पासफ़्रेज़ मेल नहीं खाते', 'पासफ्रेज जुळत नाहीत', 'পাসফ্রেজ মিলছে না', 'పాస్‌ఫ్రేజ్‌లు సరిపోలడం లేదు', 'கடவுச்சொற்றொடர்கள் பொருந்தவில்லை');
  String get encryptingBackup =>
      _t('Encrypting backup…', 'बैकअप एन्क्रिप्ट हो रहा है…', 'बॅकअप एन्क्रिप्ट होत आहे…', 'ব্যাকআপ এনক্রিপ্ট করা হচ্ছে…', 'బ్యాకప్ ఎన్‌క్రిప్ట్ అవుతోంది…', 'காப்புப்பிரதி மறையாக்கப்படுகிறது…');
  String get encryptedBackupSaved => _t(
      'Encrypted backup saved', 'एन्क्रिप्टेड बैकअप सहेजा गया', 'एन्क्रिप्टेड बॅकअप जतन केला', 'এনক্রিপ্ট করা ব্যাকআপ সেভ হয়েছে', 'ఎన్‌క్రిప్టెడ్ బ్యాకప్ సేవ్ అయింది', 'மறையாக்கப்பட்ட காப்புப்பிரதி சேமிக்கப்பட்டது');
  String get open => _t('Open', 'खोलें', 'उघडा', 'খুলুন', 'తెరువు', 'திற');
  String backupFailed(String e) =>
      _t('Backup failed: $e', 'बैकअप विफल: $e', 'बॅकअप अयशस्वी: $e', 'ব্যাকআপ ব্যর্থ: $e', 'బ్యాకప్ విఫలమైంది: $e', 'காப்புப்பிரதி தோல்வியடைந்தது: $e');
  String get decryptingRestoring => _t('Decrypting and restoring…',
      'डिक्रिप्ट और पुनर्स्थापित हो रहा है…', 'डिक्रिप्ट व पुनर्संचयित होत आहे…', 'ডিক্রিপ্ট ও পুনরুদ্ধার করা হচ্ছে…', 'డిక్రిప్ట్ చేసి పునరుద్ధరిస్తోంది…', 'மறைநீக்கம் செய்து மீட்டமைக்கிறது…');
  String get backupRestoredNothing => _t(
        'Backup restored — everything was already on this device',
        'बैकअप पुनर्स्थापित — सब कुछ पहले से इस डिवाइस पर था',
        'बॅकअप पुनर्संचयित — सर्व काही आधीच या डिव्हाइसवर होते',
        'ব্যাকআপ পুনরুদ্ধার — সবকিছু আগে থেকেই এই ডিভাইসে ছিল',
        'బ్యాకప్ పునరుద్ధరించబడింది — అంతా ఇప్పటికే ఈ పరికరంలో ఉంది',
        'காப்புப்பிரதி மீட்டமைக்கப்பட்டது — அனைத்தும் ஏற்கனவே இந்த சாதனத்தில் இருந்தன',
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
        'पुनर्संचयित: $transactions व्यवहार, $budgets बजेट, $rules नियम, '
            '$holdings होल्डिंग्ज, $sips SIP',
        'পুনরুদ্ধার: $transactions লেনদেন, $budgets বাজেট, $rules নিয়ম, '
            '$holdings হোল্ডিং, $sips SIP',
        'పునరుద్ధరించబడింది: $transactions లావాదేవీలు, $budgets బడ్జెట్లు, $rules రూల్స్, $holdings హోల్డింగ్‌లు, $sips SIPలు',
        'மீட்டமைக்கப்பட்டது: $transactions பரிவர்த்தனைகள், $budgets பட்ஜெட்கள், $rules விதிகள், $holdings ஹோல்டிங்குகள், $sips SIPகள்',
      );
  String restoreFailed(String e) =>
      _t('Restore failed: $e', 'पुनर्स्थापना विफल: $e', 'पुनर्संचयन अयशस्वी: $e', 'পুনরুদ্ধার ব্যর্থ: $e', 'పునరుద్ధరణ విఫలమైంది: $e', 'மீட்டமைப்பு தோல்வியடைந்தது: $e');
  String get noTxnMatchFilters => _t(
        'No transactions match those filters',
        'उन फ़िल्टर से कोई लेन-देन मेल नहीं खाता',
        'त्या फिल्टरशी कोणताही व्यवहार जुळत नाही',
        'ওই ফিল্টারের সাথে কোনো লেনদেন মেলে না',
        'ఆ ఫిల్టర్‌లతో ఏ లావాదేవీలు సరిపోలడం లేదు',
        'அந்த வடிகட்டிகளுடன் எந்தப் பரிவர்த்தனையும் பொருந்தவில்லை',
      );
  String get exporting => _t('Exporting…', 'एक्सपोर्ट हो रहा है…', 'एक्सपोर्ट होत आहे…', 'এক্সপোর্ট করা হচ্ছে…', 'ఎగుమతి అవుతోంది…', 'ஏற்றுமதி செய்கிறது…');
  String savedToDownloads(String file) => _t(
      'Saved to Downloads/$file', 'Downloads/$file में सहेजा गया', 'Downloads/$file मध्ये जतन केले', 'Downloads/$file-এ সেভ হয়েছে', 'Downloads/$file కు సేవ్ అయింది', 'Downloads/$file இல் சேமிக்கப்பட்டது');
  String exportSavedAs(String file) => _t(
      'Saved $file', '$file सहेजा गया', '$file जतन केले', '$file সেভ হয়েছে', '$file సేవ్ అయింది', '$file சேமிக்கப்பட்டது');
  String exportFailed(String e) =>
      _t('Export failed: $e', 'एक्सपोर्ट विफल: $e', 'एक्सपोर्ट अयशस्वी: $e', 'এক্সপোর্ট ব্যর্থ: $e', 'ఎగుమతి విఫలమైంది: $e', 'ஏற்றுமதி தோல்வியடைந்தது: $e');
  String get storagePermissionRequired => _t(
        'Storage permission is required to export data',
        'डेटा एक्सपोर्ट करने के लिए स्टोरेज अनुमति आवश्यक है',
        'डेटा एक्सपोर्ट करण्यासाठी स्टोरेज परवानगी आवश्यक आहे',
        'ডেটা এক্সপোর্ট করতে স্টোরেজ অনুমতি প্রয়োজন',
        'డేటాను ఎగుమతి చేయడానికి స్టోరేజ్ అనుమతి అవసరం',
        'தரவை ஏற்றுமதி செய்ய சேமிப்பக அனுமதி தேவை',
      );

  // ── Budgets & Analytics ───────────────────────────────────────────────────
  String get budgetAndAnalytics =>
      _t('Budget & Analytics', 'बजट और विश्लेषण', 'बजेट आणि विश्लेषण', 'বাজেট ও বিশ্লেষণ', 'బడ్జెట్ & విశ్లేషణ', 'பட்ஜெட் & பகுப்பாய்வு');
  String get tabOverview => _t('Overview', 'अवलोकन', 'आढावा', 'সংক্ষিপ্ত চিত্র', 'సమగ్ర చిత్రం', 'கண்ணோட்டம்');
  String get tabCalendar => _t('Calendar', 'कैलेंडर', 'कॅलेंडर', 'ক্যালেন্ডার', 'క్యాలెండర్', 'நாட்காட்டி');
  String get tabCategories => _t('Categories', 'श्रेणियाँ', 'श्रेण्या', 'বিভাগসমূহ', 'వర్గాలు', 'வகைகள்');
  String get tabTrends => _t('Trends', 'रुझान', 'कल', 'প্রবণতা', 'ధోరణులు', 'போக்குகள்');
  String get setBudget => _t('Set Budget', 'बजट सेट करें', 'बजेट सेट करा', 'বাজেট সেট করুন', 'బడ్జెట్ సెట్ చేయి', 'பட்ஜெட் அமை');
  String get swipeForOtherMonths => _t(
      'Swipe for other months', 'अन्य महीनों के लिए स्वाइप करें', 'इतर महिन्यांसाठी स्वाइप करा', 'অন্য মাসের জন্য সোয়াইপ করুন', 'ఇతర నెలల కోసం స్వైప్ చేయండి', 'மற்ற மாதங்களுக்கு ஸ்வைப் செய்யுங்கள்');
  String noActivityIn(String monthYear) => _t('No activity in $monthYear',
      '$monthYear में कोई गतिविधि नहीं', '$monthYear मध्ये कोणतीही हालचाल नाही', '$monthYear-এ কোনো কার্যকলাপ নেই', '$monthYear లో ఏ కార్యకలాపం లేదు', '$monthYear இல் எந்த செயல்பாடும் இல்லை');
  String get whereItWent => _t('Where it went', 'पैसा कहाँ गया', 'पैसे कुठे गेले', 'টাকা কোথায় গেল', 'ఎక్కడికి వెళ్లింది', 'எங்கு சென்றது');
  String budgetOf(String amount) => _t('of $amount', '$amount में से', '$amount पैकी', '$amount-এর মধ্যে', '$amount లో', '$amount இல்');
  String amountLeft(String amount) => _t('$amount left', '$amount बचे', '$amount शिल्लक', '$amount বাকি', '$amount మిగిలింది', '$amount மீதம்');
  String amountOver(String amount) => _t('$amount over!', '$amount अधिक!', '$amount जास्त!', '$amount বেশি!', '$amount ఎక్కువైంది!', '$amount அதிகம்!');
  String get topMerchants => _t('Top merchants', 'शीर्ष व्यापारी', 'आघाडीचे व्यापारी', 'শীর্ষ বিক্রেতা', 'టాప్ మర్చెంట్‌లు', 'சிறந்த வணிகர்கள்');
  String get seeAllLower => _t('See all', 'सभी देखें', 'सर्व पाहा', 'সব দেখুন', 'అన్నీ చూడు', 'அனைத்தையும் காண்க');
  String get dailySpending => _t('Daily Spending', 'दैनिक खर्च', 'दैनिक खर्च', 'দৈনিক খরচ', 'రోజువారీ ఖర్చు', 'தினசரி செலவு');
  String get noDataYet => _t('No data yet', 'अभी कोई डेटा नहीं', 'अजून डेटा नाही', 'এখনও কোনো ডেটা নেই', 'ఇంకా డేటా లేదు', 'இன்னும் தரவு இல்லை');
  String get noSpendingThisMonth => _t('No spending data for this month',
      'इस महीने का कोई खर्च डेटा नहीं', 'या महिन्याचा खर्च डेटा नाही', 'এই মাসের কোনো খরচ ডেটা নেই', 'ఈ నెలకు ఖర్చు డేటా లేదు', 'இந்த மாதத்திற்கு செலவு தரவு இல்லை');
  String get noHistoricalData => _t(
      'No historical data available', 'कोई ऐतिहासिक डेटा उपलब्ध नहीं', 'ऐतिहासिक डेटा उपलब्ध नाही', 'কোনো ঐতিহাসিক ডেটা নেই', 'చారిత్రక డేటా అందుబాటులో లేదు', 'வரலாற்று தரவு எதுவும் இல்லை');
  String get monthlySpendingTrend =>
      _t('Monthly Spending Trend', 'मासिक खर्च का रुझान', 'मासिक खर्चाचा कल', 'মাসিক খরচের প্রবণতা', 'నెలవారీ ఖర్చు ధోరణి', 'மாதாந்திர செலவு போக்கு');
  String get nowBadge => _t('NOW', 'अभी', 'आत्ता', 'এখন', 'ఇప్పుడు', 'இப்போது');
  String get categoryBudgets => _t('Category Budgets', 'श्रेणी बजट', 'श्रेणी बजेट', 'বিভাগ বাজেট', 'వర్గ బడ్జెట్లు', 'வகை பட்ஜெட்கள்');
  String get add => _t('Add', 'जोड़ें', 'जोडा', 'যোগ করুন', 'జోడించు', 'சேர்');
  String get categoryBudgetsEmptyDesc => _t(
        'Set a monthly limit for individual categories like Food or Shopping, '
            'and track exactly where the money goes.',
        'भोजन या खरीदारी जैसी अलग-अलग श्रेणियों के लिए मासिक सीमा तय करें, '
            'और देखें कि पैसा कहाँ जाता है।',
        'अन्न किंवा खरेदीसारख्या वेगवेगळ्या श्रेणींसाठी मासिक मर्यादा ठरवा, '
            'आणि पैसे नेमके कुठे जातात ते पाहा.',
        'খাবার বা শপিংয়ের মতো আলাদা আলাদা বিভাগের জন্য মাসিক সীমা ঠিক করুন, '
            'এবং টাকা ঠিক কোথায় যায় তা ট্র্যাক করুন।',
        'ఆహారం లేదా షాపింగ్ వంటి వ్యక్తిగత వర్గాలకు నెలవారీ పరిమితిని సెట్ చేయండి, మరియు డబ్బు సరిగ్గా ఎక్కడికి వెళ్తుందో ట్రాక్ చేయండి.',
        'உணவு அல்லது ஷாப்பிங் போன்ற தனிப்பட்ட வகைகளுக்கு மாதாந்திர வரம்பை அமைத்து, பணம் சரியாக எங்கு செல்கிறது என்பதைக் கண்காணியுங்கள்.',
      );
  String setBudgetForCategory(String category) => _t('Set a budget for $category?',
      '$category के लिए बजट सेट करें?', '$category साठी बजेट सेट करायचे?', '$category-এর জন্য বাজেট সেট করবেন?', '$category కోసం బడ్జెట్ సెట్ చేయాలా?', '$category க்கு பட்ஜெட் அமைக்கவா?');
  String suggestionMostTagged(int count) => _t(
        "It's your most-tagged spend this month ($count transactions). "
            'A monthly limit keeps it in check.',
        'इस महीने इसी पर सबसे ज़्यादा खर्च हुआ ($count लेन-देन)। '
            'मासिक सीमा इसे नियंत्रण में रखती है।',
        'या महिन्यात याच्यावरच सर्वाधिक खर्च झाला ($count व्यवहार). '
            'मासिक मर्यादा हे नियंत्रणात ठेवते.',
        'এই মাসে এতেই সবচেয়ে বেশি খরচ হয়েছে ($count লেনদেন)। '
            'মাসিক সীমা এটিকে নিয়ন্ত্রণে রাখে।',
        'ఈ నెలలో ఇదే మీ అత్యధికంగా ట్యాగ్ చేసిన ఖర్చు ($count లావాదేవీలు). నెలవారీ పరిమితి దీన్ని అదుపులో ఉంచుతుంది.',
        'இந்த மாதம் இதுவே உங்கள் அதிகம் குறிச்சொல் இட்ட செலவு ($count பரிவர்த்தனைகள்). மாதாந்திர வரம்பு இதைக் கட்டுக்குள் வைக்கிறது.',
      );
  String get setBudgetLower => _t('Set budget', 'बजट सेट करें', 'बजेट सेट करा', 'বাজেট সেট করুন', 'బడ్జెట్ సెట్ చేయి', 'பட்ஜெட் அமை');
  String get notNow => _t('Not now', 'अभी नहीं', 'आत्ता नको', 'এখন নয়', 'ఇప్పుడు కాదు', 'இப்போது வேண்டாம்');
  String budgetSpentOf(String spent, String total) =>
      _t('$spent of $total', '$total में से $spent', '$total पैकी $spent', '$total-এর মধ্যে $spent', '$total లో $spent', '$total இல் $spent');
  String get over => _t('over', 'अधिक', 'जास्त', 'বেশি', 'ఎక్కువ', 'அதிகம்');
  String get everyCategoryHasBudget => _t(
        'Every category already has a budget',
        'हर श्रेणी का पहले से बजट है',
        'प्रत्येक श्रेणीला आधीच बजेट आहे',
        'প্রতিটি বিভাগের ইতিমধ্যে বাজেট আছে',
        'ప్రతి వర్గానికి ఇప్పటికే బడ్జెట్ ఉంది',
        'ஒவ்வொரு வகைக்கும் ஏற்கனவே பட்ஜெட் உள்ளது',
      );
  String get newCategoryBudget =>
      _t('New category budget', 'नया श्रेणी बजट', 'नवीन श्रेणी बजेट', 'নতুন বিভাগ বাজেট', 'కొత్త వర్గ బడ్జెట్', 'புதிய வகை பட்ஜெட்');
  String get newCategoryBudgetDesc => _t(
        'Set a monthly limit for one category. Alerts fire at 50, 75, 90 and 100%+.',
        'एक श्रेणी के लिए मासिक सीमा तय करें। 50, 75, 90 और 100%+ पर अलर्ट मिलते हैं।',
        'एका श्रेणीसाठी मासिक मर्यादा ठरवा. 50, 75, 90 आणि 100%+ वर सूचना मिळतात.',
        'একটি বিভাগের জন্য মাসিক সীমা ঠিক করুন। 50, 75, 90 এবং 100%+ এ সতর্কতা আসে।',
        'ఒక వర్గానికి నెలవారీ పరిమితిని సెట్ చేయండి. 50, 75, 90 మరియు 100%+ వద్ద హెచ్చరికలు వస్తాయి.',
        'ஒரு வகைக்கு மாதாந்திர வரம்பை அமையுங்கள். 50, 75, 90 மற்றும் 100%+ இல் எச்சரிக்கைகள் வரும்.',
      );
  String get monthlyAmount => _t('Monthly amount', 'मासिक राशि', 'मासिक रक्कम', 'মাসিক পরিমাণ', 'నెలవారీ మొత్తం', 'மாதாந்திர தொகை');
  String get category => _t('Category', 'श्रेणी', 'श्रेणी', 'বিভাগ', 'వర్గం', 'வகை');
  String categoryBudgetSet(String category) =>
      _t('$category budget set', '$category बजट सेट हुआ', '$category बजेट सेट झाले', '$category বাজেট সেট হয়েছে', '$category బడ్జెట్ సెట్ అయింది', '$category பட்ஜெட் அமைக்கப்பட்டது');
  String get editBudget => _t('Edit Budget', 'बजट संपादित करें', 'बजेट संपादित करा', 'বাজেট সম্পাদনা করুন', 'బడ్జెట్ సవరించు', 'பட்ஜெட்டைத் திருத்து');
  String get budgetDialogDesc => _t(
        'Track spending against a monthly limit. Self-transfers and '
            'investments are excluded automatically.',
        'मासिक सीमा के सापेक्ष खर्च ट्रैक करें। स्वयं-स्थानांतरण और '
            'निवेश स्वतः बाहर रखे जाते हैं।',
        'मासिक मर्यादेच्या तुलनेत खर्च ट्रॅक करा. स्वतः-हस्तांतरण आणि '
            'गुंतवणूक आपोआप वगळली जातात.',
        'মাসিক সীমার বিপরীতে খরচ ট্র্যাক করুন। নিজের অ্যাকাউন্টে স্থানান্তর ও '
            'বিনিয়োগ স্বয়ংক্রিয়ভাবে বাদ দেওয়া হয়।',
        'నెలవారీ పరిమితికి వ్యతిరేకంగా ఖర్చును ట్రాక్ చేయండి. సొంత బదిలీలు మరియు పెట్టుబడులు ఆటోమేటిక్‌గా మినహాయించబడతాయి.',
        'மாதாந்திர வரம்பிற்கு எதிராக செலவைக் கண்காணியுங்கள். சொந்த பரிமாற்றங்கள் மற்றும் முதலீடுகள் தானாகவே விலக்கப்படுகின்றன.',
      );
  String get name => _t('Name', 'नाम', 'नाव', 'নাম', 'పేరు', 'பெயர்');

  // ── Net Worth ─────────────────────────────────────────────────────────────
  String get addLabel => _t('Add', 'जोड़ें', 'जोडा', 'যোগ করুন', 'జోడించు', 'சேர்');
  String get netWorthLabel => _t('NET WORTH', 'नेट वर्थ', 'नेट वर्थ', 'নেট ওয়ার্থ', 'నెట్ వర్త్', 'நிகர மதிப்பு');
  String get assets => _t('Assets', 'संपत्ति', 'मालमत्ता', 'সম্পদ', 'ఆస్తులు', 'சொத்துகள்');
  String get liabilities => _t('Liabilities', 'देनदारियाँ', 'दायित्वे', 'দায়', 'అప్పులు', 'கடன்கள்');
  String get otherAssets => _t('Other assets', 'अन्य संपत्ति', 'इतर मालमत्ता', 'অন্যান্য সম্পদ', 'ఇతర ఆస్తులు', 'பிற சொத்துகள்');
  String get allocation => _t('Allocation', 'आवंटन', 'वाटप', 'বণ্টন', 'కేటాయింపు', 'ஒதுக்கீடு');
  String get investments => _t('Investments', 'निवेश', 'गुंतवणूक', 'বিনিয়োগ', 'పెట్టుబడులు', 'முதலீடுகள்');
  String instalmentsProgress(int completed, int total) => _t(
        '$completed of $total instalments',
        '$total में से $completed किस्तें',
        '$total पैकी $completed हप्ते',
        '$total টির মধ্যে $completed কিস্তি',
        '$total వాయిదాల్లో $completed',
        '$total தவணைகளில் $completed',
      );
  String get statusCompleted => _t('Completed', 'पूर्ण', 'पूर्ण', 'সম্পূর্ণ', 'పూర్తయింది', 'முடிந்தது');
  String get statusDue => _t('Due', 'बकाया', 'देय', 'বকেয়া', 'బకాయి', 'நிலுவை');
  String nextDue(DateTime d) => _t(
        'Next ${DateFormat('d MMM').format(d)}',
        'अगला ${d.day} ${_hiMonthsShort[d.month - 1]}',
        'पुढील ${d.day} ${_mrMonthsShort[d.month - 1]}',
        'পরবর্তী ${d.day} ${_bnMonthsShort[d.month - 1]}',
        'తదుపరి ${d.day} ${_teMonthsShort[d.month - 1]}',
        'அடுத்து ${d.day} ${_taMonthsShort[d.month - 1]}',
      );
  String get statusLogged => _t('Logged ✓', 'दर्ज ✓', 'नोंदवले ✓', 'নথিভুক্ত ✓', 'నమోదైంది ✓', 'பதிவு செய்யப்பட்டது ✓');
  String didYouInvestThisMonth(String amountPrefix) => _t(
        'Did you make your ${amountPrefix}investment this month?',
        'क्या आपने इस महीने अपना $amountPrefixनिवेश किया?',
        'तुम्ही या महिन्यात तुमची $amountPrefixगुंतवणूक केली का?',
        'আপনি কি এই মাসে আপনার $amountPrefixবিনিয়োগ করেছেন?',
        'ఈ నెల మీరు మీ $amountPrefixపెట్టుబడి చేశారా?',
        'இந்த மாதம் நீங்கள் உங்கள் $amountPrefixமுதலீட்டைச் செய்தீர்களா?',
      );
  String get no => _t('No', 'नहीं', 'नाही', 'না', 'లేదు', 'இல்லை');
  String get yesIDid => _t('Yes, I did', 'हाँ, किया', 'होय, केली', 'হ্যাঁ, করেছি', 'అవును, చేశాను', 'ஆம், செய்தேன்');
  String get trackYourNetWorth =>
      _t('Track your net worth', 'अपनी नेट वर्थ ट्रैक करें', 'तुमची नेट वर्थ ट्रॅक करा', 'আপনার নেট ওয়ার্থ ট্র্যাক করুন', 'మీ నెట్ వర్త్‌ను ట్రాక్ చేయండి', 'உங்கள் நிகர மதிப்பைக் கண்காணியுங்கள்');
  String get netWorthEmptyDesc => _t(
        'Add your FDs, mutual funds, stocks, gold, savings and loans to see '
            "your complete picture. For SIPs & RDs, add a monthly schedule and "
            "we'll prompt you to log each instalment.",
        'अपनी FD, म्यूचुअल फंड, स्टॉक, सोना, बचत और ऋण जोड़ें ताकि आपकी '
            'पूरी तस्वीर दिखे। SIP और RD के लिए मासिक शेड्यूल जोड़ें और हम '
            'आपको हर किस्त दर्ज करने की याद दिलाएँगे।',
        'तुमच्या FD, म्युच्युअल फंड, स्टॉक, सोने, बचत व कर्ज जोडा म्हणजे तुमचे '
            'संपूर्ण चित्र दिसेल. SIP व RD साठी मासिक वेळापत्रक जोडा आणि आम्ही '
            'तुम्हाला प्रत्येक हप्ता नोंदवण्याची आठवण करून देऊ.',
        'আপনার সম্পূর্ণ চিত্র দেখতে আপনার FD, মিউচুয়াল ফান্ড, স্টক, সোনা, সঞ্চয় ও ঋণ '
            'যোগ করুন। SIP ও RD-এর জন্য একটি মাসিক সূচি যোগ করুন এবং আমরা '
            'প্রতিটি কিস্তি নথিভুক্ত করার কথা মনে করিয়ে দেব।',
        'మీ పూర్తి చిత్రాన్ని చూడటానికి మీ FDలు, మ్యూచువల్ ఫండ్‌లు, స్టాక్‌లు, బంగారం, పొదుపు మరియు రుణాలను జోడించండి. SIPలు & RDల కోసం నెలవారీ షెడ్యూల్ జోడించండి, మేము ప్రతి వాయిదాను నమోదు చేయమని మీకు గుర్తు చేస్తాము.',
        'உங்கள் முழு சித்திரத்தைப் பார்க்க உங்கள் FDகள், மியூச்சுவல் ஃபண்டுகள், பங்குகள், தங்கம், சேமிப்பு மற்றும் கடன்களைச் சேருங்கள். SIPகள் & RDகளுக்கு மாதாந்திர அட்டவணையைச் சேருங்கள், ஒவ்வொரு தவணையையும் பதிவு செய்ய நாங்கள் உங்களுக்கு நினைவூட்டுவோம்.',
      );
  String get addFirstHolding =>
      _t('Add your first holding', 'अपनी पहली होल्डिंग जोड़ें', 'तुमची पहिली होल्डिंग जोडा', 'আপনার প্রথম হোল্ডিং যোগ করুন', 'మీ మొదటి హోల్డింగ్‌ను జోడించండి', 'உங்கள் முதல் ஹோல்டிங்கைச் சேருங்கள்');
  String investedViaSmsNote(String amount) => _t(
        '$amount detected from your Investments-tagged transactions',
        'आपके Investments-टैग किए लेन-देन से $amount पाया गया',
        'तुमच्या Investments-टॅग केलेल्या व्यवहारांमधून $amount आढळले',
        'আপনার Investments-ট্যাগ করা লেনদেন থেকে $amount শনাক্ত হয়েছে',
        'మీ Investments-ట్యాగ్ చేసిన లావాదేవీల నుండి $amount గుర్తించబడింది',
        'உங்கள் Investments-குறிச்சொல் இட்ட பரிவர்த்தனைகளிலிருந்து $amount கண்டறியப்பட்டது',
      );
  String get variableAmount => _t('Variable', 'परिवर्तनीय', 'परिवर्तनीय', 'পরিবর্তনশীল', 'మారుతుంది', 'மாறுபடும்');
  String scheduleMonthly(String amount, int day) => _t(
        '$amount · ${_enOrdinal(day)} monthly',
        '$amount · हर महीने $day तारीख',
        '$amount · दरमहा $day तारखेला',
        '$amount · প্রতি মাসে $day তারিখে',
        '$amount · ప్రతి నెల $dayవ తేదీ',
        '$amount · மாதம் $dayஆம் தேதி',
      );
  String scheduleRange(String amount, int day, DateTime start, DateTime end) {
    final s = _monthYy(start);
    final e = _monthYy(end);
    return _t(
      '$amount · ${_enOrdinal(day)} · $s – $e',
      '$amount · $day तारीख · $s – $e',
      '$amount · $day तारीख · $s – $e',
      '$amount · $day তারিখ · $s – $e',
      '$amount · $dayవ తేదీ · $s – $e',
      '$amount · $dayஆம் தேதி · $s – $e',
    );
  }
  String _monthYy(DateTime d) => _t(
        DateFormat("MMM ''yy").format(d),
        "${_hiMonthsShort[d.month - 1]} '${(d.year % 100).toString().padLeft(2, '0')}",
        "${_mrMonthsShort[d.month - 1]} '${(d.year % 100).toString().padLeft(2, '0')}",
        "${_bnMonthsShort[d.month - 1]} '${(d.year % 100).toString().padLeft(2, '0')}",
        "${_teMonthsShort[d.month - 1]} '${(d.year % 100).toString().padLeft(2, '0')}",
        "${_taMonthsShort[d.month - 1]} '${(d.year % 100).toString().padLeft(2, '0')}",
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
  String didYouInvestIn(String name) => _t('Did you invest in $name?',
      'क्या आपने $name में निवेश किया?', 'तुम्ही $name मध्ये गुंतवणूक केली का?', 'আপনি কি $name-এ বিনিয়োগ করেছেন?', 'మీరు $nameలో పెట్టుబడి పెట్టారా?', 'நீங்கள் $name இல் முதலீடு செய்தீர்களா?');
  String get confirmInstalmentDesc => _t(
        "Confirm this month's instalment and we'll add it to your net worth.",
        'इस महीने की किस्त की पुष्टि करें और हम इसे आपकी नेट वर्थ में जोड़ देंगे।',
        'या महिन्याच्या हप्त्याची पुष्टी करा आणि आम्ही तो तुमच्या नेट वर्थमध्ये जोडू.',
        'এই মাসের কিস্তি নিশ্চিত করুন এবং আমরা এটি আপনার নেট ওয়ার্থে যোগ করব।',
        'ఈ నెల వాయిదాను నిర్ధారించండి, మేము దాన్ని మీ నెట్ వర్త్‌కు జోడిస్తాము.',
        'இந்த மாதத் தவணையை உறுதிப்படுத்துங்கள், நாங்கள் அதை உங்கள் நிகர மதிப்பில் சேர்ப்போம்.',
      );
  String get amount => _t('Amount', 'राशि', 'रक्कम', 'পরিমাণ', 'మొత్తం', 'தொகை');
  String get amountInvested => _t('Amount invested', 'निवेश की गई राशि', 'गुंतवलेली रक्कम', 'বিনিয়োগ করা পরিমাণ', 'పెట్టుబడి పెట్టిన మొత్తం', 'முதலீடு செய்த தொகை');
  String get enterValidAmount =>
      _t('Enter a valid amount', 'मान्य राशि दर्ज करें', 'वैध रक्कम प्रविष्ट करा', 'একটি বৈধ পরিমাণ লিখুন', 'చెల్లుబాటు అయ్యే మొత్తాన్ని నమోదు చేయండి', 'சரியான தொகையை உள்ளிடு');
  String addedToNetWorth(String amount) => _t(
      'Added $amount to net worth', 'नेट वर्थ में $amount जोड़ा', 'नेट वर्थमध्ये $amount जोडले', 'নেট ওয়ার্থে $amount যোগ হয়েছে', 'నెట్ వర్త్‌కు $amount జోడించబడింది', 'நிகர மதிப்பில் $amount சேர்க்கப்பட்டது');
  String get markedNotDone => _t('Marked as not done this month',
      'इस महीने नहीं किया, चिह्नित किया', 'या महिन्यात केले नाही, असे चिन्हांकित केले', 'এই মাসে করা হয়নি বলে চিহ্নিত করা হয়েছে', 'ఈ నెల చేయలేదని గుర్తు పెట్టబడింది', 'இந்த மாதம் செய்யவில்லை எனக் குறிக்கப்பட்டது');
  String get savedToast => _t('Saved', 'सहेजा गया', 'जतन केले', 'সেভ হয়েছে', 'సేవ్ అయింది', 'சேமிக்கப்பட்டது');
  String get addedToast => _t('Added', 'जोड़ा गया', 'जोडले', 'যোগ হয়েছে', 'జోడించబడింది', 'சேர்க்கப்பட்டது');

  // ── Categories (DISPLAY names only) ───────────────────────────────────────
  // The stored category value stays the canonical English key (DB rows, color
  // & icon maps, expense-matching all key off it). This maps a key to its
  // Hindi label purely for display. Unknown keys (user custom tags) pass
  // through unchanged — they are the user's own text.
  String categoryName(String key) {
    switch (key) {
      case 'Food & Dining':
        return _t('Food & Dining', 'खान-पान', 'खाणे-पिणे', 'খাবার ও খাওয়া-দাওয়া', 'ఆహారం & భోజనం', 'உணவு & சாப்பாடு');
      case 'Groceries':
        return _t('Groceries', 'किराना', 'किराणा', 'মুদিখানা', 'కిరాణా', 'மளிகை');
      case 'Shopping':
        return _t('Shopping', 'खरीदारी', 'खरेदी', 'শপিং', 'షాపింగ్', 'ஷாப்பிங்');
      case 'Transportation':
        return _t('Transportation', 'परिवहन', 'वाहतूक', 'পরিবহন', 'రవాణా', 'போக்குவரத்து');
      case 'Bills & Utilities':
        return _t('Bills & Utilities', 'बिल और यूटिलिटी', 'बिले व सुविधा', 'বিল ও ইউটিলিটি', 'బిల్లులు & యుటిలిటీలు', 'பில்கள் & பயன்பாட்டுச் சேவைகள்');
      case 'Entertainment':
        return _t('Entertainment', 'मनोरंजन', 'मनोरंजन', 'বিনোদন', 'వినోదం', 'பொழுதுபோக்கு');
      case 'Health & Medical':
        return _t('Health & Medical', 'स्वास्थ्य और चिकित्सा', 'आरोग्य व वैद्यकीय', 'স্বাস্থ্য ও চিকিৎসা', 'ఆరోగ్యం & వైద్యం', 'உடல்நலம் & மருத்துவம்');
      case 'Travel':
        return _t('Travel', 'यात्रा', 'प्रवास', 'ভ্রমণ', 'ప్రయాణం', 'பயணம்');
      case 'Education':
        return _t('Education', 'शिक्षा', 'शिक्षण', 'শিক্ষা', 'విద్య', 'கல்வி');
      case 'Salary':
        return _t('Salary', 'वेतन', 'पगार', 'বেতন', 'జీతం', 'சம்பளம்');
      case 'Transfer':
        return _t('Transfer', 'ट्रांसफर', 'हस्तांतरण', 'ট্রান্সফার', 'బదిలీ', 'பரிமாற்றம்');
      case 'Self Transfer':
        return _t('Self Transfer', 'स्वयं ट्रांसफर', 'स्वतः हस्तांतरण', 'নিজস্ব ট্রান্সফার', 'సొంత బదిలీ', 'சொந்த பரிமாற்றம்');
      case 'Investments':
        return _t('Investments', 'निवेश', 'गुंतवणूक', 'বিনিয়োগ', 'పెట్టుబడులు', 'முதலீடுகள்');
      case 'Refund':
        return _t('Refund', 'रिफंड', 'परतावा', 'রিফান্ড', 'రీఫండ్', 'பணத்திரும்பம்');
      case 'Cash':
        return _t('Cash', 'नकद', 'रोख', 'নগদ', 'నగదు', 'ரொக்கம்');
      case 'Cash Conversion':
        return _t('Cash Conversion', 'नकद रूपांतरण', 'रोख रूपांतरण', 'নগদ রূপান্তর', 'నగదు మార్పిడి', 'ரொக்க மாற்றம்');
      case 'Other':
        return _t('Other', 'अन्य', 'इतर', 'অন্যান্য', 'ఇతర', 'மற்றவை');
      case 'Uncategorized':
        return _t('Uncategorized', 'अवर्गीकृत', 'अवर्गीकृत', 'অশ্রেণীবদ্ধ', 'వర్గీకరించనివి', 'வகைப்படுத்தப்படாதவை');
      default:
        return key;
    }
  }

  /// Display label for a credit/debit transaction type. `isCredit` true → the
  /// "Credit" label. Stored value is the enum index, so this is display-only.
  String txnTypeName(bool isCredit) => isCredit
      ? _t('Credit', 'क्रेडिट', 'क्रेडिट', 'ক্রেডিট', 'క్రెడిట్', 'வரவு')
      : _t('Debit', 'डेबिट', 'डेबिट', 'ডেবিট', 'డెబిట్', 'பற்று');

  // ── Transactions ──────────────────────────────────────────────────────────
  String get addTransactionTitle => _t('Add Transaction', 'लेन-देन जोड़ें', 'व्यवहार जोडा', 'লেনদেন যোগ করুন', 'లావాదేవీని జోడించు', 'பரிவர்த்தனையைச் சேர்');
  String get deleteTransactionTitle =>
      _t('Delete Transaction', 'लेन-देन हटाएँ', 'व्यवहार हटवा', 'লেনদেন মুছুন', 'లావాదేవీని తొలగించు', 'பரிவர்த்தனையை நீக்கு');
  String get deleteTransactionConfirm => _t(
        "This won't return on the next scan. Are you sure?",
        'यह अगली स्कैन में वापस नहीं आएगा। क्या आप निश्चित हैं?',
        'हे पुढील स्कॅनमध्ये परत येणार नाही. तुम्हाला खात्री आहे का?',
        'এটি পরবর্তী স্ক্যানে আর ফিরবে না। আপনি কি নিশ্চিত?',
        'ఇది తదుపరి స్కాన్‌లో తిరిగి రాదు. మీరు ఖచ్చితంగా ఉన్నారా?',
        'இது அடுத்த ஸ்கேனில் திரும்பி வராது. நீங்கள் உறுதியாக இருக்கிறீர்களா?',
      );
  String get manualEntry => _t('Manual Entry', 'मैनुअल एंट्री', 'मॅन्युअल नोंद', 'ম্যানুয়াল এন্ট্রি', 'మాన్యువల్ ఎంట్రీ', 'கைமுறை உள்ளீடு');
  String get manuallyAddedTxn => _t(
      'Manually added transaction', 'हाथ से जोड़ा गया लेन-देन', 'स्वहस्ते जोडलेला व्यवहार', 'হাতে যোগ করা লেনদেন', 'చేతితో జోడించిన లావాదేవీ', 'கைமுறையாகச் சேர்க்கப்பட்ட பரிவர்த்தனை');
  String get expenseWord => _t('Expense', 'खर्च', 'खर्च', 'খরচ', 'ఖర్చు', 'செலவு');
  String get enterAmount => _t('Enter amount', 'राशि दर्ज करें', 'रक्कम प्रविष्ट करा', 'পরিমাণ লিখুন', 'మొత్తాన్ని నమోదు చేయండి', 'தொகையை உள்ளிடு');
  String get invalidAmount => _t('Invalid amount', 'अमान्य राशि', 'अवैध रक्कम', 'অবৈধ পরিমাণ', 'చెల్లని మొత్తం', 'தவறான தொகை');
  String get dateLabel => _t('Date', 'तारीख', 'तारीख', 'তারিখ', 'తేదీ', 'தேதி');
  String get notesOptional => _t('Notes (Optional)', 'नोट्स (वैकल्पिक)', 'नोट्स (पर्यायी)', 'নোট (ঐচ্ছিক)', 'నోట్‌లు (ఐచ్ఛికం)', 'குறிப்புகள் (விருப்பம்)');
  String get addDescriptionHint =>
      _t('Add a description...', 'विवरण जोड़ें...', 'वर्णन जोडा...', 'একটি বিবরণ যোগ করুন...', 'ఒక వివరణ జోడించండి...', 'ஒரு விளக்கத்தைச் சேர்...');
  String saveTxnLabel(bool isExpense) => isExpense
      ? _t('Save Expense', 'खर्च सहेजें', 'खर्च जतन करा', 'খরচ সেভ করুন', 'ఖర్చును సేవ్ చేయి', 'செலவைச் சேமி')
      : _t('Save Income', 'आय सहेजें', 'उत्पन्न जतन करा', 'আয় সেভ করুন', 'ఆదాయాన్ని సేవ్ చేయి', 'வருமானத்தைச் சேமி');
  // Transactions list · filters & empty states
  String get selectDateOrRange =>
      _t('Select a date or range', 'तारीख या अवधि चुनें', 'तारीख किंवा कालावधी निवडा', 'একটি তারিখ বা পরিসর নির্বাচন করুন', 'తేదీ లేదా పరిధిని ఎంచుకోండి', 'ஒரு தேதி அல்லது வரம்பைத் தேர்ந்தெடு');
  String get customRange => _t('Custom', 'कस्टम', 'कस्टम', 'কাস্টম', 'కస్టమ్', 'தனிப்பயன்');
  String get filterType => _t('Type', 'प्रकार', 'प्रकार', 'ধরন', 'రకం', 'வகை');
  String get filterStatus => _t('Status', 'स्थिति', 'स्थिती', 'অবস্থা', 'స్థితి', 'நிலை');
  String get filterAll => _t('All', 'सभी', 'सर्व', 'সব', 'అన్నీ', 'அனைத்தும்');
  String get credits => _t('Credits', 'क्रेडिट', 'क्रेडिट', 'ক্রেডিট', 'క్రెడిట్‌లు', 'வரவுகள்');
  String get debits => _t('Debits', 'डेबिट', 'डेबिट', 'ডেবিট', 'డెబిట్‌లు', 'பற்றுகள்');
  String get classified => _t('Classified', 'वर्गीकृत', 'वर्गीकृत', 'শ্রেণীবদ্ধ', 'వర్గీకరించినవి', 'வகைப்படுத்தப்பட்டவை');
  String get searchTxnHint => _t('Search by payee, amount, or date',
      'प्राप्तकर्ता, राशि या तारीख से खोजें', 'प्राप्तकर्ता, रक्कम किंवा तारखेनुसार शोधा', 'প্রাপক, পরিমাণ বা তারিখ দিয়ে খুঁজুন', 'చెల్లింపుదారు, మొత్తం లేదా తేదీతో వెతకండి', 'பணம் பெறுநர், தொகை அல்லது தேதி மூலம் தேடு');
  String get netLabel => _t('Net', 'नेट', 'नेट', 'নিট', 'నికర', 'நிகர');
  String get noMatchingTransactions =>
      _t('No matching transactions', 'कोई मेल खाता लेन-देन नहीं', 'जुळणारा व्यवहार नाही', 'কোনো মিলযুক্ত লেনদেন নেই', 'సరిపోలే లావాదేవీలు లేవు', 'பொருந்தும் பரிவர்த்தனைகள் இல்லை');
  String get noTransactionsYet =>
      _t('No transactions yet', 'अभी कोई लेन-देन नहीं', 'अजून कोणताही व्यवहार नाही', 'এখনও কোনো লেনদেন নেই', 'ఇంకా లావాదేవీలు లేవు', 'இன்னும் பரிவர்த்தனைகள் இல்லை');
  String get tryAdjustingFilters =>
      _t('Try adjusting your filters', 'अपने फ़िल्टर बदलकर देखें', 'तुमचे फिल्टर बदलून पाहा', 'আপনার ফিল্টার পরিবর্তন করে দেখুন', 'మీ ఫిల్టర్‌లను సర్దుబాటు చేసి చూడండి', 'உங்கள் வடிகட்டிகளை சரிசெய்து பாருங்கள்');
  String get txnsFromSmsAppearHere => _t(
        'Transactions from bank SMS will appear here',
        'बैंक SMS से लेन-देन यहाँ दिखेंगे',
        'बँक SMS मधील व्यवहार येथे दिसतील',
        'ব্যাংক SMS থেকে লেনদেন এখানে দেখা যাবে',
        'బ్యాంక్ SMS నుండి లావాదేవీలు ఇక్కడ కనిపిస్తాయి',
        'வங்கி SMS இலிருந்து பரிவர்த்தனைகள் இங்கே தோன்றும்',
      );
  String get clearFilters => _t('Clear Filters', 'फ़िल्टर साफ़ करें', 'फिल्टर साफ करा', 'ফিল্টার সাফ করুন', 'ఫిల్టర్‌లను క్లియర్ చేయి', 'வடிகட்டிகளை அழி');
  String get filtersTitle => _t('Filters', 'फ़िल्टर', 'फिल्टर', 'ফিল্টার', 'ఫిల్టర్‌లు', 'வடிகட்டிகள்');
  String lastNDays(int n) => _t('Last $n days', 'पिछले $n दिन', 'मागील $n दिवस', 'গত $n দিন', 'గత $n రోజులు', 'கடந்த $n நாட்கள்');
  String get summaryWord => _t('Summary', 'सारांश', 'सारांश', 'সারসংক্ষেপ', 'సారాంశం', 'சுருக்கம்');
  String get txnDeletedToast => _t(
        "Transaction deleted — it won't return on the next scan",
        'लेन-देन हटाया गया — यह अगली स्कैन में वापस नहीं आएगा',
        'व्यवहार हटवला — हे पुढील स्कॅनमध्ये परत येणार नाही',
        'লেনদেন মুছে ফেলা হয়েছে — এটি পরবর্তী স্ক্যানে আর ফিরবে না',
        'లావాదేవీ తొలగించబడింది — ఇది తదుపరి స్కాన్‌లో తిరిగి రాదు',
        'பரிவர்த்தனை நீக்கப்பட்டது — இது அடுத்த ஸ்கேனில் திரும்பி வராது',
      );
  String allOfFilter(String hint) => _t('All $hint', 'सभी $hint', 'सर्व $hint', 'সব $hint', 'అన్నీ $hint', 'அனைத்து $hint');

  // ── Recurring payments (subscriptions, rent, EMIs, bills) ─────────────────
  String get recurringTitle =>
      _t('Recurring', 'आवर्ती', 'आवर्ती', 'পুনরাবৃত্ত', 'పునరావృతం', 'தொடர்');
  String get recurringPaymentsTitle => _t(
      'Recurring Payments', 'आवर्ती भुगतान', 'आवर्ती देयके', 'পুনরাবৃত্ত পেমেন্ট', 'పునరావృత చెల్లింపులు', 'தொடர் கட்டணங்கள்');
  String get recurringSubtitle => _t(
      'Subscriptions, rent, EMIs & bills',
      'सब्सक्रिप्शन, किराया, EMI और बिल',
      'सबस्क्रिप्शन, भाडे, EMI आणि बिले',
      'সাবস্ক্রিপশন, ভাড়া, EMI ও বিল',
      'సబ్‌స్క్రిప్షన్‌లు, అద్దె, EMIలు & బిల్లులు',
      'சந்தாக்கள், வாடகை, EMIகள் & பில்கள்');
  String get newRecurring =>
      _t('New recurring', 'नया आवर्ती', 'नवीन आवर्ती', 'নতুন পুনরাবৃত্ত', 'కొత్త పునరావృతం', 'புதிய தொடர்');
  String get editRecurring =>
      _t('Edit recurring', 'आवर्ती संपादित करें', 'आवर्ती संपादित करा', 'পুনরাবৃত্ত সম্পাদনা করুন', 'పునరావృతాన్ని సవరించు', 'தொடரைத் திருத்து');
  String get recurringNameLabel => _t('Name', 'नाम', 'नाव', 'নাম', 'పేరు', 'பெயர்');
  String get recurringNameHint => _t(
      'Netflix, Rent, Insurance…', 'नेटफ्लिक्स, किराया, बीमा…',
      'नेटफ्लिक्स, भाडे, विमा…', 'নেটফ্লিক্স, ভাড়া, বিমা…', 'నెట్‌ఫ్లిక్స్, అద్దె, బీమా…', 'நெட்ஃபிக்ஸ், வாடகை, காப்பீடு…');
  String get amountVariesLabel =>
      _t('Amount varies', 'राशि बदलती है', 'रक्कम बदलते', 'পরিমাণ পরিবর্তিত হয়', 'మొత్తం మారుతుంది', 'தொகை மாறுபடும்');
  String get amountVariesShort => _t('Varies', 'परिवर्तनशील', 'बदलते', 'পরিবর্তনশীল', 'మారుతుంది', 'மாறுபடும்');
  String get repeatsLabel => _t('Repeats', 'दोहराव', 'पुनरावृत्ती', 'পুনরাবৃত্তি', 'పునరావృతి', 'மீண்டும் நிகழும்');
  String get cadenceWeekly => _t('Weekly', 'साप्ताहिक', 'साप्ताहिक', 'সাপ্তাহিক', 'వారానికి', 'வாராந்திரம்');
  String get cadenceMonthly => _t('Monthly', 'मासिक', 'मासिक', 'মাসিক', 'నెలవారీ', 'மாதாந்திரம்');
  String get cadenceQuarterly => _t('Quarterly', 'त्रैमासिक', 'त्रैमासिक', 'ত্রৈমাসিক', 'త్రైమాసికం', 'காலாண்டு');
  String get cadenceYearly => _t('Yearly', 'वार्षिक', 'वार्षिक', 'বার্ষিক', 'వార్షికం', 'ஆண்டுதோறும்');
  String get nextDueDateLabel =>
      _t('Next due date', 'अगली देय तिथि', 'पुढील देय तारीख', 'পরবর্তী দেয় তারিখ', 'తదుపరి గడువు తేదీ', 'அடுத்த கெடு தேதி');
  String get endDateOptionalLabel =>
      _t('End date (optional)', 'समाप्ति तिथि (वैकल्पिक)', 'शेवटची तारीख (पर्यायी)', 'শেষ তারিখ (ঐচ্ছিক)', 'ముగింపు తేదీ (ఐచ్ఛికం)', 'முடிவு தேதி (விருப்பம்)');
  String get remindMeLabel => _t('Remind me', 'मुझे याद दिलाएँ', 'मला आठवण करा', 'আমাকে মনে করিয়ে দিন', 'నాకు గుర్తు చేయి', 'எனக்கு நினைவூட்டு');
  String get reminderLabel => _t('Reminder', 'रिमाइंडर', 'स्मरणपत्र', 'রিমাইন্ডার', 'రిమైండర్', 'நினைவூட்டல்');
  String get autoDetectSmsLabel => _t(
      'Auto-detect from bank SMS', 'बैंक SMS से स्वतः पहचानें',
      'बँक SMS मधून स्वयं ओळखा', 'ব্যাংক SMS থেকে স্বয়ংক্রিয় শনাক্ত করুন', 'బ్యాంక్ SMS నుండి ఆటో-గుర్తించు', 'வங்கி SMS இலிருந்து தானாகக் கண்டறி');
  String get autoDetectSmsDesc => _t(
      'Match a debit and send a reminder',
      'डेबिट मिलाएँ और रिमाइंडर भेजें',
      'डेबिट जुळवा आणि स्मरणपत्र पाठवा',
      'একটি ডেবিট মিলিয়ে রিমাইন্ডার পাঠান',
      'ఒక డెబిట్‌ను సరిపోల్చి రిమైండర్ పంపు',
      'ஒரு பற்றைப் பொருத்தி ஒரு நினைவூட்டலை அனுப்பு');
  String remindLeadDays(int n) => _t(
      '$n day${n == 1 ? '' : 's'} before', '$n दिन पहले', '$n दिवस आधी', '$n দিন আগে', '$n రోజుల ముందు', '$n நாட்களுக்கு முன்');
  String get remindOnDueDay =>
      _t('On the due day', 'देय दिन पर', 'देय दिवशी', 'দেয় দিনে', 'గడువు రోజున', 'கெடு நாளில்');
  String get addRecurring => _t('Add', 'जोड़ें', 'जोडा', 'যোগ করুন', 'జోడించు', 'சேர்');
  String get recurringEmptyTitle => _t(
      'No recurring payments yet', 'अभी कोई आवर्ती भुगतान नहीं',
      'अजून आवर्ती देयके नाहीत', 'এখনও কোনো পুনরাবৃত্ত পেমেন্ট নেই', 'ఇంకా పునరావృత చెల్లింపులు లేవు', 'இன்னும் தொடர் கட்டணங்கள் இல்லை');
  String get recurringEmptyDesc => _t(
      'Track subscriptions, rent, EMIs and bills — and get a nudge before each one is due.',
      'सब्सक्रिप्शन, किराया, EMI और बिल ट्रैक करें — और हर देय तिथि से पहले याद पाएँ।',
      'सबस्क्रिप्शन, भाडे, EMI आणि बिले ट्रॅक करा — आणि प्रत्येक देय तारखेआधी आठवण मिळवा.',
      'সাবস্ক্রিপশন, ভাড়া, EMI ও বিল ট্র্যাক করুন — এবং প্রতিটির দেয় তারিখের আগে একটি ইঙ্গিত পান।',
      'సబ్‌స్క్రిప్షన్‌లు, అద్దె, EMIలు మరియు బిల్లులను ట్రాక్ చేయండి — మరియు ప్రతిదాని గడువుకు ముందు ఒక సూచన పొందండి.',
      'சந்தாக்கள், வாடகை, EMIகள் மற்றும் பில்களைக் கண்காணியுங்கள் — மேலும் ஒவ்வொன்றின் கெடுவுக்கு முன் ஒரு நினைவூட்டலைப் பெறுங்கள்.');
  String get dueTodayLabel => _t('Due today', 'आज देय', 'आज देय', 'আজ দেয়', 'ఈ రోజు గడువు', 'இன்று கெடு');
  String dueInDays(int n) =>
      _t('Due in $n day${n == 1 ? '' : 's'}', '$n दिन में देय', '$n दिवसांत देय', '$n দিনে দেয়', '$n రోజుల్లో గడువు', '$n நாட்களில் கெடு');
  String overdueByDays(int n) => _t(
      'Overdue by $n day${n == 1 ? '' : 's'}', '$n दिन से अतिदेय',
      '$n दिवसांनी थकीत', '$n দিন বকেয়া', '$n రోజులు మించింది', '$n நாட்கள் தாமதம்');
  String get recurringPaidLabel => _t('Paid', 'चुकाया', 'भरले', 'পরিশোধিত', 'చెల్లించబడింది', 'செலுத்தப்பட்டது');
  String get recurringSkippedLabel => _t('Skipped', 'छोड़ा', 'वगळले', 'এড়ানো হয়েছে', 'దాటవేయబడింది', 'தவிர்க்கப்பட்டது');
  String get markPaidAction => _t('Mark paid', 'चुकाया चिह्नित करें', 'भरले म्हणून खूण करा', 'পরিশোধিত চিহ্নিত করুন', 'చెల్లించినట్లు గుర్తించు', 'செலுத்தியதாகக் குறி');
  String get skipThisCycle => _t('Skip', 'छोड़ें', 'वगळा', 'এড়িয়ে যান', 'దాటవేయి', 'தவிர்');
  String get pauseAction => _t('Pause', 'रोकें', 'थांबवा', 'থামান', 'పాజ్ చేయి', 'இடைநிறுத்து');
  String get resumeAction => _t('Resume', 'फिर शुरू करें', 'पुन्हा सुरू करा', 'আবার শুরু করুন', 'తిరిగి ప్రారంభించు', 'மீண்டும் தொடங்கு');
  String get pausedLabel => _t('Paused', 'रुका हुआ', 'थांबवले', 'থামানো', 'పాజ్ చేయబడింది', 'இடைநிறுத்தப்பட்டது');
  String get upcomingBillsTitle =>
      _t('Upcoming bills', 'आगामी बिल', 'आगामी बिले', 'আসন্ন বিল', 'రాబోయే బిల్లులు', 'வரவிருக்கும் பில்கள்');
  String get recurringHistoryTitle =>
      _t('Payment history', 'भुगतान इतिहास', 'भरणा इतिहास', 'পেমেন্ট ইতিহাস', 'చెల్లింపు చరిత్ర', 'கட்டண வரலாறு');
  String get deleteRecurringTitle => _t(
      'Delete recurring payment', 'आवर्ती भुगतान हटाएँ', 'आवर्ती देयक हटवा', 'পুনরাবৃত্ত পেমেন্ট মুছুন', 'పునరావృత చెల్లింపును తొలగించు', 'தொடர் கட்டணத்தை நீக்கு');
  String get deleteRecurringConfirm => _t(
      'This stops tracking and reminders. Your transactions are untouched.',
      'इससे ट्रैकिंग और रिमाइंडर बंद हो जाएँगे। आपके लेन-देन वैसे ही रहेंगे।',
      'यामुळे ट्रॅकिंग आणि स्मरणपत्रे थांबतील. तुमचे व्यवहार तसेच राहतील.',
      'এটি ট্র্যাকিং ও রিমাইন্ডার বন্ধ করে দেয়। আপনার লেনদেন অপরিবর্তিত থাকে।',
      'ఇది ట్రాకింగ్ మరియు రిమైండర్‌లను ఆపేస్తుంది. మీ లావాదేవీలు అలాగే ఉంటాయి.',
      'இது கண்காணிப்பையும் நினைவூட்டல்களையும் நிறுத்துகிறது. உங்கள் பரிவர்த்தனைகள் அப்படியே இருக்கும்.');
  String get trackAsRecurring => _t(
      'Track as recurring', 'आवर्ती के रूप में ट्रैक करें', 'आवर्ती म्हणून ट्रॅक करा', 'পুনরাবৃত্ত হিসেবে ট্র্যাক করুন', 'పునరావృతంగా ట్రాక్ చేయి', 'தொடராகக் கண்காணி');
  String get trackAsRecurringDesc => _t(
      'Get reminded before it’s due each time',
      'हर बार देय से पहले याद पाएँ',
      'प्रत्येक वेळी देयआधी आठवण मिळवा',
      'প্রতিবার দেয় হওয়ার আগে মনে করিয়ে দেওয়া হবে',
      'ప్రతిసారి గడువుకు ముందు గుర్తు చేయబడుతుంది',
      'ஒவ்வொரு முறையும் கெடுவுக்கு முன் நினைவூட்டப்படும்');
  String get detectedSubsTitle => _t(
      'Looks recurring', 'आवर्ती लगता है', 'आवर्ती वाटते', 'পুনরাবৃত্ত মনে হচ্ছে', 'పునరావృతంగా కనిపిస్తోంది', 'தொடர்வதாகத் தெரிகிறது');
  String detectedSubsDesc(int n) => _t(
      '$n payment${n == 1 ? '' : 's'} you might want to track',
      'ट्रैक करने योग्य $n भुगतान',
      'ट्रॅक करण्याजोगी $n देयके',
      'ট্র্যাক করার মতো $n টি পেমেন্ট',
      'మీరు ట్రాక్ చేయాలనుకునే $n చెల్లింపులు',
      'நீங்கள் கண்காணிக்க விரும்பக்கூடிய $n கட்டணங்கள்');
  String get trackShort => _t('Track', 'ट्रैक', 'ट्रॅक', 'ট্র্যাক', 'ట్రాక్', 'கண்காணி');
  String get monthlyCommitmentLabel =>
      _t('Monthly commitment', 'मासिक प्रतिबद्धता', 'मासिक वचनबद्धता', 'মাসিক প্রতিশ্রুতি', 'నెలవారీ నిబద్ధత', 'மாதாந்திர கடமை');
  String autoDetectedFromSms(String name) => _t(
      'Auto-detected from "$name"', '"$name" से स्वतः पता चला',
      '"$name" मधून स्वयं आढळले', '"$name" থেকে স্বয়ংক্রিয় শনাক্ত', '"$name" నుండి ఆటో-గుర్తించబడింది', '"$name" இலிருந்து தானாகக் கண்டறியப்பட்டது');
  String get recurringPaymentDeleted => _t(
      'Recurring payment deleted', 'आवर्ती भुगतान हटाया गया', 'आवर्ती देयक हटवले', 'পুনরাবৃত্ত পেমেন্ট মুছে ফেলা হয়েছে', 'పునరావృత చెల్లింపు తొలగించబడింది', 'தொடர் கட்டணம் நீக்கப்பட்டது');
  String get enterAmountForCycle => _t(
      'Enter the amount paid', 'चुकाई गई राशि दर्ज करें', 'भरलेली रक्कम प्रविष्ट करा', 'পরিশোধিত পরিমাণ লিখুন', 'చెల్లించిన మొత్తాన్ని నమోదు చేయండి', 'செலுத்திய தொகையை உள்ளிடு');

  // ── Transaction detail ────────────────────────────────────────────────────
  String get transactionDetailsTitle =>
      _t('Transaction Details', 'लेन-देन विवरण', 'व्यवहार तपशील', 'লেনদেনের বিবরণ', 'లావాదేవీ వివరాలు', 'பரிவர்த்தனை விவரங்கள்');
  String get detailsLabel => _t('Details', 'विवरण', 'तपशील', 'বিবরণ', 'వివరాలు', 'விவரங்கள்');
  String get fromLabel => _t('From', 'भेजने वाला', 'पाठवणारा', 'প্রেরক', 'నుండి', 'அனுப்புநர்');
  String get payeeLabel => _t('Payee', 'प्राप्तकर्ता', 'प्राप्तकर्ता', 'প্রাপক', 'చెల్లింపుదారు', 'பணம் பெறுநர்');
  String get accountLabel => _t('Account', 'खाता', 'खाते', 'অ্যাকাউন্ট', 'ఖాతా', 'கணக்கு');
  String get originalMessage => _t('Original Message', 'मूल संदेश', 'मूळ संदेश', 'মূল বার্তা', 'అసలు సందేశం', 'அசல் செய்தி');
  String get notesLabel => _t('Notes', 'नोट्स', 'नोट्स', 'নোট', 'నోట్‌లు', 'குறிப்புகள்');
  String get addNotesHint => _t('Add notes about this transaction...',
      'इस लेन-देन के बारे में नोट्स जोड़ें...', 'या व्यवहाराबद्दल नोट्स जोडा...', 'এই লেনদেন সম্পর্কে নোট যোগ করুন...', 'ఈ లావాదేవీ గురించి నోట్‌లు జోడించండి...', 'இந்த பரிவர்த்தனை பற்றிய குறிப்புகளைச் சேர்...');
  String get removeTag => _t('Remove Tag', 'टैग हटाएँ', 'टॅग काढा', 'ট্যাগ সরান', 'ట్యాగ్ తీసివేయి', 'குறிச்சொல்லை அகற்று');
  String get saveClassification =>
      _t('Save Classification', 'वर्गीकरण सहेजें', 'वर्गीकरण जतन करा', 'শ্রেণীবিভাগ সেভ করুন', 'వర్గీకరణను సేవ్ చేయి', 'வகைப்பாட்டைச் சேமி');
  String get newTag => _t('New Tag', 'नया टैग', 'नवीन टॅग', 'নতুন ট্যাগ', 'కొత్త ట్యాగ్', 'புதிய குறிச்சொல்');
  String get tagRemoved => _t('Tag removed', 'टैग हटाया गया', 'टॅग काढला', 'ট্যাগ সরানো হয়েছে', 'ట్యాగ్ తీసివేయబడింది', 'குறிச்சொல் அகற்றப்பட்டது');
  String errorSaving(Object e) =>
      _t('Error saving: $e', 'सहेजने में त्रुटि: $e', 'जतन करताना त्रुटी: $e', 'সেভ করতে ত্রুটি: $e', 'సేవ్ చేయడంలో లోపం: $e', 'சேமிப்பதில் பிழை: $e');
  String errorGeneric(Object e) => _t('Error: $e', 'त्रुटि: $e', 'त्रुटी: $e', 'ত্রুটি: $e', 'లోపం: $e', 'பிழை: $e');
  String get applyToSimilarTitle => _t(
      'Apply to Similar Transactions?', 'समान लेन-देन पर लागू करें?', 'समान व्यवहारांना लागू करायचे?', 'একই ধরনের লেনদেনে প্রয়োগ করবেন?', 'ఇలాంటి లావాదేవీలకు వర్తింపజేయాలా?', 'ஒத்த பரிவர்த்தனைகளுக்குப் பயன்படுத்தவா?');
  String foundTxnsForMerchant(String name) => _t(
        'Found transactions for "$name". How would you like to classify them?',
        '"$name" के लिए लेन-देन मिले। इन्हें कैसे वर्गीकृत करना चाहेंगे?',
        '"$name" साठी व्यवहार आढळले. ते कसे वर्गीकृत करायचे?',
        '"$name"-এর জন্য লেনদেন পাওয়া গেছে। এগুলো কীভাবে শ্রেণীবদ্ধ করতে চান?',
        '"$name" కోసం లావాదేవీలు కనుగొనబడ్డాయి. వాటిని ఎలా వర్గీకరించాలనుకుంటున్నారు?',
        '"$name" க்கான பரிவர்த்தனைகள் கண்டறியப்பட்டன. அவற்றை எப்படி வகைப்படுத்த விரும்புகிறீர்கள்?',
      );
  String get applyToAll => _t('Apply to All', 'सभी पर लागू करें', 'सर्वांना लागू करा', 'সবগুলোতে প্রয়োগ করুন', 'అన్నింటికీ వర్తింపజేయి', 'அனைத்திற்கும் பயன்படுத்து');
  String get applyToAllDesc => _t(
        'Classify all existing & auto-flag future transactions',
        'सभी मौजूदा वर्गीकृत करें और भविष्य के लेन-देन स्वतः चिह्नित करें',
        'सर्व विद्यमान वर्गीकृत करा व भविष्यातील व्यवहार आपोआप चिन्हांकित करा',
        'সব বিদ্যমান শ্রেণীবদ্ধ করুন ও ভবিষ্যৎ লেনদেন স্বয়ংক্রিয়ভাবে চিহ্নিত করুন',
        'ప్రస్తుత అన్నింటినీ వర్గీకరించి భవిష్యత్ లావాదేవీలను ఆటో-ఫ్లాగ్ చేయి',
        'ஏற்கனவே உள்ள அனைத்தையும் வகைப்படுத்தி எதிர்கால பரிவர்த்தனைகளைத் தானாகக் கொடியிடு',
      );
  String get applyToExisting =>
      _t('Apply to Existing Only', 'केवल मौजूदा पर लागू करें', 'फक्त विद्यमानांना लागू करा', 'শুধু বিদ্যমানগুলোতে প্রয়োগ করুন', 'ప్రస్తుతమున్నవాటికి మాత్రమే వర్తింపజేయి', 'ஏற்கனவே உள்ளவற்றுக்கு மட்டும் பயன்படுத்து');
  String get applyToExistingDesc => _t(
        'Classify existing transactions, flag future ones manually',
        'मौजूदा लेन-देन वर्गीकृत करें, भविष्य के लिए मैन्युअल रूप से चिह्नित करें',
        'विद्यमान व्यवहार वर्गीकृत करा, भविष्यातील स्वहस्ते चिन्हांकित करा',
        'বিদ্যমান লেনদেন শ্রেণীবদ্ধ করুন, ভবিষ্যতেরগুলো হাতে চিহ্নিত করুন',
        'ప్రస్తుత లావాదేవీలను వర్గీకరించు, భవిష్యత్తువాటిని చేతితో ఫ్లాగ్ చేయి',
        'ஏற்கனவே உள்ள பரிவர்த்தனைகளை வகைப்படுத்து, எதிர்காலத்தவற்றைக் கைமுறையாகக் கொடியிடு',
      );
  String get onlyThisOne => _t('Only This One', 'केवल यही', 'फक्त हाच', 'শুধু এটি', 'ఇది మాత్రమే', 'இது மட்டும்');
  String get onlyThisOneDesc => _t(
        'Tag only this transaction, handle others manually',
        'केवल इसी लेन-देन को टैग करें, बाकी मैन्युअल रूप से संभालें',
        'फक्त याच व्यवहाराला टॅग करा, बाकीचे स्वहस्ते हाताळा',
        'শুধু এই লেনদেনে ট্যাগ করুন, বাকিগুলো হাতে সামলান',
        'ఈ లావాదేవీకి మాత్రమే ట్యాగ్ చేయి, మిగతావాటిని చేతితో నిర్వహించు',
        'இந்த பரிவர்த்தனைக்கு மட்டும் குறிச்சொல் இடு, மற்றவற்றைக் கைமுறையாகக் கையாளு',
      );
  String get txnSaved => _t('Transaction saved', 'लेन-देन सहेजा गया', 'व्यवहार जतन केला', 'লেনদেন সেভ হয়েছে', 'లావాదేవీ సేవ్ అయింది', 'பரிவர்த்தனை சேமிக்கப்பட்டது');
  String get txnSavedNoMerchant => _t(
        'Transaction saved (no merchant to match)',
        'लेन-देन सहेजा गया (मिलान के लिए कोई व्यापारी नहीं)',
        'व्यवहार जतन केला (जुळवण्यासाठी व्यापारी नाही)',
        'লেনদেন সেভ হয়েছে (মেলানোর মতো কোনো বিক্রেতা নেই)',
        'లావాదేవీ సేవ్ అయింది (సరిపోల్చడానికి మర్చెంట్ లేదు)',
        'பரிவர்த்தனை சேமிக்கப்பட்டது (பொருத்த வணிகர் இல்லை)',
      );
  String updatedSimilarTxns(int count, bool isDebit) => _t(
        'Updated $count similar ${isDebit ? 'debits' : 'credits'}',
        '$count समान ${isDebit ? 'डेबिट' : 'क्रेडिट'} अपडेट किए',
        '$count समान ${isDebit ? 'डेबिट' : 'क्रेडिट'} अपडेट केले',
        '$count টি একই ধরনের ${isDebit ? 'ডেবিট' : 'ক্রেডিট'} আপডেট হয়েছে',
        '$count సారూప్య ${isDebit ? 'డెబిట్‌లు' : 'క్రెడిట్‌లు'} నవీకరించబడ్డాయి',
        '$count ஒத்த ${isDebit ? 'பற்றுகள்' : 'வரவுகள்'} புதுப்பிக்கப்பட்டன',
      );
  String futureTxnsAutoClassified(bool isDebit, String merchant) => _t(
        ' • Future ${isDebit ? 'debits' : 'credits'} from "$merchant" will be auto-classified',
        ' • "$merchant" से भविष्य के ${isDebit ? 'डेबिट' : 'क्रेडिट'} स्वतः वर्गीकृत होंगे',
        ' • "$merchant" कडून भविष्यातील ${isDebit ? 'डेबिट' : 'क्रेडिट'} आपोआप वर्गीकृत होतील',
        ' • "$merchant" থেকে ভবিষ্যৎ ${isDebit ? 'ডেবিট' : 'ক্রেডিট'} স্বয়ংক্রিয়ভাবে শ্রেণীবদ্ধ হবে',
        ' • "$merchant" నుండి భవిష్యత్ ${isDebit ? 'డెబిట్‌లు' : 'క్రెడిట్‌లు'} ఆటో-వర్గీకరించబడతాయి',
        ' • "$merchant" இலிருந்து எதிர்கால ${isDebit ? 'பற்றுகள்' : 'வரவுகள்'} தானாக வகைப்படுத்தப்படும்',
      );
  String emojiForTag(String name) =>
      _t('Emoji for "$name"', '"$name" के लिए इमोजी', '"$name" साठी इमोजी', '"$name"-এর জন্য ইমোজি', '"$name" కోసం ఇమోజీ', '"$name" க்கான எமோஜி');
  String get createCustomTag =>
      _t('Create Custom Tag', 'कस्टम टैग बनाएँ', 'कस्टम टॅग तयार करा', 'কাস্টম ট্যাগ তৈরি করুন', 'కస్టమ్ ట్యాగ్ సృష్టించు', 'தனிப்பயன் குறிச்சொல்லை உருவாக்கு');
  String get createTagDesc => _t('Choose an emoji and name for your tag',
      'अपने टैग के लिए इमोजी और नाम चुनें', 'तुमच्या टॅगसाठी इमोजी आणि नाव निवडा', 'আপনার ট্যাগের জন্য একটি ইমোজি ও নাম বেছে নিন', 'మీ ట్యాగ్ కోసం ఒక ఇమోజీ మరియు పేరును ఎంచుకోండి', 'உங்கள் குறிச்சொல்லுக்கு ஒரு எமோஜி மற்றும் பெயரைத் தேர்ந்தெடுக்கவும்');
  String get tagNameHint =>
      _t('Tag name (e.g. Rent, Gym)', 'टैग नाम (जैसे किराया, जिम)', 'टॅग नाव (उदा. भाडे, जिम)', 'ট্যাগের নাম (যেমন ভাড়া, জিম)', 'ట్యాగ్ పేరు (ఉదా. అద్దె, జిమ్)', 'குறிச்சொல் பெயர் (எ.கா. வாடகை, ஜிம்)');
  String get pickAnEmoji => _t('Pick an emoji', 'इमोजी चुनें', 'इमोजी निवडा', 'একটি ইমোজি বেছে নিন', 'ఒక ఇమోజీ ఎంచుకోండి', 'ஒரு எமோஜியைத் தேர்ந்தெடு');
  String get enterTagName =>
      _t('Please enter a tag name', 'कृपया टैग नाम दर्ज करें', 'कृपया टॅग नाव प्रविष्ट करा', 'অনুগ্রহ করে একটি ট্যাগের নাম লিখুন', 'దయచేసి ఒక ట్యాగ్ పేరు నమోదు చేయండి', 'தயவுசெய்து ஒரு குறிச்சொல் பெயரை உள்ளிடவும்');
  String get tagExists => _t('A tag with this name already exists',
      'इस नाम का टैग पहले से मौजूद है', 'या नावाचा टॅग आधीच अस्तित्वात आहे', 'এই নামের একটি ট্যাগ ইতিমধ্যে আছে', 'ఈ పేరుతో ఒక ట్యాగ్ ఇప్పటికే ఉంది', 'இந்தப் பெயரில் ஒரு குறிச்சொல் ஏற்கனவே உள்ளது');
  String get createTag => _t('Create Tag', 'टैग बनाएँ', 'टॅग तयार करा', 'ট্যাগ তৈরি করুন', 'ట్యాగ్ సృష్టించు', 'குறிச்சொல்லை உருவாக்கு');

  // ── Merchants ─────────────────────────────────────────────────────────────
  String get noMerchantSpending => _t('No merchant spending this month',
      'इस महीने कोई व्यापारी खर्च नहीं', 'या महिन्यात कोणताही व्यापारी खर्च नाही', 'এই মাসে কোনো বিক্রেতা খরচ নেই', 'ఈ నెల మర్చెంట్ ఖర్చు లేదు', 'இந்த மாதம் வணிகர் செலவு இல்லை');
  String get topMerchantLabel => _t('Top merchant', 'शीर्ष व्यापारी', 'आघाडीचा व्यापारी', 'শীর্ষ বিক্রেতা', 'టాప్ మర్చెంట్', 'சிறந்த வணிகர்');
  String pctOfMerchantSpend(int pct) =>
      _t('$pct% of merchant spend', 'व्यापारी खर्च का $pct%', 'व्यापारी खर्चाच्या $pct%', 'বিক্রেতা খরচের $pct%', 'మర్చెంట్ ఖర్చులో $pct%', 'வணிகர் செலவில் $pct%');
  String get ofSpending => _t('of spending', 'खर्च का', 'खर्चाच्या', 'খরচের', 'ఖర్చులో', 'செலவில்');
  String get ofCategory => _t('of category', 'श्रेणी का', 'श्रेणीच्या', 'বিভাগের', 'వర్గంలో', 'வகையில்');
  String get topBadge => _t('TOP', 'शीर्ष', 'आघाडी', 'শীর্ষ', 'టాప్', 'சிறந்தது');
  String txnCountCaption(int n) =>
      _t('$n transaction${n == 1 ? '' : 's'}', '$n लेन-देन', '$n व्यवहार', '$n লেনদেন', '$n లావాదేవీలు', '$n பரிவர்த்தனைகள்');
  String get avgPerTxn => _t('Avg / txn', 'औसत / लेन-देन', 'सरासरी / व्यवहार', 'গড় / লেনদেন', 'సగటు / లావాదేవీ', 'சராசரி / பரிவர்த்தனை');
  String get largestLabel => _t('Largest', 'सबसे बड़ा', 'सर्वात मोठा', 'সর্বোচ্চ', 'అత్యధికం', 'மிகப்பெரியது');
  String get vsLastMonth => _t('vs last month', 'पिछले महीने से', 'मागील महिन्याच्या तुलनेत', 'গত মাসের তুলনায়', 'గత నెలతో పోలిస్తే', 'கடந்த மாதத்துடன்');
  String get noTxnsThisMonth => _t(
      'No transactions this month', 'इस महीने कोई लेन-देन नहीं', 'या महिन्यात कोणताही व्यवहार नाही', 'এই মাসে কোনো লেনদেন নেই', 'ఈ నెల లావాదేవీలు లేవు', 'இந்த மாதம் பரிவர்த்தனைகள் இல்லை');

  // ── Splits / Ledger ───────────────────────────────────────────────────────
  String get addToLedger => _t('Add to ledger', 'खाते में जोड़ें', 'खात्यात जोडा', 'খাতায় যোগ করুন', 'లెడ్జర్‌కు జోడించు', 'லெட்ஜரில் சேர்');
  String get splitAnExpense => _t('Split an expense', 'खर्च बाँटें', 'खर्च विभागा', 'একটি খরচ ভাগ করুন', 'ఖర్చును విభజించు', 'ஒரு செலவைப் பிரி');
  String get splitAnExpenseDesc => _t(
        'You paid or split a bill — others owe you their share',
        'आपने भुगतान किया या बिल बाँटा — दूसरों पर आपका हिस्सा बकाया है',
        'तुम्ही पैसे दिले किंवा बिल विभागले — इतरांकडे तुमचा वाटा येणे आहे',
        'আপনি একটি বিল পরিশোধ বা ভাগ করেছেন — অন্যদের কাছে আপনার ভাগ পাওনা',
        'మీరు ఒక బిల్లు చెల్లించారు లేదా విభజించారు — ఇతరులు మీకు వారి వాటా బాకీ ఉన్నారు',
        'நீங்கள் ஒரு பில்லைச் செலுத்தினீர்கள் அல்லது பிரித்தீர்கள் — மற்றவர்கள் தங்கள் பங்கை உங்களுக்குத் தர வேண்டும்',
      );
  String get someoneOwesMe => _t('Someone owes me', 'किसी पर मेरा बकाया है', 'कोणाकडे माझे येणे आहे', 'কারও কাছে আমার পাওনা', 'ఎవరో నాకు బాకీ ఉన్నారు', 'யாரோ எனக்குக் கடன்பட்டுள்ளார்');
  String get someoneOwesMeDesc => _t(
        'You paid for or lent them — expect the cash back',
        'आपने उनके लिए भुगतान किया या उधार दिया — पैसे वापस मिलेंगे',
        'तुम्ही त्यांच्यासाठी पैसे दिले किंवा उसने दिले — पैसे परत मिळतील',
        'আপনি তাদের জন্য পরিশোধ বা ধার দিয়েছেন — টাকা ফেরত আশা করুন',
        'మీరు వారి కోసం చెల్లించారు లేదా అప్పు ఇచ్చారు — డబ్బు తిరిగి రావాలని ఆశించండి',
        'நீங்கள் அவர்களுக்காகச் செலுத்தினீர்கள் அல்லது கடன் கொடுத்தீர்கள் — பணம் திரும்பி வரும் என எதிர்பாருங்கள்',
      );
  String get iOweSomeone => _t('I owe someone', 'मुझ पर किसी का बकाया है', 'माझ्याकडे कोणाचे देणे आहे', 'আমার কারও কাছে দেনা', 'నేను ఎవరికో బాకీ ఉన్నాను', 'நான் யாருக்கோ கடன்பட்டுள்ளேன்');
  String get iOweSomeoneDesc => _t(
        'Someone covered you — record what you owe them',
        'किसी ने आपके लिए भुगतान किया — जो आप पर बकाया है दर्ज करें',
        'कोणीतरी तुमच्यासाठी पैसे दिले — तुमचे देणे नोंदवा',
        'কেউ আপনার হয়ে পরিশোধ করেছে — আপনার দেনা নথিভুক্ত করুন',
        'ఎవరో మీ కోసం చెల్లించారు — మీరు వారికి బాకీ ఉన్నదాన్ని నమోదు చేయండి',
        'யாரோ உங்களுக்காகச் செலுத்தினார் — நீங்கள் அவர்களுக்குத் தரவேண்டியதைப் பதிவு செய்யுங்கள்',
      );
  String get peopleLabel => _t('People', 'लोग', 'लोक', 'মানুষ', 'వ్యక్తులు', 'நபர்கள்');
  String get allSettled => _t('ALL SETTLED', 'सब निपट गया', 'सर्व निकाली', 'সব নিষ্পত্তি', 'అన్నీ సెటిల్ అయ్యాయి', 'அனைத்தும் தீர்க்கப்பட்டன');
  String get owedOverall =>
      _t("YOU'RE OWED OVERALL", 'कुल मिलाकर आपका बकाया है', 'एकूण तुमचे येणे आहे', 'সব মিলিয়ে আপনার পাওনা', 'మొత్తంగా మీకు రావాలి', 'மொத்தத்தில் உங்களுக்கு வரவேண்டும்');
  String get youOweOverall =>
      _t('YOU OWE OVERALL', 'कुल मिलाकर आप पर बकाया है', 'एकूण तुमचे देणे आहे', 'সব মিলিয়ে আপনার দেনা', 'మొత్తంగా మీరు చెల్లించాలి', 'மொத்தத்தில் நீங்கள் தரவேண்டும்');
  String get owedToYou => _t('Owed to you', 'आपको मिलना है', 'तुम्हाला मिळणार', 'আপনার প্রাপ্য', 'మీకు రావాల్సినది', 'உங்களுக்கு வரவேண்டியது');
  String get youOwe => _t('You owe', 'आप पर बकाया', 'तुमचे देणे', 'আপনার দেনা', 'మీరు చెల్లించాల్సినది', 'நீங்கள் தரவேண்டியது');
  String get owesYouStatus => _t('owes you', 'का आप पर बकाया', 'चे तुम्हाला येणे', 'এর কাছে আপনার পাওনা', 'మీకు బాకీ ఉన్నారు', 'உங்களுக்குக் கடன்பட்டுள்ளார்');
  String get youOweStatus => _t('you owe', 'आप पर बकाया', 'तुमचे देणे', 'আপনার দেনা', 'మీరు బాకీ ఉన్నారు', 'நீங்கள் கடன்பட்டுள்ளீர்கள்');
  String get settledUp => _t('settled up', 'निपट गया', 'निकाली', 'নিষ্পত্তি হয়েছে', 'సెటిల్ అయింది', 'தீர்க்கப்பட்டது');
  String get settledFromPayments =>
      _t('Settled from payments', 'भुगतान से निपटा', 'पेमेंटमधून निकाली', 'পেমেন্ট থেকে নিষ্পত্তি', 'చెల్లింపుల నుండి సెటిల్ అయింది', 'கட்டணங்களிலிருந்து தீர்க்கப்பட்டது');
  String get noSplitsYet => _t('No splits yet', 'अभी कोई स्प्लिट नहीं', 'अजून कोणतेही स्प्लिट नाही', 'এখনও কোনো স্প্লিট নেই', 'ఇంకా స్ప్లిట్‌లు లేవు', 'இன்னும் பிரிப்புகள் இல்லை');
  String get noSplitsDesc => _t(
        'Split a bill, or record what you owe someone — all on your device. '
            'Tap Add to get started. When you pay for a group, only your share '
            'counts as your spending.',
        'बिल बाँटें, या किसी का आप पर बकाया दर्ज करें — सब आपके डिवाइस पर। '
            'शुरू करने के लिए जोड़ें टैप करें। जब आप समूह के लिए भुगतान करते हैं, '
            'तो केवल आपका हिस्सा आपके खर्च में गिना जाता है।',
        'बिल विभागा, किंवा तुमचे कोणाला देणे आहे ते नोंदवा — सर्व तुमच्या डिव्हाइसवर. '
            'सुरू करण्यासाठी जोडा वर टॅप करा. जेव्हा तुम्ही गटासाठी पैसे देता, '
            'तेव्हा फक्त तुमचा वाटा तुमच्या खर्चात मोजला जातो.',
        'একটি বিল ভাগ করুন, বা কারও কাছে আপনার দেনা নথিভুক্ত করুন — সব আপনার ডিভাইসে। '
            'শুরু করতে যোগ করুন ট্যাপ করুন। আপনি যখন একটি দলের জন্য পরিশোধ করেন, '
            'তখন শুধু আপনার ভাগ আপনার খরচ হিসেবে গণ্য হয়।',
        'ఒక బిల్లును విభజించండి, లేదా మీరు ఎవరికో బాకీ ఉన్నదాన్ని నమోదు చేయండి — అంతా మీ పరికరంలో. ప్రారంభించడానికి జోడించు నొక్కండి. మీరు ఒక గ్రూప్ కోసం చెల్లించినప్పుడు, మీ వాటా మాత్రమే మీ ఖర్చుగా లెక్కించబడుతుంది.',
        'ஒரு பில்லைப் பிரியுங்கள், அல்லது நீங்கள் யாருக்கோ தரவேண்டியதைப் பதிவு செய்யுங்கள் — அனைத்தும் உங்கள் சாதனத்தில். தொடங்க சேர் தட்டுங்கள். ஒரு குழுவிற்காக நீங்கள் செலுத்தும்போது, உங்கள் பங்கு மட்டுமே உங்கள் செலவாகக் கணக்கிடப்படும்.',
      );

  // ── Split editor ──────────────────────────────────────────────────────────
  String get youLabel => _t('You', 'आप', 'तुम्ही', 'আপনি', 'మీరు', 'நீங்கள்');
  String get whoPaid => _t('Who paid?', 'किसने भुगतान किया?', 'कोणी पैसे दिले?', 'কে পরিশোধ করেছে?', 'ఎవరు చెల్లించారు?', 'யார் செலுத்தினார்?');
  String get whoOwesYou => _t('Who owes you?', 'किस पर आपका बकाया है?', 'कोणाकडे तुमचे येणे आहे?', 'কার কাছে আপনার পাওনা?', 'మీకు ఎవరు బాకీ ఉన్నారు?', 'உங்களுக்கு யார் கடன்பட்டுள்ளார்?');
  String get addAPerson => _t('Add a person', 'व्यक्ति जोड़ें', 'व्यक्ती जोडा', 'একজন ব্যক্তি যোগ করুন', 'ఒక వ్యక్తిని జోడించు', 'ஒரு நபரைச் சேர்');
  String get giveItATitle => _t('Give it a title', 'एक शीर्षक दें', 'एक शीर्षक द्या', 'একটি শিরোনাম দিন', 'ఒక శీర్షిక ఇవ్వండి', 'ஒரு தலைப்பு கொடுங்கள்');
  String get enterAmountAbove0 =>
      _t('Enter an amount above ₹0', '₹0 से अधिक राशि दर्ज करें', '₹0 पेक्षा जास्त रक्कम प्रविष्ट करा', '₹0-এর বেশি পরিমাণ লিখুন', '₹0 కంటే ఎక్కువ మొత్తాన్ని నమోదు చేయండి', '₹0 க்கு மேல் ஒரு தொகையை உள்ளிடு');
  String get addOtherPerson => _t(
      'Add the other person involved', 'शामिल दूसरे व्यक्ति को जोड़ें', 'सहभागी असलेली दुसरी व्यक्ती जोडा', 'জড়িত অন্য ব্যক্তিকে যোগ করুন', 'పాల్గొన్న ఇతర వ్యక్తిని జోడించండి', 'சம்பந்தப்பட்ட மற்ற நபரைச் சேருங்கள்');
  String get pickWhoSplit => _t('Pick who the expense is split between',
      'चुनें कि खर्च किन-किन में बँटा है', 'खर्च कोणाकोणात विभागला आहे ते निवडा', 'খরচ কাদের মধ্যে ভাগ হয়েছে তা বেছে নিন', 'ఖర్చు ఎవరి మధ్య విభజించబడిందో ఎంచుకోండి', 'செலவு யார் யாருக்கிடையே பிரிக்கப்படுகிறது என்பதைத் தேர்ந்தெடு');
  String sharesMustAddUp(String amount) => _t(
      'Shares must add up to $amount', 'हिस्सों का योग $amount होना चाहिए', 'वाट्यांची बेरीज $amount असावी', 'ভাগের যোগফল $amount হতে হবে', 'వాటాల మొత్తం $amount కావాలి', 'பங்குகளின் கூட்டுத்தொகை $amount ஆக இருக்க வேண்டும்');
  String get whatFor => _t('What for', 'किसलिए', 'कशासाठी', 'কীসের জন্য', 'దేని కోసం', 'எதற்காக');
  String get splitTitleHint =>
      _t('e.g. Dinner at Barbeque Nation', 'जैसे बारबेक्यू नेशन में डिनर', 'उदा. बार्बेक्यू नेशनमध्ये डिनर', 'যেমন বার্বিকিউ নেশনে ডিনার', 'ఉదా. బార్బెక్యూ నేషన్‌లో డిన్నర్', 'எ.கா. Barbeque Nation இல் இரவு உணவு');
  String get totalAmount => _t('Total amount', 'कुल राशि', 'एकूण रक्कम', 'মোট পরিমাণ', 'మొత్తం సొమ్ము', 'மொத்த தொகை');
  String get paidBy => _t('Paid by', 'भुगतानकर्ता', 'पैसे दिले', 'পরিশোধ করেছেন', 'చెల్లించినవారు', 'செலுத்தியவர்');
  String get splitBetween => _t('Split between', 'किनमें बँटा', 'कोणात विभागले', 'যাদের মধ্যে ভাগ', 'వీరి మధ్య విభజన', 'இவர்களிடையே பிரிப்பு');
  String get recordWhatYouOwe =>
      _t('Record what you owe', 'जो आप पर बकाया है दर्ज करें', 'तुमचे देणे नोंदवा', 'আপনার দেনা নথিভুক্ত করুন', 'మీరు బాకీ ఉన్నదాన్ని నమోదు చేయండి', 'நீங்கள் தரவேண்டியதைப் பதிவு செய்');
  String get recordWhatYoureOwed =>
      _t("Record what you're owed", 'जो आपको मिलना है दर्ज करें', 'तुम्हाला मिळणारे नोंदवा', 'আপনার প্রাপ্য নথিভুক্ত করুন', 'మీకు రావాల్సినదాన్ని నమోదు చేయండి', 'உங்களுக்கு வரவேண்டியதைப் பதிவு செய்');
  String get editSplit => _t('Edit split', 'स्प्लिट संपादित करें', 'स्प्लिट संपादित करा', 'স্প্লিট সম্পাদনা করুন', 'స్ప్లిట్‌ను సవరించు', 'பிரிப்பைத் திருத்து');
  String get newSplit => _t('New split', 'नया स्प्लिट', 'नवीन स्प्लिट', 'নতুন স্প্লিট', 'కొత్త స్ప్లిట్', 'புதிய பிரிப்பு');
  String get equallyLabel => _t('Equally', 'बराबर', 'समान', 'সমানভাবে', 'సమానంగా', 'சமமாக');
  String get exactLabel => _t('Exact ₹', 'सटीक ₹', 'नेमके ₹', 'নির্দিষ্ট ₹', 'ఖచ్చితమైన ₹', 'சரியான ₹');
  String get someoneElse => _t('Someone else', 'कोई और', 'दुसरे कोणी', 'অন্য কেউ', 'మరొకరు', 'வேறு யாரோ');
  String get notInSplit => _t('not in split', 'स्प्लिट में नहीं', 'स्प्लिटमध्ये नाही', 'স্প্লিটে নেই', 'స్ప్లిట్‌లో లేదు', 'பிரிப்பில் இல்லை');
  String get addPersonToSplit =>
      _t('Add person to the split', 'स्प्लिट में व्यक्ति जोड़ें', 'स्प्लिटमध्ये व्यक्ती जोडा', 'স্প্লিটে ব্যক্তি যোগ করুন', 'స్ప్లిట్‌కు వ్యక్తిని జోడించు', 'பிரிப்பில் நபரைச் சேர்');
  String get resultLabel => _t('Result', 'परिणाम', 'निकाल', 'ফলাফল', 'ఫలితం', 'முடிவு');
  String get fillToSeeResult => _t(
        'Fill in the amount and who paid to see the result.',
        'परिणाम देखने के लिए राशि और भुगतानकर्ता भरें।',
        'निकाल पाहण्यासाठी रक्कम आणि कोणी पैसे दिले ते भरा.',
        'ফলাফল দেখতে পরিমাণ ও কে পরিশোধ করেছে তা পূরণ করুন।',
        'ఫలితం చూడటానికి మొత్తం మరియు ఎవరు చెల్లించారో పూరించండి.',
        'முடிவைப் பார்க்க தொகை மற்றும் யார் செலுத்தினார் என்பதை நிரப்புங்கள்.',
      );
  String get addSplit => _t('Add split', 'स्प्लिट जोड़ें', 'स्प्लिट जोडा', 'স্প্লিট যোগ করুন', 'స్ప్లిట్ జోడించు', 'பிரிப்பைச் சேர்');
  String get linkedTxnFallback => _t('Transaction', 'लेन-देन', 'व्यवहार', 'লেনদেন', 'లావాదేవీ', 'பரிவர்த்தனை');
  String linkedToTxn(String label) => _t(
        'Linked to $label — only your share counts as spending',
        '$label से जुड़ा — केवल आपका हिस्सा खर्च में गिना जाता है',
        '$label शी जोडलेले — फक्त तुमचा वाटा खर्चात मोजला जातो',
        '$label-এর সাথে যুক্ত — শুধু আপনার ভাগ খরচ হিসেবে গণ্য হয়',
        '$labelకు లింక్ చేయబడింది — మీ వాటా మాత్రమే ఖర్చుగా లెక్కించబడుతుంది',
        '$label உடன் இணைக்கப்பட்டது — உங்கள் பங்கு மட்டுமே செலவாகக் கணக்கிடப்படும்',
      );
  // Outcome-card sentence fragments (composed around bold name + amount spans;
  // word order differs across languages, hence the lead/mid/trail split).
  String get owesYouMid => _t(' owes you ', ' पर आपका ', ' कडे तुमचे ', '-এর কাছে আপনার ', ' మీకు ', ' உங்களுக்கு ');
  String get owesYouTrail => _t('', ' बकाया है', ' येणे आहे', ' পাওনা', ' బాకీ', ' தர வேண்டும்');
  String get youOweLead => _t('You owe ', 'आपको ', 'तुम्हाला ', 'আপনাকে ', 'మీరు ', 'நீங்கள் ');
  String get youOweMid => _t(' ', ' को ', ' ला ', '-কে ', 'కి ', 'க்கு ');
  String get youOweTrail => _t('', ' देना है', ' द्यायचे आहेत', ' দিতে হবে', ' చెల్లించాలి', ' தர வேண்டும்');

  // ── Person detail / settle up ─────────────────────────────────────────────
  String get shareSummary => _t('Share summary', 'सारांश साझा करें', 'सारांश शेअर करा', 'সারসংক্ষেপ শেয়ার করুন', 'సారాంశాన్ని షేర్ చేయి', 'சுருக்கத்தைப் பகிர்');
  String get activityLabel => _t('Activity', 'गतिविधि', 'हालचाल', 'কার্যকলাপ', 'కార్యకలాపం', 'செயல்பாடு');
  String get allSettledUp => _t('ALL SETTLED UP', 'सब निपट गया', 'सर्व निकाली', 'সব নিষ্পত্তি', 'అన్నీ సెటిల్ అయ్యాయి', 'அனைத்தும் தீர்க்கப்பட்டன');
  String personOwesYou(String name) =>
      _t('${name.toUpperCase()} OWES YOU', '$name पर आपका बकाया', '$name कडे तुमचे येणे', '$name-এর কাছে আপনার পাওনা', '${name.toUpperCase()} మీకు బాకీ ఉన్నారు', '${name.toUpperCase()} உங்களுக்குக் கடன்பட்டுள்ளார்');
  String youOwePerson(String name) =>
      _t('YOU OWE ${name.toUpperCase()}', 'आप पर $name का बकाया', 'तुमचे $name ला देणे', '$name-কে আপনার দেনা', 'మీరు ${name.toUpperCase()}కి చెల్లించాలి', 'நீங்கள் ${name.toUpperCase()}க்கு தரவேண்டும்');
  String get settleUp => _t('Settle up', 'निपटाएँ', 'निकाली करा', 'নিষ্পত্তি করুন', 'సెటిల్ చేయి', 'தீர்');
  String get shareLabel => _t('Share', 'साझा करें', 'शेअर करा', 'শেয়ার করুন', 'షేర్ చేయి', 'பகிர்');
  String personPaidMe(String name) =>
      _t('$name paid me', '$name ने मुझे भुगतान किया', '$name ने मला पैसे दिले', '$name আমাকে পরিশোধ করেছে', '$name నాకు చెల్లించారు', '$name எனக்குச் செலுத்தினார்');
  String iPaidPerson(String name) =>
      _t('I paid $name', 'मैंने $name को भुगतान किया', 'मी $name ला पैसे दिले', 'আমি $name-কে পরিশোধ করেছি', 'నేను $nameకి చెల్లించాను', 'நான் $name க்கு செலுத்தினேன்');
  String get recordSettlement => _t('Record settlement', 'निपटान दर्ज करें', 'निकाली नोंदवा', 'নিষ্পত্তি নথিভুক্ত করুন', 'సెటిల్‌మెంట్‌ను నమోదు చేయి', 'தீர்வைப் பதிவு செய்');

  // ── Split a transaction ─────────────────────────────────────────────────────
  String get splitThisTransaction =>
      _t('Split this transaction', 'इस लेन-देन को विभाजित करें', 'हा व्यवहार विभागा', 'এই লেনদেন ভাগ করুন', 'ఈ లావాదేవీని విభజించు', 'இந்த பரிவர்த்தனையைப் பிரி');
  String get splitTransactionTitle =>
      _t('Split transaction', 'लेन-देन विभाजित करें', 'व्यवहार विभागा', 'লেনদেন ভাগ করুন', 'లావాదేవీని విభజించు', 'பரிவர்த்தனையைப் பிரி');
  String get splitTagline => _t(
        'Count only your share toward budgets',
        'बजट में केवल अपना हिस्सा गिनें',
        'बजेटमध्ये फक्त तुमचा वाटा मोजा',
        'বাজেটে শুধু আপনার ভাগ গণনা করুন',
        'బడ్జెట్‌లలో మీ వాటా మాత్రమే లెక్కించు',
        'பட்ஜெட்களில் உங்கள் பங்கை மட்டும் கணக்கிடு',
      );
  String get yourShareLabel => _t('Your share', 'आपका हिस्सा', 'तुमचा वाटा', 'আপনার ভাগ', 'మీ వాటా', 'உங்கள் பங்கு');
  String get quickSplit => _t('Quick split', 'त्वरित विभाजन', 'झटपट विभाजन', 'দ্রুত ভাগ', 'త్వరిత విభజన', 'விரைவு பிரிப்பு');
  String splitEquallyAmongN(int n) => _t(
        'Split equally among $n',
        '$n लोगों में बराबर बाँटें',
        '$n जणांमध्ये समान वाटा',
        '$n জনের মধ্যে সমানভাবে ভাগ করুন',
        '$n మంది మధ్య సమానంగా విభజించు',
        '$n பேருக்கு இடையே சமமாகப் பிரி',
      );
  String countsToBudgets(String share) => _t(
        '$share counts toward your budgets',
        '$share आपके बजट में गिना जाएगा',
        '$share तुमच्या बजेटमध्ये मोजला जाईल',
        '$share আপনার বাজেটে গণনা হবে',
        '$share మీ బడ్జెట్‌లలో లెక్కించబడుతుంది',
        '$share உங்கள் பட்ஜெட்களில் கணக்கிடப்படும்',
      );
  String restNotYours(String rest) => _t(
        "$rest isn't your spend",
        '$rest आपका खर्च नहीं है',
        '$rest तुमचा खर्च नाही',
        '$rest আপনার খরচ নয়',
        '$rest మీ ఖర్చు కాదు',
        '$rest உங்கள் செலவு அல்ல',
      );
  String trackWhoOwes(String amount) => _t(
        'Track who owes you $amount',
        'आपको $amount किसका बकाया है, ट्रैक करें',
        'तुम्हाला $amount कोण देणे आहे ते ट्रॅक करा',
        'কার কাছে আপনার $amount পাওনা তা ট্র্যাক করুন',
        'మీకు $amount ఎవరు బాకీ ఉన్నారో ట్రాక్ చేయండి',
        'உங்களுக்கு $amount யார் தரவேண்டும் என்பதைக் கண்காணி',
      );
  String get trackWhoOwesHint => _t(
        'Records it in the ledger so you can settle up later',
        'इसे लेज़र में दर्ज करता है ताकि आप बाद में निपटा सकें',
        'नंतर निकाली करता यावी म्हणून लेजरमध्ये नोंदवते',
        'এটি খাতায় নথিভুক্ত করে যাতে আপনি পরে নিষ্পত্তি করতে পারেন',
        'మీరు తర్వాత సెటిల్ చేయగలిగేలా దీన్ని లెడ్జర్‌లో నమోదు చేస్తుంది',
        'நீங்கள் பிறகு தீர்க்கும் வகையில் இதை லெட்ஜரில் பதிவு செய்கிறது',
      );
  String owesAmount(String share) =>
      _t('owes $share', '$share बकाया', '$share देणे', '$share পাওনা', '$share బాకీ', '$share தரவேண்டும்');
  String get removeSplit => _t('Remove split', 'विभाजन हटाएँ', 'विभाजन काढा', 'স্প্লিট সরান', 'స్ప్లిట్ తీసివేయి', 'பிரிப்பை அகற்று');
  String get splitSavedToast =>
      _t('Split saved', 'विभाजन सहेजा गया', 'विभाजन जतन केले', 'স্প্লিট সেভ হয়েছে', 'స్ప్లిట్ సేవ్ అయింది', 'பிரிப்பு சேமிக்கப்பட்டது');
  String get splitRemovedToast =>
      _t('Split removed', 'विभाजन हटाया गया', 'विभाजन काढले', 'স্প্লিট সরানো হয়েছে', 'స్ప్లిట్ తీసివేయబడింది', 'பிரிப்பு அகற்றப்பட்டது');
  String get shareCantExceedTotal => _t(
        "Your share can't exceed the total",
        'आपका हिस्सा कुल से अधिक नहीं हो सकता',
        'तुमचा वाटा एकूणपेक्षा जास्त असू शकत नाही',
        'আপনার ভাগ মোটের চেয়ে বেশি হতে পারে না',
        'మీ వాటా మొత్తాన్ని మించకూడదు',
        'உங்கள் பங்கு மொத்தத்தை மீற முடியாது',
      );
  String get addSomeoneWhoOwes => _t(
        'Add at least one person who owes you',
        'कम से कम एक व्यक्ति जोड़ें जिस पर आपका बकाया है',
        'तुम्हाला देणे असलेली किमान एक व्यक्ती जोडा',
        'অন্তত একজন ব্যক্তি যোগ করুন যার কাছে আপনার পাওনা',
        'మీకు బాకీ ఉన్న కనీసం ఒక వ్యక్తిని జోడించండి',
        'உங்களுக்குக் கடன்பட்ட குறைந்தது ஒரு நபரையாவது சேருங்கள்',
      );
  String yourShareOfTotal(String share, String total) => _t(
        'Your share · $share of $total',
        'आपका हिस्सा · $total में से $share',
        'तुमचा वाटा · $total पैकी $share',
        'আপনার ভাগ · $total-এর মধ্যে $share',
        'మీ వాటా · $total లో $share',
        'உங்கள் பங்கு · $total இல் $share',
      );
  String get splitBadgeLabel => _t('Split', 'विभाजित', 'विभागलेले', 'ভাগ করা', 'విభజన', 'பிரிப்பு');
  String cardYourShare(String share) =>
      _t('your share $share', 'आपका हिस्सा $share', 'तुमचा वाटा $share', 'আপনার ভাগ $share', 'మీ వాటా $share', 'உங்கள் பங்கு $share');
  String get saveSplitCta => _t('Save', 'सहेजें', 'जतन करा', 'সেভ করুন', 'సేవ్ చేయి', 'சேமி');

  // ── Settlement (repayments are not income) ──────────────────────────────────
  String get thisIsASettlement =>
      _t('This is a settlement', 'यह एक निपटान है', 'हे एक निकाली आहे', 'এটি একটি নিষ্পত্তি', 'ఇది ఒక సెటిల్‌మెంట్', 'இது ஒரு தீர்வு');
  String get markAsSettlement => _t('Mark as settlement',
      'निपटान के रूप में चिह्नित करें', 'निकाली म्हणून चिन्हांकित करा', 'নিষ্পত্তি হিসেবে চিহ্নিত করুন', 'సెటిల్‌మెంట్‌గా గుర్తించు', 'தீர்வாகக் குறி');
  String get settlementTagline => _t(
        "Money settled — won't count as income or spending",
        'निपटाया गया पैसा — आय या खर्च में नहीं गिना जाएगा',
        'निकाली केलेले पैसे — उत्पन्न किंवा खर्चात मोजले जाणार नाहीत',
        'নিষ্পত্তি করা টাকা — আয় বা খরচ হিসেবে গণ্য হবে না',
        'సెటిల్ చేసిన డబ్బు — ఆదాయం లేదా ఖర్చుగా లెక్కించబడదు',
        'தீர்க்கப்பட்ட பணம் — வருமானம் அல்லது செலவாகக் கணக்கிடப்படாது',
      );
  String get settlementExplainer => _t(
        'Repaying — or being repaid for — money one of you fronted. It stays '
            'out of your income and spending.',
        'किसी के द्वारा आगे दिए गए पैसे की वापसी — यह आपकी आय और खर्च से बाहर रहता है।',
        'कोणीतरी आधी दिलेल्या पैशांची परतफेड — हे तुमच्या उत्पन्न आणि खर्चाबाहेर राहते.',
        'আপনাদের একজনের আগে দেওয়া টাকার পরিশোধ — অথবা ফেরত পাওয়া। এটি '
            'আপনার আয় ও খরচের বাইরে থাকে।',
        'మీలో ఒకరు ముందుగా చెల్లించిన డబ్బును తిరిగి చెల్లించడం — లేదా తిరిగి పొందడం. ఇది మీ ఆదాయం మరియు ఖర్చు నుండి బయట ఉంటుంది.',
        'உங்களில் ஒருவர் முன்பணமாகச் செலுத்திய பணத்தைத் திருப்பிச் செலுத்துதல் — அல்லது திரும்பப் பெறுதல். இது உங்கள் வருமானம் மற்றும் செலவுக்கு வெளியே இருக்கும்.',
      );
  String get settlementBadge => _t('Settlement', 'निपटान', 'निकाली', 'নিষ্পত্তি', 'సెటిల్‌మెంట్', 'தீர்வு');
  String get whoPaidYouBack =>
      _t('Who paid you back?', 'किसने आपको लौटाया?', 'कोणी परत दिले?', 'কে আপনাকে ফেরত দিয়েছে?', 'మీకు ఎవరు తిరిగి చెల్లించారు?', 'உங்களுக்கு யார் திரும்பச் செலுத்தினார்?');
  String get settlementFromOptional =>
      _t('From (optional)', 'से (वैकल्पिक)', 'कडून (पर्यायी)', 'কাছ থেকে (ঐচ্ছিক)', 'నుండి (ఐచ్ఛికం)', 'இருந்து (விருப்பம்)');
  String clearsBalance(String person, String amount) => _t(
        "Clears $person's balance by $amount",
        '$person का बकाया $amount से घटाता है',
        '$person चे येणे $amount ने कमी करते',
        '$person-এর বকেয়া $amount কমিয়ে দেয়',
        '$person యొక్క బ్యాలెన్స్‌ను $amount తగ్గిస్తుంది',
        '$person இன் இருப்பை $amount குறைக்கிறது',
      );
  String get removeSettlement =>
      _t('Remove settlement', 'निपटान हटाएँ', 'निकाली काढा', 'নিষ্পত্তি সরান', 'సెటిల్‌మెంట్ తీసివేయి', 'தீர்வை அகற்று');
  String get settlementSavedToast => _t('Marked as settlement',
      'निपटान के रूप में चिह्नित', 'निकाली म्हणून चिन्हांकित', 'নিষ্পত্তি হিসেবে চিহ্নিত', 'సెటిల్‌మెంట్‌గా గుర్తించబడింది', 'தீர்வாகக் குறிக்கப்பட்டது');
  String get settlementRemovedToast =>
      _t('Settlement removed', 'निपटान हटाया गया', 'निकाली काढली', 'নিষ্পত্তি সরানো হয়েছে', 'సెటిల్‌మెంట్ తీసివేయబడింది', 'தீர்வு அகற்றப்பட்டது');
  String settlementSuggestFrom(String person) => _t(
        'Looks like $person settling up — mark as settlement?',
        'लगता है $person निपटा रहे हैं — निपटान के रूप में चिह्नित करें?',
        '$person निकाली करत आहेत असे दिसते — निकाली म्हणून चिन्हांकित करावे?',
        'মনে হচ্ছে $person নিষ্পত্তি করছে — নিষ্পত্তি হিসেবে চিহ্নিত করবেন?',
        '$person సెటిల్ చేస్తున్నట్లుంది — సెటిల్‌మెంట్‌గా గుర్తించాలా?',
        '$person தீர்ப்பது போல் தெரிகிறது — தீர்வாகக் குறிக்கவா?',
      );
  String get settlementSuggestGeneric => _t(
        'Looks like a repayment — mark as settlement?',
        'यह एक वापसी लगती है — निपटान के रूप में चिह्नित करें?',
        'ही परतफेड वाटते — निकाली म्हणून चिन्हांकित करावे?',
        'এটি একটি পরিশোধ মনে হচ্ছে — নিষ্পত্তি হিসেবে চিহ্নিত করবেন?',
        'ఇది తిరిగి చెల్లింపులా ఉంది — సెటిల్‌మెంట్‌గా గుర్తించాలా?',
        'இது ஒரு திருப்பிச் செலுத்துதல் போல் தெரிகிறது — தீர்வாகக் குறிக்கவா?',
      );
  String get cardSettlement => _t('settlement', 'निपटान', 'निकाली', 'নিষ্পত্তি', 'సెటిల్‌మెంట్', 'தீர்வு');

  // ── Savings goals ─────────────────────────────────────────────────────────
  String get savingsGoalsTitle => _t('Savings Goals', 'बचत लक्ष्य', 'बचत उद्दिष्टे', 'সঞ্চয় লক্ষ্য', 'పొదుపు లక్ష్యాలు', 'சேமிப்பு இலக்குகள்');
  String get goalsSubtitle => _t('Set a target and watch the jar fill up',
      'लक्ष्य तय करें और जार को भरते देखें', 'उद्दिष्ट ठरवा आणि भरणारी बरणी पाहा', 'একটি লক্ষ্য ঠিক করুন এবং বয়াম ভরে উঠতে দেখুন', 'ఒక లక్ష్యాన్ని సెట్ చేసి జార్ నిండటాన్ని చూడండి', 'ஒரு இலக்கை அமைத்து ஜாடி நிரம்புவதைப் பாருங்கள்');
  String get newGoal => _t('New goal', 'नया लक्ष्य', 'नवीन उद्दिष्ट', 'নতুন লক্ষ্য', 'కొత్త లక్ష్యం', 'புதிய இலக்கு');
  String get setFirstGoal =>
      _t('Set your first savings goal', 'अपना पहला बचत लक्ष्य तय करें', 'तुमचे पहिले बचत उद्दिष्ट ठरवा', 'আপনার প্রথম সঞ্চয় লক্ষ্য ঠিক করুন', 'మీ మొదటి పొదుపు లక్ష్యాన్ని సెట్ చేయండి', 'உங்கள் முதல் சேமிப்பு இலக்கை அமையுங்கள்');
  String get setFirstGoalDesc => _t(
        'Name a target like "Goa trip ₹40k by December", then chip away at '
            'it. Add to it whenever you set money aside.',
        '"दिसंबर तक गोवा ट्रिप ₹40k" जैसा लक्ष्य रखें, फिर धीरे-धीरे जोड़ें। '
            'जब भी पैसे अलग रखें, इसमें डालें।',
        '"डिसेंबरपर्यंत गोवा ट्रिप ₹40k" सारखे उद्दिष्ट ठेवा, मग हळूहळू त्याकडे '
            'वाटचाल करा. जेव्हा तुम्ही पैसे बाजूला ठेवता तेव्हा त्यात भर घाला.',
        '"ডিসেম্বরের মধ্যে গোয়া ট্রিপ ₹40k"-এর মতো একটি লক্ষ্য রাখুন, তারপর ধীরে ধীরে '
            'এগিয়ে যান। যখনই টাকা আলাদা করে রাখবেন, এতে যোগ করুন।',
        '"డిసెంబర్‌లోగా గోవా ట్రిప్ ₹40k" వంటి లక్ష్యానికి పేరు పెట్టండి, తర్వాత దాన్ని క్రమంగా చేరుకోండి. మీరు డబ్బు పక్కన పెట్టినప్పుడల్లా దానికి జోడించండి.',
        '"டிசம்பருக்குள் கோவா பயணம் ₹40k" போன்ற ஒரு இலக்குக்குப் பெயரிடுங்கள், பிறகு படிப்படியாக அதை நோக்கிச் செல்லுங்கள். நீங்கள் பணத்தை ஒதுக்கும் போதெல்லாம் அதில் சேருங்கள்.',
      );
  String get goalReachedTitle => _t('Goal reached! 🎉', 'लक्ष्य पूरा! 🎉', 'उद्दिष्ट पूर्ण! 🎉', 'লক্ষ্য পূর্ণ! 🎉', 'లక్ష్యం చేరుకున్నారు! 🎉', 'இலக்கை அடைந்தீர்கள்! 🎉');
  String goalReachedMsg(String amount, String name) => _t(
        'You saved $amount for $name. Incredible work!',
        'आपने $name के लिए $amount बचाए। शानदार काम!',
        'तुम्ही $name साठी $amount बचत केली. भन्नाट काम!',
        'আপনি $name-এর জন্য $amount সঞ্চয় করেছেন। অসাধারণ কাজ!',
        'మీరు $name కోసం $amount పొదుపు చేశారు. అద్భుతమైన పని!',
        'நீங்கள் $name க்காக $amount சேமித்தீர்கள். அற்புதமான வேலை!',
      );
  String get niceExclaim => _t('Nice!', 'बढ़िया!', 'छान!', 'দারুণ!', 'బాగుంది!', 'அருமை!');
  String get deleteGoalTitle => _t('Delete goal?', 'लक्ष्य हटाएँ?', 'उद्दिष्ट हटवायचे?', 'লক্ষ্য মুছবেন?', 'లక్ష్యాన్ని తొలగించాలా?', 'இலக்கை நீக்கவா?');
  String get deleteGoalConfirm => _t(
        "This removes the goal and all its contributions. It can't be undone.",
        'यह लक्ष्य और इसके सभी योगदान हटा देगा। इसे पूर्ववत नहीं किया जा सकता।',
        'हे उद्दिष्ट व त्याची सर्व योगदाने हटवेल. हे पूर्ववत करता येणार नाही.',
        'এটি লক্ষ্য ও এর সব অবদান মুছে ফেলে। এটি পূর্বাবস্থায় ফেরানো যায় না।',
        'ఇది లక్ష్యాన్ని మరియు దాని అన్ని విరాళాలను తొలగిస్తుంది. దీన్ని రద్దు చేయలేరు.',
        'இது இலக்கையும் அதன் அனைத்து பங்களிப்புகளையும் நீக்குகிறது. இதைச் செயல்தவிர்க்க முடியாது.',
      );
  String get goalLabel => _t('Goal', 'लक्ष्य', 'उद्दिष्ट', 'লক্ষ্য', 'లక్ష్యం', 'இலக்கு');
  String get goalComplete => _t('Goal complete', 'लक्ष्य पूरा', 'उद्दिष्ट पूर्ण', 'লক্ষ্য সম্পূর্ণ', 'లక్ష్యం పూర్తయింది', 'இலக்கு முடிந்தது');
  String get addToGoal => _t('Add to goal', 'लक्ष्य में जोड़ें', 'उद्दिष्टात जोडा', 'লক্ষ্যে যোগ করুন', 'లక్ష్యానికి జోడించు', 'இலக்கில் சேர்');
  String get contributionsLabel => _t('Contributions', 'योगदान', 'योगदाने', 'অবদান', 'విరాళాలు', 'பங்களிப்புகள்');
  String get noContributionsYet => _t(
        'No contributions yet — add your first deposit above.',
        'अभी कोई योगदान नहीं — ऊपर अपनी पहली जमा जोड़ें।',
        'अजून कोणतेही योगदान नाही — वर तुमची पहिली जमा जोडा.',
        'এখনও কোনো অবদান নেই — উপরে আপনার প্রথম জমা যোগ করুন।',
        'ఇంకా విరాళాలు లేవు — పైన మీ మొదటి డిపాజిట్‌ను జోడించండి.',
        'இன்னும் பங்களிப்புகள் இல்லை — மேலே உங்கள் முதல் வைப்பைச் சேருங்கள்.',
      );
  String get progressLabel => _t('Progress', 'प्रगति', 'प्रगती', 'অগ্রগতি', 'పురోగతి', 'முன்னேற்றம்');
  String get remainingLabel => _t('Remaining', 'शेष', 'शिल्लक', 'বাকি', 'మిగిలింది', 'மீதம்');
  String get deadlineLabel => _t('Deadline', 'समयसीमा', 'मुदत', 'সময়সীমা', 'గడువు', 'காலக்கெடு');
  String get toStayOnTrack => _t('To stay on track', 'राह पर बने रहने के लिए', 'मार्गावर राहण्यासाठी', 'পথে থাকতে', 'ట్రాక్‌లో ఉండటానికి', 'தடத்தில் இருக்க');
  String perMonthValue(String amount) => _t('$amount/month', '$amount/माह', '$amount/महिना', '$amount/মাস', '$amount/నెల', '$amount/மாதம்');
  String get statusLabel => _t('Status', 'स्थिति', 'स्थिती', 'অবস্থা', 'స్థితి', 'நிலை');
  String get completedStatus => _t('Completed 🎉', 'पूर्ण 🎉', 'पूर्ण 🎉', 'সম্পূর্ণ 🎉', 'పూర్తయింది 🎉', 'முடிந்தது 🎉');
  String get newSavingsGoal => _t('New savings goal', 'नया बचत लक्ष्य', 'नवीन बचत उद्दिष्ट', 'নতুন সঞ্চয় লক্ষ্য', 'కొత్త పొదుపు లక్ష్యం', 'புதிய சேமிப்பு இலக்கு');
  String get editGoal => _t('Edit goal', 'लक्ष्य संपादित करें', 'उद्दिष्ट संपादित करा', 'লক্ষ্য সম্পাদনা করুন', 'లక్ష్యాన్ని సవరించు', 'இலக்கைத் திருத்து');
  String get goalNameLabel => _t('Goal name', 'लक्ष्य का नाम', 'उद्दिष्टाचे नाव', 'লক্ষ্যের নাম', 'లక్ష్యం పేరు', 'இலக்கு பெயர்');
  String get goalNameHint => _t('e.g. Goa trip', 'जैसे गोवा ट्रिप', 'उदा. गोवा ट्रिप', 'যেমন গোয়া ট্রিপ', 'ఉదా. గోవా ట్రిప్', 'எ.கா. கோவா பயணம்');
  String get targetAmount => _t('Target amount', 'लक्ष्य राशि', 'लक्ष्य रक्कम', 'লক্ষ্য পরিমাণ', 'లక్ష్య మొత్తం', 'இலக்கு தொகை');
  String get iconLabel => _t('ICON', 'आइकन', 'आयकॉन', 'আইকন', 'ఐకాన్', 'ஐகான்');
  String get colourLabel => _t('COLOUR', 'रंग', 'रंग', 'রং', 'రంగు', 'நிறம்');
  String get deadlineOptionalLabel =>
      _t('DEADLINE (OPTIONAL)', 'समयसीमा (वैकल्पिक)', 'मुदत (पर्यायी)', 'সময়সীমা (ঐচ্ছিক)', 'గడువు (ఐచ్ఛికం)', 'காலக்கெடு (விருப்பம்)');
  String get pickADate => _t('Pick a date', 'तारीख चुनें', 'तारीख निवडा', 'একটি তারিখ বেছে নিন', 'ఒక తేదీని ఎంచుకోండి', 'ஒரு தேதியைத் தேர்ந்தெடு');
  String get createGoal => _t('Create goal', 'लक्ष्य बनाएँ', 'उद्दिष्ट तयार करा', 'লক্ষ্য তৈরি করুন', 'లక్ష్యాన్ని సృష్టించు', 'இலக்கை உருவாக்கு');
  String completeAmount(String amount) =>
      _t('Complete ($amount)', 'पूरा करें ($amount)', 'पूर्ण करा ($amount)', 'সম্পূর্ণ করুন ($amount)', 'పూర్తి చేయి ($amount)', 'முடி ($amount)');
  String get noteOptional => _t('Note (optional)', 'नोट (वैकल्पिक)', 'नोट (पर्यायी)', 'নোট (ঐচ্ছিক)', 'నోట్ (ఐచ్ఛికం)', 'குறிப்பு (விருப்பம்)');

  // ── Insights / analytics ──────────────────────────────────────────────────
  String get insightsTitle => _t('Insights', 'अंतर्दृष्टि', 'अंतर्दृष्टी', 'অন্তর্দৃষ্টি', 'అంతర్దృష్టులు', 'நுண்ணறிவுகள்');
  String get spendingTrend => _t('Spending trend', 'खर्च का रुझान', 'खर्चाचा कल', 'খরচের প্রবণতা', 'ఖర్చు ధోరణి', 'செலவு போக்கு');
  String get last6Months => _t('Last 6 months', 'पिछले 6 महीने', 'मागील 6 महिने', 'গত 6 মাস', 'గత 6 నెలలు', 'கடந்த 6 மாதங்கள்');
  String get highlights => _t('Highlights', 'मुख्य बातें', 'ठळक बाबी', 'মূল বিষয়', 'ముఖ్యాంశాలు', 'முக்கிய அம்சங்கள்');
  String get projectedThisMonth =>
      _t('PROJECTED THIS MONTH', 'इस महीने का अनुमान', 'या महिन्याचा अंदाज', 'এই মাসের পূর্বাভাস', 'ఈ నెల అంచనా', 'இந்த மாதம் கணிக்கப்பட்டது');
  String get notEnoughHistoryYet =>
      _t('Not enough history yet', 'अभी पर्याप्त इतिहास नहीं', 'अजून पुरेसा इतिहास नाही', 'এখনও পর্যাপ্ত ইতিহাস নেই', 'ఇంకా తగినంత చరిత్ర లేదు', 'இன்னும் போதிய வரலாறு இல்லை');
  String get buildingBaselineTrends => _t(
        'Building your baseline. Trends and forecasts sharpen after a few '
            'weeks of activity.',
        'आपका आधार बन रहा है। कुछ हफ़्तों की गतिविधि के बाद रुझान और अनुमान '
            'और साफ़ होंगे।',
        'तुमचा आधार तयार होत आहे. काही आठवड्यांच्या हालचालीनंतर कल आणि अंदाज '
            'अधिक स्पष्ट होतील.',
        'আপনার ভিত্তি তৈরি হচ্ছে। কয়েক সপ্তাহের কার্যকলাপের পর প্রবণতা ও পূর্বাভাস '
            'আরও স্পষ্ট হবে।',
        'మీ ఆధారరేఖను నిర్మిస్తోంది. కొన్ని వారాల కార్యకలాపం తర్వాత ధోరణులు మరియు అంచనాలు మరింత స్పష్టమవుతాయి.',
        'உங்கள் அடிப்படையை உருவாக்குகிறது. சில வாரங்கள் செயல்பாட்டுக்குப் பிறகு போக்குகளும் முன்கணிப்புகளும் தெளிவாகும்.',
      );
  String get buildingBaselineInsights => _t(
        'Building your baseline. Insights and forecasts sharpen after a '
            'few weeks of activity.',
        'आपका आधार बन रहा है। कुछ हफ़्तों की गतिविधि के बाद जानकारी और अनुमान '
            'और साफ़ होंगे।',
        'तुमचा आधार तयार होत आहे. काही आठवड्यांच्या हालचालीनंतर माहिती आणि अंदाज '
            'अधिक स्पष्ट होतील.',
        'আপনার ভিত্তি তৈরি হচ্ছে। কয়েক সপ্তাহের কার্যকলাপের পর অন্তর্দৃষ্টি ও পূর্বাভাস '
            'আরও স্পষ্ট হবে।',
        'మీ ఆధారరేఖను నిర్మిస్తోంది. కొన్ని వారాల కార్యకలాపం తర్వాత అంతర్దృష్టులు మరియు అంచనాలు మరింత స్పష్టమవుతాయి.',
        'உங்கள் அடிப்படையை உருவாக்குகிறது. சில வாரங்கள் செயல்பாட்டுக்குப் பிறகு நுண்ணறிவுகளும் முன்கணிப்புகளும் தெளிவாகும்.',
      );
  String get safeToSpendPrefix =>
      _t('Safe to spend: ', 'खर्च के लिए सुरक्षित: ', 'खर्चासाठी सुरक्षित: ', 'খরচের জন্য নিরাপদ: ', 'ఖర్చు చేయడానికి సురక్షితం: ', 'செலவழிக்க பாதுகாப்பானது: ');
  String get noSpendingYetInsights => _t(
        'No spending yet this month — insights will appear as you spend.',
        'इस महीने अभी कोई खर्च नहीं — जैसे-जैसे खर्च करेंगे, जानकारी दिखेगी।',
        'या महिन्यात अजून खर्च नाही — जसजसे खर्च कराल तसतशी माहिती दिसेल.',
        'এই মাসে এখনও কোনো খরচ নেই — যত খরচ করবেন তত অন্তর্দৃষ্টি দেখা যাবে।',
        'ఈ నెల ఇంకా ఖర్చు లేదు — మీరు ఖర్చు చేస్తున్న కొద్దీ అంతర్దృష్టులు కనిపిస్తాయి.',
        'இந்த மாதம் இன்னும் செலவு இல்லை — நீங்கள் செலவழிக்கும் போது நுண்ணறிவுகள் தோன்றும்.',
      );
  // Daily analysis
  String get dailyAnalysisTitle => _t('Daily Analysis', 'दैनिक विश्लेषण', 'दैनिक विश्लेषण', 'দৈনিক বিশ্লেষণ', 'రోజువారీ విశ్లేషణ', 'தினசரி பகுப்பாய்வு');
  String get noTransactions => _t('No transactions', 'कोई लेन-देन नहीं', 'कोणताही व्यवहार नाही', 'কোনো লেনদেন নেই', 'లావాదేవీలు లేవు', 'பரிவர்த்தனைகள் இல்லை');
  String get received => _t('Received', 'प्राप्त', 'मिळाले', 'প্রাপ্ত', 'అందింది', 'பெறப்பட்டது');
  String get spendingBreakdown => _t('Spending Breakdown', 'खर्च का विवरण', 'खर्चाचा तपशील', 'খরচের বিশ্লেষণ', 'ఖర్చు విభజన', 'செலவு விவரம்');
  // Category budget insights
  String get categoryBudgetUpper => _t('CATEGORY BUDGET', 'श्रेणी बजट', 'श्रेणी बजेट', 'বিভাগ বাজেট', 'వర్గ బడ్జెట్', 'வகை பட்ஜெட்');
  String get whereItGoes => _t('Where it goes', 'पैसा कहाँ जाता है', 'पैसे कुठे जातात', 'টাকা কোথায় যায়', 'ఎక్కడికి వెళ్తుంది', 'எங்கு செல்கிறது');
  String topMerchantsIn(String cat) => _t('Top merchants in $cat this month',
      'इस महीने $cat में शीर्ष व्यापारी', 'या महिन्यात $cat मधील आघाडीचे व्यापारी', 'এই মাসে $cat-এ শীর্ষ বিক্রেতা', 'ఈ నెల $catలో టాప్ మర్చెంట్‌లు', 'இந்த மாதம் $cat இல் சிறந்த வணிகர்கள்');
  String get noSpendingInCategory => _t(
      'No spending in this category yet', 'इस श्रेणी में अभी कोई खर्च नहीं', 'या श्रेणीत अजून कोणताही खर्च नाही', 'এই বিভাগে এখনও কোনো খরচ নেই', 'ఈ వర్గంలో ఇంకా ఖర్చు లేదు', 'இந்த வகையில் இன்னும் செலவு இல்லை');
  String editCategoryBudget(String cat) =>
      _t('Edit $cat budget', '$cat बजट संपादित करें', '$cat बजेट संपादित करा', '$cat বাজেট সম্পাদনা করুন', '$cat బడ్జెట్ సవరించు', '$cat பட்ஜெட்டைத் திருத்து');
  String get setCategoryLimitDesc => _t(
        'Set the monthly limit for this category. Alerts fire at '
            '50, 75, 90 and 100%+.',
        'इस श्रेणी के लिए मासिक सीमा तय करें। 50, 75, 90 और 100%+ पर अलर्ट मिलते हैं।',
        'या श्रेणीसाठी मासिक मर्यादा ठरवा. 50, 75, 90 आणि 100%+ वर सूचना मिळतात.',
        'এই বিভাগের জন্য মাসিক সীমা ঠিক করুন। '
            '50, 75, 90 এবং 100%+ এ সতর্কতা আসে।',
        'ఈ వర్గానికి నెలవారీ పరిమితిని సెట్ చేయండి. 50, 75, 90 మరియు 100%+ వద్ద హెచ్చరికలు వస్తాయి.',
        'இந்த வகைக்கு மாதாந்திர வரம்பை அமையுங்கள். 50, 75, 90 மற்றும் 100%+ இல் எச்சரிக்கைகள் வரும்.',
      );
  String get budgetUpdated => _t('Budget updated', 'बजट अपडेट हुआ', 'बजेट अपडेट झाले', 'বাজেট আপডেট হয়েছে', 'బడ్జెట్ నవీకరించబడింది', 'பட்ஜெட் புதுப்பிக்கப்பட்டது');
  // Safe to spend
  String get budgetWord => _t('budget', 'बजट', 'बजेट', 'বাজেট', 'బడ్జెట్', 'பட்ஜெட்');
  String get typicalMonth => _t('typical month', 'सामान्य महीना', 'नेहमीचा महिना', 'সাধারণ মাস', 'సాధారణ నెల', 'வழக்கமான மாதம்');
  String get safeToSpend => _t('Safe to spend', 'खर्च के लिए सुरक्षित', 'खर्चासाठी सुरक्षित', 'খরচের জন্য নিরাপদ', 'ఖర్చు చేయడానికి సురక్షితం', 'செலவழிக்க பாதுகாப்பானது');
  String get vsBudget => _t('vs budget', 'बजट बनाम', 'बजेटच्या तुलनेत', 'বাজেটের তুলনায়', 'బడ్జెట్‌తో పోలిస్తే', 'பட்ஜெட்டுடன்');
  String get vsTypical => _t('vs typical', 'सामान्य बनाम', 'नेहमीच्या तुलनेत', 'সাধারণের তুলনায়', 'సాధారణంతో పోలిస్తే', 'வழக்கத்துடன்');
  String passedTarget(String target, String month, String amount) => _t(
        "You've passed your $target for $month by $amount.",
        'आपने $month के लिए अपना $target $amount से पार कर लिया।',
        'तुम्ही $month साठी तुमचा $target $amount ने ओलांडला.',
        'আপনি $month-এর জন্য আপনার $target $amount দিয়ে অতিক্রম করেছেন।',
        'మీరు $month కోసం మీ $targetను $amount తో అధిగమించారు.',
        '$month க்கான உங்கள் $target ஐ $amount ஆல் தாண்டிவிட்டீர்கள்.',
      );
  String amountLeftDays(String amount, int days) => _t(
        '$amount left · $days day${days == 1 ? '' : 's'} to go',
        '$amount शेष · $days दिन बाकी',
        '$amount शिल्लक · $days दिवस बाकी',
        '$amount বাকি · $days দিন বাকি',
        '$amount మిగిలింది · $days రోజులు మిగిలాయి',
        '$amount மீதம் · இன்னும் $days நாட்கள்',
      );
  String overTargetMsg(String target, String month) => _t(
        'Over your $target — go easy for the rest of $month.',
        'आपका $target पार — $month के बाकी दिन संभलकर खर्च करें।',
        'तुमचा $target ओलांडला — $month चे उरलेले दिवस जपून खर्च करा.',
        'আপনার $target অতিক্রম — $month-এর বাকি দিনগুলো সাবধানে খরচ করুন।',
        'మీ $targetను మించారు — $month మిగిలిన రోజులు జాగ్రత్తగా ఖర్చు చేయండి.',
        'உங்கள் $target ஐ மீறிவிட்டீர்கள் — $month இன் மீதமுள்ள நாட்களில் கவனமாகச் செலவழியுங்கள்.',
      );
  String get aheadOfPaceMsg => _t(
        'A little ahead of pace — ease up to stay comfortable.',
        'गति से थोड़ा आगे — सहज रहने के लिए थोड़ा धीमे चलें।',
        'गतीपेक्षा थोडे पुढे — सुखरूप राहण्यासाठी थोडे सावकाश करा.',
        'গতির চেয়ে একটু এগিয়ে — স্বচ্ছন্দ থাকতে একটু ধীরে চলুন।',
        'వేగం కంటే కొంచెం ముందున్నారు — స్వేచ్ఛగా ఉండటానికి కొంచెం నెమ్మదించండి.',
        'வேகத்தை விட சற்று முன்னால் உள்ளீர்கள் — வசதியாக இருக்க சற்று மெதுவாகச் செல்லுங்கள்.',
      );
  String get onTrackMsg => _t(
        'On track. Spending evenly keeps you within plan.',
        'सही राह पर। समान रूप से खर्च आपको योजना में रखता है।',
        'योग्य मार्गावर. समान खर्च तुम्हाला योजनेत ठेवतो.',
        'পথে আছেন। সমানভাবে খরচ করলে পরিকল্পনার মধ্যে থাকবেন।',
        'ట్రాక్‌లో ఉన్నారు. సమానంగా ఖర్చు చేస్తే ప్రణాళికలో ఉంటారు.',
        'தடத்தில் உள்ளீர்கள். சமமாகச் செலவழித்தால் திட்டத்திற்குள் இருப்பீர்கள்.',
      );
  // Financial health
  String get financialHealth => _t('Financial Health', 'वित्तीय स्वास्थ्य', 'आर्थिक आरोग्य', 'আর্থিক স্বাস্থ্য', 'ఆర్థిక ఆరోగ్యం', 'நிதி ஆரோக்கியம்');
  String get financialHealthUpper =>
      _t('FINANCIAL HEALTH', 'वित्तीय स्वास्थ्य', 'आर्थिक आरोग्य', 'আর্থিক স্বাস্থ্য', 'ఆర్థిక ఆరోగ్యం', 'நிதி ஆரோக்கியம்');
  String get howScoreCalculated => _t(
      'How your score is calculated', 'आपका स्कोर कैसे निकाला जाता है', 'तुमचा स्कोअर कसा काढला जातो', 'আপনার স্কোর কীভাবে গণনা করা হয়', 'మీ స్కోర్ ఎలా లెక్కించబడుతుంది', 'உங்கள் மதிப்பெண் எப்படிக் கணக்கிடப்படுகிறது');
  String get budgetAdherence => _t('Budget adherence', 'बजट पालन', 'बजेट पालन', 'বাজেট মেনে চলা', 'బడ్జెట్ పాటించడం', 'பட்ஜெட் கடைப்பிடிப்பு');
  String get recurringLoad => _t('Recurring load', 'आवर्ती भार', 'आवर्ती भार', 'পুনরাবৃত্ত বোঝা', 'పునరావృత భారం', 'தொடர் சுமை');
  String get netWorthWord => _t('Net worth', 'नेट वर्थ', 'नेट वर्थ', 'নেট ওয়ার্থ', 'నెట్ వర్త్', 'நிகர மதிப்பு');
  String get healthEmptyDesc => _t(
        'Add some income, a budget, or holdings and your Financial Health '
            'Score will appear here.',
        'कुछ आय, बजट या होल्डिंग जोड़ें और आपका वित्तीय स्वास्थ्य स्कोर यहाँ दिखेगा।',
        'थोडे उत्पन्न, बजेट किंवा होल्डिंग जोडा आणि तुमचा आर्थिक आरोग्य स्कोअर येथे दिसेल.',
        'কিছু আয়, একটি বাজেট, বা হোল্ডিং যোগ করুন এবং আপনার আর্থিক স্বাস্থ্য '
            'স্কোর এখানে দেখা যাবে।',
        'కొంత ఆదాయం, ఒక బడ్జెట్, లేదా హోల్డింగ్‌లను జోడించండి, మీ ఆర్థిక ఆరోగ్య స్కోర్ ఇక్కడ కనిపిస్తుంది.',
        'சில வருமானம், ஒரு பட்ஜெட், அல்லது ஹோல்டிங்குகளைச் சேருங்கள், உங்கள் நிதி ஆரோக்கிய மதிப்பெண் இங்கே தோன்றும்.',
      );
  String get howScoreWorks =>
      _t('How your score works', 'आपका स्कोर कैसे काम करता है', 'तुमचा स्कोअर कसा काम करतो', 'আপনার স্কোর কীভাবে কাজ করে', 'మీ స్కోర్ ఎలా పనిచేస్తుంది', 'உங்கள் மதிப்பெண் எப்படி வேலை செய்கிறது');
  String get howScoreWorksDesc => _t(
        'A single 0–100 number (100 is healthy, 0 is poor) blended from up '
            'to four pillars. Pillars without data yet are skipped and the rest '
            'reweighted, so the score always reflects what we can see.',
        'एक ही 0–100 अंक (100 स्वस्थ, 0 कमज़ोर) जो चार स्तंभों से बनता है। '
            'जिन स्तंभों का डेटा नहीं, उन्हें छोड़ दिया जाता है और बाकी का भार '
            'पुनः समायोजित होता है, ताकि स्कोर हमेशा उपलब्ध डेटा दर्शाए।',
        'चार स्तंभांमधून बनलेला एकच 0–100 आकडा (100 निरोगी, 0 कमकुवत). '
            'ज्या स्तंभांचा डेटा नाही ते वगळले जातात आणि बाकीच्यांचे वजन पुन्हा '
            'समायोजित होते, त्यामुळे स्कोअर नेहमी उपलब्ध डेटा दर्शवतो.',
        'চারটি স্তম্ভ থেকে মিশ্রিত একটি একক 0–100 সংখ্যা (100 সুস্থ, 0 দুর্বল)। '
            'যেসব স্তম্ভের এখনও ডেটা নেই সেগুলো বাদ দেওয়া হয় এবং বাকিগুলোর '
            'ওজন পুনর্বিন্যাস করা হয়, যাতে স্কোর সবসময় যা দেখা যায় তা প্রতিফলিত করে।',
        'నాలుగు స్తంభాల నుండి మిళితమైన ఒకే 0–100 సంఖ్య (100 ఆరోగ్యకరం, 0 బలహీనం). ఇంకా డేటా లేని స్తంభాలు దాటవేయబడతాయి మరియు మిగతావాటి బరువు తిరిగి సర్దుబాటు చేయబడుతుంది, కాబట్టి స్కోర్ ఎల్లప్పుడూ మనం చూడగలిగేదాన్ని ప్రతిబింబిస్తుంది.',
        'நான்கு தூண்களிலிருந்து கலந்த ஒரே 0–100 எண் (100 ஆரோக்கியம், 0 மோசம்). இன்னும் தரவு இல்லாத தூண்கள் தவிர்க்கப்பட்டு மீதமுள்ளவை மறு எடையிடப்படுகின்றன, எனவே மதிப்பெண் எப்போதும் நாம் பார்க்கக்கூடியதைப் பிரதிபலிக்கிறது.',
      );
  String get savingsRateExplain => _t(
        'How much of your income you keep. 20% or more earns full marks.',
        'आप अपनी आय का कितना हिस्सा रखते हैं। 20% या अधिक पर पूरे अंक।',
        'तुम्ही तुमच्या उत्पन्नाचा किती भाग ठेवता. 20% किंवा अधिकवर पूर्ण गुण.',
        'আপনার আয়ের কতটা আপনি রাখেন। 20% বা বেশি হলে পূর্ণ নম্বর।',
        'మీ ఆదాయంలో మీరు ఎంత ఉంచుకుంటారు. 20% లేదా అంతకంటే ఎక్కువ ఉంటే పూర్తి మార్కులు.',
        'உங்கள் வருமானத்தில் எவ்வளவு வைத்திருக்கிறீர்கள். 20% அல்லது அதற்கு மேல் இருந்தால் முழு மதிப்பெண்.',
      );
  String get budgetAdherenceExplain => _t(
        'Staying within the budgets you set. Going over costs points.',
        'अपने तय बजट में रहना। पार करने पर अंक घटते हैं।',
        'तुम्ही ठरवलेल्या बजेटमध्ये राहणे. ओलांडल्यास गुण कमी होतात.',
        'আপনার ঠিক করা বাজেটের মধ্যে থাকা। অতিক্রম করলে নম্বর কমে।',
        'మీరు సెట్ చేసిన బడ్జెట్‌లలో ఉండటం. మించితే పాయింట్లు తగ్గుతాయి.',
        'நீங்கள் அமைத்த பட்ஜெட்களுக்குள் இருப்பது. மீறினால் புள்ளிகள் குறையும்.',
      );
  String get recurringLoadExplain => _t(
        'Recurring commitments (SIPs/RDs) versus income — more headroom scores higher.',
        'आवर्ती प्रतिबद्धताएँ (SIP/RD) बनाम आय — ज़्यादा गुंजाइश पर अधिक अंक।',
        'आवर्ती बांधिलकी (SIP/RD) विरुद्ध उत्पन्न — जास्त वाव असल्यास अधिक गुण.',
        'পুনরাবৃত্ত প্রতিশ্রুতি (SIP/RD) বনাম আয় — বেশি অবকাশ থাকলে বেশি নম্বর।',
        'పునరావృత నిబద్ధతలు (SIP/RD) వర్సెస్ ఆదాయం — ఎక్కువ వెసులుబాటు ఉంటే ఎక్కువ స్కోర్.',
        'தொடர் கடமைகள் (SIP/RD) vs வருமானம் — அதிக இடம் இருந்தால் அதிக மதிப்பெண்.',
      );
  String get netWorthExplain => _t(
        'Your equity — assets versus debts. Counts only if you track holdings.',
        'आपकी इक्विटी — संपत्ति बनाम ऋण। केवल तभी गिना जाता है जब आप होल्डिंग ट्रैक करें।',
        'तुमची इक्विटी — मालमत्ता विरुद्ध कर्ज. तुम्ही होल्डिंग ट्रॅक केल्यासच मोजले जाते.',
        'আপনার ইকুইটি — সম্পদ বনাম ঋণ। আপনি হোল্ডিং ট্র্যাক করলেই কেবল গণনা হয়।',
        'మీ ఈక్విటీ — ఆస్తులు వర్సెస్ అప్పులు. మీరు హోల్డింగ్‌లను ట్రాక్ చేస్తేనే లెక్కించబడుతుంది.',
        'உங்கள் ஈக்விட்டி — சொத்துகள் vs கடன்கள். நீங்கள் ஹோல்டிங்குகளைக் கண்காணித்தால் மட்டுமே கணக்கிடப்படும்.',
      );
  String get computedOnDevice => _t('Everything is computed on your device.',
      'सब कुछ आपके डिवाइस पर गणना होता है।', 'सर्व काही तुमच्या डिव्हाइसवर मोजले जाते.', 'সবকিছু আপনার ডিভাইসে গণনা করা হয়।', 'అంతా మీ పరికరంలోనే లెక్కించబడుతుంది.', 'அனைத்தும் உங்கள் சாதனத்திலேயே கணக்கிடப்படுகிறது.');
  String get gotIt => _t('Got it', 'समझ गया', 'समजले', 'বুঝেছি', 'అర్థమైంది', 'புரிந்தது');
  // Spending calendar
  List<String> get weekdayInitials => switch (lang) {
        AppLanguage.hindi => const ['सो', 'मं', 'बु', 'गु', 'शु', 'श', 'र'],
        AppLanguage.marathi => const ['सो', 'मं', 'बु', 'गु', 'शु', 'श', 'र'],
        AppLanguage.bengali => const ['সো', 'ম', 'বু', 'বৃ', 'শু', 'শ', 'র'],
        AppLanguage.telugu => const ['సో', 'మం', 'బు', 'గు', 'శు', 'శ', 'ఆ'],
        AppLanguage.tamil => const ['தி', 'செ', 'பு', 'வி', 'வெ', 'ச', 'ஞா'],
        AppLanguage.english => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      };
  String get lessLabel => _t('Less', 'कम', 'कमी', 'কম', 'తక్కువ', 'குறைவு');
  String get moreLabel => _t('More', 'ज़्यादा', 'जास्त', 'বেশি', 'ఎక్కువ', 'அதிகம்');
  // Expense chart
  String get expenseTrend => _t('Expense Trend', 'खर्च का रुझान', 'खर्चाचा कल', 'খরচের প্রবণতা', 'ఖర్చు ధోరణి', 'செலவு போக்கு');
  String get last7Days => _t('Last 7 Days', 'पिछले 7 दिन', 'मागील 7 दिवस', 'গত 7 দিন', 'గత 7 రోజులు', 'கடந்த 7 நாட்கள்');
  String get tapForAnalysis => _t('Tap a day for detailed analysis',
      'विस्तृत विश्लेषण के लिए किसी दिन पर टैप करें', 'सविस्तर विश्लेषणासाठी एखाद्या दिवसावर टॅप करा', 'বিস্তারিত বিশ্লেষণের জন্য একটি দিনে ট্যাপ করুন', 'వివరణాత్మక విశ్లేషణ కోసం ఒక రోజుపై ట్యాప్ చేయండి', 'விரிவான பகுப்பாய்வுக்கு ஒரு நாளைத் தட்டுங்கள்');
  String get tapForDetails => _t('Tap for details', 'विवरण के लिए टैप करें', 'तपशिलासाठी टॅप करा', 'বিস্তারিত জানতে ট্যাপ করুন', 'వివరాల కోసం ట్యాప్ చేయండి', 'விவரங்களுக்குத் தட்டுங்கள்');
  String get noExpenseData =>
      _t('No expense data yet', 'अभी कोई खर्च डेटा नहीं', 'अजून कोणताही खर्च डेटा नाही', 'এখনও কোনো খরচ ডেটা নেই', 'ఇంకా ఖర్చు డేటా లేదు', 'இன்னும் செலவு தரவு இல்லை');
  String get todayLabel => _t('Today', 'आज', 'आज', 'আজ', 'ఈ రోజు', 'இன்று');
  // Savings summary
  String get savingsRateUpper => _t('SAVINGS RATE', 'बचत दर', 'बचत दर', 'সঞ্চয় হার', 'పొదుపు రేటు', 'சேமிப்பு விகிதம்');
  String get noIncomeThisMonth => _t(
      'No income recorded this month', 'इस महीने कोई आय दर्ज नहीं', 'या महिन्यात कोणतेही उत्पन्न नोंदले नाही', 'এই মাসে কোনো আয় নথিভুক্ত হয়নি', 'ఈ నెల ఆదాయం ఏదీ నమోదు కాలేదు', 'இந்த மாதம் வருமானம் எதுவும் பதிவாகவில்லை');
  String get noActivityThisMonth => _t(
      'No activity yet this month', 'इस महीने अभी कोई गतिविधि नहीं', 'या महिन्यात अजून कोणतीही हालचाल नाही', 'এই মাসে এখনও কোনো কার্যকলাপ নেই', 'ఈ నెల ఇంకా కార్యకలాపం లేదు', 'இந்த மாதம் இன்னும் செயல்பாடு இல்லை');

  // ── Rewards hub / gamification ────────────────────────────────────────────
  String get rewardsTitle => _t('Rewards', 'रिवॉर्ड', 'रिवॉर्ड', 'রিওয়ার্ড', 'రివార్డ్‌లు', 'வெகுமதிகள்');
  String get profileTab => _t('Profile', 'प्रोफ़ाइल', 'प्रोफाइल', 'প্রোফাইল', 'ప్రొఫైల్', 'சுயவிவரம்');
  String get trophiesTab => _t('Trophies', 'ट्रॉफी', 'ट्रॉफी', 'ট্রফি', 'ట్రోఫీలు', 'கோப்பைகள்');
  String get streaksTab => _t('Streaks', 'स्ट्रीक', 'स्ट्रीक', 'স্ট্রিক', 'స్ట్రీక్‌లు', 'ஸ்ட்ரீக்குகள்');
  // Wrapped
  String get monthlyWrappedTitle => _t('Monthly Wrapped', 'मासिक रैप्ड', 'मासिक रॅप्ड', 'মাসিক Wrapped', 'నెలవారీ Wrapped', 'மாதாந்திர Wrapped');
  String get couldNotShareCard =>
      _t('Could not share the card', 'कार्ड साझा नहीं हो सका', 'कार्ड शेअर करता आले नाही', 'কার্ড শেয়ার করা যায়নি', 'కార్డును షేర్ చేయలేకపోయాం', 'அட்டையைப் பகிர முடியவில்லை');
  String get showActualAmountsTitle =>
      _t('Show actual amounts?', 'वास्तविक राशि दिखाएँ?', 'प्रत्यक्ष रक्कम दाखवायची?', 'প্রকৃত পরিমাণ দেখাবেন?', 'అసలు మొత్తాలను చూపాలా?', 'உண்மையான தொகைகளைக் காட்டவா?');
  String get showAmountsDesc => _t(
        "Your Wrapped normally shows only percentages, so it's safe to "
            'share. Revealing amounts displays your real ₹ figures — and any '
            'card you share will include them.',
        'आपका Wrapped आम तौर पर केवल प्रतिशत दिखाता है, इसलिए साझा करना सुरक्षित है। '
            'राशि दिखाने पर आपके असली ₹ आँकड़े दिखेंगे — और जो भी कार्ड आप साझा करेंगे '
            'उसमें वे शामिल होंगे।',
        'तुमचे Wrapped सहसा फक्त टक्केवारी दाखवते, त्यामुळे शेअर करणे सुरक्षित आहे. '
            'रक्कम दाखवल्यास तुमचे खरे ₹ आकडे दिसतील — आणि तुम्ही शेअर कराल त्या '
            'कार्डमध्येही ते असतील.',
        'আপনার Wrapped সাধারণত শুধু শতাংশ দেখায়, তাই শেয়ার করা নিরাপদ। '
            'পরিমাণ প্রকাশ করলে আপনার আসল ₹ সংখ্যা দেখা যাবে — এবং আপনি যে '
            'কার্ড শেয়ার করবেন তাতেও সেগুলো থাকবে।',
        'మీ Wrapped సాధారణంగా శాతాలను మాత్రమే చూపిస్తుంది, కాబట్టి షేర్ చేయడం సురక్షితం. మొత్తాలను చూపిస్తే మీ నిజమైన ₹ సంఖ్యలు కనిపిస్తాయి — మరియు మీరు షేర్ చేసే ఏ కార్డులోనైనా అవి ఉంటాయి.',
        'உங்கள் Wrapped பொதுவாக சதவீதங்களை மட்டுமே காட்டுகிறது, எனவே பகிர்வது பாதுகாப்பானது. தொகைகளைக் காட்டினால் உங்கள் உண்மையான ₹ எண்கள் தெரியும் — மேலும் நீங்கள் பகிரும் எந்த அட்டையிலும் அவை இருக்கும்.',
      );
  String get showAmounts => _t('Show amounts', 'राशि दिखाएँ', 'रक्कम दाखवा', 'পরিমাণ দেখান', 'మొత్తాలను చూపు', 'தொகைகளைக் காட்டு');
  String get showActualAmounts =>
      _t('Show actual amounts', 'वास्तविक राशि दिखाएँ', 'प्रत्यक्ष रक्कम दाखवा', 'প্রকৃত পরিমাণ দেখান', 'అసలు మొత్తాలను చూపు', 'உண்மையான தொகைகளைக் காட்டு');
  String get notEnoughDataYet =>
      _t('Not enough data yet', 'अभी पर्याप्त डेटा नहीं', 'अजून पुरेसा डेटा नाही', 'এখনও পর্যাপ্ত ডেটা নেই', 'ఇంకా తగినంత డేటా లేదు', 'இன்னும் போதிய தரவு இல்லை');
  String get preparing => _t('Preparing…', 'तैयार हो रहा है…', 'तयार होत आहे…', 'প্রস্তুত হচ্ছে…', 'సిద్ధమవుతోంది…', 'தயாராகிறது…');
  String get shareMyWrapped =>
      _t('Share my Wrapped', 'मेरा Wrapped साझा करें', 'माझे Wrapped शेअर करा', 'আমার Wrapped শেয়ার করুন', 'నా Wrapped ను షేర్ చేయి', 'என் Wrapped ஐப் பகிர்');
  String wrappedShareText(String month) => _t(
        'My $month on Budgetify ✨ — private, on-device money tracking.',
        '$month — Budgetify पर ✨ निजी, ऑन-डिवाइस मनी ट्रैकिंग।',
        '$month — Budgetify वर ✨ खाजगी, ऑन-डिव्हाइस मनी ट्रॅकिंग.',
        'Budgetify-তে আমার $month ✨ — ব্যক্তিগত, অন-ডিভাইস মানি ট্র্যাকিং।',
        'Budgetify లో నా $month ✨ — ప్రైవేట్, ఆన్-డివైస్ మనీ ట్రాకింగ్.',
        'Budgetify இல் என் $month ✨ — தனிப்பட்ட, சாதனத்தில் பணக் கண்காணிப்பு.',
      );
  String wrappedWarmingUp(String month, int minDays, int days) => _t(
        '$month is still warming up. A Wrapped needs at least $minDays days '
            'of activity — there ${days == 1 ? 'is' : 'are'} $days '
            'day${days == 1 ? '' : 's'} so far. Check back later in the month.',
        '$month अभी तैयार हो रहा है। Wrapped के लिए कम से कम $minDays दिन की '
            'गतिविधि चाहिए — अब तक $days दिन हैं। महीने में बाद में देखें।',
        '$month अजून तयार होत आहे. Wrapped साठी किमान $minDays दिवसांची '
            'हालचाल हवी — आतापर्यंत $days दिवस आहेत. महिन्यात नंतर पुन्हा पाहा.',
        '$month এখনও প্রস্তুত হচ্ছে। একটি Wrapped-এর জন্য অন্তত $minDays দিনের '
            'কার্যকলাপ দরকার — এখন পর্যন্ত $days দিন আছে। মাসের পরে আবার দেখুন।',
        '$month ఇంకా సిద్ధమవుతోంది. ఒక Wrapped కు కనీసం $minDays రోజుల కార్యకలాపం అవసరం — ఇప్పటివరకు $days రోజులు ఉన్నాయి. నెలలో తర్వాత మళ్లీ చూడండి.',
        '$month இன்னும் தயாராகிறது. ஒரு Wrapped க்கு குறைந்தது $minDays நாட்கள் செயல்பாடு தேவை — இதுவரை $days நாட்கள் உள்ளன. மாதத்தில் பிறகு மீண்டும் பாருங்கள்.',
      );
  String wrappedNotEnoughData(String month, int minDays) => _t(
        'Not enough data for $month — a Wrapped needs at least $minDays days '
            'of recorded activity in the month.',
        '$month के लिए पर्याप्त डेटा नहीं — Wrapped के लिए महीने में कम से कम '
            '$minDays दिन की दर्ज गतिविधि चाहिए।',
        '$month साठी पुरेसा डेटा नाही — Wrapped साठी महिन्यात किमान '
            '$minDays दिवसांची नोंदलेली हालचाल हवी.',
        '$month-এর জন্য পর্যাপ্ত ডেটা নেই — একটি Wrapped-এর জন্য মাসে অন্তত '
            '$minDays দিনের নথিভুক্ত কার্যকলাপ দরকার।',
        '$month కోసం తగినంత డేటా లేదు — ఒక Wrapped కు నెలలో కనీసం $minDays రోజుల నమోదైన కార్యకలాపం అవసరం.',
        '$month க்கு போதிய தரவு இல்லை — ஒரு Wrapped க்கு மாதத்தில் குறைந்தது $minDays நாட்கள் பதிவான செயல்பாடு தேவை.',
      );
  // Profile
  String get sharingProgress => _t('Sharing…', 'साझा हो रहा है…', 'शेअर होत आहे…', 'শেয়ার হচ্ছে…', 'షేర్ అవుతోంది…', 'பகிர்கிறது…');
  String get showcase => _t('Showcase', 'शोकेस', 'शोकेस', 'শোকেস', 'షోకేస్', 'காட்சியகம்');
  String get earnBadgesDesc => _t(
        'Earn badges in the Trophies tab to feature them here.',
        'यहाँ दिखाने के लिए Trophies टैब में बैज कमाएँ।',
        'येथे दाखवण्यासाठी Trophies टॅबमध्ये बॅज मिळवा.',
        'এখানে দেখানোর জন্য Trophies ট্যাবে ব্যাজ অর্জন করুন।',
        'ఇక్కడ చూపించడానికి Trophies ట్యాబ్‌లో బ్యాడ్జ్‌లను సంపాదించండి.',
        'இங்கே காட்ட Trophies தாவலில் பேட்ஜ்களைப் பெறுங்கள்.',
      );
  String get chooseBadgesToFeature =>
      _t('Choose up to 5 badges to feature', 'दिखाने के लिए 5 बैज तक चुनें', 'दाखवण्यासाठी 5 पर्यंत बॅज निवडा', 'দেখানোর জন্য 5টি পর্যন্ত ব্যাজ বেছে নিন', 'చూపించడానికి 5 వరకు బ్యాడ్జ్‌లను ఎంచుకోండి', 'காட்ட 5 பேட்ஜ்கள் வரை தேர்ந்தெடுக்கவும்');
  String get tapToChangeBadges => _t('Tap to change your featured badges',
      'अपने चुने बैज बदलने के लिए टैप करें', 'तुमचे निवडलेले बॅज बदलण्यासाठी टॅप करा', 'আপনার নির্বাচিত ব্যাজ পরিবর্তন করতে ট্যাপ করুন', 'మీ ఫీచర్ చేసిన బ్యాడ్జ్‌లను మార్చడానికి ట్యాప్ చేయండి', 'உங்கள் சிறப்பு பேட்ஜ்களை மாற்றத் தட்டுங்கள்');
  String get titlesLabel => _t('Titles', 'खिताब', 'किताब', 'খেতাব', 'బిరుదులు', 'பட்டங்கள்');
  String get titlesIntro => _t(
        'Titles reflect where your money goes — each shows your progress. '
            'Tap one for details.',
        'खिताब दर्शाते हैं कि आपका पैसा कहाँ जाता है — हर एक आपकी प्रगति दिखाता है। '
            'विवरण के लिए टैप करें।',
        'किताब दर्शवतात की तुमचा पैसा कुठे जातो — प्रत्येक तुमची प्रगती दाखवते. '
            'तपशिलासाठी टॅप करा.',
        'খেতাব দেখায় আপনার টাকা কোথায় যায় — প্রতিটি আপনার অগ্রগতি দেখায়। '
            'বিস্তারিত জানতে ট্যাপ করুন।',
        'బిరుదులు మీ డబ్బు ఎక్కడికి వెళ్తుందో ప్రతిబింబిస్తాయి — ప్రతి ఒక్కటి మీ పురోగతిని చూపిస్తుంది. వివరాల కోసం ఒకదానిపై ట్యాప్ చేయండి.',
        'பட்டங்கள் உங்கள் பணம் எங்கு செல்கிறது என்பதைப் பிரதிபலிக்கின்றன — ஒவ்வொன்றும் உங்கள் முன்னேற்றத்தைக் காட்டுகிறது. விவரங்களுக்கு ஒன்றைத் தட்டுங்கள்.',
      );
  String get tapTitleDesc => _t(
        'Tap a title for details. Earned titles can be featured on your profile.',
        'विवरण के लिए किसी खिताब पर टैप करें। कमाए खिताब आपकी प्रोफ़ाइल पर दिखाए जा सकते हैं।',
        'तपशिलासाठी एखाद्या किताबावर टॅप करा. मिळवलेली किताब तुमच्या प्रोफाइलवर दाखवता येतात.',
        'বিস্তারিত জানতে একটি খেতাবে ট্যাপ করুন। অর্জিত খেতাব আপনার প্রোফাইলে দেখানো যায়।',
        'వివరాల కోసం ఒక బిరుదుపై ట్యాప్ చేయండి. సంపాదించిన బిరుదులను మీ ప్రొఫైల్‌లో చూపించవచ్చు.',
        'விவரங்களுக்கு ஒரு பட்டத்தைத் தட்டுங்கள். சம்பாதித்த பட்டங்களை உங்கள் சுயவிவரத்தில் காட்டலாம்.',
      );
  String get earned => _t('Earned', 'अर्जित', 'मिळवले', 'অর্জিত', 'సంపాదించింది', 'சம்பாதித்தது');
  String get inProgress => _t('In progress', 'प्रगति में', 'प्रगतीत', 'চলমান', 'పురోగతిలో', 'நடப்பில்');
  String get removeFromProfile =>
      _t('Remove from profile', 'प्रोफ़ाइल से हटाएँ', 'प्रोफाइलमधून काढा', 'প্রোফাইল থেকে সরান', 'ప్రొఫైల్ నుండి తీసివేయి', 'சுயவிவரத்திலிருந்து அகற்று');
  String get featureOnProfile => _t('Feature on profile', 'प्रोफ़ाइल पर दिखाएँ', 'प्रोफाइलवर दाखवा', 'প্রোফাইলে দেখান', 'ప్రొఫైల్‌లో చూపించు', 'சுயவிவரத்தில் காட்டு');
  String get featuredBadges => _t('Featured badges', 'चुने हुए बैज', 'निवडलेले बॅज', 'নির্বাচিত ব্যাজ', 'ఫీచర్ చేసిన బ్యాడ్జ్‌లు', 'சிறப்பு பேட்ஜ்கள்');
  String get couldntCreateShareImage => _t("Couldn't create the share image just now",
      'अभी साझा छवि नहीं बना सके', 'सध्या शेअर प्रतिमा तयार करता आली नाही', 'এই মুহূর্তে শেয়ার ছবি তৈরি করা যায়নি', 'ప్రస్తుతం షేర్ చిత్రాన్ని సృష్టించలేకపోయాం', 'இப்போது பகிர்வு படத்தை உருவாக்க முடியவில்லை');
  String get profileShareText =>
      _t('My Budgetify rewards 🏆', 'मेरे Budgetify रिवॉर्ड 🏆', 'माझे Budgetify रिवॉर्ड 🏆', 'আমার Budgetify রিওয়ার্ড 🏆', 'నా Budgetify రివార్డ్‌లు 🏆', 'என் Budgetify வெகுமதிகள் 🏆');
  String earnedOn(String date) => _t('Earned $date', '$date को अर्जित', '$date रोजी मिळवले', '$date-এ অর্জিত', '$date న సంపాదించింది', '$date அன்று சம்பாதித்தது');
  // Avatar picker
  String get usernameLabel => _t('Username', 'उपयोगकर्ता नाम', 'वापरकर्तानाव', 'ব্যবহারকারীর নাম', 'యూజర్‌నేమ్', 'பயனர்பெயர்');
  String get pickAName => _t('Pick a name', 'एक नाम चुनें', 'एक नाव निवडा', 'একটি নাম বেছে নিন', 'ఒక పేరును ఎంచుకోండి', 'ஒரு பெயரைத் தேர்ந்தெடு');
  String get styleLabel => _t('STYLE', 'शैली', 'शैली', 'স্টাইল', 'స్టైల్', 'பாணி');
  String get emojiStyle => _t('Emoji', 'इमोजी', 'इमोजी', 'ইমোজি', 'ఇమోజీ', 'எமோஜி');
  String get pixelStyle => _t('Pixel', 'पिक्सेल', 'पिक्सेल', 'পিক্সেল', 'పిక్సెల్', 'பிக்சல்');
  String get avatarLabel => _t('AVATAR', 'अवतार', 'अवतार', 'অবতার', 'అవతార్', 'அவதாரம்');
  String get pixelAvatarLabel => _t('PIXEL AVATAR', 'पिक्सेल अवतार', 'पिक्सेल अवतार', 'পিক্সেল অবতার', 'పిక్సెల్ అవతార్', 'பிக்சல் அவதாரம்');
  String get accentLabel => _t('ACCENT', 'रंग', 'रंग', 'রং', 'యాక్సెంట్', 'ஆக்சென்ட்');
  // Badges / achievements
  String tierName(String key) {
    switch (key) {
      case 'Copper':
        return _t('Copper', 'कॉपर', 'कॉपर', 'কপার', 'కాపర్', 'காப்பர்');
      case 'Bronze':
        return _t('Bronze', 'ब्रॉन्ज़', 'ब्रॉन्झ', 'ব্রোঞ্জ', 'బ్రాంజ్', 'ப்ரான்ஸ்');
      case 'Silver':
        return _t('Silver', 'सिल्वर', 'सिल्व्हर', 'সিলভার', 'సిల్వర్', 'சில்வர்');
      case 'Gold':
        return _t('Gold', 'गोल्ड', 'गोल्ड', 'গোল্ড', 'గోల్డ్', 'கோல்ட்');
      case 'Platinum':
        return _t('Platinum', 'प्लैटिनम', 'प्लॅटिनम', 'প্ল্যাটিনাম', 'ప్లాటినం', 'பிளாட்டினம்');
      case 'Ruby':
        return _t('Ruby', 'रूबी', 'रुबी', 'রুবি', 'రూబీ', 'ரூபி');
      case 'Diamond':
        return _t('Diamond', 'डायमंड', 'डायमंड', 'ডায়মন্ড', 'డైమండ్', 'டைமண்ட்');
      default:
        return key;
    }
  }
  String tierLabel(String name) => _t('$name tier', '$name टियर', '$name टियर', '$name টিয়ার', '$name టియర్', '$name அடுக்கு');
  String get achievementUnlocked =>
      _t('ACHIEVEMENT UNLOCKED', 'उपलब्धि अनलॉक', 'उपलब्धी अनलॉक', 'অর্জন আনলক', 'అచీవ్‌మెంట్ అన్‌లాక్ అయింది', 'சாதனை திறக்கப்பட்டது');
  String get awesomeBtn => _t('Awesome', 'बढ़िया', 'भारी', 'দারুণ', 'అద్భుతం', 'அருமை');
  // Streak reward road
  String bestStreak(int days) => _t(
      'Best: $days ${days == 1 ? 'day' : 'days'}', 'सर्वश्रेष्ठ: $days दिन', 'सर्वोत्तम: $days दिवस', 'সেরা: $days দিন', 'అత్యుత్తమం: $days రోజులు', 'சிறந்தது: $days நாட்கள்');
  String get allStreakRewardsUnlocked => _t(
      'Every streak reward unlocked — more on the way!',
      'सभी स्ट्रीक रिवॉर्ड अनलॉक — और आ रहे हैं!',
      'सर्व स्ट्रीक रिवॉर्ड अनलॉक — आणखी येत आहेत!',
      'সব স্ট্রিক রিওয়ার্ড আনলক — আরও আসছে!',
      'ప్రతి స్ట్రీక్ రివార్డ్ అన్‌లాక్ అయింది — మరిన్ని రాబోతున్నాయి!',
      'ஒவ்வொரு ஸ்ட்ரீக் வெகுமதியும் திறக்கப்பட்டது — மேலும் வரவிருக்கின்றன!');
  String openToUnlock(String daysAway, String name) => _t(
        'Open Budgetify $daysAway to unlock “$name”.',
        '“$name” अनलॉक करने के लिए $daysAway Budgetify खोलें।',
        '“$name” अनलॉक करण्यासाठी $daysAway Budgetify उघडा.',
        '“$name” আনলক করতে $daysAway Budgetify খুলুন।',
        '“$name” ను అన్‌లాక్ చేయడానికి $daysAway Budgetify తెరవండి.',
        '“$name” ஐப் பெற $daysAway Budgetify ஐத் திறக்கவும்.',
      );
  String get todayWord => _t('today', 'आज', 'आज', 'আজ', 'ఈ రోజు', 'இன்று');
  String daysMore(int n) =>
      _t('$n more ${n == 1 ? 'day' : 'days'}', '$n दिन और', 'आणखी $n दिवस', 'আরও $n দিন', 'మరో $n రోజులు', 'இன்னும் $n நாட்கள்');
  String reachStreakStatus(int days, int current) => _t(
        'Reach a $days-day streak · $current/$days',
        '$days-दिन की स्ट्रीक · $current/$days',
        '$days-दिवसांची स्ट्रीक · $current/$days',
        '$days-দিনের স্ট্রিকে পৌঁছান · $current/$days',
        '$days-రోజుల స్ట్రీక్ చేరుకోండి · $current/$days',
        '$days-நாள் ஸ்ட்ரீக்கை அடையுங்கள் · $current/$days',
      );
  String get unlockingSoon => _t('Unlocking soon…', 'जल्द अनलॉक हो रहा है…', 'लवकरच अनलॉक होत आहे…', 'শীঘ্রই আনলক হচ্ছে…', 'త్వరలో అన్‌లాక్ అవుతోంది…', 'விரைவில் திறக்கப்படும்…');
  String get currentlyApplied => _t('Currently applied', 'अभी लागू है', 'सध्या लागू आहे', 'এখন প্রয়োগ করা', 'ప్రస్తుతం వర్తింపజేయబడింది', 'தற்போது பயன்பாட்டில்');
  String get applyTheme => _t('Apply theme', 'थीम लागू करें', 'थीम लागू करा', 'থিম প্রয়োগ করুন', 'థీమ్‌ను వర్తింపజేయి', 'தீமைப் பயன்படுத்து');
  String get unlockedLabel => _t('Unlocked', 'अनलॉक', 'अनलॉक', 'আনলক', 'అన్‌లాక్ అయింది', 'திறக்கப்பட்டது');
  String get activeBadge => _t('ACTIVE', 'सक्रिय', 'सक्रिय', 'সক্রিয়', 'యాక్టివ్', 'செயலில்');
  String get moreStreakRewards =>
      _t('More streak rewards on the way.', 'और स्ट्रीक रिवॉर्ड आ रहे हैं।', 'आणखी स्ट्रीक रिवॉर्ड येत आहेत.', 'আরও স্ট্রিক রিওয়ার্ড আসছে।', 'మరిన్ని స్ట్రీక్ రివార్డ్‌లు రాబోతున్నాయి.', 'மேலும் ஸ்ட்ரீக் வெகுமதிகள் வரவிருக்கின்றன.');
  String lockedProgress(String progress, String threshold) =>
      _t('Locked · $progress / $threshold', 'लॉक · $progress / $threshold', 'लॉक · $progress / $threshold', 'লক · $progress / $threshold', 'లాక్ · $progress / $threshold', 'பூட்டப்பட்டது · $progress / $threshold');

  // ── Budget defaults ───────────────────────────────────────────────────────
  String get defaultBudgetName => _t('Monthly Budget', 'मासिक बजट', 'मासिक बजेट', 'মাসিক বাজেট', 'నెలవారీ బడ్జెట్', 'மாதாந்திர பட்ஜெட்');

  // ── Theme variant names (display labels; stored as enum) ──────────────────
  String get themeNameLight => _t('Light', 'हल्का', 'फिकट', 'হালকা', 'లైట్', 'ஒளி');
  String get themeNameDark => _t('Dark', 'गहरा', 'गडद', 'গাঢ়', 'డార్క్', 'இருள்');
  String get themeNameSmoky => _t('Smoky', 'स्मोकी', 'स्मोकी', 'স্মোকি', 'స్మోకీ', 'ஸ்மோக்கி');
  String get themeNameSeashell => _t('Seashell', 'सीशेल', 'सीशेल', 'সিশেল', 'సీషెల్', 'சீஷெல்');
  String get themeNameAmber => _t('Amber', 'एम्बर', 'अंबर', 'অ্যাম্বার', 'అంబర్', 'அம்பர்');
  String get themeNameRoyalIndigo =>
      _t('Royal Indigo', 'रॉयल इंडिगो', 'रॉयल इंडिगो', 'রয়্যাল ইন্ডিগো', 'రాయల్ ఇండిగో', 'ராயல் இண்டிகோ');
  String get themeNameMidnightIndigo =>
      _t('Midnight Indigo', 'मिडनाइट इंडिगो', 'मिडनाइट इंडिगो', 'মিডনাইট ইন্ডিগো', 'మిడ్‌నైట్ ఇండిగో', 'மிட்நைட் இண்டிகோ');

  // ── Onboarding ────────────────────────────────────────────────────────────
  String get chooseLanguageTitle => _t('Choose your language',
      'अपनी भाषा चुनें', 'तुमची भाषा निवडा', 'আপনার ভাষা বেছে নিন', 'మీ భాషను ఎంచుకోండి', 'உங்கள் மொழியைத் தேர்ந்தெடுங்கள்');
  String get chooseLanguageDesc => _t(
        'Budgetify — and its guided tour — will use this language. You can change it anytime in Settings.',
        'Budgetify और इसका गाइडेड टूर इसी भाषा में चलेंगे। इसे कभी भी सेटिंग्स में बदला जा सकता है।',
        'Budgetify आणि त्याचा गाईडेड टूर याच भाषेत चालतील. हे केव्हाही सेटिंग्जमध्ये बदलता येते.',
        'Budgetify আর তার গাইডেড ট্যুর এই ভাষাতেই চলবে। এটি যেকোনো সময় সেটিংসে বদলানো যায়।',
        'Budgetify — మరియు దాని గైడెడ్ టూర్ — ఈ భాషను ఉపయోగిస్తుంది. మీరు దీన్ని సెట్టింగ్స్‌లో ఎప్పుడైనా మార్చవచ్చు.',
        'Budgetify — மற்றும் அதன் வழிகாட்டப்பட்ட சுற்றுலா — இந்த மொழியைப் பயன்படுத்தும். நீங்கள் இதை எப்போது வேண்டுமானாலும் அமைப்புகளில் மாற்றலாம்.',
      );
  String get onboardWelcomeTitle => _t('Welcome to\nBudget Tracker',
      'Budget Tracker में\nआपका स्वागत है', 'Budget Tracker मध्ये\nआपले स्वागत आहे', 'Budget Tracker-এ\nস্বাগতম', 'స్వాగతం\nBudget Tracker', 'வரவேற்பு\nBudget Tracker');
  String get onboardWelcomeDesc => _t(
        'Track your expenses automatically by reading bank SMS messages',
        'बैंक SMS संदेश पढ़कर अपने खर्च अपने आप ट्रैक करें',
        'बँक SMS संदेश वाचून तुमचे खर्च आपोआप ट्रॅक करा',
        'ব্যাংক SMS বার্তা পড়ে আপনার খরচ স্বয়ংক্রিয়ভাবে ট্র্যাক করুন',
        'బ్యాంక్ SMS సందేశాలను చదవడం ద్వారా మీ ఖర్చులను ఆటోమేటిక్‌గా ట్రాక్ చేయండి',
        'வங்கி SMS செய்திகளைப் படித்து உங்கள் செலவுகளைத் தானாகக் கண்காணியுங்கள்',
      );
  String get smsPermissionTitle =>
      _t('SMS Permission Required', 'SMS अनुमति आवश्यक है', 'SMS परवानगी आवश्यक आहे', 'SMS অনুমতি প্রয়োজন', 'SMS అనుమతి అవసరం', 'SMS அனுமதி தேவை');
  String get smsPermissionDesc => _t(
        'We need SMS permission to automatically detect transactions from your bank messages.',
        'आपके बैंक संदेशों से लेन-देन अपने आप पहचानने के लिए हमें SMS अनुमति चाहिए।',
        'तुमच्या बँक संदेशांमधून व्यवहार आपोआप ओळखण्यासाठी आम्हाला SMS परवानगी हवी.',
        'আপনার ব্যাংক বার্তা থেকে লেনদেন স্বয়ংক্রিয়ভাবে শনাক্ত করতে আমাদের SMS অনুমতি প্রয়োজন।',
        'మీ బ్యాంక్ సందేశాల నుండి లావాదేవీలను ఆటోమేటిక్‌గా గుర్తించడానికి మాకు SMS అనుమతి అవసరం.',
        'உங்கள் வங்கி செய்திகளிலிருந்து பரிவர்த்தனைகளைத் தானாகக் கண்டறிய எங்களுக்கு SMS அனுமதி தேவை.',
      );
  String get smsPrivacyNote => _t(
        'Your SMS stays private and is never uploaded to any server. All processing happens locally on your device.',
        'आपका SMS निजी रहता है और कभी किसी सर्वर पर अपलोड नहीं होता। सारी प्रोसेसिंग आपके डिवाइस पर ही होती है।',
        'तुमचे SMS खाजगी राहते आणि कधीही कोणत्याही सर्व्हरवर अपलोड होत नाही. सर्व प्रोसेसिंग तुमच्या डिव्हाइसवरच होते.',
        'আপনার SMS ব্যক্তিগত থাকে এবং কখনও কোনো সার্ভারে আপলোড করা হয় না। সব প্রক্রিয়াকরণ আপনার ডিভাইসেই স্থানীয়ভাবে ঘটে।',
        'మీ SMS ప్రైవేట్‌గా ఉంటుంది మరియు ఏ సర్వర్‌కు ఎప్పుడూ అప్‌లోడ్ చేయబడదు. అన్ని ప్రాసెసింగ్ మీ పరికరంలోనే స్థానికంగా జరుగుతుంది.',
        'உங்கள் SMS தனிப்பட்டதாக இருக்கும், எந்த சர்வருக்கும் ஒருபோதும் பதிவேற்றப்படாது. அனைத்து செயலாக்கமும் உங்கள் சாதனத்திலேயே உள்நாட்டில் நடக்கிறது.',
      );
  String get getStarted => _t('Get Started', 'शुरू करें', 'सुरू करा', 'শুরু করুন', 'ప్రారంభించండి', 'தொடங்குங்கள்');
  String get back => _t('Back', 'पीछे', 'मागे', 'পিছনে', 'వెనుకకు', 'பின்');
  String get grantPermissionAndStart =>
      _t('Grant Permission & Start', 'अनुमति दें और शुरू करें', 'परवानगी द्या आणि सुरू करा', 'অনুমতি দিন ও শুরু করুন', 'అనుమతి ఇచ్చి ప్రారంభించండి', 'அனுமதி வழங்கி தொடங்கு');
  String genericError(Object e) => _t('Error: $e', 'त्रुटि: $e', 'त्रुटी: $e', 'ত্রুটি: $e', 'లోపం: $e', 'பிழை: $e');

  // ── Lock screen ───────────────────────────────────────────────────────────
  String get appLockedTitle => _t('Budgetify is locked', 'Budgetify लॉक है', 'Budgetify लॉक आहे', 'Budgetify লক করা আছে', 'Budgetify లాక్ చేయబడింది', 'Budgetify பூட்டப்பட்டுள்ளது');
  String get unlock => _t('Unlock', 'अनलॉक करें', 'अनलॉक करा', 'আনলক করুন', 'అన్‌లాక్ చేయి', 'திற');
  String get waiting => _t('Waiting…', 'प्रतीक्षा…', 'प्रतीक्षा…', 'অপেক্ষা…', 'వేచి ఉంది…', 'காத்திருக்கிறது…');

  // ── Permission request card ───────────────────────────────────────────────
  String get enableSmsReading =>
      _t('Enable SMS Reading', 'SMS पढ़ना चालू करें', 'SMS वाचन चालू करा', 'SMS পড়া চালু করুন', 'SMS చదవడాన్ని ప్రారంభించు', 'SMS படித்தலை இயக்கு');
  String get smsDeniedDesc => _t(
        'SMS permission was denied. Please enable it in Settings to auto-detect bank transactions.',
        'SMS अनुमति अस्वीकृत कर दी गई। बैंक लेन-देन अपने आप पहचानने के लिए कृपया इसे सेटिंग्स में चालू करें।',
        'SMS परवानगी नाकारली गेली. बँक व्यवहार आपोआप ओळखण्यासाठी कृपया ती सेटिंग्जमध्ये चालू करा.',
        'SMS অনুমতি প্রত্যাখ্যান করা হয়েছে। ব্যাংক লেনদেন স্বয়ংক্রিয়ভাবে শনাক্ত করতে অনুগ্রহ করে এটি সেটিংসে চালু করুন।',
        'SMS అనుమతి తిరస్కరించబడింది. బ్యాంక్ లావాదేవీలను ఆటో-గుర్తించడానికి దయచేసి దాన్ని సెట్టింగ్స్‌లో ప్రారంభించండి.',
        'SMS அனுமதி மறுக்கப்பட்டது. வங்கி பரிவர்த்தனைகளைத் தானாகக் கண்டறிய தயவுசெய்து அதை அமைப்புகளில் இயக்கவும்.',
      );
  String get smsAllowDesc => _t(
        'Allow Budget Tracker to read your SMS messages to automatically detect and log bank transactions.',
        'बैंक लेन-देन अपने आप पहचानने और दर्ज करने के लिए Budget Tracker को अपने SMS संदेश पढ़ने दें।',
        'बँक व्यवहार आपोआप ओळखण्यासाठी व नोंदवण्यासाठी Budget Tracker ला तुमचे SMS संदेश वाचू द्या.',
        'ব্যাংক লেনদেন স্বয়ংক্রিয়ভাবে শনাক্ত ও নথিভুক্ত করতে Budget Tracker-কে আপনার SMS বার্তা পড়তে দিন।',
        'బ్యాంక్ లావాదేవీలను ఆటోమేటిక్‌గా గుర్తించి నమోదు చేయడానికి Budget Tracker మీ SMS సందేశాలను చదవడానికి అనుమతించండి.',
        'வங்கி பரிவர்த்தனைகளைத் தானாகக் கண்டறிந்து பதிவு செய்ய Budget Tracker உங்கள் SMS செய்திகளைப் படிக்க அனுமதியுங்கள்.',
      );
  String get featAutoDetect =>
      _t('Auto-detect credits & debits', 'जमा और निकासी अपने आप पहचानें', 'जमा व नावे आपोआप ओळखा', 'ক্রেডিট ও ডেবিট স্বয়ংক্রিয়ভাবে শনাক্ত করুন', 'క్రెడిట్‌లు & డెబిట్‌లను ఆటో-గుర్తించు', 'வரவுகள் & பற்றுகளைத் தானாகக் கண்டறி');
  String get featWorksInBackground =>
      _t('Works in background', 'बैकग्राउंड में काम करता है', 'बॅकग्राउंडमध्ये काम करते', 'ব্যাকগ্রাউন্ডে কাজ করে', 'బ్యాక్‌గ్రౌండ్‌లో పనిచేస్తుంది', 'பின்னணியில் வேலை செய்கிறது');
  String get featSecurePrivate => _t('Secure & private', 'सुरक्षित और निजी', 'सुरक्षित व खाजगी', 'নিরাপদ ও ব্যক্তিগত', 'సురక్షితం & ప్రైవేట్', 'பாதுகாப்பான & தனிப்பட்ட');
  String get openSettings => _t('Open Settings', 'सेटिंग्स खोलें', 'सेटिंग्ज उघडा', 'সেটিংস খুলুন', 'సెట్టింగ్స్ తెరువు', 'அமைப்புகளைத் திற');
  String get grantPermission => _t('Grant Permission', 'अनुमति दें', 'परवानगी द्या', 'অনুমতি দিন', 'అనుమతి ఇవ్వు', 'அனுமதி வழங்கு');
  String get dataStaysOnDevice =>
      _t('Your data stays on your device', 'आपका डेटा आपके डिवाइस पर रहता है', 'तुमचा डेटा तुमच्या डिव्हाइसवर राहतो', 'আপনার ডেটা আপনার ডিভাইসে থাকে', 'మీ డేటా మీ పరికరంలోనే ఉంటుంది', 'உங்கள் தரவு உங்கள் சாதனத்தில் இருக்கும்');

  // ── Manage tags ───────────────────────────────────────────────────────────
  String get manageTagsIntro => _t(
        "Delete tags you don't use. Deleting a tag never deletes your "
            'transactions — they just become unclassified.',
        'जो टैग आप उपयोग नहीं करते उन्हें हटाएँ। टैग हटाने से आपके लेन-देन कभी '
            'नहीं हटते — वे बस अवर्गीकृत हो जाते हैं।',
        'तुम्ही वापरत नसलेले टॅग हटवा. टॅग हटवल्याने तुमचे व्यवहार कधीही '
            'हटत नाहीत — ते फक्त अवर्गीकृत होतात.',
        'আপনি যে ট্যাগ ব্যবহার করেন না সেগুলো মুছুন। ট্যাগ মুছলে আপনার '
            'লেনদেন কখনও মুছে যায় না — সেগুলো কেবল অশ্রেণীবদ্ধ হয়ে যায়।',
        'మీరు ఉపయోగించని ట్యాగ్‌లను తొలగించండి. ట్యాగ్‌ను తొలగించడం మీ లావాదేవీలను ఎప్పుడూ తొలగించదు — అవి కేవలం వర్గీకరించనివిగా మారతాయి.',
        'நீங்கள் பயன்படுத்தாத குறிச்சொற்களை நீக்குங்கள். ஒரு குறிச்சொல்லை நீக்குவது உங்கள் பரிவர்த்தனைகளை ஒருபோதும் நீக்காது — அவை வெறுமனே வகைப்படுத்தப்படாதவையாக மாறும்.',
      );
  String get hiddenTags => _t('HIDDEN TAGS', 'छिपे हुए टैग', 'लपवलेले टॅग', 'লুকানো ট্যাগ', 'దాచిన ట్యాగ్‌లు', 'மறைக்கப்பட்ட குறிச்சொற்கள்');
  String get restore => _t('Restore', 'पुनर्स्थापित करें', 'पुनर्संचयित करा', 'পুনরুদ্ধার করুন', 'పునరుద్ధరించు', 'மீட்டமை');
  String get deleteTagTooltip => _t('Delete tag', 'टैग हटाएँ', 'टॅग हटवा', 'ট্যাগ মুছুন', 'ట్యాగ్‌ను తొలగించు', 'குறிச்சொல்லை நீக்கு');
  String get untagAndDelete => _t('Untag & Delete', 'टैग हटाएँ और मिटाएँ', 'टॅग काढा व हटवा', 'ট্যাগ সরান ও মুছুন', 'ట్యాగ్ తీసి తొలగించు', 'குறிச்சொல்லை நீக்கி அழி');
  String deleteTagTitle(String tag) => _t('Delete "$tag"?', '"$tag" हटाएँ?', '"$tag" हटवायचा?', '"$tag" মুছবেন?', '"$tag" ను తొలగించాలా?', '"$tag" ஐ நீக்கவா?');
  String deleteTagWithCount(int count, String tag) => _t(
        '$count transaction${count == 1 ? '' : 's'} '
            '${count == 1 ? 'is' : 'are'} tagged "$tag". Deleting the tag will '
            'untag ${count == 1 ? 'it' : 'them'} (moved to Unclassified). '
            'The transactions are kept.',
        '$count लेन-देन पर "$tag" टैग है। टैग हटाने पर ${count == 1 ? 'इसका' : 'इनका'} '
            'टैग हट जाएगा (अवर्गीकृत में चला जाएगा)। लेन-देन सुरक्षित रहेंगे।',
        '$count व्यवहारांना "$tag" टॅग आहे. टॅग हटवल्यास तो काढला जाईल '
            '(अवर्गीकृतमध्ये जाईल). व्यवहार राहतील.',
        '$count টি লেনদেনে "$tag" ট্যাগ আছে। ট্যাগ মুছলে তা '
            'সরানো হবে (অশ্রেণীবদ্ধে চলে যাবে)। লেনদেন থেকে যাবে।',
        '$count లావాదేవీలకు "$tag" ట్యాగ్ ఉంది. ట్యాగ్‌ను తొలగిస్తే అవి అన్‌ట్యాగ్ అవుతాయి (వర్గీకరించనివిలోకి వెళ్తాయి). లావాదేవీలు ఉంచబడతాయి.',
        '$count பரிவர்த்தனைகளுக்கு "$tag" குறிச்சொல் உள்ளது. குறிச்சொல்லை நீக்கினால் அவை குறிச்சொல் நீக்கப்படும் (வகைப்படுத்தப்படாதவைக்கு நகர்த்தப்படும்). பரிவர்த்தனைகள் வைத்திருக்கப்படும்.',
      );
  String get deleteCustomTagDesc => _t(
      'This custom tag will be removed.', 'यह कस्टम टैग हटा दिया जाएगा।', 'हा कस्टम टॅग हटवला जाईल.', 'এই কাস্টম ট্যাগটি সরানো হবে।', 'ఈ కస్టమ్ ట్యాగ్ తీసివేయబడుతుంది.', 'இந்த தனிப்பயன் குறிச்சொல் அகற்றப்படும்.');
  String get deleteBuiltinTagDesc => _t(
        'This tag will be hidden from the tag pickers. You can restore it later.',
        'यह टैग, टैग-चयन से छिप जाएगा। आप इसे बाद में पुनर्स्थापित कर सकते हैं।',
        'हा टॅग, टॅग-निवडीतून लपवला जाईल. तुम्ही तो नंतर पुनर्संचयित करू शकता.',
        'এই ট্যাগটি ট্যাগ-নির্বাচক থেকে লুকানো হবে। আপনি পরে এটি পুনরুদ্ধার করতে পারেন।',
        'ఈ ట్యాగ్ ట్యాగ్-పికర్‌ల నుండి దాచబడుతుంది. మీరు దీన్ని తర్వాత పునరుద్ధరించవచ్చు.',
        'இந்த குறிச்சொல் குறிச்சொல் தேர்விகளிலிருந்து மறைக்கப்படும். நீங்கள் இதை பிறகு மீட்டமைக்கலாம்.',
      );
  String deletedTagWithCount(int count, String tag) => _t(
        'Deleted "$tag" and untagged $count transaction${count == 1 ? '' : 's'}',
        '"$tag" हटाया और $count लेन-देन से टैग हटाया',
        '"$tag" हटवला आणि $count व्यवहारांमधून टॅग काढला',
        '"$tag" মুছে $count টি লেনদেন থেকে ট্যাগ সরানো হয়েছে',
        '"$tag" తొలగించి $count లావాదేవీల నుండి ట్యాగ్ తీసివేయబడింది',
        '"$tag" நீக்கப்பட்டது மற்றும் $count பரிவர்த்தனைகளிலிருந்து குறிச்சொல் அகற்றப்பட்டது',
      );
  String deletedTag(String tag) => _t('Deleted "$tag"', '"$tag" हटाया', '"$tag" हटवला', '"$tag" মুছে ফেলা হয়েছে', '"$tag" తొలగించబడింది', '"$tag" நீக்கப்பட்டது');
  String restoredTag(String tag) =>
      _t('Restored "$tag"', '"$tag" पुनर्स्थापित किया', '"$tag" पुनर्संचयित केला', '"$tag" পুনরুদ্ধার করা হয়েছে', '"$tag" పునరుద్ధరించబడింది', '"$tag" மீட்டமைக்கப்பட்டது');
  String tagMeta(bool isCustom, int count) {
    final kind = isCustom
        ? _t('Custom', 'कस्टम', 'कस्टम', 'কাস্টম', 'కస్టమ్', 'தனிப்பயன்')
        : _t('Built-in', 'अंतर्निहित', 'अंतर्गत', 'বিল্ট-ইন', 'బిల్ట్-ఇన్', 'உள்ளமைந்த');
    final usage = count == 0
        ? _t('unused', 'अप्रयुक्त', 'न वापरलेले', 'অব্যবহৃত', 'ఉపయోగించనిది', 'பயன்படுத்தப்படாதது')
        : _t('$count tagged', '$count पर टैग', '$count टॅग केलेले', '$count টি ট্যাগ করা', '$count ట్యాగ్ చేయబడ్డాయి', '$count குறிச்சொல் இடப்பட்டன');
    return '$kind · $usage';
  }

  // ── Export sheet ──────────────────────────────────────────────────────────
  String get formatLabel => _t('Format', 'फ़ॉर्मेट', 'फॉरमॅट', 'ফরম্যাট', 'ఫార్మాట్', 'வடிவம்');
  String get textFormat => _t('Text', 'टेक्स्ट', 'मजकूर', 'টেক্সট', 'టెక్స్ట్', 'உரை');
  String get dateRangeLabel => _t('Date Range', 'तिथि सीमा', 'तारीख श्रेणी', 'তারিখ পরিসর', 'తేదీ పరిధి', 'தேதி வரம்பு');
  String get allTime => _t('All time', 'पूरा समय', 'सर्व वेळ', 'সর্বকাল', 'అన్ని కాలం', 'எல்லா காலமும்');
  String get typeLabel => _t('Type', 'प्रकार', 'प्रकार', 'ধরন', 'రకం', 'வகை');
  String get allFilter => _t('All', 'सभी', 'सर्व', 'সব', 'అన్నీ', 'அனைத்தும்');
  String get payeeMerchantContains =>
      _t('Payee / Merchant contains', 'प्राप्तकर्ता / व्यापारी में हो', 'प्राप्तकर्ता / व्यापारी मध्ये असेल', 'প্রাপক / বিক্রেতায় আছে', 'చెల్లింపుదారు / మర్చెంట్‌లో ఉంది', 'பணம் பெறுநர் / வணிகர் உள்ளடக்கியது');
  String get merchantQueryHint => _t(
        'e.g. Swiggy, Amazon (leave blank for all)',
        'जैसे Swiggy, Amazon (सभी के लिए खाली छोड़ें)',
        'उदा. Swiggy, Amazon (सर्वांसाठी रिकामे ठेवा)',
        'যেমন Swiggy, Amazon (সবের জন্য ফাঁকা রাখুন)',
        'ఉదా. Swiggy, Amazon (అన్నింటికీ ఖాళీగా ఉంచండి)',
        'எ.கா. Swiggy, Amazon (அனைத்திற்கும் காலியாக விடவும்)',
      );
  String get categoriesAll => _t('Categories (all)', 'श्रेणियाँ (सभी)', 'श्रेण्या (सर्व)', 'বিভাগ (সব)', 'వర్గాలు (అన్నీ)', 'வகைகள் (அனைத்தும்)');
  String categoriesSelected(int n) => _t('Categories ($n)', 'श्रेणियाँ ($n)', 'श्रेण्या ($n)', 'বিভাগ ($n)', 'వర్గాలు ($n)', 'வகைகள் ($n)');
  String get clearLabel => _t('Clear', 'साफ़ करें', 'साफ करा', 'সাফ করুন', 'క్లియర్ చేయి', 'அழி');
  String get exportLabel => _t('Export', 'एक्सपोर्ट', 'एक्सपोर्ट', 'এক্সপোর্ট', 'ఎగుమతి', 'ஏற்றுமதி');

  // ── Net worth entry editor ────────────────────────────────────────────────
  String get editEntry => _t('Edit entry', 'प्रविष्टि संपादित करें', 'नोंद संपादित करा', 'এন্ট্রি সম্পাদনা করুন', 'ఎంట్రీని సవరించు', 'உள்ளீட்டைத் திருத்து');
  String get addToNetWorth => _t('Add to net worth', 'नेट वर्थ में जोड़ें', 'नेट वर्थमध्ये जोडा', 'নেট ওয়ার্থে যোগ করুন', 'నెట్ వర్త్‌కు జోడించు', 'நிகர மதிப்பில் சேர்');
  String get assetKind => _t('Asset', 'संपत्ति', 'मालमत्ता', 'সম্পদ', 'ఆస్తి', 'சொத்து');
  String get liabilityKind => _t('Liability', 'देनदारी', 'दायित्व', 'দায়', 'అప్పు', 'கடன்');
  String get nameLabel => _t('Name', 'नाम', 'नाव', 'নাম', 'పేరు', 'பெயர்');
  String get holdingNameHint =>
      _t('e.g. HDFC Tax Saver', 'जैसे HDFC Tax Saver', 'उदा. HDFC Tax Saver', 'যেমন HDFC Tax Saver', 'ఉదా. HDFC Tax Saver', 'எ.கா. HDFC Tax Saver');
  String get investedSoFar => _t('Invested so far', 'अब तक निवेशित', 'आतापर्यंत गुंतवले', 'এ পর্যন্ত বিনিয়োগ', 'ఇప్పటివరకు పెట్టుబడి', 'இதுவரை முதலீடு');
  String get currentValue => _t('Current value', 'वर्तमान मूल्य', 'सध्याचे मूल्य', 'বর্তমান মূল্য', 'ప్రస్తుత విలువ', 'தற்போதைய மதிப்பு');
  String get recurringSipRd => _t('Recurring SIP / RD', 'आवर्ती SIP / RD', 'आवर्ती SIP / RD', 'আবর্তক SIP / RD', 'పునరావృత SIP / RD', 'தொடர் SIP / RD');
  String get trackEachInstalment =>
      _t('Track each monthly instalment', 'हर मासिक किस्त ट्रैक करें', 'प्रत्येक मासिक हप्ता ट्रॅक करा', 'প্রতিটি মাসিক কিস্তি ট্র্যাক করুন', 'ప్రతి నెలవారీ వాయిదాను ట్రాక్ చేయి', 'ஒவ்வொரு மாதத் தவணையையும் கண்காணி');
  String get onDay => _t('On day', 'किस दिन', 'कोणत्या दिवशी', 'কোন দিনে', 'ఏ రోజున', 'எந்த நாளில்');
  String get remindToLog => _t('Remind me to log it', 'दर्ज करने की याद दिलाएँ', 'नोंदवण्याची आठवण करा', 'নথিভুক্ত করার কথা মনে করিয়ে দিন', 'దీన్ని నమోదు చేయమని నాకు గుర్తు చేయి', 'இதைப் பதிவு செய்ய எனக்கு நினைவூட்டு');
  String get remindToLogDesc => _t(
        'Get a Yes/No alert at noon (and 8 PM if unanswered).',
        'दोपहर को हाँ/नहीं अलर्ट पाएँ (और उत्तर न देने पर रात 8 बजे)।',
        'दुपारी हो/नाही सूचना मिळवा (आणि उत्तर न दिल्यास रात्री 8 वाजता).',
        'দুপুরে একটি হ্যাঁ/না সতর্কতা পান (এবং উত্তর না দিলে রাত 8টায়)।',
        'మధ్యాహ్నం ఒక అవును/కాదు హెచ్చరిక పొందండి (సమాధానం ఇవ్వకపోతే రాత్రి 8 గంటలకు).',
        'மதியம் ஒரு ஆம்/இல்லை எச்சரிக்கையைப் பெறுங்கள் (பதிலளிக்கவில்லை என்றால் இரவு 8 மணிக்கு).',
      );
  String get durationOptional => _t('Duration (optional)', 'अवधि (वैकल्पिक)', 'कालावधी (पर्यायी)', 'সময়কাল (ঐচ্ছিক)', 'వ్యవధి (ఐచ్ఛికం)', 'கால அளவு (விருப்பம்)');
  String get durationDesc => _t(
        'Add a start & end date to see a progress bar to your goal.',
        'अपने लक्ष्य तक प्रगति बार देखने के लिए आरंभ और समाप्ति तिथि जोड़ें।',
        'तुमच्या उद्दिष्टापर्यंतचा प्रगती बार पाहण्यासाठी आरंभ व समाप्ती तारीख जोडा.',
        'আপনার লক্ষ্যের অগ্রগতি বার দেখতে একটি শুরু ও শেষ তারিখ যোগ করুন।',
        'మీ లక్ష్యానికి పురోగతి బార్ చూడటానికి ప్రారంభ & ముగింపు తేదీని జోడించండి.',
        'உங்கள் இலக்குக்கான முன்னேற்றப் பட்டியைப் பார்க்க ஒரு தொடக்க & முடிவு தேதியைச் சேருங்கள்.',
      );
  String get startLabel => _t('Start', 'आरंभ', 'आरंभ', 'শুরু', 'ప్రారంభం', 'தொடக்கம்');
  String get endLabel => _t('End', 'समाप्ति', 'समाप्ती', 'শেষ', 'ముగింపు', 'முடிவு');
  String catchingUpSince(String month) =>
      _t('Catching up since $month', '$month से बकाया भर रहे हैं', '$month पासून भरून काढत आहात', '$month থেকে পূরণ করছেন', '$month నుండి పూర్తి చేస్తున్నారు', '$month முதல் நிறைவு செய்கிறீர்கள்');
  String get catchUpDesc => _t(
        "We can't verify past instalments, so just tell us how many you've "
            'already completed — your progress will reflect them.',
        'हम पिछली किस्तों की पुष्टि नहीं कर सकते, इसलिए हमें बस बताएँ कि आपने '
            'कितनी पहले ही पूरी कर लीं — आपकी प्रगति में वे दिखेंगी।',
        'आम्ही मागील हप्त्यांची पडताळणी करू शकत नाही, म्हणून तुम्ही आधीच किती '
            'पूर्ण केले ते सांगा — तुमच्या प्रगतीत ते दिसतील.',
        'আমরা অতীতের কিস্তি যাচাই করতে পারি না, তাই কেবল বলুন আপনি আগে থেকে '
            'কতগুলো সম্পূর্ণ করেছেন — আপনার অগ্রগতিতে সেগুলো প্রতিফলিত হবে।',
        'మేము గత వాయిదాలను ధృవీకరించలేము, కాబట్టి మీరు ఇప్పటికే ఎన్ని పూర్తి చేశారో మాకు చెప్పండి — మీ పురోగతిలో అవి ప్రతిబింబిస్తాయి.',
        'கடந்த தவணைகளை எங்களால் சரிபார்க்க முடியாது, எனவே நீங்கள் ஏற்கனவே எத்தனை முடித்துள்ளீர்கள் என்பதை எங்களிடம் சொல்லுங்கள் — உங்கள் முன்னேற்றத்தில் அவை பிரதிபலிக்கும்.',
      );
  String get instalmentsAlreadyPaid =>
      _t('Instalments already paid', 'पहले से भरी किस्तें', 'आधीच भरलेले हप्ते', 'আগে থেকে পরিশোধিত কিস্তি', 'ఇప్పటికే చెల్లించిన వాయిదాలు', 'ஏற்கனவே செலுத்திய தவணைகள்');
  String get giveItAName => _t('Give it a name', 'इसे एक नाम दें', 'याला एक नाव द्या', 'এটিকে একটি নাম দিন', 'దీనికి ఒక పేరు ఇవ్వండి', 'இதற்கு ஒரு பெயர் கொடுங்கள்');
  String get enterMonthlyAmount =>
      _t('Enter the monthly amount', 'मासिक राशि दर्ज करें', 'मासिक रक्कम प्रविष्ट करा', 'মাসিক পরিমাণ লিখুন', 'నెలవారీ మొత్తాన్ని నమోదు చేయండి', 'மாதாந்திர தொகையை உள்ளிடு');
  String get endAfterStart => _t(
        'End date must be after the start date',
        'समाप्ति तिथि आरंभ तिथि के बाद होनी चाहिए',
        'समाप्ती तारीख आरंभ तारखेनंतर असावी',
        'শেষ তারিখ অবশ্যই শুরুর তারিখের পরে হতে হবে',
        'ముగింపు తేదీ ప్రారంభ తేదీ తర్వాత ఉండాలి',
        'முடிவு தேதி தொடக்க தேதிக்குப் பிறகு இருக்க வேண்டும்',
      );
  String get enterValueAboveZero =>
      _t('Enter a value above ₹0', '₹0 से अधिक मान दर्ज करें', '₹0 पेक्षा जास्त मूल्य प्रविष्ट करा', '₹0-এর বেশি মান লিখুন', '₹0 కంటే ఎక్కువ విలువను నమోదు చేయండి', '₹0 க்கு மேல் ஒரு மதிப்பை உள்ளிடு');
  String deleteHoldingTitle(bool isInvestment) => _t(
        'Delete ${isInvestment ? 'investment' : 'entry'}?',
        '${isInvestment ? 'निवेश' : 'प्रविष्टि'} हटाएँ?',
        '${isInvestment ? 'गुंतवणूक' : 'नोंद'} हटवायची?',
        '${isInvestment ? 'বিনিয়োগ' : 'এন্ট্রি'} মুছবেন?',
        '${isInvestment ? 'పెట్టుబడి' : 'ఎంట్రీ'}ని తొలగించాలా?',
        '${isInvestment ? 'முதலீட்டை' : 'உள்ளீட்டை'} நீக்கவா?',
      );
  String deleteHoldingWithPlan(String name) => _t(
        'This removes "$name", its recurring schedule and all logged '
            "instalments from your net worth. This can't be undone.",
        'यह "$name", इसका आवर्ती शेड्यूल और सभी दर्ज किस्तें आपकी नेट वर्थ से '
            'हटा देगा। इसे पूर्ववत नहीं किया जा सकता।',
        'हे "$name", त्याचे आवर्ती वेळापत्रक आणि सर्व नोंदवलेले हप्ते तुमच्या '
            'नेट वर्थमधून काढून टाकेल. हे पूर्ववत करता येणार नाही.',
        'এটি আপনার নেট ওয়ার্থ থেকে "$name", এর আবর্তক সূচি ও সব নথিভুক্ত '
            'কিস্তি সরিয়ে দেয়। এটি পূর্বাবস্থায় ফেরানো যায় না।',
        'ఇది "$name", దాని పునరావృత షెడ్యూల్ మరియు అన్ని నమోదైన వాయిదాలను మీ నెట్ వర్త్ నుండి తీసివేస్తుంది. దీన్ని రద్దు చేయలేరు.',
        'இது "$name", அதன் தொடர் அட்டவணை மற்றும் அனைத்து பதிவான தவணைகளையும் உங்கள் நிகர மதிப்பிலிருந்து அகற்றுகிறது. இதைச் செயல்தவிர்க்க முடியாது.',
      );
  String deleteHoldingSimple(String name) => _t(
        "This removes \"$name\" from your net worth. This can't be undone.",
        'यह "$name" को आपकी नेट वर्थ से हटा देगा। इसे पूर्ववत नहीं किया जा सकता।',
        'हे "$name" तुमच्या नेट वर्थमधून काढून टाकेल. हे पूर्ववत करता येणार नाही.',
        'এটি আপনার নেট ওয়ার্থ থেকে "$name" সরিয়ে দেয়। এটি পূর্বাবস্থায় ফেরানো যায় না।',
        'ఇది మీ నెట్ వర్త్ నుండి "$name" ను తీసివేస్తుంది. దీన్ని రద్దు చేయలేరు.',
        'இது உங்கள் நிகர மதிப்பிலிருந்து "$name" ஐ அகற்றுகிறது. இதைச் செயல்தவிர்க்க முடியாது.',
      );
  String dayOrdinal(int n) => _t(_enOrdinal(n), '$n', '$n', '$n', '$nవ', '$nஆம்');

  /// Display label for a net-worth holding category. Keys stay the canonical
  /// English value in the DB; this maps to a Hindi label for display only.
  String holdingCategoryName(String key) {
    switch (key) {
      case 'Fixed Deposit':
        return _t('Fixed Deposit', 'सावधि जमा', 'मुदत ठेव', 'স্থায়ী আমানত', 'ఫిక్స్‌డ్ డిపాజిట్', 'நிலையான வைப்பு');
      case 'Recurring Deposit':
        return _t('Recurring Deposit', 'आवर्ती जमा', 'आवर्ती ठेव', 'আবর্তক আমানত', 'రికరింగ్ డిపాజిట్', 'தொடர் வைப்பு');
      case 'Mutual Fund':
        return _t('Mutual Fund', 'म्यूचुअल फंड', 'म्युच्युअल फंड', 'মিউচুয়াল ফান্ড', 'మ్యూచువల్ ఫండ్', 'மியூச்சுவல் ஃபண்ட்');
      case 'Stocks':
        return _t('Stocks', 'स्टॉक', 'स्टॉक', 'স্টক', 'స్టాక్‌లు', 'பங்குகள்');
      case 'Bonds':
        return _t('Bonds', 'बॉन्ड', 'बॉन्ड', 'বন্ড', 'బాండ్‌లు', 'பத்திரங்கள்');
      case 'Gold':
        return _t('Gold', 'सोना', 'सोने', 'সোনা', 'బంగారం', 'தங்கம்');
      case 'PPF / EPF':
        return _t('PPF / EPF', 'PPF / EPF', 'PPF / EPF', 'PPF / EPF', 'PPF / EPF', 'PPF / EPF');
      case 'Crypto':
        return _t('Crypto', 'क्रिप्टो', 'क्रिप्टो', 'ক্রিপ্টো', 'క్రిప్టో', 'கிரிப்டோ');
      case 'Other Investment':
        return _t('Other Investment', 'अन्य निवेश', 'इतर गुंतवणूक', 'অন্যান্য বিনিয়োগ', 'ఇతర పెట్టుబడి', 'பிற முதலீடு');
      case 'Savings':
        return _t('Savings', 'बचत', 'बचत', 'সঞ্চয়', 'పొదుపు', 'சேமிப்பு');
      case 'Cash':
        return _t('Cash', 'नकद', 'रोख', 'নগদ', 'నగదు', 'ரொக்கம்');
      case 'Real Estate':
        return _t('Real Estate', 'रियल एस्टेट', 'स्थावर मालमत्ता', 'রিয়েল এস্টেট', 'రియల్ ఎస్టేట్', 'ரியல் எஸ்டேட்');
      case 'Vehicle':
        return _t('Vehicle', 'वाहन', 'वाहन', 'যানবাহন', 'వాహనం', 'வாகனம்');
      case 'Other Asset':
        return _t('Other Asset', 'अन्य संपत्ति', 'इतर मालमत्ता', 'অন্যান্য সম্পদ', 'ఇతర ఆస్తి', 'பிற சொத்து');
      case 'Home Loan':
        return _t('Home Loan', 'होम लोन', 'गृहकर्ज', 'হোম লোন', 'హోమ్ లోన్', 'வீட்டுக் கடன்');
      case 'Personal Loan':
        return _t('Personal Loan', 'पर्सनल लोन', 'वैयक्तिक कर्ज', 'পার্সোনাল লোন', 'పర్సనల్ లోన్', 'தனிநபர் கடன்');
      case 'Car Loan':
        return _t('Car Loan', 'कार लोन', 'कार कर्ज', 'কার লোন', 'కార్ లోన్', 'கார் கடன்');
      case 'Credit Card':
        return _t('Credit Card', 'क्रेडिट कार्ड', 'क्रेडिट कार्ड', 'ক্রেডিট কার্ড', 'క్రెడిట్ కార్డ్', 'கிரெடிட் கார்டு');
      case 'Other Liability':
        return _t('Other Liability', 'अन्य देनदारी', 'इतर दायित्व', 'অন্যান্য দায়', 'ఇతర అప్పు', 'பிற கடன்');
      default:
        return key;
    }
  }

  // ── Wrapped share card ────────────────────────────────────────────────────
  String wrappedCardMonth(DateTime d) => _t(
        DateFormat('MMMM yyyy').format(d),
        '${_hiMonths[d.month - 1]} ${d.year}',
        '${_mrMonths[d.month - 1]} ${d.year}',
        '${_bnMonths[d.month - 1]} ${d.year}',
        '${_teMonths[d.month - 1]} ${d.year}',
        '${_taMonths[d.month - 1]} ${d.year}',
      );
  String get myMonthInReview =>
      _t('My month in review', 'मेरा महीना, एक नज़र में', 'माझा महिना, एका दृष्टीक्षेपात', 'আমার মাস, এক নজরে', 'నా నెల సమీక్ష', 'என் மாத மதிப்பாய்வு');
  String get privateOnDevice => _t('Private & on-device', 'निजी और ऑन-डिवाइस', 'खाजगी व ऑन-डिव्हाइस', 'ব্যক্তিগত ও অন-ডিভাইস', 'ప్రైవేట్ & ఆన్-డివైస్', 'தனிப்பட்ட & சாதனத்தில்');
  String get wSpentThisMonth => _t('SPENT THIS MONTH', 'इस माह खर्च', 'या महिन्यात खर्च', 'এই মাসে খরচ', 'ఈ నెల ఖర్చు', 'இந்த மாதம் செலவழித்தது');
  String get wOfIncomeSaved => _t('OF INCOME SAVED', 'आय में से बचत', 'उत्पन्नातून बचत', 'আয় থেকে সঞ্চয়', 'ఆదాయంలో పొదుపు', 'வருமானத்தில் சேமித்தது');
  String get wOver => _t('Over', 'अधिक', 'जास्त', 'বেশি', 'ఎక్కువ', 'அதிகம்');
  String get wSpentMoreThanEarned =>
      _t('SPENT MORE THAN EARNED', 'कमाई से ज़्यादा खर्च', 'कमाईपेक्षा जास्त खर्च', 'আয়ের চেয়ে বেশি খরচ', 'సంపాదించిన దానికంటే ఎక్కువ ఖర్చు', 'சம்பாதித்ததை விட அதிகம் செலவழித்தது');
  String wWentTo(String category) => _t('WENT TO $category', '$category में गया', '$category कडे गेला', '$category-এ গেছে', '$categoryకి వెళ్లింది', '$category க்குச் சென்றது');
  String get wTransactionsThisMonth =>
      _t('TRANSACTIONS THIS MONTH', 'इस माह लेन-देन', 'या महिन्यात व्यवहार', 'এই মাসে লেনদেন', 'ఈ నెల లావాదేవీలు', 'இந்த மாத பரிவர்த்தனைகள்');
  String get wTopCategory => _t('Top category', 'शीर्ष श्रेणी', 'आघाडीची श्रेणी', 'শীর্ষ বিভাগ', 'టాప్ వర్గం', 'சிறந்த வகை');
  String get wTopMerchant => _t('Top merchant', 'शीर्ष व्यापारी', 'आघाडीचा व्यापारी', 'শীর্ষ বিক্রেতা', 'టాప్ మర్చెంట్', 'சிறந்த வணிகர்');
  String get wSpendingVsLastMonth =>
      _t('Spending vs last month', 'पिछले माह की तुलना में खर्च', 'मागील महिन्याच्या तुलनेत खर्च', 'গত মাসের তুলনায় খরচ', 'గత నెలతో పోలిస్తే ఖర్చు', 'கடந்த மாதத்துடன் செலவு');
  String get wAvgPerDay => _t('Avg per day', 'प्रति दिन औसत', 'प्रति दिवस सरासरी', 'প্রতিদিন গড়', 'రోజుకు సగటు', 'நாள் ஒன்றுக்கு சராசரி');
  String get wBiggestExpense => _t('Biggest expense', 'सबसे बड़ा खर्च', 'सर्वात मोठा खर्च', 'সবচেয়ে বড় খরচ', 'అతిపెద్ద ఖర్చు', 'மிகப்பெரிய செலவு');
  String get wNetWorth => _t('Net worth', 'नेट वर्थ', 'नेट वर्थ', 'নেট ওয়ার্থ', 'నెట్ వర్త్', 'நிகர மதிப்பு');
  String wInvestedPctOfAssets(int pct) =>
      _t('$pct% of assets', 'संपत्ति का $pct%', 'मालमत्तेच्या $pct%', 'সম্পদের $pct%', 'ఆస్తులలో $pct%', 'சொத்துகளில் $pct%');
  String get wInvested => _t('Invested', 'निवेशित', 'गुंतवले', 'বিনিয়োগ করা', 'పెట్టుబడి పెట్టింది', 'முதலீடு செய்தது');
  String get wActivity => _t('Activity', 'गतिविधि', 'हालचाल', 'কার্যকলাপ', 'కార్యకలాపం', 'செயல்பாடு');
  String wActivitySummary(int txns, int merchants) => _t(
        '$txns txns · $merchants merchants',
        '$txns लेन-देन · $merchants व्यापारी',
        '$txns व्यवहार · $merchants व्यापारी',
        '$txns লেনদেন · $merchants বিক্রেতা',
        '$txns లావాదేవీలు · $merchants మర్చెంట్‌లు',
        '$txns பரிவர்த்தனைகள் · $merchants வணிகர்கள்',
      );
  String wMover(String label, bool up) =>
      _t('$label ${up ? 'up' : 'down'}', '$label ${up ? 'ऊपर' : 'नीचे'}', '$label ${up ? 'वर' : 'खाली'}', '$label ${up ? 'উপরে' : 'নিচে'}', '$label ${up ? 'పైకి' : 'కిందికి'}', '$label ${up ? 'மேலே' : 'கீழே'}');

  // ── Profile share card ─────────────────────────────────────────────────────
  String get defaultBudgeteer => _t('Budgeteer', 'बजटीयर', 'बजेटियर', 'বাজেটিয়ার', 'బడ్జెటీర్', 'பட்ஜெட்டியர்');
  String get trackingWithBudgetify =>
      _t('Tracking with Budgetify', 'Budgetify के साथ ट्रैकिंग', 'Budgetify सह ट्रॅकिंग', 'Budgetify দিয়ে ট্র্যাকিং', 'Budgetify తో ట్రాకింగ్', 'Budgetify உடன் கண்காணிப்பு');
  String get trophyCase => _t('TROPHY CASE', 'ट्रॉफ़ी केस', 'ट्रॉफी केस', 'ট্রফি কেস', 'ట్రోఫీ కేస్', 'கோப்பைப் பேழை');
  String get dayStreakLabel => _t('day streak', 'दिन की स्ट्रीक', 'दिवसांची स्ट्रीक', 'দিনের স্ট্রিক', 'రోజుల స్ట్రీక్', 'நாள் ஸ்ட்ரீக்');
  String trophyWord(int n) => _t(n == 1 ? 'trophy' : 'trophies', 'ट्रॉफ़ी', 'ट्रॉफी', 'ট্রফি', 'ట్రోఫీలు', 'கோப்பைகள்');
  String titleWord(int n) => _t(n == 1 ? 'title' : 'titles', 'खिताब', 'किताब', 'খেতাব', 'బిరుదులు', 'பட்டங்கள்');

  // ── Streak rewards (catalog content) ────────────────────────────────────────
  String get streakRewardGroup => _t('Streak Reward', 'स्ट्रीक रिवॉर्ड', 'स्ट्रीक रिवॉर्ड', 'স্ট্রিক রিওয়ার্ড', 'స్ట్రీక్ రివార్డ్', 'ஸ்ட்ரீக் வெகுமதி');
  String streakRewardName(String id) {
    switch (id) {
      case 'theme_smoky_ivory':
        return _t('Smoky Blue & Warm Ivory', 'स्मोकी ब्लू और वॉर्म आइवरी', 'स्मोकी ब्लू व वॉर्म आयव्हरी', 'স্মোকি ব্লু ও ওয়ার্ম আইভরি', 'స్మోకీ బ్లూ & వార్మ్ ఐవరీ', 'ஸ்மோக்கி நீலம் & வெதுவெதுப்பான ஐவரி');
      case 'theme_seashell_mauve':
        return _t('Soft Seashell & Dusty Mauve', 'सॉफ़्ट सीशेल और डस्टी मॉव', 'सॉफ्ट सीशेल व डस्टी मॉव', 'সফট সিশেল ও ডাস্টি মভ', 'సాఫ్ట్ సీషెల్ & డస్టీ మావ్', 'மென் சீஷெல் & டஸ்டி மவ்');
      case 'theme_onyx_amber':
        return _t('Onyx & Amber', 'ओनिक्स और एम्बर', 'ओनिक्स व अंबर', 'অনিক্স ও অ্যাম্বার', 'ఆనిక్స్ & అంబర్', 'ஆனிக்ஸ் & அம்பர்');
      case 'theme_royal_indigo':
        return _t('Royal Indigo', 'रॉयल इंडिगो', 'रॉयल इंडिगो', 'রয়্যাল ইন্ডিগো', 'రాయల్ ఇండిగో', 'ராயல் இண்டிகோ');
      case 'theme_midnight_indigo':
        return _t('Midnight Indigo', 'मिडनाइट इंडिगो', 'मिडनाइट इंडिगो', 'মিডনাইট ইন্ডিগো', 'మిడ్‌నైట్ ఇండిగో', 'மிட்நைட் இண்டிகோ');
      default:
        return id;
    }
  }
  String streakRewardBlurb(String id) {
    switch (id) {
      case 'theme_smoky_ivory':
        return _t(
          'A calm smoky-blue accent on a warm ivory canvas. Unlocked at a 3-day streak.',
          'गर्म आइवरी कैनवास पर शांत स्मोकी-ब्लू रंग। 3-दिन की स्ट्रीक पर अनलॉक।',
          'उबदार आयव्हरी कॅनव्हासवर शांत स्मोकी-ब्लू रंग. 3-दिवसांच्या स्ट्रीकवर अनलॉक.',
          'উষ্ণ আইভরি ক্যানভাসে শান্ত স্মোকি-ব্লু রং। 3-দিনের স্ট্রিকে আনলক।',
          'వార్మ్ ఐవరీ కాన్వాస్‌పై ప్రశాంతమైన స్మోకీ-బ్లూ యాక్సెంట్. 3-రోజుల స్ట్రీక్ వద్ద అన్‌లాక్.',
          'வெதுவெதுப்பான ஐவரி கேன்வாஸில் அமைதியான ஸ்மோக்கி-நீல ஆக்சென்ட். 3-நாள் ஸ்ட்ரீக்கில் திறக்கப்படும்.',
        );
      case 'theme_seashell_mauve':
        return _t(
          'Blush seashell with a dusty-mauve accent. Unlocked at a 7-day streak.',
          'डस्टी-मॉव रंग के साथ ब्लश सीशेल। 7-दिन की स्ट्रीक पर अनलॉक।',
          'डस्टी-मॉव रंगासह ब्लश सीशेल. 7-दिवसांच्या स्ट्रीकवर अनलॉक.',
          'ডাস্টি-মভ রং সহ ব্লাশ সিশেল। 7-দিনের স্ট্রিকে আনলক।',
          'డస్టీ-మావ్ యాక్సెంట్‌తో బ్లష్ సీషెల్. 7-రోజుల స్ట్రీక్ వద్ద అన్‌లాక్.',
          'டஸ்டி-மவ் ஆக்சென்ட்டுடன் ப்ளஷ் சீஷெல். 7-நாள் ஸ்ட்ரீக்கில் திறக்கப்படும்.',
        );
      case 'theme_onyx_amber':
        return _t(
          'A vivid amber accent on a deep onyx canvas. Unlocked at a 14-day streak.',
          'गहरे ओनिक्स कैनवास पर चमकीला एम्बर रंग। 14-दिन की स्ट्रीक पर अनलॉक।',
          'गडद ओनिक्स कॅनव्हासवर ठळक अंबर रंग. 14-दिवसांच्या स्ट्रीकवर अनलॉक.',
          'গাঢ় অনিক্স ক্যানভাসে উজ্জ্বল অ্যাম্বার রং। 14-দিনের স্ট্রিকে আনলক।',
          'లోతైన ఆనిక్స్ కాన్వాస్‌పై స్పష్టమైన అంబర్ యాక్సెంట్. 14-రోజుల స్ట్రీక్ వద్ద అన్‌లాక్.',
          'ஆழமான ஆனிக்ஸ் கேன்வாஸில் தெளிவான அம்பர் ஆக்சென்ட். 14-நாள் ஸ்ட்ரீக்கில் திறக்கப்படும்.',
        );
      case 'theme_royal_indigo':
        return _t(
          'A deep-indigo accent with an electric-cyan hero on a frosted-lavender canvas. Unlocked at a 30-day streak.',
          'फ्रॉस्टेड-लैवेंडर कैनवास पर इलेक्ट्रिक-सायन हीरो के साथ गहरा इंडिगो रंग। 30-दिन की स्ट्रीक पर अनलॉक।',
          'फ्रॉस्टेड-लॅव्हेंडर कॅनव्हासवर इलेक्ट्रिक-सायन हिरोसह गडद इंडिगो रंग. 30-दिवसांच्या स्ट्रीकवर अनलॉक.',
          'ফ্রস্টেড-ল্যাভেন্ডার ক্যানভাসে ইলেকট্রিক-সায়ান হিরো সহ গাঢ় ইন্ডিগো রং। 30-দিনের স্ট্রিকে আনলক।',
          'ఫ్రాస్టెడ్-లావెండర్ కాన్వాస్‌పై ఎలక్ట్రిక్-సైన్ హీరోతో లోతైన ఇండిగో యాక్సెంట్. 30-రోజుల స్ట్రీక్ వద్ద అన్‌లాక్.',
          'ஃப்ராஸ்டட்-லாவெண்டர் கேன்வாஸில் எலெக்ட்ரிக்-சயான் ஹீரோவுடன் ஆழமான இண்டிகோ ஆக்சென்ட். 30-நாள் ஸ்ட்ரீக்கில் திறக்கப்படும்.',
        );
      case 'theme_midnight_indigo':
        return _t(
          'An electric-cyan accent on a deep indigo-navy canvas — Royal Indigo after dark. Unlocked at a 45-day streak.',
          'गहरे इंडिगो-नेवी कैनवास पर इलेक्ट्रिक-सायन रंग — रॉयल इंडिगो का रात्रि रूप। 45-दिन की स्ट्रीक पर अनलॉक।',
          'गडद इंडिगो-नेव्ही कॅनव्हासवर इलेक्ट्रिक-सायन रंग — रॉयल इंडिगोचे रात्र रूप. 45-दिवसांच्या स्ट्रीकवर अनलॉक.',
          'গাঢ় ইন্ডিগো-নেভি ক্যানভাসে ইলেকট্রিক-সায়ান রং — অন্ধকারের পরে রয়্যাল ইন্ডিগো। 45-দিনের স্ট্রিকে আনলক।',
          'లోతైన ఇండిగో-నేవీ కాన్వాస్‌పై ఎలక్ట్రిక్-సైన్ యాక్సెంట్ — చీకటి తర్వాత రాయల్ ఇండిగో. 45-రోజుల స్ట్రీక్ వద్ద అన్‌లాక్.',
          'ஆழமான இண்டிகோ-நேவி கேன்வாஸில் எலெக்ட்ரிக்-சயான் ஆக்சென்ட் — இருள் பின் ராயல் இண்டிகோ. 45-நாள் ஸ்ட்ரீக்கில் திறக்கப்படும்.',
        );
      default:
        return '';
    }
  }

  // ── Gamification catalog (display names; ids stay canonical keys) ───────────
  String achievementName(String id) {
    switch (id) {
      case 'streak':
        return _t('Daily Streak', 'रोज़ की स्ट्रीक', 'रोजची स्ट्रीक', 'দৈনিক স্ট্রিক', 'రోజువారీ స్ట్రీక్', 'தினசரி ஸ்ட்ரீக்');
      case 'amount':
        return _t('Money Tracked', 'ट्रैक किया पैसा', 'ट्रॅक केलेला पैसा', 'ট্র্যাক করা টাকা', 'ట్రాక్ చేసిన డబ్బు', 'கண்காணித்த பணம்');
      case 'txn':
        return _t('Transactions', 'लेन-देन', 'व्यवहार', 'লেনদেন', 'లావాదేవీలు', 'பரிவர்த்தனைகள்');
      case 'history':
        return _t('Time Tracked', 'ट्रैक किया समय', 'ट्रॅक केलेला वेळ', 'ট্র্যাক করা সময়', 'ట్రాక్ చేసిన సమయం', 'கண்காணித்த நேரம்');
      case 'tagged':
        return _t('Fully Tagged', 'पूरी तरह टैग', 'पूर्ण टॅग', 'সম্পূর্ণ ট্যাগ', 'పూర్తిగా ట్యాగ్ చేయబడింది', 'முழுமையாகக் குறிச்சொல் இடப்பட்டது');
      case 'budget':
        return _t('Budget Hero', 'बजट हीरो', 'बजेट हीरो', 'বাজেট হিরো', 'బడ్జెట్ హీరో', 'பட்ஜெட் ஹீரோ');
      case 'saver':
        return _t('Super Saver', 'सुपर सेवर', 'सुपर सेव्हर', 'সুপার সেভার', 'సూపర్ సేవర్', 'சூப்பர் சேவர்');
      case 'networth':
        return _t('Net Worth', 'नेट वर्थ', 'नेट वर्थ', 'নেট ওয়ার্থ', 'నెట్ వర్త్', 'நிகர மதிப்பு');
      case 'debtfree':
        return _t('Debt-Free', 'कर्ज़-मुक्त', 'कर्जमुक्त', 'ঋণমুক্ত', 'రుణ రహిత', 'கடன் இல்லாதவர்');
      case 'nospend':
        return _t('No-Spend Days', 'बिना-खर्च दिन', 'बिनखर्च दिवस', 'বিনা-খরচ দিন', 'ఖర్చు లేని రోజులు', 'செலவில்லா நாட்கள்');
      case 'goals':
        return _t('Goal Getter', 'लक्ष्य-प्राप्तकर्ता', 'उद्दिष्ट-प्राप्तकर्ता', 'লক্ষ্য-অর্জনকারী', 'లక్ష్య సాధకుడు', 'இலக்கை அடைபவர்');
      case 'explorer':
        return _t('Category Explorer', 'श्रेणी अन्वेषक', 'श्रेणी अन्वेषक', 'বিভাগ অন্বেষক', 'వర్గ అన్వేషకుడు', 'வகை ஆய்வாளர்');
      default:
        return id;
    }
  }
  String achievementBlurb(String id) {
    switch (id) {
      case 'streak':
        return _t(
          'Open Budgetify on consecutive days. Your best streak keeps the badge.',
          'लगातार दिनों तक Budgetify खोलें। आपकी सर्वश्रेष्ठ स्ट्रीक बैज बनाए रखती है।',
          'सलग दिवस Budgetify उघडा. तुमची सर्वोत्तम स्ट्रीक बॅज टिकवते.',
          'পরপর দিন Budgetify খুলুন। আপনার সেরা স্ট্রিক ব্যাজটি ধরে রাখে।',
          'వరుస రోజులలో Budgetify తెరవండి. మీ అత్యుత్తమ స్ట్రీక్ బ్యాడ్జ్‌ను ఉంచుతుంది.',
          'தொடர்ச்சியான நாட்களில் Budgetify ஐத் திறங்கள். உங்கள் சிறந்த ஸ்ட்ரீக் பேட்ஜை வைத்திருக்கும்.',
        );
      case 'amount':
        return _t(
          'Total value tracked across every transaction, money in and out.',
          'हर लेन-देन में ट्रैक किया कुल मूल्य, आने और जाने वाला पैसा।',
          'प्रत्येक व्यवहारात ट्रॅक केलेले एकूण मूल्य, येणारा व जाणारा पैसा.',
          'প্রতিটি লেনদেনে ট্র্যাক করা মোট মূল্য, আসা ও যাওয়া টাকা।',
          'ప్రతి లావాదేవీలో ట్రాక్ చేసిన మొత్తం విలువ, లోపలికి మరియు బయటికి వెళ్లే డబ్బు.',
          'ஒவ்வொரு பரிவர்த்தனையிலும் கண்காணிக்கப்பட்ட மொத்த மதிப்பு, உள்ளே மற்றும் வெளியே செல்லும் பணம்.',
        );
      case 'txn':
        return _t(
          'Every transaction the app has tracked for you.',
          'ऐप ने आपके लिए ट्रैक किए सभी लेन-देन।',
          'अॅपने तुमच्यासाठी ट्रॅक केलेले सर्व व्यवहार.',
          'অ্যাপ আপনার জন্য ট্র্যাক করা প্রতিটি লেনদেন।',
          'యాప్ మీ కోసం ట్రాక్ చేసిన ప్రతి లావాదేవీ.',
          'ஆப் உங்களுக்காகக் கண்காணித்த ஒவ்வொரு பரிவர்த்தனையும்.',
        );
      case 'history':
        return _t(
          'How long your money history spans.',
          'आपका पैसा-इतिहास कितने समय तक फैला है।',
          'तुमचा पैसा-इतिहास किती काळ पसरला आहे.',
          'আপনার টাকার ইতিহাস কত সময় জুড়ে বিস্তৃত।',
          'మీ డబ్బు చరిత్ర ఎంత కాలం విస్తరించి ఉందో.',
          'உங்கள் பணத்தின் வரலாறு எவ்வளவு காலம் நீள்கிறது.',
        );
      case 'tagged':
        return _t(
          'Months where every transaction was categorised (need not be in a row).',
          'वे महीने जब हर लेन-देन वर्गीकृत था (लगातार होना ज़रूरी नहीं)।',
          'ज्या महिन्यांत प्रत्येक व्यवहार वर्गीकृत होता (सलग असणे आवश्यक नाही).',
          'যেসব মাসে প্রতিটি লেনদেন শ্রেণীবদ্ধ ছিল (পরপর হওয়া আবশ্যক নয়)।',
          'ప్రతి లావాదేవీ వర్గీకరించబడిన నెలలు (వరుసగా ఉండాల్సిన అవసరం లేదు).',
          'ஒவ்வொரு பரிவர்த்தனையும் வகைப்படுத்தப்பட்ட மாதங்கள் (வரிசையாக இருக்க வேண்டியதில்லை).',
        );
      case 'budget':
        return _t(
          'Months you finished within your overall budget.',
          'वे महीने जब आप अपने कुल बजट के भीतर रहे।',
          'ज्या महिन्यांत तुम्ही तुमच्या एकूण बजेटमध्ये राहिलात.',
          'যেসব মাসে আপনি আপনার মোট বাজেটের মধ্যে শেষ করেছেন।',
          'మీరు మీ మొత్తం బడ్జెట్‌లో ముగించిన నెలలు.',
          'உங்கள் மொத்த பட்ஜெட்டுக்குள் நீங்கள் முடித்த மாதங்கள்.',
        );
      case 'saver':
        return _t(
          'Months you saved at least 20% of your income.',
          'वे महीने जब आपने अपनी आय का कम से कम 20% बचाया।',
          'ज्या महिन्यांत तुम्ही तुमच्या उत्पन्नाच्या किमान 20% बचत केली.',
          'যেসব মাসে আপনি আপনার আয়ের অন্তত 20% সঞ্চয় করেছেন।',
          'మీరు మీ ఆదాయంలో కనీసం 20% పొదుపు చేసిన నెలలు.',
          'உங்கள் வருமானத்தில் குறைந்தது 20% சேமித்த மாதங்கள்.',
        );
      case 'networth':
        return _t(
          'Your tracked net worth (assets minus debts).',
          'आपकी ट्रैक की नेट वर्थ (संपत्ति घटा कर्ज़)।',
          'तुमची ट्रॅक केलेली नेट वर्थ (मालमत्ता वजा कर्ज).',
          'আপনার ট্র্যাক করা নেট ওয়ার্থ (সম্পদ বিয়োগ ঋণ)।',
          'మీ ట్రాక్ చేసిన నెట్ వర్త్ (ఆస్తులు మైనస్ అప్పులు).',
          'உங்கள் கண்காணித்த நிகர மதிப்பு (சொத்துகள் கழித்தல் கடன்கள்).',
        );
      case 'debtfree':
        return _t(
          'Stay debt-free (assets, zero liabilities) for 120 days straight.',
          'लगातार 120 दिन कर्ज़-मुक्त रहें (संपत्ति, शून्य देनदारी)।',
          'सलग 120 दिवस कर्जमुक्त राहा (मालमत्ता, शून्य दायित्व).',
          'টানা 120 দিন ঋণমুক্ত থাকুন (সম্পদ, শূন্য দায়)।',
          'వరుసగా 120 రోజులు రుణ రహితంగా ఉండండి (ఆస్తులు, సున్నా అప్పులు).',
          'தொடர்ச்சியாக 120 நாட்கள் கடன் இல்லாமல் இருங்கள் (சொத்துகள், பூஜ்ஜிய கடன்கள்).',
        );
      case 'nospend':
        return _t(
          'Days with zero spending, totalled up over time.',
          'शून्य खर्च वाले दिन, समय के साथ जोड़े गए।',
          'शून्य खर्च असलेले दिवस, कालांतराने जमा.',
          'শূন্য খরচের দিন, সময়ের সাথে যোগ করা।',
          'సున్నా ఖర్చు ఉన్న రోజులు, కాలక్రమేణా మొత్తం చేయబడ్డాయి.',
          'பூஜ்ஜிய செலவுள்ள நாட்கள், காலப்போக்கில் கூட்டப்பட்டன.',
        );
      case 'goals':
        return _t(
          'Savings goals you have fully funded.',
          'वे बचत-लक्ष्य जिन्हें आपने पूरी तरह पूरा किया।',
          'तुम्ही पूर्णपणे पूर्ण केलेली बचत-उद्दिष्टे.',
          'যেসব সঞ্চয় লক্ষ্য আপনি সম্পূর্ণরূপে পূর্ণ করেছেন।',
          'మీరు పూర్తిగా నిధులు సమకూర్చిన పొదుపు లక్ష్యాలు.',
          'நீங்கள் முழுமையாக நிதியளித்த சேமிப்பு இலக்குகள்.',
        );
      case 'explorer':
        return _t(
          'Different spending categories you have used.',
          'आपके द्वारा उपयोग की गई विभिन्न खर्च श्रेणियाँ।',
          'तुम्ही वापरलेल्या विविध खर्च श्रेणी.',
          'আপনি যেসব বিভিন্ন খরচ বিভাগ ব্যবহার করেছেন।',
          'మీరు ఉపయోగించిన వివిధ ఖర్చు వర్గాలు.',
          'நீங்கள் பயன்படுத்திய பல்வேறு செலவு வகைகள்.',
        );
      default:
        return '';
    }
  }
  String titleName(String id) {
    switch (id) {
      case 'foodie':
        return _t('Foodie', 'फ़ूडी', 'फूडी', 'ফুডি', 'ఫుడీ', 'உணவுப் பிரியர்');
      case 'homechef':
        return _t('Home Chef', 'होम शेफ़', 'होम शेफ', 'হোম শেফ', 'హోమ్ షెఫ్', 'வீட்டு சமையல்காரர்');
      case 'shopaholic':
        return _t('Shopaholic', 'शॉपहॉलिक', 'शॉपहोलिक', 'শপাহোলিক', 'షాపహాలిక్', 'ஷாப்பஹாலிக்');
      case 'roadwarrior':
        return _t('Road Warrior', 'रोड वॉरियर', 'रोड वॉरियर', 'রোড ওয়ারিয়র', 'రోడ్ వారియర్', 'சாலை வீரர்');
      case 'billmaster':
        return _t('Bill Master', 'बिल मास्टर', 'बिल मास्टर', 'বিল মাস্টার', 'బిల్ మాస్టర్', 'பில் மாஸ்டர்');
      case 'showstopper':
        return _t('Showstopper', 'शोस्टॉपर', 'शोस्टॉपर', 'শোস্টপার', 'షోస్టాపర్', 'ஷோஸ்டாப்பர்');
      case 'wellness':
        return _t('Wellness Warrior', 'वेलनेस वॉरियर', 'वेलनेस वॉरियर', 'ওয়েলনেস ওয়ারিয়র', 'వెల్‌నెస్ వారియర్', 'நல்வாழ்வு வீரர்');
      case 'globetrotter':
        return _t('Globetrotter', 'ग्लोबट्रॉटर', 'ग्लोबट्रॉटर', 'গ্লোবট্রটার', 'గ్లోబ్‌ట్రాటర్', 'உலகப் பயணி');
      case 'scholar':
        return _t('Scholar', 'स्कॉलर', 'स्कॉलर', 'স্কলার', 'స్కాలర్', 'அறிஞர்');
      case 'investor':
        return _t('Investor', 'निवेशक', 'गुंतवणूकदार', 'বিনিয়োগকারী', 'పెట్టుబడిదారు', 'முதலீட்டாளர்');
      case 'moneymagnet':
        return _t('Money Magnet', 'मनी मैग्नेट', 'मनी मॅग्नेट', 'মানি ম্যাগনেট', 'మనీ మాగ్నెట్', 'பண காந்தம்');
      case 'frugal':
        return _t('Frugal Master', 'फ्रूगल मास्टर', 'फ्रुगल मास्टर', 'ফ্রুগাল মাস্টার', 'ఫ్రూగల్ మాస్టర్', 'சிக்கன மாஸ்டர்');
      case 'broke':
        return _t('Broke Spender', 'ब्रोक स्पेंडर', 'ब्रोक स्पेंडर', 'ব্রোক স্পেন্ডার', 'బ్రోక్ స్పెండర్', 'ப்ரோக் ஸ்பெண்டர்');
      default:
        return id;
    }
  }
  String titleBlurb(String id) {
    switch (id) {
      case 'foodie':
        return _t(
          'Have 6 months where Food & Dining was 35%+ of your income.',
          '6 महीने ऐसे हों जब खान-पान आपकी आय का 35%+ रहा।',
          'खाणे-पिणे तुमच्या उत्पन्नाच्या 35%+ असलेले 6 महिने मिळवा.',
          'খাবার ও খাওয়া-দাওয়া আপনার আয়ের 35%+ ছিল এমন 6 মাস অর্জন করুন।',
          'ఆహారం & భోజనం మీ ఆదాయంలో 35%+ ఉన్న 6 నెలలు సాధించండి.',
          'உணவு & சாப்பாடு உங்கள் வருமானத்தில் 35%+ இருந்த 6 மாதங்களைப் பெறுங்கள்.',
        );
      case 'homechef':
        return _t(
          'Have 6 months where Groceries were 25%+ of your income.',
          '6 महीने ऐसे हों जब किराना आपकी आय का 25%+ रहा।',
          'किराणा तुमच्या उत्पन्नाच्या 25%+ असलेले 6 महिने मिळवा.',
          'মুদিখানা আপনার আয়ের 25%+ ছিল এমন 6 মাস অর্জন করুন।',
          'కిరాణా మీ ఆదాయంలో 25%+ ఉన్న 6 నెలలు సాధించండి.',
          'மளிகை உங்கள் வருமானத்தில் 25%+ இருந்த 6 மாதங்களைப் பெறுங்கள்.',
        );
      case 'shopaholic':
        return _t(
          'Have 6 months where Shopping was 25%+ of your income.',
          '6 महीने ऐसे हों जब खरीदारी आपकी आय का 25%+ रही।',
          'खरेदी तुमच्या उत्पन्नाच्या 25%+ असलेले 6 महिने मिळवा.',
          'শপিং আপনার আয়ের 25%+ ছিল এমন 6 মাস অর্জন করুন।',
          'షాపింగ్ మీ ఆదాయంలో 25%+ ఉన్న 6 నెలలు సాధించండి.',
          'ஷாப்பிங் உங்கள் வருமானத்தில் 25%+ இருந்த 6 மாதங்களைப் பெறுங்கள்.',
        );
      case 'roadwarrior':
        return _t(
          'Have 6 months where Transportation was 20%+ of your income.',
          '6 महीने ऐसे हों जब परिवहन आपकी आय का 20%+ रहा।',
          'वाहतूक तुमच्या उत्पन्नाच्या 20%+ असलेले 6 महिने मिळवा.',
          'পরিবহন আপনার আয়ের 20%+ ছিল এমন 6 মাস অর্জন করুন।',
          'రవాణా మీ ఆదాయంలో 20%+ ఉన్న 6 నెలలు సాధించండి.',
          'போக்குவரத்து உங்கள் வருமானத்தில் 20%+ இருந்த 6 மாதங்களைப் பெறுங்கள்.',
        );
      case 'billmaster':
        return _t(
          'Have 6 months where Bills & Utilities were 25%+ of your income.',
          '6 महीने ऐसे हों जब बिल और यूटिलिटी आपकी आय का 25%+ रहे।',
          'बिले व सुविधा तुमच्या उत्पन्नाच्या 25%+ असलेले 6 महिने मिळवा.',
          'বিল ও ইউটিলিটি আপনার আয়ের 25%+ ছিল এমন 6 মাস অর্জন করুন।',
          'బిల్లులు & యుటిలిటీలు మీ ఆదాయంలో 25%+ ఉన్న 6 నెలలు సాధించండి.',
          'பில்கள் & பயன்பாட்டுச் சேவைகள் உங்கள் வருமானத்தில் 25%+ இருந்த 6 மாதங்களைப் பெறுங்கள்.',
        );
      case 'showstopper':
        return _t(
          'Have 6 months where Entertainment was 20%+ of your income.',
          '6 महीने ऐसे हों जब मनोरंजन आपकी आय का 20%+ रहा।',
          'मनोरंजन तुमच्या उत्पन्नाच्या 20%+ असलेले 6 महिने मिळवा.',
          'বিনোদন আপনার আয়ের 20%+ ছিল এমন 6 মাস অর্জন করুন।',
          'వినోదం మీ ఆదాయంలో 20%+ ఉన్న 6 నెలలు సాధించండి.',
          'பொழுதுபோக்கு உங்கள் வருமானத்தில் 20%+ இருந்த 6 மாதங்களைப் பெறுங்கள்.',
        );
      case 'wellness':
        return _t(
          'Have 6 months where Health & Medical was 15%+ of your income.',
          '6 महीने ऐसे हों जब स्वास्थ्य और चिकित्सा आपकी आय का 15%+ रहा।',
          'आरोग्य व वैद्यकीय तुमच्या उत्पन्नाच्या 15%+ असलेले 6 महिने मिळवा.',
          'স্বাস্থ্য ও চিকিৎসা আপনার আয়ের 15%+ ছিল এমন 6 মাস অর্জন করুন।',
          'ఆరోగ్యం & వైద్యం మీ ఆదాయంలో 15%+ ఉన్న 6 నెలలు సాధించండి.',
          'உடல்நலம் & மருத்துவம் உங்கள் வருமானத்தில் 15%+ இருந்த 6 மாதங்களைப் பெறுங்கள்.',
        );
      case 'globetrotter':
        return _t(
          'Have 3 months where Travel was 25%+ of your income.',
          '3 महीने ऐसे हों जब यात्रा आपकी आय का 25%+ रही।',
          'प्रवास तुमच्या उत्पन्नाच्या 25%+ असलेले 3 महिने मिळवा.',
          'ভ্রমণ আপনার আয়ের 25%+ ছিল এমন 3 মাস অর্জন করুন।',
          'ప్రయాణం మీ ఆదాయంలో 25%+ ఉన్న 3 నెలలు సాధించండి.',
          'பயணம் உங்கள் வருமானத்தில் 25%+ இருந்த 3 மாதங்களைப் பெறுங்கள்.',
        );
      case 'scholar':
        return _t(
          'Have 6 months where Education was 15%+ of your income.',
          '6 महीने ऐसे हों जब शिक्षा आपकी आय का 15%+ रही।',
          'शिक्षण तुमच्या उत्पन्नाच्या 15%+ असलेले 6 महिने मिळवा.',
          'শিক্ষা আপনার আয়ের 15%+ ছিল এমন 6 মাস অর্জন করুন।',
          'విద్య మీ ఆదాయంలో 15%+ ఉన్న 6 నెలలు సాధించండి.',
          'கல்வி உங்கள் வருமானத்தில் 15%+ இருந்த 6 மாதங்களைப் பெறுங்கள்.',
        );
      case 'investor':
        return _t(
          'Have 6 months where you invested 20%+ of your income.',
          '6 महीने ऐसे हों जब आपने अपनी आय का 20%+ निवेश किया।',
          'तुम्ही तुमच्या उत्पन्नाच्या 20%+ गुंतवणूक केलेले 6 महिने मिळवा.',
          'আপনি আপনার আয়ের 20%+ বিনিয়োগ করেছেন এমন 6 মাস অর্জন করুন।',
          'మీరు మీ ఆదాయంలో 20%+ పెట్టుబడి పెట్టిన 6 నెలలు సాధించండి.',
          'உங்கள் வருமானத்தில் 20%+ முதலீடு செய்த 6 மாதங்களைப் பெறுங்கள்.',
        );
      case 'moneymagnet':
        return _t(
          'Have 6 months with a savings rate of 35%+.',
          '35%+ बचत दर वाले 6 महीने हों।',
          '35%+ बचत दर असलेले 6 महिने मिळवा.',
          '35%+ সঞ্চয় হার সহ 6 মাস অর্জন করুন।',
          '35%+ పొదుపు రేటుతో 6 నెలలు సాధించండి.',
          '35%+ சேமிப்பு விகிதத்துடன் 6 மாதங்களைப் பெறுங்கள்.',
        );
      case 'frugal':
        return _t(
          'Have 6 months with a savings rate of 60%+.',
          '60%+ बचत दर वाले 6 महीने हों।',
          '60%+ बचत दर असलेले 6 महिने मिळवा.',
          '60%+ সঞ্চয় হার সহ 6 মাস অর্জন করুন।',
          '60%+ పొదుపు రేటుతో 6 నెలలు సాధించండి.',
          '60%+ சேமிப்பு விகிதத்துடன் 6 மாதங்களைப் பெறுங்கள்.',
        );
      case 'broke':
        return _t(
          'Rack up 90 total no-spend days (they need not be in a row).',
          'कुल 90 बिना-खर्च दिन जमा करें (लगातार होना ज़रूरी नहीं)।',
          'एकूण 90 बिनखर्च दिवस जमा करा (ते सलग असणे आवश्यक नाही).',
          'মোট 90টি বিনা-খরচ দিন জমা করুন (সেগুলো পরপর হওয়া আবশ্যক নয়)।',
          'మొత్తం 90 ఖర్చు లేని రోజులు సమకూర్చుకోండి (అవి వరుసగా ఉండాల్సిన అవసరం లేదు).',
          'மொத்தம் 90 செலவில்லா நாட்களைச் சேர்த்துக் கொள்ளுங்கள் (அவை வரிசையாக இருக்க வேண்டியதில்லை).',
        );
      default:
        return '';
    }
  }

  /// Display label for a [GamiUnit]/title unit string ('days', 'months', …).
  String gamiUnit(String unit) {
    switch (unit) {
      case 'days':
        return _t('days', 'दिन', 'दिवस', 'দিন', 'రోజులు', 'நாட்கள்');
      case 'months':
        return _t('months', 'माह', 'महिने', 'মাস', 'నెలలు', 'மாதங்கள்');
      case 'rupees':
        return _t('rupees', 'रुपये', 'रुपये', 'টাকা', 'రూపాయలు', 'ரூபாய்');
      case 'count':
        return _t('count', 'गिनती', 'संख्या', 'সংখ্যা', 'సంఖ్య', 'எண்ணிக்கை');
      default:
        return unit;
    }
  }

  /// Translate the time-unit words inside a tier badge label ('7-Day',
  /// '3 Months', '1 Year', 'All'…). Currency/number labels pass through.
  String tierBadgeLabel(String label) {
    switch (lang) {
      case AppLanguage.hindi:
        return label
            .replaceAll('Days', 'दिन')
            .replaceAll('Day', 'दिन')
            .replaceAll('Years', 'वर्ष')
            .replaceAll('Year', 'वर्ष')
            .replaceAll('Months', 'माह')
            .replaceAll('Month', 'माह')
            .replaceAll('Goals', 'लक्ष्य')
            .replaceAll('Goal', 'लक्ष्य')
            .replaceAll('All', 'सभी');
      case AppLanguage.marathi:
        return label
            .replaceAll('Days', 'दिवस')
            .replaceAll('Day', 'दिवस')
            .replaceAll('Years', 'वर्षे')
            .replaceAll('Year', 'वर्ष')
            .replaceAll('Months', 'महिने')
            .replaceAll('Month', 'महिना')
            .replaceAll('Goals', 'उद्दिष्टे')
            .replaceAll('Goal', 'उद्दिष्ट')
            .replaceAll('All', 'सर्व');
      case AppLanguage.bengali:
        return label
            .replaceAll('Days', 'দিন')
            .replaceAll('Day', 'দিন')
            .replaceAll('Years', 'বছর')
            .replaceAll('Year', 'বছর')
            .replaceAll('Months', 'মাস')
            .replaceAll('Month', 'মাস')
            .replaceAll('Goals', 'লক্ষ্য')
            .replaceAll('Goal', 'লক্ষ্য')
            .replaceAll('All', 'সব');
      case AppLanguage.telugu:
        return label
            .replaceAll('Days', 'రోజులు')
            .replaceAll('Day', 'రోజు')
            .replaceAll('Years', 'సంవత్సరాలు')
            .replaceAll('Year', 'సంవత్సరం')
            .replaceAll('Months', 'నెలలు')
            .replaceAll('Month', 'నెల')
            .replaceAll('Goals', 'లక్ష్యాలు')
            .replaceAll('Goal', 'లక్ష్యం')
            .replaceAll('All', 'అన్నీ');
      case AppLanguage.tamil:
        return label
            .replaceAll('Days', 'நாட்கள்')
            .replaceAll('Day', 'நாள்')
            .replaceAll('Years', 'ஆண்டுகள்')
            .replaceAll('Year', 'ஆண்டு')
            .replaceAll('Months', 'மாதங்கள்')
            .replaceAll('Month', 'மாதம்')
            .replaceAll('Goals', 'இலக்குகள்')
            .replaceAll('Goal', 'இலக்கு')
            .replaceAll('All', 'அனைத்தும்');
      case AppLanguage.english:
        return label;
    }
  }
  String nextTierLabel(String label) => _t('Next: $label', 'अगला: $label', 'पुढील: $label', 'পরবর্তী: $label', 'తదుపరి: $label', 'அடுத்து: $label');

  // ── Misc toasts ────────────────────────────────────────────────────────────
  String errorLoadingTransactions(Object e) => _t(
      'Error loading transactions: $e', 'लेन-देन लोड करने में त्रुटि: $e', 'व्यवहार लोड करताना त्रुटी: $e', 'লেনদেন লোড করতে ত্রুটি: $e', 'లావాదేవీలు లోడ్ చేయడంలో లోపం: $e', 'பரிவர்த்தனைகளை ஏற்றுவதில் பிழை: $e');
  String get enterAmountAboveZero =>
      _t('Enter an amount above ₹0', '₹0 से अधिक राशि दर्ज करें', '₹0 पेक्षा जास्त रक्कम प्रविष्ट करा', '₹0-এর বেশি পরিমাণ লিখুন', '₹0 కంటే ఎక్కువ మొత్తాన్ని నమోదు చేయండి', '₹0 க்கு மேல் ஒரு தொகையை உள்ளிடு');

  // ── Guided tutorial (in-context coach marks) & feature spotlights ─────────
  String get tutSkip =>
      _t('Skip tour', 'टूर छोड़ें', 'टूर वगळा', 'ট্যুর এড়িয়ে যান', 'టూర్ దాటవేయి', 'சுற்றுலாவைத் தவிர்');
  String get tutNext => _t('Next', 'आगे', 'पुढे', 'পরবর্তী', 'తదుపరి', 'அடுத்து');
  String get tutFinish => _t('Finish', 'समाप्त', 'संपवा', 'শেষ করুন', 'ముగించు', 'முடி');

  String get tutViewTxnsTitle => _t('A transaction just landed!',
      'एक लेन-देन आ गया!', 'एक व्यवहार आला!', 'একটি লেনদেন এসে গেছে!', 'ఒక లావాదేవీ ఇప్పుడే వచ్చింది!', 'ஒரு பரிவர்த்தனை இப்போதுதான் வந்தது!');
  String get tutViewTxnsBody => _t(
        'Budgetify caught this from your bank SMS — nothing to type. Tap the highlighted transaction to open it.',
        'Budgetify ने इसे आपके बैंक SMS से पकड़ा — कुछ टाइप नहीं करना। खोलने के लिए हाइलाइट किए गए लेन-देन पर टैप करें।',
        'Budgetify ने हे तुमच्या बँक SMS मधून पकडले — काही टाइप करायचे नाही. उघडण्यासाठी हायलाइट केलेल्या व्यवहारावर टॅप करा.',
        'Budgetify এটি আপনার ব্যাংক SMS থেকে ধরেছে — কিছু টাইপ করতে হয়নি। খুলতে হাইলাইট করা লেনদেনে ট্যাপ করুন।',
        'Budgetify దీన్ని మీ బ్యాంక్ SMS నుండి పట్టుకుంది — ఏమీ టైప్ చేయనవసరం లేదు. తెరవడానికి హైలైట్ చేసిన లావాదేవీపై ట్యాప్ చేయండి.',
        'Budgetify இதை உங்கள் வங்கி SMS இலிருந்து பிடித்தது — எதுவும் தட்டச்சு செய்யத் தேவையில்லை. திறக்க, சிறப்பிக்கப்பட்ட பரிவர்த்தனையைத் தட்டுங்கள்.',
      );
  String get tutOpenTxnTitle =>
      _t('Open it up', 'इसे खोलें', 'हे उघडा', 'এটি খুলুন', 'దాన్ని తెరవండి', 'அதைத் திறங்கள்');
  String get tutOpenTxnBody => _t(
        'Tap this transaction to see its full details.',
        'पूरा विवरण देखने के लिए इस लेन-देन पर टैप करें।',
        'संपूर्ण तपशील पाहण्यासाठी या व्यवहारावर टॅप करा.',
        'পুরো বিবরণ দেখতে এই লেনদেনে ট্যাপ করুন।',
        'దాని పూర్తి వివరాలను చూడటానికి ఈ లావాదేవీపై ట్యాప్ చేయండి.',
        'அதன் முழு விவரங்களைப் பார்க்க இந்த பரிவர்த்தனையைத் தட்டுங்கள்.',
      );
  String get tutChooseTagTitle =>
      _t('Give it a tag', 'इसे टैग दें', 'याला टॅग द्या', 'এটিকে একটি ট্যাগ দিন', 'దీనికి ఒక ట్యాగ్ ఇవ్వండి', 'இதற்கு ஒரு குறிச்சொல் கொடுங்கள்');
  String get tutChooseTagBody => _t(
        'Tags turn raw spends into budgets and insights. Tap the category that fits best.',
        'टैग कच्चे खर्च को बजट और इनसाइट में बदलते हैं। सबसे सही श्रेणी पर टैप करें।',
        'टॅग्स कच्च्या खर्चाला बजेट व इनसाइट्समध्ये बदलतात. सर्वांत योग्य श्रेणीवर टॅप करा.',
        'ট্যাগ কাঁচা খরচকে বাজেট আর ইনসাইটে বদলে দেয়। সবচেয়ে মানানসই ক্যাটাগরিতে ট্যাপ করুন।',
        'ట్యాగ్‌లు ముడి ఖర్చులను బడ్జెట్‌లు మరియు అంతర్దృష్టులుగా మారుస్తాయి. బాగా సరిపోయే వర్గంపై ట్యాప్ చేయండి.',
        'குறிச்சொற்கள் மூல செலவுகளை பட்ஜெட்களாகவும் நுண்ணறிவுகளாகவும் மாற்றுகின்றன. மிகப் பொருத்தமான வகையைத் தட்டுங்கள்.',
      );
  String get tutSaveTagTitle =>
      _t('Now save it', 'अब सहेजें', 'आता जतन करा', 'এবার সেভ করুন', 'ఇప్పుడు దాన్ని సేవ్ చేయండి', 'இப்போது அதைச் சேமியுங்கள்');
  String get tutSaveTagBody => _t(
        'Nice pick! Hit Save to apply your tag.',
        'बढ़िया चुनाव! टैग लागू करने के लिए Save दबाएँ।',
        'छान निवड! टॅग लागू करण्यासाठी Save दाबा.',
        'দারুণ পছন্দ! ট্যাগ প্রয়োগ করতে Save চাপুন।',
        'మంచి ఎంపిక! మీ ట్యాగ్‌ను వర్తింపజేయడానికి Save నొక్కండి.',
        'நல்ல தேர்வு! உங்கள் குறிச்சொல்லைப் பயன்படுத்த Save அழுத்துங்கள்.',
      );
  String get tutApplyBody => _t(
        'Budgetify found more transactions from this payee. Each choice below decides how far your tag reaches — all of them (past and future), only the existing ones, or just this single transaction. Read each and pick.',
        'Budgetify को इसी प्राप्तकर्ता के और लेन-देन मिले। नीचे का हर विकल्प तय करता है कि आपका टैग कहाँ तक जाए — सभी (पिछले और आगे के), केवल मौजूदा, या सिर्फ़ यही एक। पढ़कर चुनें।',
        'Budgetify ला याच प्राप्तकर्त्याचे आणखी व्यवहार सापडले. खालील प्रत्येक पर्याय ठरवतो की तुमचा टॅग कुठवर पोहोचेल — सर्व (मागील व पुढील), फक्त विद्यमान, की फक्त हाच एक. वाचून निवडा.',
        'Budgetify এই প্রাপকের আরও লেনদেন পেয়েছে। নিচের প্রতিটি অপশন ঠিক করে আপনার ট্যাগ কতদূর যাবে — সবগুলো (আগের ও পরের), শুধু বিদ্যমানগুলো, নাকি শুধু এটিই। পড়ে বেছে নিন।',
        'ఈ చెల్లింపుదారు నుండి Budgetify మరిన్ని లావాదేవీలను కనుగొంది. దిగువ ప్రతి ఎంపిక మీ ట్యాగ్ ఎంత దూరం చేరుతుందో నిర్ణయిస్తుంది — అన్నీ (గతం మరియు భవిష్యత్తు), ప్రస్తుతమున్నవి మాత్రమే, లేదా ఈ ఒక్క లావాదేవీ మాత్రమే. ప్రతిదీ చదివి ఎంచుకోండి.',
        'இந்த பணம் பெறுநரிடமிருந்து Budgetify மேலும் பரிவர்த்தனைகளைக் கண்டறிந்தது. கீழே உள்ள ஒவ்வொரு தேர்வும் உங்கள் குறிச்சொல் எவ்வளவு தூரம் செல்கிறது என்பதைத் தீர்மானிக்கிறது — அனைத்தும் (கடந்த மற்றும் எதிர்காலம்), ஏற்கனவே உள்ளவை மட்டும், அல்லது இந்த ஒரே பரிவர்த்தனை மட்டும். ஒவ்வொன்றையும் படித்துத் தேர்ந்தெடுங்கள்.',
      );
  String get tutHealthTitle => _t('Your Financial Health',
      'आपकी फ़ाइनेंशियल हेल्थ', 'तुमची फायनान्शिअल हेल्थ', 'আপনার ফাইন্যান্সিয়াল হেলথ', 'మీ ఆర్థిక ఆరోగ్యం', 'உங்கள் நிதி ஆரோக்கியம்');
  String get tutHealthBody => _t(
        "Tag done — you're officially tracking! This card carries your balance and a 0–100 health score blending savings, budgets, recurring load and net worth. The full breakdown can be enabled in Settings → Intelligence.",
        'टैग हो गया — ट्रैकिंग शुरू! इस कार्ड पर आपका बैलेंस और 0–100 हेल्थ स्कोर है, जो बचत, बजट, आवर्ती खर्च और नेट वर्थ को मिलाकर बनता है। पूरा ब्रेकडाउन Settings → Intelligence से चालू करें।',
        'टॅग झाला — ट्रॅकिंग सुरू! या कार्डावर तुमचा बॅलन्स आणि 0–100 हेल्थ स्कोअर आहे — बचत, बजेट, आवर्ती खर्च व नेट वर्थ मिळून. सविस्तर ब्रेकडाउन Settings → Intelligence मधून सुरू करा.',
        'ট্যাগ হয়ে গেছে — ট্র্যাকিং শুরু! এই কার্ডে আপনার ব্যালান্স আর ০–১০০ হেলথ স্কোর আছে — সঞ্চয়, বাজেট, পুনরাবৃত্ত খরচ ও নেট ওয়ার্থ মিলিয়ে। পূর্ণ ব্রেকডাউন Settings → Intelligence থেকে চালু করুন।',
        'ట్యాగ్ పూర్తయింది — మీరు అధికారికంగా ట్రాక్ చేస్తున్నారు! ఈ కార్డ్ మీ బ్యాలెన్స్ మరియు పొదుపు, బడ్జెట్‌లు, పునరావృత భారం మరియు నెట్ వర్త్‌ను మిళితం చేసే 0–100 ఆరోగ్య స్కోర్‌ను కలిగి ఉంటుంది. పూర్తి విభజనను Settings → Intelligence లో ప్రారంభించవచ్చు.',
        'குறிச்சொல் முடிந்தது — நீங்கள் அதிகாரப்பூர்வமாகக் கண்காணிக்கிறீர்கள்! இந்த அட்டை உங்கள் இருப்பையும் சேமிப்பு, பட்ஜெட்கள், தொடர் சுமை மற்றும் நிகர மதிப்பைக் கலந்த 0–100 ஆரோக்கிய மதிப்பெண்ணையும் கொண்டுள்ளது. முழு விவரத்தை Settings → Intelligence இல் இயக்கலாம்.',
      );
  String get tutGoalsTitle => _t(
      'Savings Goals', 'सेविंग गोल', 'बचत उद्दिष्टे', 'সঞ্চয়ের লক্ষ্য', 'పొదుపు లక్ష్యాలు', 'சேமிப்பு இலக்குகள்');
  String get tutGoalsBody => _t(
        'Set a target — a trip, a phone — add to it as you go, and watch the jar fill up.',
        'कोई लक्ष्य रखें — कोई यात्रा, कोई फ़ोन — धीरे-धीरे जोड़ते रहें और जार भरता देखें।',
        'एखादे उद्दिष्ट ठेवा — सहल, फोन — हळूहळू भर घालत राहा आणि बरणी भरताना पाहा.',
        'একটা লক্ষ্য রাখুন — কোনো ভ্রমণ, কোনো ফোন — অল্প অল্প করে জমান আর জারটা ভরে উঠতে দেখুন।',
        'ఒక లక్ష్యాన్ని సెట్ చేయండి — ఒక ట్రిప్, ఒక ఫోన్ — మీరు వెళ్తున్న కొద్దీ దానికి జోడించండి, మరియు జార్ నిండటాన్ని చూడండి.',
        'ஒரு இலக்கை அமையுங்கள் — ஒரு பயணம், ஒரு ஃபோன் — நீங்கள் செல்லும்போது அதில் சேருங்கள், மேலும் ஜாடி நிரம்புவதைப் பாருங்கள்.',
      );
  String get tutTapTabBody => _t(
        'Tap the highlighted tab below to open it.',
        'नीचे हाइलाइट किए गए टैब पर टैप करके खोलें।',
        'खाली हायलाइट केलेल्या टॅबवर टॅप करून उघडा.',
        'নিচে হাইলাইট করা ট্যাবে ট্যাপ করে খুলুন।',
        'దాన్ని తెరవడానికి దిగువ హైలైట్ చేసిన ట్యాబ్‌పై ట్యాప్ చేయండి.',
        'அதைத் திறக்க கீழே சிறப்பிக்கப்பட்ட தாவலைத் தட்டுங்கள்.',
      );
  String get tutBudgetsTitle => _t('Budgets live here',
      'बजट यहाँ रहते हैं', 'बजेट इथे असतात', 'বাজেট থাকে এখানে', 'బడ్జెట్‌లు ఇక్కడ ఉంటాయి', 'பட்ஜெட்கள் இங்கே இருக்கின்றன');
  String get tutBudgetsIntroTitle => _t('Set your monthly budget',
      'मासिक बजट सेट करें', 'मासिक बजेट सेट करा', 'মাসিক বাজেট ঠিক করুন', 'మీ నెలవారీ బడ్జెట్‌ను సెట్ చేయండి', 'உங்கள் மாதாந்திர பட்ஜெட்டை அமையுங்கள்');
  String get tutBudgetsIntroBody => _t(
        "This button sets (or edits) the month's overall limit — the Overview gauge then paces your spending against it. Tap the highlighted button to see how it works; nothing will be saved.",
        'यह बटन महीने की कुल सीमा तय करता (या बदलता) है — फिर ओवरव्यू गेज उसी के मुकाबले आपकी रफ़्तार नापता है। यह कैसे काम करता है देखने के लिए हाइलाइट किए गए बटन पर टैप करें; कुछ सहेजा नहीं जाएगा।',
        'हे बटण महिन्याची एकूण मर्यादा ठरवते (किंवा बदलते) — मग ओव्हरव्ह्यू गेज त्याच्या तुलनेत तुमची गती मोजते. हे कसे चालते ते पाहण्यासाठी हायलाइट केलेल्या बटणावर टॅप करा; काहीही जतन होणार नाही.',
        'এই বোতামটি মাসের মোট সীমা ঠিক করে (বা বদলায়) — তারপর ওভারভিউ গেজ তার সাপেক্ষে আপনার গতি মাপে। কীভাবে কাজ করে দেখতে হাইলাইট করা বোতামে ট্যাপ করুন; কিছুই সেভ হবে না।',
        'ఈ బటన్ నెల మొత్తం పరిమితిని సెట్ చేస్తుంది (లేదా సవరిస్తుంది) — తర్వాత ఓవర్‌వ్యూ గేజ్ దానికి వ్యతిరేకంగా మీ ఖర్చును కొలుస్తుంది. ఇది ఎలా పనిచేస్తుందో చూడటానికి హైలైట్ చేసిన బటన్‌పై ట్యాప్ చేయండి; ఏదీ సేవ్ చేయబడదు.',
        'இந்த பொத்தான் மாதத்தின் மொத்த வரம்பை அமைக்கிறது (அல்லது திருத்துகிறது) — பிறகு கண்ணோட்ட அளவி அதற்கு எதிராக உங்கள் செலவை அளவிடுகிறது. இது எப்படி வேலை செய்கிறது என்பதைப் பார்க்க சிறப்பிக்கப்பட்ட பொத்தானைத் தட்டுங்கள்; எதுவும் சேமிக்கப்படாது.',
      );
  String get tutBudgetDialogBanner => _t(
        "Name the budget and enter the month's total amount — Save would start the Overview gauge pacing you against it, with a nudge before you overshoot. Just exploring — tap Cancel for now.",
        'बजट का नाम रखें और महीने की कुल राशि भरें — Save करते ही ओवरव्यू गेज उसके मुकाबले आपकी रफ़्तार नापने लगता है, और सीमा पार होने से पहले आगाह करता है। अभी सिर्फ़ देख रहे हैं — फ़िलहाल Cancel दबाएँ।',
        'बजेटला नाव द्या आणि महिन्याची एकूण रक्कम भरा — Save करताच ओव्हरव्ह्यू गेज त्याच्या तुलनेत तुमची गती मोजू लागते, आणि मर्यादा ओलांडण्यापूर्वी सुचवते. सध्या फक्त पाहत आहोत — आत्ता Cancel दाबा.',
        'বাজেটের নাম দিন আর মাসের মোট পরিমাণ লিখুন — Save করলেই ওভারভিউ গেজ তার সাপেক্ষে আপনার গতি মাপতে শুরু করে, আর সীমা ছাড়ানোর আগে সতর্ক করে। এখন শুধু দেখছেন — আপাতত Cancel চাপুন।',
        'బడ్జెట్‌కు పేరు పెట్టి నెల మొత్తం సొమ్మును నమోదు చేయండి — Save చేస్తే ఓవర్‌వ్యూ గేజ్ దానికి వ్యతిరేకంగా మిమ్మల్ని కొలవడం ప్రారంభిస్తుంది, మీరు మించే ముందు ఒక సూచనతో. ఇప్పుడు కేవలం చూస్తున్నారు — ప్రస్తుతానికి Cancel నొక్కండి.',
        'பட்ஜெட்டுக்குப் பெயரிட்டு மாதத்தின் மொத்த தொகையை உள்ளிடுங்கள் — Save செய்தால் கண்ணோட்ட அளவி அதற்கு எதிராக உங்களை அளவிடத் தொடங்கும், நீங்கள் மீறுவதற்கு முன் ஒரு நினைவூட்டலுடன். இப்போது வெறும் பார்க்கிறீர்கள் — தற்போதைக்கு Cancel தட்டுங்கள்.',
      );
  String get tutBudgetsHeatmapTitle => _t('The spending heatmap',
      'खर्च का हीटमैप', 'खर्चाचा हीटमॅप', 'খরচের হিটম্যাপ', 'ఖర్చు హీట్‌మ్యాప్', 'செலவு ஹீட்மேப்');
  String get tutBudgetsHeatmapBody => _t(
        "Each square is one day of the month — the deeper its shade, the heavier that day's spending. Spot expensive days and quiet stretches at a glance; tap any day for its transactions.",
        'हर वर्ग महीने का एक दिन है — रंग जितना गहरा, उस दिन का खर्च उतना ज़्यादा। महँगे दिन और शांत दौर एक नज़र में पहचानें; किसी दिन के लेन-देन देखने के लिए उस पर टैप करें।',
        'प्रत्येक चौकोन म्हणजे महिन्याचा एक दिवस — रंग जितका गडद, त्या दिवसाचा खर्च तितका जास्त. महागडे दिवस आणि शांत काळ एका नजरेत ओळखा; कोणत्याही दिवसाचे व्यवहार पाहण्यासाठी त्यावर टॅप करा.',
        'প্রতিটি ঘর মাসের এক-একটি দিন — রং যত গাঢ়, সেই দিনের খরচ তত বেশি। ব্যয়বহুল দিন আর শান্ত সময় এক নজরে চিনুন; কোনো দিনের লেনদেন দেখতে তাতে ট্যাপ করুন।',
        'ప్రతి చతురస్రం నెలలోని ఒక రోజు — దాని ఛాయ ఎంత లోతుగా ఉంటే, ఆ రోజు ఖర్చు అంత ఎక్కువ. ఖరీదైన రోజులు మరియు ప్రశాంతమైన కాలాలను ఒక్క చూపులో గుర్తించండి; ఏ రోజు లావాదేవీల కోసమైనా దానిపై ట్యాప్ చేయండి.',
        'ஒவ்வொரு சதுரமும் மாதத்தின் ஒரு நாள் — அதன் நிழல் எவ்வளவு அடர்த்தியாக இருக்கிறதோ, அந்த நாளின் செலவு அவ்வளவு அதிகம். விலையுயர்ந்த நாட்களையும் அமைதியான காலங்களையும் ஒரே பார்வையில் கண்டறியுங்கள்; எந்த நாளின் பரிவர்த்தனைகளுக்கும் அதைத் தட்டுங்கள்.',
      );
  String get tutBudgetsCategoriesTitle => _t('Category budgets',
      'श्रेणी बजट', 'श्रेणी बजेट', 'ক্যাটাগরি বাজেট', 'వర్గ బడ్జెట్‌లు', 'வகை பட்ஜெட்கள்');
  String get tutBudgetsCategoriesBody => _t(
        'Each category can carry its own cap — food, travel, shopping. Tap "Set budget" in the highlighted section to see how one is created; nothing will be saved.',
        'हर श्रेणी की अपनी सीमा हो सकती है — खाना, यात्रा, शॉपिंग। कैसे बनती है देखने के लिए हाइलाइट किए गए हिस्से में "Set budget" पर टैप करें; कुछ सहेजा नहीं जाएगा।',
        'प्रत्येक श्रेणीची स्वतःची मर्यादा असू शकते — जेवण, प्रवास, खरेदी. कशी तयार होते ते पाहण्यासाठी हायलाइट केलेल्या भागात "Set budget" वर टॅप करा; काहीही जतन होणार नाही.',
        'প্রতিটি ক্যাটাগরির নিজস্ব সীমা থাকতে পারে — খাবার, ভ্রমণ, কেনাকাটা। কীভাবে তৈরি হয় দেখতে হাইলাইট করা অংশে "Set budget"-এ ট্যাপ করুন; কিছুই সেভ হবে না।',
        'ప్రతి వర్గం దాని స్వంత పరిమితిని కలిగి ఉంటుంది — ఆహారం, ప్రయాణం, షాపింగ్. ఒకటి ఎలా సృష్టించబడుతుందో చూడటానికి హైలైట్ చేసిన విభాగంలో "Set budget" పై ట్యాప్ చేయండి; ఏదీ సేవ్ చేయబడదు.',
        'ஒவ்வொரு வகைக்கும் அதன் சொந்த வரம்பு இருக்கலாம் — உணவு, பயணம், ஷாப்பிங். ஒன்று எப்படி உருவாக்கப்படுகிறது என்பதைப் பார்க்க சிறப்பிக்கப்பட்ட பகுதியில் "Set budget" ஐத் தட்டுங்கள்; எதுவும் சேமிக்கப்படாது.',
      );
  String get tutCategoryBudgetBanner => _t(
        'Pick the category below and give it a monthly cap — its bar on the Budgets tab then fills as the month progresses, with a nudge as you near the limit. Just exploring — tap Cancel for now.',
        'नीचे श्रेणी चुनें और उसे मासिक सीमा दें — फिर Budgets टैब पर उसकी पट्टी महीने के साथ भरती जाती है, और सीमा के पास पहुँचने पर आगाह किया जाता है। अभी सिर्फ़ देख रहे हैं — फ़िलहाल Cancel दबाएँ।',
        'खाली श्रेणी निवडा आणि तिला मासिक मर्यादा द्या — मग Budgets टॅबवर तिची पट्टी महिन्याबरोबर भरत जाते, आणि मर्यादेजवळ पोहोचल्यावर सूचना मिळते. सध्या फक्त पाहत आहोत — आत्ता Cancel दाबा.',
        'নিচে ক্যাটাগরি বাছুন আর তাকে মাসিক সীমা দিন — তারপর Budgets ট্যাবে তার বার মাসের সাথে ভরে ওঠে, সীমার কাছে গেলে সতর্কতা পাবেন। এখন শুধু দেখছেন — আপাতত Cancel চাপুন।',
        'దిగువ వర్గాన్ని ఎంచుకుని దానికి నెలవారీ పరిమితిని ఇవ్వండి — తర్వాత Budgets ట్యాబ్‌లో దాని బార్ నెల గడిచే కొద్దీ నిండుతుంది, మీరు పరిమితికి దగ్గరవుతున్నప్పుడు ఒక సూచనతో. ఇప్పుడు కేవలం చూస్తున్నారు — ప్రస్తుతానికి Cancel నొక్కండి.',
        'கீழே உள்ள வகையைத் தேர்ந்தெடுத்து அதற்கு ஒரு மாதாந்திர வரம்பைக் கொடுங்கள் — பிறகு Budgets தாவலில் அதன் பட்டை மாதம் முன்னேறும்போது நிரம்பும், நீங்கள் வரம்பை நெருங்கும்போது ஒரு நினைவூட்டலுடன். இப்போது வெறும் பார்க்கிறீர்கள் — தற்போதைக்கு Cancel தட்டுங்கள்.',
      );
  String get tutBudgetsTrendsTitle =>
      _t('Your trends', 'आपके ट्रेंड', 'तुमचे ट्रेंड', 'আপনার ট্রেন্ড', 'మీ ధోరణులు', 'உங்கள் போக்குகள்');
  String get tutBudgetsTrendsBody => _t(
        'Months side by side — switch between bars and a line, and expand any month below for its category split. Watch whether spending is rising or cooling.',
        'महीने आमने-सामने — बार और लाइन के बीच बदलें, और नीचे किसी भी महीने को उसकी श्रेणी-वार जानकारी के लिए खोलें। देखें कि खर्च बढ़ रहा है या घट रहा है।',
        'महिने शेजारी-शेजारी — बार आणि लाइनमध्ये बदला, आणि खाली कोणताही महिना त्याच्या श्रेणी-विभाजनासाठी उघडा. खर्च वाढतोय की कमी होतोय ते पाहा.',
        'মাসগুলো পাশাপাশি — বার আর লাইনের মধ্যে বদলান, আর নিচে যেকোনো মাস খুলে তার ক্যাটাগরি-ভাগ দেখুন। খরচ বাড়ছে না কমছে, নজরে রাখুন।',
        'నెలలు పక్కపక్కన — బార్‌లు మరియు లైన్ మధ్య మారండి, మరియు దాని వర్గ విభజన కోసం దిగువ ఏ నెలనైనా విస్తరించండి. ఖర్చు పెరుగుతోందా లేదా తగ్గుతోందా గమనించండి.',
        'மாதங்கள் அருகருகே — பட்டைகளுக்கும் ஒரு கோட்டுக்கும் இடையே மாறுங்கள், மேலும் அதன் வகைப் பிரிப்புக்காக கீழே எந்த மாதத்தையும் விரிவாக்குங்கள். செலவு உயர்கிறதா அல்லது குறைகிறதா என்பதைக் கவனியுங்கள்.',
      );
  String get tutRecurringTabTitle => _t('Next: Recurring', 'अगला: आवर्ती',
      'पुढे: आवर्ती', 'এরপর: পুনরাবৃত্ত', 'తదుపరి: పునరావృతం', 'அடுத்து: தொடர்');
  String get tutRecurringIntroTitle => _t(
        'Never miss a due date',
        'कोई देय तारीख न छूटे',
        'कोणतीही देय तारीख चुकणार नाही',
        'কোনো নির্ধারিত তারিখ মিস নয়',
        'ఏ గడువు తేదీని కోల్పోకండి',
        'எந்த கெடு தேதியையும் தவறவிடாதீர்கள்',
      );
  String get tutRecurringIntroBody => _t(
        'Track SIPs, rent, EMIs and subscriptions here — Budgetify reminds you when they fall due and logs them once paid.',
        'SIP, किराया, EMI और सब्सक्रिप्शन यहाँ ट्रैक करें — देय होने पर Budgetify याद दिलाता है और भुगतान होते ही दर्ज करता है।',
        'SIP, भाडे, EMI आणि सबस्क्रिप्शन येथे ट्रॅक करा — देय झाल्यावर Budgetify आठवण करून देते आणि भरल्यावर नोंदवते.',
        'SIP, ভাড়া, EMI ও সাবস্ক্রিপশন এখানে ট্র্যাক করুন — নির্ধারিত হলে Budgetify মনে করিয়ে দেয় আর পরিশোধ হলে লিখে রাখে।',
        'SIPలు, అద్దె, EMIలు మరియు సబ్‌స్క్రిప్షన్‌లను ఇక్కడ ట్రాక్ చేయండి — గడువు వచ్చినప్పుడు Budgetify మీకు గుర్తు చేస్తుంది మరియు చెల్లించిన తర్వాత వాటిని నమోదు చేస్తుంది.',
        'SIPகள், வாடகை, EMIகள் மற்றும் சந்தாக்களை இங்கே கண்காணியுங்கள் — கெடு வரும்போது Budgetify உங்களுக்கு நினைவூட்டுகிறது, செலுத்திய பிறகு அவற்றைப் பதிவு செய்கிறது.',
      );
  String get tutRecurringAddTitle => _t('See how one is set up',
      'देखें कैसे जुड़ता है', 'कसे जोडायचे ते पाहा', 'কীভাবে যোগ হয় দেখুন', 'ఒకటి ఎలా సెటప్ చేయబడుతుందో చూడండి', 'ஒன்று எப்படி அமைக்கப்படுகிறது என்பதைப் பாருங்கள்');
  String get tutRecurringAddBody => _t(
        'Tap the highlighted Add button — just to look around, nothing will be saved.',
        'हाइलाइट किए गए Add बटन पर टैप करें — बस देखने के लिए, कुछ सहेजा नहीं जाएगा।',
        'हायलाइट केलेल्या Add बटणावर टॅप करा — फक्त पाहण्यासाठी, काहीही जतन होणार नाही.',
        'হাইলাইট করা Add বোতামে ট্যাপ করুন — শুধু দেখার জন্য, কিছুই সেভ হবে না।',
        'హైలైట్ చేసిన Add బటన్‌పై ట్యాప్ చేయండి — కేవలం చూడటానికి, ఏదీ సేవ్ చేయబడదు.',
        'சிறப்பிக்கப்பட்ட Add பொத்தானைத் தட்டுங்கள் — வெறும் பார்வைக்காக, எதுவும் சேமிக்கப்படாது.',
      );
  String get tutRecurringEditorBanner => _t(
        'Name the plan, set its amount (or mark it as varying), pick the cadence — weekly, monthly, EMI months — and the next due date. Budgetify reminds you before each due date and logs matching payments automatically. Just exploring for now — swipe this sheet down to close without saving.',
        'प्लान का नाम रखें, राशि तय करें (या बदलती राशि चुनें), दोहराव चुनें — साप्ताहिक, मासिक, EMI महीने — और अगली देय तारीख। हर देय तारीख से पहले Budgetify याद दिलाता है और मेल खाते भुगतान अपने आप दर्ज करता है। अभी सिर्फ़ देख रहे हैं — बिना सहेजे बंद करने के लिए इस शीट को नीचे स्वाइप करें।',
        'प्लॅनला नाव द्या, रक्कम ठरवा (किंवा बदलती रक्कम निवडा), पुनरावृत्ती निवडा — साप्ताहिक, मासिक, EMI महिने — आणि पुढील देय तारीख. प्रत्येक देय तारखेपूर्वी Budgetify आठवण करून देते आणि जुळणारी देयके आपोआप नोंदवते. सध्या फक्त पाहत आहोत — न जतन करता बंद करण्यासाठी ही शीट खाली स्वाइप करा.',
        'প্ল্যানের নাম দিন, পরিমাণ ঠিক করুন (বা পরিবর্তনশীল চিহ্নিত করুন), পুনরাবৃত্তি বাছুন — সাপ্তাহিক, মাসিক, EMI মাস — আর পরের নির্ধারিত তারিখ। প্রতি নির্ধারিত তারিখের আগে Budgetify মনে করিয়ে দেয় আর মিলে যাওয়া পেমেন্ট নিজে থেকে লিখে রাখে। এখন শুধু দেখছেন — সেভ না করে বন্ধ করতে শিটটি নিচে সোয়াইপ করুন।',
        'ప్లాన్‌కు పేరు పెట్టండి, దాని మొత్తాన్ని సెట్ చేయండి (లేదా మారుతున్నట్లు గుర్తించండి), వ్యవధిని ఎంచుకోండి — వారానికి, నెలవారీ, EMI నెలలు — మరియు తదుపరి గడువు తేదీ. ప్రతి గడువు తేదీకి ముందు Budgetify మీకు గుర్తు చేస్తుంది మరియు సరిపోలే చెల్లింపులను ఆటోమేటిక్‌గా నమోదు చేస్తుంది. ఇప్పుడు కేవలం చూస్తున్నారు — సేవ్ చేయకుండా మూసివేయడానికి ఈ షీట్‌ను కిందికి స్వైప్ చేయండి.',
        'திட்டத்திற்குப் பெயரிட்டு, அதன் தொகையை அமையுங்கள் (அல்லது மாறுவதாகக் குறியிடுங்கள்), இடைவெளியைத் தேர்ந்தெடுங்கள் — வாராந்திரம், மாதாந்திரம், EMI மாதங்கள் — மற்றும் அடுத்த கெடு தேதி. ஒவ்வொரு கெடு தேதிக்கும் முன் Budgetify உங்களுக்கு நினைவூட்டுகிறது, பொருந்தும் கட்டணங்களைத் தானாகப் பதிவு செய்கிறது. இப்போது வெறும் பார்க்கிறீர்கள் — சேமிக்காமல் மூட இந்த தாளைக் கீழே ஸ்வைப் செய்யுங்கள்.',
      );
  String get tutInvestTitle => _t('Investments & net worth',
      'निवेश और नेट वर्थ', 'गुंतवणूक व नेट वर्थ', 'বিনিয়োগ ও নেট ওয়ার্থ', 'పెట్టుబడులు & నెట్ వర్త్', 'முதலீடுகள் & நிகர மதிப்பு');
  String get tutInvestIntroTitle => _t(
        'Your whole wealth picture',
        'आपकी पूरी संपत्ति की तस्वीर',
        'तुमच्या संपत्तीचे संपूर्ण चित्र',
        'আপনার সম্পদের পূর্ণ চিত্র',
        'మీ మొత్తం సంపద చిత్రం',
        'உங்கள் முழு செல்வ சித்திரம்',
      );
  String get tutInvestIntroBody => _t(
        'Track FDs, mutual funds, gold, stocks and loans here — assets minus liabilities, fully offline.',
        'यहाँ FD, म्यूचुअल फ़ंड, सोना, शेयर और लोन ट्रैक करें — संपत्ति में से देनदारियाँ, पूरी तरह ऑफ़लाइन।',
        'येथे FD, म्युच्युअल फंड, सोने, शेअर्स व कर्जे ट्रॅक करा — मालमत्ता वजा देणी, पूर्णपणे ऑफलाइन.',
        'এখানে FD, মিউচুয়াল ফান্ড, সোনা, শেয়ার ও ঋণ ট্র্যাক করুন — সম্পদ বিয়োগ দায়, সম্পূর্ণ অফলাইনে।',
        'FDలు, మ్యూచువల్ ఫండ్‌లు, బంగారం, స్టాక్‌లు మరియు రుణాలను ఇక్కడ ట్రాక్ చేయండి — ఆస్తులు మైనస్ అప్పులు, పూర్తిగా ఆఫ్‌లైన్‌లో.',
        'FDகள், மியூச்சுவல் ஃபண்டுகள், தங்கம், பங்குகள் மற்றும் கடன்களை இங்கே கண்காணியுங்கள் — சொத்துகள் கழித்தல் கடன்கள், முழுவதும் ஆஃப்லைனில்.',
      );
  String get tutInvestAddTitle => _t('See how holdings go in',
      'देखें कैसे जुड़ते हैं', 'कशी नोंद होते ते पाहा', 'কীভাবে যোগ হয় দেখুন', 'హోల్డింగ్‌లు ఎలా జోడించబడతాయో చూడండి', 'ஹோல்டிங்குகள் எப்படிச் சேர்க்கப்படுகின்றன என்பதைப் பாருங்கள்');
  String get tutInvestAddBody => _t(
        'Tap the highlighted Add button — just to look around, nothing will be saved.',
        'हाइलाइट किए गए Add बटन पर टैप करें — बस देखने के लिए, कुछ सहेजा नहीं जाएगा।',
        'हायलाइट केलेल्या Add बटणावर टॅप करा — फक्त पाहण्यासाठी, काहीही जतन होणार नाही.',
        'হাইলাইট করা Add বোতামে ট্যাপ করুন — শুধু দেখার জন্য, কিছুই সেভ হবে না।',
        'హైలైట్ చేసిన Add బటన్‌పై ట్యాప్ చేయండి — కేవలం చూడటానికి, ఏదీ సేవ్ చేయబడదు.',
        'சிறப்பிக்கப்பட்ட Add பொத்தானைத் தட்டுங்கள் — வெறும் பார்வைக்காக, எதுவும் சேமிக்கப்படாது.',
      );
  String get tutInvestEditorBanner => _t(
        'Pick Asset or Liability, then a type. An FD is a one-time deposit; RD, SIP and other recurring types open a schedule — give them a date and Budgetify sends a reminder for every instalment. Loans and card dues go under Liability and subtract from your net worth. Just exploring — tap Cancel to close without saving.',
        'Asset या Liability चुनें, फिर प्रकार। FD एकमुश्त जमा है; RD, SIP और अन्य आवर्ती प्रकारों में शेड्यूल खुलता है — तारीख़ दें और Budgetify हर किस्त की याद दिलाता है। लोन और कार्ड बकाया Liability में जाते हैं और नेट वर्थ से घटते हैं। अभी सिर्फ़ देख रहे हैं — बिना सहेजे बंद करने के लिए Cancel दबाएँ।',
        'Asset किंवा Liability निवडा, मग प्रकार. FD म्हणजे एकरकमी ठेव; RD, SIP आणि इतर आवर्ती प्रकारांत वेळापत्रक उघडते — तारीख द्या आणि Budgetify प्रत्येक हप्त्याची आठवण पाठवते. कर्जे व कार्ड थकबाकी Liability मध्ये जातात आणि नेट वर्थमधून वजा होतात. सध्या फक्त पाहत आहोत — न जतन करता बंद करण्यासाठी Cancel दाबा.',
        'Asset বা Liability বাছুন, তারপর ধরন। FD এককালীন জমা; RD, SIP ও অন্য পুনরাবৃত্ত ধরনে একটি সূচি খোলে — তারিখ দিন আর Budgetify প্রতিটি কিস্তির জন্য মনে করিয়ে দেয়। ঋণ ও কার্ডের বকেয়া Liability-তে যায় আর নেট ওয়ার্থ থেকে বাদ পড়ে। এখন শুধু দেখছেন — সেভ না করে বন্ধ করতে Cancel চাপুন।',
        'Asset లేదా Liability ఎంచుకోండి, తర్వాత ఒక రకం. FD అనేది ఒక్కసారి డిపాజిట్; RD, SIP మరియు ఇతర పునరావృత రకాలు ఒక షెడ్యూల్‌ను తెరుస్తాయి — వాటికి ఒక తేదీ ఇవ్వండి మరియు Budgetify ప్రతి వాయిదాకు గుర్తు పంపుతుంది. రుణాలు మరియు కార్డ్ బకాయిలు Liability కింద వెళ్తాయి మరియు మీ నెట్ వర్త్ నుండి తీసివేయబడతాయి. ఇప్పుడు కేవలం చూస్తున్నారు — సేవ్ చేయకుండా మూసివేయడానికి Cancel నొక్కండి.',
        'Asset அல்லது Liability ஐத் தேர்ந்தெடுங்கள், பிறகு ஒரு வகை. FD என்பது ஒரு முறை வைப்பு; RD, SIP மற்றும் பிற தொடர் வகைகள் ஒரு அட்டவணையைத் திறக்கின்றன — அவற்றுக்கு ஒரு தேதியைக் கொடுங்கள், Budgetify ஒவ்வொரு தவணைக்கும் ஒரு நினைவூட்டலை அனுப்புகிறது. கடன்கள் மற்றும் கார்டு நிலுவைகள் Liability இன் கீழ் சென்று உங்கள் நிகர மதிப்பிலிருந்து கழிக்கப்படுகின்றன. இப்போது வெறும் பார்க்கிறீர்கள் — சேமிக்காமல் மூட Cancel தட்டுங்கள்.',
      );
  String get tutSettingsTabTitle => _t('One last stop: Settings',
      'आख़िरी पड़ाव: सेटिंग्स', 'शेवटचा थांबा: सेटिंग्ज', 'শেষ গন্তব্য: সেটিংস', 'చివరి మజిలీ: సెట్టింగ్స్', 'கடைசி நிறுத்தம்: அமைப்புகள்');
  String get tutSettingsAiTitle => _t('AI Prediction Mode',
      'AI प्रेडिक्शन मोड', 'AI प्रेडिक्शन मोड', 'AI প্রেডিকশন মোড', 'AI అంచనా మోడ్', 'AI முன்கணிப்பு பயன்முறை');
  String get tutSettingsAiBody => _t(
        'A fully on-device forecast: your spending pace, the projected month-end total and which categories moved most — nothing ever leaves your phone. Turn it on any time and Budgetify slides Home to show you the new Insights card.',
        'पूरी तरह फ़ोन पर चलने वाला पूर्वानुमान: आपकी खर्च की रफ़्तार, महीने के अंत का अनुमानित कुल और सबसे ज़्यादा बदली श्रेणियाँ — कुछ भी फ़ोन से बाहर नहीं जाता। कभी भी ऑन करें, Budgetify होम पर ले जाकर नया Insights कार्ड दिखाता है।',
        'पूर्णपणे फोनवर चालणारा अंदाज: तुमची खर्चाची गती, महिनाअखेरीचा अंदाजित एकूण आणि सर्वांत जास्त बदललेल्या श्रेणी — काहीही फोनबाहेर जात नाही. केव्हाही सुरू करा, Budgetify होमवर नेऊन नवे Insights कार्ड दाखवते.',
        'সম্পূর্ণ ফোনে চলা পূর্বাভাস: আপনার খরচের গতি, মাস-শেষের আনুমানিক মোট আর সবচেয়ে বেশি বদলানো ক্যাটাগরি — কিছুই ফোনের বাইরে যায় না। যেকোনো সময় চালু করুন, Budgetify হোমে নিয়ে গিয়ে নতুন Insights কার্ড দেখায়।',
        'పూర్తిగా ఆన్-డివైస్ అంచనా: మీ ఖర్చు వేగం, అంచనా వేసిన నెల-చివరి మొత్తం మరియు ఏ వర్గాలు ఎక్కువగా మారాయి — ఏదీ మీ ఫోన్ నుండి బయటకు వెళ్లదు. దీన్ని ఎప్పుడైనా ఆన్ చేయండి మరియు Budgetify హోమ్‌కు జారి కొత్త Insights కార్డును చూపిస్తుంది.',
        'முழுவதும் சாதனத்தில் இயங்கும் முன்கணிப்பு: உங்கள் செலவு வேகம், கணிக்கப்பட்ட மாத-இறுதி மொத்தம் மற்றும் எந்த வகைகள் அதிகம் மாறின — எதுவும் உங்கள் ஃபோனை விட்டு வெளியேறாது. இதை எப்போது வேண்டுமானாலும் இயக்குங்கள், Budgetify முகப்புக்குச் சென்று புதிய Insights அட்டையைக் காட்டும்.',
      );
  String get tutSettingsHealthTitle => _t('Detailed Financial Health',
      'विस्तृत फ़ाइनेंशियल हेल्थ', 'सविस्तर फायनान्शिअल हेल्थ', 'বিস্তারিত ফাইন্যান্সিয়াল হেলথ', 'వివరణాత్మక ఆర్థిక ఆరోగ్యం', 'விரிவான நிதி ஆரோக்கியம்');
  String get tutSettingsHealthBody => _t(
        'Your 0–100 score blends savings rate, budget adherence, recurring load and net worth. This switch expands the compact score on the balance card into a full breakdown card — turn it on and Budgetify slides Home to reveal it.',
        'आपका 0–100 स्कोर बचत दर, बजट पालन, आवर्ती खर्च और नेट वर्थ को मिलाकर बनता है। यह स्विच बैलेंस कार्ड के छोटे स्कोर को पूरे ब्रेकडाउन कार्ड में बदल देता है — ऑन करें, Budgetify होम पर ले जाकर दिखाता है।',
        'तुमचा 0–100 स्कोअर बचत दर, बजेट पालन, आवर्ती खर्च आणि नेट वर्थ मिळून बनतो. हे स्विच बॅलन्स कार्डावरील छोट्या स्कोअरला संपूर्ण ब्रेकडाउन कार्डात बदलते — सुरू करा, Budgetify होमवर नेऊन दाखवते.',
        'আপনার ০–১০০ স্কোর সঞ্চয়ের হার, বাজেট মানা, পুনরাবৃত্ত খরচ আর নেট ওয়ার্থ মিলিয়ে তৈরি। এই সুইচ ব্যালান্স কার্ডের ছোট স্কোরকে পূর্ণ ব্রেকডাউন কার্ডে বদলে দেয় — চালু করুন, Budgetify হোমে নিয়ে গিয়ে দেখায়।',
        'మీ 0–100 స్కోర్ పొదుపు రేటు, బడ్జెట్ పాటించడం, పునరావృత భారం మరియు నెట్ వర్త్‌ను మిళితం చేస్తుంది. ఈ స్విచ్ బ్యాలెన్స్ కార్డ్‌పై ఉన్న కాంపాక్ట్ స్కోర్‌ను పూర్తి విభజన కార్డుగా విస్తరిస్తుంది — దీన్ని ఆన్ చేయండి మరియు Budgetify హోమ్‌కు జారి దాన్ని చూపిస్తుంది.',
        'உங்கள் 0–100 மதிப்பெண் சேமிப்பு விகிதம், பட்ஜெட் கடைப்பிடிப்பு, தொடர் சுமை மற்றும் நிகர மதிப்பைக் கலக்கிறது. இந்த சுவிட்ச் இருப்பு அட்டையில் உள்ள சிறிய மதிப்பெண்ணை முழு விவர அட்டையாக விரிவாக்குகிறது — இதை இயக்குங்கள், Budgetify முகப்புக்குச் சென்று அதைக் காட்டும்.',
      );
  String get tutSettingsGamifiedTitle => _t('Gamified Budgets',
      'गेमिफ़ाइड बजट', 'गेमिफाइड बजेट', 'গেমিফাইড বাজেট', 'గేమిఫైడ్ బడ్జెట్‌లు', 'கேமிஃபைட் பட்ஜெட்கள்');
  String get tutSettingsGamifiedBody => _t(
        'Daily streaks, badge ladders, rare titles and a shareable profile — earned just by tracking, all offline. Enable it and your avatar appears top-right on Home; that avatar is the Rewards hub.',
        'रोज़ की स्ट्रीक, बैज लैडर, दुर्लभ खिताब और शेयर करने लायक प्रोफ़ाइल — सिर्फ़ ट्रैक करते रहने से, पूरी तरह ऑफ़लाइन। ऑन करें और होम पर ऊपर-दाएँ आपका अवतार दिखेगा; वही अवतार Rewards हब है।',
        'रोजची स्ट्रीक, बॅज शिड्या, दुर्मीळ किताब आणि शेअर करण्याजोगी प्रोफाइल — फक्त ट्रॅक करत राहिल्याने, पूर्णपणे ऑफलाइन. सुरू करा आणि होमवर वर-उजवीकडे तुमचा अवतार दिसेल; तोच अवतार Rewards हब आहे.',
        'দৈনিক স্ট্রিক, ব্যাজ ল্যাডার, বিরল খেতাব আর শেয়ার-যোগ্য প্রোফাইল — শুধু ট্র্যাক করলেই, সম্পূর্ণ অফলাইনে। চালু করুন, হোমের ওপরে ডানদিকে আপনার অবতার দেখা যাবে; সেই অবতারই Rewards হাব।',
        'రోజువారీ స్ట్రీక్‌లు, బ్యాడ్జ్ నిచ్చెనలు, అరుదైన బిరుదులు మరియు షేర్ చేయదగిన ప్రొఫైల్ — కేవలం ట్రాక్ చేయడం ద్వారానే సంపాదించబడతాయి, అన్నీ ఆఫ్‌లైన్‌లో. దీన్ని ప్రారంభించండి మరియు మీ అవతార్ హోమ్‌పై కుడి-పైన కనిపిస్తుంది; ఆ అవతారే Rewards హబ్.',
        'தினசரி ஸ்ட்ரீக்குகள், பேட்ஜ் ஏணிகள், அரிய பட்டங்கள் மற்றும் பகிரக்கூடிய சுயவிவரம் — வெறும் கண்காணிப்பதன் மூலமே சம்பாதிக்கப்படுகின்றன, அனைத்தும் ஆஃப்லைனில். இதை இயக்குங்கள், உங்கள் அவதாரம் முகப்பில் மேல்-வலதில் தோன்றும்; அந்த அவதாரமே Rewards ஹப்.',
      );
  String get tutSettingsDataTitle => _t('Your data, your control',
      'आपका डेटा, आपका नियंत्रण', 'तुमचा डेटा, तुमचे नियंत्रण', 'আপনার ডেটা, আপনার নিয়ন্ত্রণ', 'మీ డేటా, మీ నియంత్రణ', 'உங்கள் தரவு, உங்கள் கட்டுப்பாடு');
  String get tutSettingsDataBody => _t(
        'Encrypted backups (.bgfy) carry everything to a new phone. Below them: import bank statements or app exports, and export your data anytime as Excel, CSV, text or PDF.',
        'एन्क्रिप्टेड बैकअप (.bgfy) सब कुछ नए फ़ोन पर ले जाते हैं। इनके नीचे: बैंक स्टेटमेंट या ऐप एक्सपोर्ट इम्पोर्ट करें, और अपना डेटा कभी भी Excel, CSV, टेक्स्ट या PDF में एक्सपोर्ट करें।',
        'एन्क्रिप्टेड बॅकअप (.bgfy) सारे काही नव्या फोनवर नेतात. त्यांच्या खाली: बँक स्टेटमेंट किंवा अ‍ॅप एक्सपोर्ट इम्पोर्ट करा, आणि तुमचा डेटा केव्हाही Excel, CSV, मजकूर किंवा PDF मध्ये एक्सपोर्ट करा.',
        'এনক্রিপ্টেড ব্যাকআপ (.bgfy) সবকিছু নতুন ফোনে নিয়ে যায়। এর নিচে: ব্যাংক স্টেটমেন্ট বা অ্যাপ এক্সপোর্ট ইমপোর্ট করুন, আর আপনার ডেটা যেকোনো সময় Excel, CSV, টেক্সট বা PDF-এ এক্সপোর্ট করুন।',
        'ఎన్‌క్రిప్టెడ్ బ్యాకప్‌లు (.bgfy) అంతటినీ కొత్త ఫోన్‌కు తీసుకువెళ్తాయి. వాటి కింద: బ్యాంక్ స్టేట్‌మెంట్‌లు లేదా యాప్ ఎగుమతులను దిగుమతి చేయండి, మరియు మీ డేటాను ఎప్పుడైనా Excel, CSV, టెక్స్ట్ లేదా PDF గా ఎగుమతి చేయండి.',
        'மறையாக்கப்பட்ட காப்புப்பிரதிகள் (.bgfy) அனைத்தையும் புதிய ஃபோனுக்குக் கொண்டு செல்கின்றன. அவற்றுக்குக் கீழே: வங்கி அறிக்கைகள் அல்லது ஆப் ஏற்றுமதிகளை இறக்குமதி செய்யுங்கள், மேலும் உங்கள் தரவை எப்போது வேண்டுமானாலும் Excel, CSV, உரை அல்லது PDF ஆக ஏற்றுமதி செய்யுங்கள்.',
      );
  String get tutSettingsMoreTitle => _t('Make it yours',
      'इसे अपना बनाएँ', 'हे तुमचे करा', 'নিজের মতো সাজান', 'దీన్ని మీదిగా చేసుకోండి', 'இதை உங்களுடையதாக்குங்கள்');
  String get tutSettingsMoreBody => _t(
        "App lock, encrypted backups, privacy mode, streak-reward themes and your language all live here. That's the tour — enjoy Budgetify!",
        'ऐप लॉक, एन्क्रिप्टेड बैकअप, प्राइवेसी मोड, स्ट्रीक-रिवॉर्ड थीम और आपकी भाषा — सब यहीं। बस, टूर पूरा — Budgetify का आनंद लें!',
        'अ‍ॅप लॉक, एन्क्रिप्टेड बॅकअप, प्रायव्हसी मोड, स्ट्रीक-रिवॉर्ड थीम आणि तुमची भाषा — सारे इथेच. झाला टूर — Budgetify चा आनंद घ्या!',
        'অ্যাপ লক, এনক্রিপ্টেড ব্যাকআপ, প্রাইভেসি মোড, স্ট্রিক-রিওয়ার্ড থিম আর আপনার ভাষা — সব এখানেই। ট্যুর শেষ — Budgetify উপভোগ করুন!',
        'యాప్ లాక్, ఎన్‌క్రిప్టెడ్ బ్యాకప్‌లు, ప్రైవసీ మోడ్, స్ట్రీక్-రివార్డ్ థీమ్‌లు మరియు మీ భాష అన్నీ ఇక్కడే ఉన్నాయి. అదే టూర్ — Budgetify ఆనందించండి!',
        'ஆப் பூட்டு, மறையாக்கப்பட்ட காப்புப்பிரதிகள், தனியுரிமை பயன்முறை, ஸ்ட்ரீக்-வெகுமதி தீம்கள் மற்றும் உங்கள் மொழி அனைத்தும் இங்கே இருக்கின்றன. அதுதான் சுற்றுலா — Budgetify ஐ அனுபவியுங்கள்!',
      );
  String get tutDoneToast => _t(
        "Tour complete — you're all set!",
        'टूर पूरा — आप तैयार हैं!',
        'टूर पूर्ण — तुम्ही सज्ज आहात!',
        'ট্যুর শেষ — আপনি প্রস্তুত!',
        'టూర్ పూర్తయింది — మీరు సిద్ధంగా ఉన్నారు!',
        'சுற்றுலா முடிந்தது — நீங்கள் தயார்!',
      );

  String get rewardsSpotlightTitle => _t('Your Rewards hub',
      'आपका Rewards हब', 'तुमचे Rewards हब', 'আপনার Rewards হাব', 'మీ Rewards హబ్', 'உங்கள் Rewards ஹப்');
  String get rewardsSpotlightBody => _t(
        'Gamified Budgets is on! Tap your avatar here anytime to see streaks, badges, titles and your shareable profile.',
        'Gamified Budgets ऑन है! स्ट्रीक, बैज, टाइटल और शेयर करने लायक प्रोफ़ाइल देखने के लिए यहाँ अपने अवतार पर टैप करें।',
        'Gamified Budgets सुरू झाले! स्ट्रीक, बॅज, किताब आणि शेअर करण्याजोगी प्रोफाइल पाहण्यासाठी येथे तुमच्या अवतारावर टॅप करा.',
        'Gamified Budgets চালু হয়েছে! স্ট্রিক, ব্যাজ, টাইটেল আর শেয়ার-যোগ্য প্রোফাইল দেখতে এখানে আপনার অবতারে ট্যাপ করুন।',
        'Gamified Budgets ఆన్‌లో ఉంది! స్ట్రీక్‌లు, బ్యాడ్జ్‌లు, బిరుదులు మరియు మీ షేర్ చేయదగిన ప్రొఫైల్‌ను చూడటానికి ఎప్పుడైనా ఇక్కడ మీ అవతార్‌పై ట్యాప్ చేయండి.',
        'Gamified Budgets இயக்கத்தில் உள்ளது! ஸ்ட்ரீக்குகள், பேட்ஜ்கள், பட்டங்கள் மற்றும் உங்கள் பகிரக்கூடிய சுயவிவரத்தைப் பார்க்க எப்போது வேண்டுமானாலும் இங்கே உங்கள் அவதாரத்தைத் தட்டுங்கள்.',
      );

  String get insightsSpotlightTitle => _t('AI Insights is on',
      'AI इनसाइट्स ऑन है', 'AI इनसाइट्स सुरू आहे', 'AI ইনসাইটস চালু হয়েছে', 'AI అంతర్దృష్టులు ఆన్‌లో ఉన్నాయి', 'AI நுண்ணறிவுகள் இயக்கத்தில் உள்ளன');
  String get insightsSpotlightBody => _t(
        'Your on-device forecast lives here — spending pace, the month-end projection and category movers. Everything is computed on your phone.',
        'आपका ऑन-डिवाइस पूर्वानुमान यहाँ है — खर्च की रफ़्तार, महीने के अंत का अनुमान और श्रेणी बदलाव। सब कुछ आपके फ़ोन पर ही आँका जाता है।',
        'तुमचा ऑन-डिव्हाइस अंदाज इथे आहे — खर्चाची गती, महिनाअखेरीचा अंदाज आणि श्रेणी बदल. सारे काही तुमच्या फोनवरच मोजले जाते.',
        'আপনার অন-ডিভাইস পূর্বাভাস এখানে — খরচের গতি, মাস-শেষের অনুমান আর ক্যাটাগরির ওঠানামা। সবকিছু আপনার ফোনেই হিসাব হয়।',
        'మీ ఆన్-డివైస్ అంచనా ఇక్కడ ఉంటుంది — ఖర్చు వేగం, నెల-చివరి అంచనా మరియు వర్గ మార్పులు. అంతా మీ ఫోన్‌లోనే లెక్కించబడుతుంది.',
        'உங்கள் சாதனத்தில் இயங்கும் முன்கணிப்பு இங்கே உள்ளது — செலவு வேகம், மாத-இறுதி கணிப்பு மற்றும் வகை மாற்றங்கள். அனைத்தும் உங்கள் ஃபோனிலேயே கணக்கிடப்படுகிறது.',
      );
  String get healthSpotlightTitle => _t('Detailed Financial Health',
      'विस्तृत फ़ाइनेंशियल हेल्थ', 'सविस्तर फायनान्शिअल हेल्थ', 'বিস্তারিত ফাইন্যান্সিয়াল হেলথ', 'వివరణాత్మక ఆర్థిక ఆరోగ్యం', 'விரிவான நிதி ஆரோக்கியம்');
  String get healthSpotlightBody => _t(
        'The full breakdown now sits on your dashboard — savings, budgets, recurring load and net worth blended into your 0–100 score. Tap the info icon for how it works.',
        'पूरा ब्रेकडाउन अब आपके डैशबोर्ड पर है — बचत, बजट, आवर्ती खर्च और नेट वर्थ मिलकर आपका 0–100 स्कोर बनाते हैं। यह कैसे काम करता है, जानने के लिए info आइकन पर टैप करें।',
        'संपूर्ण ब्रेकडाउन आता तुमच्या डॅशबोर्डवर आहे — बचत, बजेट, आवर्ती खर्च आणि नेट वर्थ मिळून तुमचा 0–100 स्कोअर बनतो. हे कसे चालते हे जाणण्यासाठी info आयकॉनवर टॅप करा.',
        'পূর্ণ ব্রেকডাউন এখন আপনার ড্যাশবোর্ডে — সঞ্চয়, বাজেট, পুনরাবৃত্ত খরচ আর নেট ওয়ার্থ মিলে আপনার ০–১০০ স্কোর। কীভাবে কাজ করে জানতে info আইকনে ট্যাপ করুন।',
        'పూర్తి విభజన ఇప్పుడు మీ డాష్‌బోర్డ్‌లో ఉంది — పొదుపు, బడ్జెట్‌లు, పునరావృత భారం మరియు నెట్ వర్త్ మీ 0–100 స్కోర్‌లో మిళితం చేయబడ్డాయి. ఇది ఎలా పనిచేస్తుందో తెలుసుకోవడానికి info ఐకాన్‌పై ట్యాప్ చేయండి.',
        'முழு விவரம் இப்போது உங்கள் டாஷ்போர்டில் உள்ளது — சேமிப்பு, பட்ஜெட்கள், தொடர் சுமை மற்றும் நிகர மதிப்பு உங்கள் 0–100 மதிப்பெண்ணில் கலந்தன. இது எப்படி வேலை செய்கிறது என்பதை அறிய info ஐகானைத் தட்டுங்கள்.',
      );

  String get appTourTitle =>
      _t('App tour', 'ऐप टूर', 'अ‍ॅप टूर', 'অ্যাপ ট্যুর', 'యాప్ టూర్', 'ஆப் சுற்றுலா');
  String get appTourDesc => _t(
        'Replay the guided tour',
        'गाइडेड टूर फिर से चलाएँ',
        'गाईडेड टूर पुन्हा चालवा',
        'গাইডেড ট্যুর আবার চালান',
        'గైడెడ్ టూర్‌ను మళ్లీ ప్లే చేయండి',
        'வழிகாட்டப்பட்ட சுற்றுலாவை மீண்டும் இயக்கு',
      );
}

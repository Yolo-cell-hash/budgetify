import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/l10n/app_strings.dart';

/// Guards the hand-rolled four-language string table. English is the default;
/// Hindi, Marathi and Bengali must each resolve to their own text.
void main() {
  final en = AppStrings(AppLanguage.english);
  final hi = AppStrings(AppLanguage.hindi);
  final mr = AppStrings(AppLanguage.marathi);
  final bn = AppStrings(AppLanguage.bengali);

  group('AppLanguage metadata', () {
    test('all four languages are registered', () {
      expect(AppLanguage.values, [
        AppLanguage.english,
        AppLanguage.hindi,
        AppLanguage.marathi,
        AppLanguage.bengali,
      ]);
    });

    test('locale codes', () {
      expect(AppLanguage.english.code, 'en');
      expect(AppLanguage.hindi.code, 'hi');
      expect(AppLanguage.marathi.code, 'mr');
      expect(AppLanguage.bengali.code, 'bn');
    });

    test('native + english names', () {
      expect(AppLanguage.marathi.nativeName, 'मराठी');
      expect(AppLanguage.marathi.englishName, 'Marathi');
      expect(AppLanguage.bengali.nativeName, 'বাংলা');
      expect(AppLanguage.bengali.englishName, 'Bengali');
    });
  });

  group('Marathi resolves to its own text', () {
    test('plain getters differ from English and Hindi', () {
      // Budgets: Budgets / बजट / बजेट
      expect(en.navBudgets, 'Budgets');
      expect(hi.navBudgets, 'बजट');
      expect(mr.navBudgets, 'बजेट');
      expect(mr.navBudgets, isNot(en.navBudgets));
      expect(mr.navBudgets, isNot(hi.navBudgets));
    });

    test('parameterised strings interpolate in Marathi', () {
      final s = mr.foundTransactions(3);
      expect(s.contains('3'), isTrue);
      expect(s, isNot(en.foundTransactions(3)));
    });

    test('switch-based display translators return Marathi', () {
      expect(mr.categoryName('Groceries'), 'किराणा');
      expect(mr.holdingCategoryName('Home Loan'), 'गृहकर्ज');
      expect(mr.achievementName('saver'), 'सुपर सेव्हर');
      expect(mr.titleName('investor'), 'गुंतवणूकदार');
      // Unknown keys pass through unchanged in every language.
      expect(mr.categoryName('My Custom Tag'), 'My Custom Tag');
    });

    test('date helpers use Marathi month/weekday data', () {
      expect(mr.monthName(1), 'जानेवारी');
      expect(mr.monthName(7), 'जुलै');
      expect(hi.monthName(1), 'जनवरी'); // unchanged
    });

    test('tier badge labels translate unit words per language', () {
      expect(mr.tierBadgeLabel('7-Day').contains('दिवस'), isTrue);
      expect(hi.tierBadgeLabel('7-Day').contains('दिन'), isTrue);
      expect(en.tierBadgeLabel('7-Day'), '7-Day');
    });
  });

  group('Bengali resolves to its own text', () {
    test('plain getters differ from the other languages', () {
      // Budgets: Budgets / बजट / बजेट / বাজেট
      expect(bn.navBudgets, 'বাজেট');
      expect(bn.navBudgets, isNot(en.navBudgets));
      expect(bn.navBudgets, isNot(hi.navBudgets));
      expect(bn.navBudgets, isNot(mr.navBudgets));
    });

    test('parameterised strings interpolate in Bengali', () {
      final s = bn.foundTransactions(3);
      expect(s.contains('3'), isTrue);
      expect(s, isNot(en.foundTransactions(3)));
    });

    test('switch-based display translators return Bengali', () {
      expect(bn.categoryName('Groceries'), 'মুদিখানা');
      expect(bn.holdingCategoryName('Home Loan'), 'হোম লোন');
      expect(bn.achievementName('saver'), 'সুপার সেভার');
      expect(bn.titleName('investor'), 'বিনিয়োগকারী');
      // Unknown keys pass through unchanged in every language.
      expect(bn.categoryName('My Custom Tag'), 'My Custom Tag');
    });

    test('date helpers use Bengali month/weekday data', () {
      expect(bn.monthName(1), 'জানুয়ারি');
      expect(bn.monthName(7), 'জুলাই');
    });

    test('tier badge labels translate unit words into Bengali', () {
      expect(bn.tierBadgeLabel('7-Day').contains('দিন'), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/services/custom_tag_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('exportSettings captures emoji overrides and hidden tags', () async {
    final svc = CustomTagService();
    await svc.initialize();

    await svc.setTagEmoji('Food & Dining', '🌮'); // override on a built-in
    await svc.deleteTag('Education'); // hide a built-in

    final settings = svc.exportSettings();
    expect(settings['emoji_overrides'], containsPair('food & dining', '🌮'));
    expect((settings['hidden'] as List).map((e) => e.toString()),
        contains('education'));
  });

  test('importSettings restores overrides and hidden tags', () async {
    final svc = CustomTagService();
    await svc.initialize();

    await svc.importSettings({
      'emoji_overrides': {'shopping': '🧦'},
      'hidden': ['travel'],
    });

    expect(svc.getTagEmoji('Shopping'), '🧦');
    expect(svc.isHidden('Travel'), isTrue);
  });

  test('deleting a custom tag removes it; restoring a built-in unhides it',
      () async {
    final svc = CustomTagService();
    await svc.initialize();

    await svc.addCustomTag('Rent', '🏠');
    expect(svc.isCustomTag('Rent'), isTrue);
    await svc.deleteTag('Rent');
    expect(svc.isCustomTag('Rent'), isFalse);

    await svc.deleteTag('Salary'); // built-in → hidden
    expect(svc.isHidden('Salary'), isTrue);
    await svc.restoreTag('Salary');
    expect(svc.isHidden('Salary'), isFalse);
  });
}

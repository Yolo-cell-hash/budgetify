import 'package:budget_tracker/services/tutorial_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TutorialService.instance.debugReset();
  });

  test('starts at the first step and only advances forward, in order',
      () async {
    final svc = TutorialService.instance;
    await svc.load();
    expect(svc.step, TutorialStep.viewTransactions);

    svc.advanceFrom(TutorialStep.viewTransactions);
    expect(svc.step, TutorialStep.openTransaction);

    // Re-firing a completed step's trigger is harmless.
    svc.advanceFrom(TutorialStep.viewTransactions);
    expect(svc.step, TutorialStep.openTransaction);

    // Triggers for later steps don't fire early either.
    svc.advanceFrom(TutorialStep.saveTag);
    expect(svc.step, TutorialStep.openTransaction);

    // Backward jumps are ignored.
    svc.advanceTo(TutorialStep.viewTransactions);
    expect(svc.step, TutorialStep.openTransaction);
  });

  test('skipAll ends the tour and restart brings it back', () async {
    final svc = TutorialService.instance;
    await svc.load();

    svc.skipAll();
    expect(svc.isDone, isTrue);

    await svc.restart();
    expect(svc.step, TutorialStep.viewTransactions);
  });

  test('progress persists to preferences', () async {
    final svc = TutorialService.instance;
    await svc.load();

    svc.advanceTo(TutorialStep.health);
    // _persist runs fire-and-forget; give it a beat to land.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('tutorial_step_v1'), TutorialStep.health.index);
  });

  test('inert before load — triggers do nothing', () {
    final svc = TutorialService.instance;
    expect(svc.isDone, isTrue); // reads as done while unloaded
    svc.advanceFrom(TutorialStep.viewTransactions);
    expect(svc.isDone, isTrue);
  });
}

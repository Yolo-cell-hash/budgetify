import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/services/sms_diagnostics_service.dart';
import 'package:budget_tracker/services/sms_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SmsDiagnosticsService', () {
    test('records noAmount/noType, newest first', () async {
      await SmsDiagnosticsService.maybeRecord(
        sender: 'AD-MAHABK-S',
        body: 'Your a/c is debited for a UPI payment to X',
        reason: SmsParseReason.noAmount,
      );
      await SmsDiagnosticsService.maybeRecord(
        sender: 'AD-MAHABK-S',
        body: 'something odd',
        reason: SmsParseReason.noType,
      );
      final all = await SmsDiagnosticsService.all();
      expect(all.length, 2);
      expect(all.first.reason, SmsParseReason.noType); // newest first
    });

    test('never records notBank / promo / parsed', () async {
      await SmsDiagnosticsService.maybeRecord(
          sender: 'X', body: 'Rs.5 spent', reason: SmsParseReason.notBank);
      await SmsDiagnosticsService.maybeRecord(
          sender: 'AD-X-P', body: 'Rs.5 spent', reason: SmsParseReason.promo);
      await SmsDiagnosticsService.maybeRecord(
          sender: 'AD-MAHABK-S',
          body: 'Rs.5 spent',
          reason: SmsParseReason.parsed);
      expect(await SmsDiagnosticsService.all(), isEmpty);
    });

    test('nonTransaction recorded only when the body mentions money', () async {
      await SmsDiagnosticsService.maybeRecord(
        sender: 'AD-MAHABK-S',
        body: '123456 is your OTP. Do not share it with anyone.',
        reason: SmsParseReason.nonTransaction,
      );
      await SmsDiagnosticsService.maybeRecord(
        sender: 'AD-MAHABK-S',
        body: 'Your statement for Rs.1,234 is ready.',
        reason: SmsParseReason.nonTransaction,
      );
      final all = await SmsDiagnosticsService.all();
      expect(all.length, 1);
      expect(all.first.body, contains('statement'));
    });

    test('caps at 200 entries and clear() empties the log', () async {
      final items = List.generate(
        205,
        (i) => (
          sender: 'AD-MAHABK-S',
          body: 'msg $i',
          reason: SmsParseReason.noAmount,
        ),
      );
      await SmsDiagnosticsService.recordAll(items);
      expect((await SmsDiagnosticsService.all()).length, 200);

      await SmsDiagnosticsService.clear();
      expect(await SmsDiagnosticsService.all(), isEmpty);
    });
  });
}

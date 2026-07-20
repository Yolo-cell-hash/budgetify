import 'package:another_telephony/telephony.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform/platform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/services/sms_service.dart';

/// Guards the bound on inbox reads.
///
/// The telephony plugin answers `getAllInboxSms` by walking the whole cursor on
/// the Android main thread and shipping every row across the method channel, so
/// an unfiltered query stalls the UI thread for as long as it takes to read the
/// entire SMS history — long enough, on a cold start, for the platform to kill
/// the process. These tests assert every query carries a date window and that
/// the watermark keeps repeat scans down to a single slice.
const _telephonyChannel =
    MethodChannel('plugins.shounakmulay.com/foreground_sms_channel');
const _permissionChannel =
    MethodChannel('flutter.baseflow.com/permissions/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<Object?, Object?>> queries;
  var permissionGranted = true;

  /// The `(since, until]` bounds of a captured query, in epoch millis.
  (int, int) boundsOf(Map<Object?, Object?> query) {
    final args = (query['selection_args'] as List).cast<String>();
    return (int.parse(args[0]), int.parse(args[1]));
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    queries = [];
    permissionGranted = true;

    SmsService().telephony = Telephony.private(
      _telephonyChannel,
      FakePlatform(operatingSystem: 'android'),
    );

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(_permissionChannel, (call) async {
      if (call.method == 'checkPermissionStatus') {
        return permissionGranted ? 1 : 0; // PermissionStatus.granted : denied
      }
      return null;
    });

    // An empty inbox: the scan still walks its windows, which is exactly what
    // these tests inspect, and no message means no database work to stub out.
    messenger.setMockMethodCallHandler(_telephonyChannel, (call) async {
      if (call.method == 'getAllInboxSms') {
        queries.add(call.arguments as Map<Object?, Object?>);
        return <Object?>[];
      }
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_permissionChannel, null);
    messenger.setMockMethodCallHandler(_telephonyChannel, null);
  });

  test('every inbox query is bounded by a date window', () async {
    await SmsService().scanExistingSms();

    expect(queries, isNotEmpty);
    for (final query in queries) {
      expect(
        query['selection'],
        allOf(contains('date >'), contains('date <=')),
        reason: 'an unfiltered query reads the entire inbox on the UI thread',
      );
      final (since, until) = boundsOf(query);
      expect(until, greaterThan(since));
    }
  });

  test('a first run reaches back a bounded history, not to the epoch',
      () async {
    await SmsService().scanExistingSms();

    final earliest = queries.map((q) => boundsOf(q).$1).reduce(
          (a, b) => a < b ? a : b,
        );
    final reach = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(earliest))
        .inDays;

    expect(reach, greaterThan(0));
    expect(reach, lessThanOrEqualTo(366));
  });

  test('slices are contiguous, so no message falls between windows', () async {
    await SmsService().scanExistingSms();

    for (var i = 1; i < queries.length; i++) {
      final (since, _) = boundsOf(queries[i]);
      final (_, previousUntil) = boundsOf(queries[i - 1]);
      expect(since, previousUntil);
    }
  });

  test('a completed scan leaves a watermark that narrows the next one',
      () async {
    await SmsService().scanExistingSms();
    final firstRunQueries = queries.length;
    expect(firstRunQueries, greaterThan(1), reason: 'a year, walked in slices');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('sms_scan_watermark'), isNotNull);

    queries = [];
    await SmsService().scanExistingSms();

    expect(
      queries,
      hasLength(1),
      reason: 'a caught-up scan is one short window, not a re-read of history',
    );
  });

  test('a repeat scan re-reads a small overlap for late-stamped messages',
      () async {
    await SmsService().scanExistingSms();
    final watermark =
        (await SharedPreferences.getInstance()).getInt('sms_scan_watermark')!;

    queries = [];
    await SmsService().scanExistingSms();

    final (since, _) = boundsOf(queries.single);
    expect(since, lessThan(watermark));
    final overlapDays = DateTime.fromMillisecondsSinceEpoch(watermark)
        .difference(DateTime.fromMillisecondsSinceEpoch(since))
        .inDays;
    expect(overlapDays, inInclusiveRange(1, 7));
  });

  test('a watermark stamped in the future still scans the recent past',
      () async {
    // A carrier stamping a message a year ahead, or a device clock that jumped,
    // must not park the watermark past now and stop scanning for good.
    SharedPreferences.setMockInitialValues({
      'sms_scan_watermark':
          DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch,
    });

    await SmsService().scanExistingSms();

    expect(queries, isNotEmpty);
    final (since, until) = boundsOf(queries.single);
    expect(since, lessThan(DateTime.now().millisecondsSinceEpoch));
    expect(until, greaterThan(since));
  });

  test('without SMS permission the inbox is never read', () async {
    permissionGranted = false;

    final found = await SmsService().scanExistingSms();

    expect(found, isEmpty);
    expect(queries, isEmpty);
  });
}

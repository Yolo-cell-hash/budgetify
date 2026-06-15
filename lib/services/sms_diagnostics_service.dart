import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'sms_parser_service.dart';

/// A single captured "bank SMS we couldn't turn into a transaction" record.
class SmsDiagnosticEntry {
  final String sender;
  final String body;
  final SmsParseReason reason;
  final DateTime time;

  const SmsDiagnosticEntry({
    required this.sender,
    required this.body,
    required this.reason,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'body': body,
        'reason': reason.name,
        'ts': time.toIso8601String(),
      };

  static SmsDiagnosticEntry fromJson(Map<String, dynamic> j) =>
      SmsDiagnosticEntry(
        sender: j['sender'] as String? ?? '',
        body: j['body'] as String? ?? '',
        reason: SmsParseReason.values.firstWhere(
          (r) => r.name == j['reason'],
          orElse: () => SmsParseReason.nonTransaction,
        ),
        time: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime(2000),
      );
}

/// Passive, on-device, capped log of bank SMS that cleared the strict sender
/// gate but could not be parsed into a transaction.
///
/// This is the autonomous way to chase down "my bank's messages aren't
/// detected" reports: the parser keeps a private record of what it choked on,
/// the tester can surface it from a hidden screen, and the dev gets the real
/// failing sample — all without prompting the user about anything, and without
/// a single byte leaving the device.
class SmsDiagnosticsService {
  static const String _key = 'sms_diagnostics_log';
  static const int _maxEntries = 200;

  /// Record a single non-parse outcome (if it's worth reviewing).
  static Future<void> maybeRecord({
    required String sender,
    required String body,
    required SmsParseReason reason,
  }) =>
      recordAll([(sender: sender, body: body, reason: reason)]);

  /// Batch variant — a single storage write for a whole inbox scan.
  static Future<void> recordAll(
    List<({String sender, String body, SmsParseReason reason})> items,
  ) async {
    final loggable = items.where((i) => _isLoggable(i.reason, i.body)).toList();
    if (loggable.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    final now = DateTime.now();
    // Insert newest-first.
    for (final i in loggable.reversed) {
      list.insert(
        0,
        jsonEncode(
          SmsDiagnosticEntry(
            sender: i.sender,
            body: i.body,
            reason: i.reason,
            time: now,
          ).toJson(),
        ),
      );
    }
    if (list.length > _maxEntries) {
      list.removeRange(_maxEntries, list.length);
    }
    await prefs.setStringList(_key, list);
  }

  /// Which non-parse outcomes are worth capturing:
  /// - [SmsParseReason.noType] / [SmsParseReason.noAmount]: "we tried but
  ///   couldn't finish" — the high-value cases (likely a new format).
  /// - [SmsParseReason.nonTransaction]: only when the body actually mentions
  ///   money, to skip the flood of ordinary bank OTPs.
  /// - notBank / promo / parsed: never logged.
  static bool _isLoggable(SmsParseReason reason, String body) {
    switch (reason) {
      case SmsParseReason.noType:
      case SmsParseReason.noAmount:
        return true;
      case SmsParseReason.nonTransaction:
        return _looksMonetary(body);
      case SmsParseReason.parsed:
      case SmsParseReason.notBank:
      case SmsParseReason.promo:
        return false;
    }
  }

  static bool _looksMonetary(String body) =>
      RegExp(r'(?:RS\.?|INR|₹)\s*\d', caseSensitive: false).hasMatch(body);

  /// All captured entries, newest first.
  static Future<List<SmsDiagnosticEntry>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    final out = <SmsDiagnosticEntry>[];
    for (final s in list) {
      try {
        out.add(
          SmsDiagnosticEntry.fromJson(jsonDecode(s) as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip a corrupt entry rather than failing the whole read.
      }
    }
    return out;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

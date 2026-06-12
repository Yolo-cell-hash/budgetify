import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/services/backup_service.dart';

void main() {
  final service = BackupService();
  const payload =
      '{"magic":"budgetify.backup.v1","data":{"transactions":[{"amount":35.0}]}}';

  group('Backup encryption', () {
    test('round-trips with the correct passphrase', () async {
      final envelope = await service.encryptEnvelope(payload, 'hunter22');
      final clear = await service.decryptEnvelope(envelope, 'hunter22');
      expect(clear, payload);
    });

    test('fails loudly with the wrong passphrase', () async {
      final envelope = await service.encryptEnvelope(payload, 'hunter22');
      expect(
        () => service.decryptEnvelope(envelope, 'hunter23'),
        throwsA(isA<BackupException>()),
      );
    });

    test('rejects tampered ciphertext', () async {
      final envelope = await service.encryptEnvelope(payload, 'hunter22');
      final map = jsonDecode(envelope) as Map<String, dynamic>;
      final cipher = base64Decode(map['cipherText'] as String);
      cipher[0] ^= 0xFF;
      map['cipherText'] = base64Encode(cipher);
      expect(
        () => service.decryptEnvelope(jsonEncode(map), 'hunter22'),
        throwsA(isA<BackupException>()),
      );
    });

    test('rejects non-backup files', () async {
      expect(
        () => service.decryptEnvelope('not json at all', 'x'),
        throwsA(isA<BackupException>()),
      );
      expect(
        () => service.decryptEnvelope('{"magic":"other"}', 'x'),
        throwsA(isA<BackupException>()),
      );
    });
  });
}

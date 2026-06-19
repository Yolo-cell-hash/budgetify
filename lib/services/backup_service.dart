import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';

import 'custom_tag_service.dart';
import 'database_service.dart';
import 'gamification_service.dart';

/// Result of a restore operation.
class RestoreResult {
  final int transactions;
  final int budgets;
  final int rules;
  final int customTags;
  final int holdings;
  final int sips;

  const RestoreResult({
    required this.transactions,
    required this.budgets,
    required this.rules,
    required this.customTags,
    this.holdings = 0,
    this.sips = 0,
  });

  int get total =>
      transactions + budgets + rules + customTags + holdings + sips;
}

/// Thrown when a backup file can't be decrypted (wrong passphrase) or is
/// not a valid Budgetify backup.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}

/// Encrypted backup/restore of all app data.
///
/// The backup is a JSON envelope holding an AES-256-GCM encrypted payload.
/// The key is derived from the user's passphrase with PBKDF2-HMAC-SHA256
/// (120k iterations, random 16-byte salt). GCM authentication means a wrong
/// passphrase or tampered file fails loudly instead of restoring garbage.
class BackupService {
  static const String _magic = 'budgetify.backup.v1';
  static const int _pbkdf2Iterations = 120000;
  static const String fileExtension = 'bgfy';

  final DatabaseService _db = DatabaseService();

  AesGcm get _cipher => AesGcm.with256bits();

  Pbkdf2 get _kdf => Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _pbkdf2Iterations,
        bits: 256,
      );

  List<int> _randomBytes(int length) {
    final rng = Random.secure();
    return List<int>.generate(length, (_) => rng.nextInt(256));
  }

  /// Encrypt a JSON payload into a self-describing envelope string.
  /// Exposed for testing.
  Future<String> encryptEnvelope(String payloadJson, String passphrase) async {
    final salt = _randomBytes(16);
    final key = await _kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      utf8.encode(payloadJson),
      secretKey: key,
      nonce: nonce,
    );

    return jsonEncode({
      'magic': _magic,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _pbkdf2Iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  /// Decrypt an envelope string back to the JSON payload.
  /// Throws [BackupException] for invalid files or a wrong passphrase.
  /// Exposed for testing.
  Future<String> decryptEnvelope(String envelopeJson, String passphrase) async {
    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('Not a valid Budgetify backup file.');
    }
    if (envelope['magic'] != _magic) {
      throw const BackupException('Not a valid Budgetify backup file.');
    }

    final key = await _kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: base64Decode(envelope['salt'] as String),
    );

    try {
      final clear = await _cipher.decrypt(
        SecretBox(
          base64Decode(envelope['cipherText'] as String),
          nonce: base64Decode(envelope['nonce'] as String),
          mac: Mac(base64Decode(envelope['mac'] as String)),
        ),
        secretKey: key,
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const BackupException(
        'Wrong passphrase — the backup could not be decrypted.',
      );
    }
  }

  /// Build, encrypt, and let the user save a backup file.
  /// Returns the saved path, or null if the user cancelled the save dialog.
  Future<String?> createBackup(String passphrase) async {
    final data = await _db.exportAllData();
    final tagService = CustomTagService();
    data['custom_tags'] =
        tagService.getCustomTags().map((t) => t.toJson()).toList();
    // Tag settings: custom emoji overrides + hidden built-in tags
    data['tag_settings'] = tagService.exportSettings();
    // Gamified Budgets: profile, avatar, streak, unlock dates (offline).
    data['gamification'] = await GamificationService().exportSettings();

    final payloadJson = jsonEncode({
      'magic': _magic,
      'createdAt': DateTime.now().toIso8601String(),
      'data': data,
    });

    final envelope = await encryptEnvelope(payloadJson, passphrase);

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    return FilePicker.saveFile(
      dialogTitle: 'Save encrypted backup',
      fileName: 'budgetify-backup-$stamp.$fileExtension',
      bytes: Uint8List.fromList(utf8.encode(envelope)),
    );
  }

  /// Let the user pick a backup file, decrypt it, and merge its contents.
  /// Returns null if the user cancelled the file picker.
  Future<RestoreResult?> restoreBackup(String passphrase) async {
    final picked = await FilePicker.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return null;

    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      throw const BackupException('Could not read the selected file.');
    }

    final clearJson = await decryptEnvelope(utf8.decode(bytes), passphrase);

    final decoded = jsonDecode(clearJson) as Map<String, dynamic>;
    if (decoded['magic'] != _magic) {
      throw const BackupException('Backup contents are corrupted.');
    }

    final data = decoded['data'] as Map<String, dynamic>;
    final counts = await _db.importBackupData(data);

    // Restore custom tags (addCustomTag is a no-op for existing names)
    var tagCount = 0;
    final tagService = CustomTagService();
    for (final raw in (data['custom_tags'] as List? ?? const [])) {
      final tag = CustomTag.fromJson(Map<String, dynamic>.from(raw as Map));
      if (await tagService.addCustomTag(tag.name, tag.emoji)) {
        tagCount++;
      }
    }

    // Restore tag settings (emoji overrides + hidden built-in tags)
    await tagService.importSettings(
      (data['tag_settings'] as Map?)?.cast<String, dynamic>(),
    );

    // Restore Gamified Budgets profile + streak + unlock state.
    await GamificationService().importSettings(
      (data['gamification'] as Map?)?.cast<String, dynamic>(),
    );

    // Now that classification rules are back, auto-tag any past
    // transactions that match them (e.g. rows the post-reinstall scan
    // re-created untagged, or transactions added after the backup).
    await _db.applyRulesToUntagged();

    return RestoreResult(
      transactions: counts['transactions'] ?? 0,
      budgets: counts['budgets'] ?? 0,
      rules: counts['rules'] ?? 0,
      customTags: tagCount,
      holdings: counts['holdings'] ?? 0,
      sips: counts['sips'] ?? 0,
    );
  }
}

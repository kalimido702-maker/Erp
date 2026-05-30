import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256 field-level encryption for SQLite sensitive columns.
///
/// Why field-level (not full-db):
/// - Full DB encryption (SQLCipher) requires native lib replacement
/// - Field-level works with standard sqflite, zero native config
/// - Key stored in flutter_secure_storage (Android Keystore / iOS Keychain)
///
/// What is encrypted:
/// - response_cache.raw          (API responses: salaries, invoices, PII)
/// - normalized_entities.data    (entity records)
/// - sync_queue.payload          (pending mutation data)
class FieldEncryptor {
  static FieldEncryptor? _instance;
  static FieldEncryptor get instance => _instance ??= FieldEncryptor._();
  FieldEncryptor._();

  static const _keyStorageKey = 'erp_db_aes_key';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Encrypter? _encrypter;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    String? keyBase64 = await _storage.read(key: _keyStorageKey);

    if (keyBase64 == null) {
      // First run — generate and persist a random 256-bit key
      final keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      keyBase64 = base64Encode(keyBytes);
      await _storage.write(key: _keyStorageKey, value: keyBase64);
    }

    final key = Key(base64Decode(keyBase64));
    _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    _initialized = true;
  }

  /// Encrypt a plain-text JSON string.
  /// Returns: "iv_base64:ciphertext_base64"
  String encrypt(String plaintext) {
    _assertReady();
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plaintext, iv: iv);
    return '${base64Encode(iv.bytes)}:${encrypted.base64}';
  }

  /// Decrypt a value produced by [encrypt].
  String decrypt(String stored) {
    _assertReady();
    final parts = stored.split(':');
    if (parts.length != 2) {
      // Fallback for unencrypted legacy rows (migration scenario)
      return stored;
    }
    final iv = IV(base64Decode(parts[0]));
    return _encrypter!.decrypt64(parts[1], iv: iv);
  }

  /// Encrypt an arbitrary JSON-encodable value.
  String encryptJson(dynamic value) {
    final json = jsonEncode(value);
    return encrypt(json);
  }

  /// Decrypt and JSON-decode a value.
  dynamic decryptJson(String stored) {
    final json = decrypt(stored);
    return jsonDecode(json);
  }

  void _assertReady() {
    if (!_initialized || _encrypter == null) {
      throw StateError('FieldEncryptor not initialized — call await FieldEncryptor.instance.init() in main()');
    }
  }
}

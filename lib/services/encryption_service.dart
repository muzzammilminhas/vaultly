import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the AES key material is persisted. Abstracted behind an interface
/// (rather than depending on [FlutterSecureStorage] directly) so tests can
/// swap in an in-memory store instead of touching the Android Keystore
/// through a platform channel.
abstract class SecureKeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureStorageKeyStore implements SecureKeyStore {
  const SecureStorageKeyStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
}

/// Encrypts document files at rest with AES-256 (CBC, random IV per call).
///
/// The key is generated once on first launch and stored via [SecureKeyStore]
/// — on Android this is backed by the Keystore (EncryptedSharedPreferences),
/// so the key material itself never lives in plain app storage or backups.
/// Encrypted bytes are what gets written to disk; decrypted bytes only ever
/// exist in memory — callers must never write a decrypted copy back to disk.
class EncryptionService {
  EncryptionService({SecureKeyStore? keyStore}) : _keyStore = keyStore ?? const SecureStorageKeyStore();

  static const _keyStorageKey = 'vaultly_aes_key_v1';
  static const _ivLength = 16;

  final SecureKeyStore _keyStore;
  enc.Key? _cachedKey;

  Future<enc.Key> _getOrCreateKey() async {
    final cached = _cachedKey;
    if (cached != null) return cached;

    var stored = await _keyStore.read(_keyStorageKey);
    if (stored == null) {
      final generated = enc.Key.fromSecureRandom(32); // AES-256
      stored = base64Encode(generated.bytes);
      await _keyStore.write(_keyStorageKey, stored);
    }
    final key = enc.Key(base64Decode(stored));
    _cachedKey = key;
    return key;
  }

  /// Encrypts [plainBytes], returning `IV || ciphertext` ready to write to disk.
  Future<Uint8List> encryptBytes(Uint8List plainBytes) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(_ivLength);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);
    return Uint8List.fromList(iv.bytes + encrypted.bytes);
  }

  /// Reverses [encryptBytes]. The returned bytes must only be held in memory.
  Future<Uint8List> decryptBytes(Uint8List fileBytes) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV(fileBytes.sublist(0, _ivLength));
    final cipherBytes = fileBytes.sublist(_ivLength);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
    return Uint8List.fromList(decrypted);
  }
}

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

import 'encryption_service.dart' show SecureKeyStore, SecureStorageKeyStore;

/// PIN + biometric app-lock gate.
///
/// The PIN itself is never stored — only a salted SHA-256 hash, held via
/// [SecureKeyStore] (Android Keystore-backed in production).
class AuthService {
  AuthService({SecureKeyStore? keyStore, LocalAuthentication? localAuth})
      : _keyStore = keyStore ?? const SecureStorageKeyStore(),
        _localAuth = localAuth ?? LocalAuthentication();

  static const _pinHashKey = 'vaultly_pin_hash_v1';
  static const _pinSaltKey = 'vaultly_pin_salt_v1';

  final SecureKeyStore _keyStore;
  final LocalAuthentication _localAuth;

  Future<bool> hasPin() async {
    return await _keyStore.read(_pinHashKey) != null;
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    await _keyStore.write(_pinSaltKey, salt);
    await _keyStore.write(_pinHashKey, _hash(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _keyStore.read(_pinSaltKey);
    final storedHash = await _keyStore.read(_pinHashKey);
    if (salt == null || storedHash == null) return false;
    return _hash(pin, salt) == storedHash;
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.isDeviceSupported() && await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Vaultly',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}

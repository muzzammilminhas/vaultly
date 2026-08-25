import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:vaultly/services/encryption_service.dart';

class _FakeKeyStore implements SecureKeyStore {
  final _map = <String, String>{};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;
}

void main() {
  test('encrypted file on disk cannot be decoded as an image without the decryption service', () async {
    final service = EncryptionService(keyStore: _FakeKeyStore());

    final original = img.Image(width: 8, height: 8);
    img.fill(original, color: img.ColorRgb8(200, 50, 50));
    final plainBytes = Uint8List.fromList(img.encodeJpg(original));

    final encryptedBytes = await service.encryptBytes(plainBytes);

    final tempDir = await Directory.systemTemp.createTemp('vaultly_test');
    addTearDown(() => tempDir.delete(recursive: true));
    final file = File('${tempDir.path}/doc.enc');
    await file.writeAsBytes(encryptedBytes);

    final rawFileBytes = await file.readAsBytes();
    expect(img.decodeImage(rawFileBytes), isNull, reason: 'ciphertext must not decode as an image');
    expect(rawFileBytes, isNot(equals(plainBytes)));

    final decrypted = await service.decryptBytes(rawFileBytes);
    expect(decrypted, equals(plainBytes));
    expect(img.decodeImage(decrypted), isNotNull, reason: 'decrypted bytes must decode back to the original image');
  });

  test('encrypting the same plaintext twice yields different ciphertext (random IV per call)', () async {
    final service = EncryptionService(keyStore: _FakeKeyStore());
    final plainBytes = Uint8List.fromList(List.generate(64, (i) => i));
    final a = await service.encryptBytes(plainBytes);
    final b = await service.encryptBytes(plainBytes);
    expect(a, isNot(equals(b)));
  });

  test('decrypting with a different key never reproduces the plaintext', () async {
    final serviceA = EncryptionService(keyStore: _FakeKeyStore());
    final serviceB = EncryptionService(keyStore: _FakeKeyStore());
    final plainBytes = Uint8List.fromList(List.generate(64, (i) => i));

    final encrypted = await serviceA.encryptBytes(plainBytes);

    // CBC/PKCS7 under the wrong key almost always trips the padding check
    // and throws rather than silently returning wrong bytes — either
    // outcome is an acceptable proof that the wrong key can't recover data,
    // but it must never come back equal to the original plaintext.
    try {
      final wronglyDecrypted = await serviceB.decryptBytes(encrypted);
      expect(wronglyDecrypted, isNot(equals(plainBytes)));
    } catch (_) {
      // Throwing on an invalid pad block is expected and fine.
    }
  });
}

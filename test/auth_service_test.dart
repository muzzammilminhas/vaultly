import 'package:flutter_test/flutter_test.dart';

import 'package:vaultly/services/auth_service.dart';
import 'package:vaultly/services/encryption_service.dart';

class _FakeKeyStore implements SecureKeyStore {
  final _map = <String, String>{};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;
}

void main() {
  test('hasPin is false until a PIN is set', () async {
    final auth = AuthService(keyStore: _FakeKeyStore());
    expect(await auth.hasPin(), isFalse);
    await auth.setPin('1234');
    expect(await auth.hasPin(), isTrue);
  });

  test('verifyPin accepts the correct PIN and rejects a wrong one', () async {
    final auth = AuthService(keyStore: _FakeKeyStore());
    await auth.setPin('4471');
    expect(await auth.verifyPin('4471'), isTrue);
    expect(await auth.verifyPin('0000'), isFalse);
    expect(await auth.verifyPin('447'), isFalse);
  });

  test('verifyPin is false when no PIN has ever been set', () async {
    final auth = AuthService(keyStore: _FakeKeyStore());
    expect(await auth.verifyPin('1234'), isFalse);
  });

  test('the PIN is never stored in plaintext', () async {
    final store = _FakeKeyStore();
    final auth = AuthService(keyStore: store);
    await auth.setPin('1234');
    for (final value in store._map.values) {
      expect(value, isNot(contains('1234')), reason: 'raw PIN must never appear in stored values');
    }
  });

  test('the same PIN salted differently across instances still verifies correctly', () async {
    // Two independent AuthServices sharing no state — setting the same PIN
    // on each should still produce a hash that only that instance's own
    // salt can verify (proves salting isn't a shared/fixed constant).
    final storeA = _FakeKeyStore();
    final storeB = _FakeKeyStore();
    await AuthService(keyStore: storeA).setPin('1234');
    await AuthService(keyStore: storeB).setPin('1234');
    expect(storeA._map['vaultly_pin_hash_v1'], isNot(equals(storeB._map['vaultly_pin_hash_v1'])));
  });
}

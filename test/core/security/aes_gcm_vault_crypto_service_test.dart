import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_contrasenas/core/security/aes_gcm_vault_crypto_service.dart';
import 'package:gestor_contrasenas/core/security/vault_session.dart';

void main() {
  // Deterministic 32-byte key reused across every test so we can compare
  // ciphertexts to expected values when needed.
  final keyBytes = List<int>.generate(32, (i) => i);
  final secretKey = SecretKey(keyBytes);
  const keyId = 'test-key-id';

  group('AesGcmVaultCryptoService', () {
    test('encrypts and decrypts a v1 payload with a raw SecretKey', () async {
      final service = AesGcmVaultCryptoService();
      const plaintext = 'hunter2';

      final ciphertext = await service.encrypt(
        plaintext: plaintext,
        secretKey: secretKey,
        keyId: keyId,
      );
      final decoded = jsonDecode(ciphertext) as Map<String, dynamic>;

      expect(decoded['version'], 1);
      expect(decoded['algorithm'], 'aes-256-gcm');
      expect(decoded['keyId'], keyId);

      final recovered = await service.decrypt(
        ciphertext: ciphertext,
        secretKey: secretKey,
        expectedKeyId: keyId,
      );
      expect(recovered, plaintext);
    });

    test('encrypts and decrypts a v2 payload via a VaultSession', () async {
      final service = AesGcmVaultCryptoService();
      const plaintext = 'correct horse battery staple';
      final session = VaultSession.v2(
        keyId: keyId,
        secretKey: secretKey,
        kdf: const {'alg': 'argon2id', 't': 3, 'm': 65536, 'p': 4},
        dekWrap: const {'alg': 'aes-256-gcm', 'ct': '...', 'nonce': '...'},
      );

      final ciphertext = await service.encrypt(
        plaintext: plaintext,
        secretKey: session,
        keyId: keyId,
      );
      final decoded = jsonDecode(ciphertext) as Map<String, dynamic>;

      expect(decoded['v'], 2);
      expect(decoded['kdf'], isA<Map<String, dynamic>>());
      expect(decoded['dek_wrap'], isA<Map<String, dynamic>>());
      expect(decoded['payload'], isA<Map<String, dynamic>>());

      final recovered = await service.decrypt(
        ciphertext: ciphertext,
        secretKey: session,
        expectedKeyId: keyId,
      );
      expect(recovered, plaintext);
    });

    test('rejects payloads with an unsupported version', () async {
      final service = AesGcmVaultCryptoService();
      final payload = jsonEncode({
        'version': 99,
        'algorithm': 'aes-256-gcm',
        'keyId': keyId,
        'nonce': base64Encode(List<int>.filled(12, 0)),
        'ciphertext': base64Encode([1, 2, 3]),
        'mac': base64Encode(List<int>.filled(16, 0)),
      });

      expect(
        () => service.decrypt(
          ciphertext: payload,
          secretKey: secretKey,
          expectedKeyId: keyId,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects payloads whose keyId does not match expected', () async {
      final service = AesGcmVaultCryptoService();
      final ciphertext = await service.encrypt(
        plaintext: 'irrelevant',
        secretKey: secretKey,
        keyId: 'old-key',
      );

      expect(
        () => service.decrypt(
          ciphertext: ciphertext,
          secretKey: secretKey,
          expectedKeyId: 'new-key',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects secretKey values that are neither SecretKey nor VaultSession',
        () async {
      final service = AesGcmVaultCryptoService();
      expect(
        () => service.encrypt(
          plaintext: 'x',
          secretKey: 'definitely-not-a-key',
          keyId: keyId,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('VaultSession', () {
    test('v1 factory yields a non-v2 session', () {
      final session = VaultSession.v1(keyId: keyId, secretKey: secretKey);
      expect(session.isV2, isFalse);
      expect(session.kdf, isNull);
      expect(session.dekWrap, isNull);
    });

    test('v2 factory yields a v2 session with both kdf and dekWrap set', () {
      final session = VaultSession.v2(
        keyId: keyId,
        secretKey: secretKey,
        kdf: const {'alg': 'argon2id'},
        dekWrap: const {'alg': 'aes-256-gcm'},
      );
      expect(session.isV2, isTrue);
      expect(session.kdf, isA<Map<String, dynamic>>());
      expect(session.dekWrap, isA<Map<String, dynamic>>());
    });

    test('v2 factory throws on empty kdf', () {
      expect(
        () => VaultSession.v2(
          keyId: keyId,
          secretKey: secretKey,
          kdf: const {},
          dekWrap: const {'alg': 'aes-256-gcm'},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('v2 factory throws on empty dekWrap', () {
      expect(
        () => VaultSession.v2(
          keyId: keyId,
          secretKey: secretKey,
          kdf: const {'alg': 'argon2id'},
          dekWrap: const {},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

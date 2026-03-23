import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'vault_crypto_service.dart';

class AesGcmVaultCryptoService implements VaultCryptoService {
  AesGcmVaultCryptoService({AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  static const _version = 1;

  final AesGcm _algorithm;

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Object secretKey,
    required String expectedKeyId,
  }) async {
    if (secretKey is! SecretKey) {
      throw ArgumentError.value(secretKey, 'secretKey', 'Expected SecretKey.');
    }

    final payload = jsonDecode(ciphertext) as Map<String, dynamic>;
    final version = payload['version'] as int?;
    final keyId = payload['keyId'] as String?;

    if (version != _version) {
      throw StateError('Unsupported vault payload version: $version');
    }

    if (keyId != expectedKeyId) {
      throw StateError('Vault payload key mismatch. Rekeying is required.');
    }

    final secretBox = SecretBox(
      base64Decode(payload['ciphertext'] as String),
      nonce: base64Decode(payload['nonce'] as String),
      mac: Mac(base64Decode(payload['mac'] as String)),
    );

    final clearBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return utf8.decode(clearBytes);
  }

  @override
  Future<String> encrypt({
    required String plaintext,
    required Object secretKey,
    required String keyId,
  }) async {
    if (secretKey is! SecretKey) {
      throw ArgumentError.value(secretKey, 'secretKey', 'Expected SecretKey.');
    }

    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
    );

    return jsonEncode({
      'version': _version,
      'algorithm': 'aes-256-gcm',
      'keyId': keyId,
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
  }
}

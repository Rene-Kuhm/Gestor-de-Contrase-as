import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'vault_session.dart';
import 'vault_crypto_service.dart';

class AesGcmVaultCryptoService implements VaultCryptoService {
  AesGcmVaultCryptoService({AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  static const _version = 1;
  static const _version2 = 2;

  final AesGcm _algorithm;

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Object secretKey,
    required String expectedKeyId,
  }) async {
    final itemKey = _readItemKey(secretKey);

    final payload = jsonDecode(ciphertext) as Map<String, dynamic>;
    final version = (payload['v'] ?? payload['version']) as int?;
    final keyId = payload['keyId'] as String?;

    if (version != _version && version != _version2) {
      throw StateError('Unsupported vault payload version: $version');
    }

    if (keyId != expectedKeyId) {
      throw StateError('Vault payload key mismatch. Rekeying is required.');
    }

    final encryptedPayload = version == _version2
        ? payload['payload'] as Map<String, dynamic>
        : payload;
    final secretBox = _secretBoxFromPayload(encryptedPayload);

    final clearBytes = await _algorithm.decrypt(secretBox, secretKey: itemKey);
    return utf8.decode(clearBytes);
  }

  @override
  Future<String> encrypt({
    required String plaintext,
    required Object secretKey,
    required String keyId,
  }) async {
    final itemKey = _readItemKey(secretKey);

    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: itemKey,
    );

    if (secretKey is VaultSession && secretKey.isV2) {
      return jsonEncode({
        'v': _version2,
        'keyId': keyId,
        'kdf': secretKey.kdf,
        'dek_wrap': secretKey.dekWrap,
        'payload': _payloadFromSecretBox(secretBox),
      });
    }

    return jsonEncode({
      'version': _version,
      'algorithm': 'aes-256-gcm',
      'keyId': keyId,
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
  }

  SecretKey _readItemKey(Object value) {
    if (value is VaultSession) {
      return value.secretKey;
    }
    if (value is SecretKey) {
      return value;
    }
    throw ArgumentError.value(
      value,
      'secretKey',
      'Expected SecretKey or VaultSession.',
    );
  }

  Map<String, dynamic> _payloadFromSecretBox(SecretBox box) {
    return {
      'alg': 'AES-256-GCM',
      'nonce_b64': base64Encode(box.nonce),
      'ciphertext_b64': base64Encode(box.cipherText),
      'tag_b64': base64Encode(box.mac.bytes),
    };
  }

  SecretBox _secretBoxFromPayload(Map<String, dynamic> payload) {
    final ciphertext = payload['ciphertext_b64'] ?? payload['ciphertext'];
    final nonce = payload['nonce_b64'] ?? payload['nonce'];
    final tag = payload['tag_b64'] ?? payload['mac'];
    return SecretBox(
      base64Decode(ciphertext as String),
      nonce: base64Decode(nonce as String),
      mac: Mac(base64Decode(tag as String)),
    );
  }
}

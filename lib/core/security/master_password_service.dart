import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'master_password_record.dart';

class MasterPasswordService {
  MasterPasswordService();

  static const minimumLength = 12;
  static const _recordVersion = 1;
  static const _verifierIterations = 210000;
  static const _encryptionIterations = 210000;
  static const _keyBits = 256;

  String? validate(String password) {
    if (password.length < minimumLength) {
      return 'Usa al menos $minimumLength caracteres.';
    }

    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSymbol = password.contains(RegExp(r'[^A-Za-z0-9]'));

    if (!hasUpper || !hasLower || !hasDigit || !hasSymbol) {
      return 'Combina mayusculas, minusculas, numeros y simbolos.';
    }

    return null;
  }

  Future<MasterPasswordRecord> createRecord(String password) async {
    final verifierSalt = _randomBytes(16);
    final encryptionSalt = _randomBytes(16);
    final verifier = await _deriveVerifier(
      password: password,
      salt: verifierSalt,
      iterations: _verifierIterations,
    );

    return MasterPasswordRecord(
      version: _recordVersion,
      verifierIterations: _verifierIterations,
      verifierSalt: base64Encode(verifierSalt),
      verifier: base64Encode(verifier),
      encryptionIterations: _encryptionIterations,
      encryptionSalt: base64Encode(encryptionSalt),
      keyId: base64UrlEncode(_randomBytes(12)),
      createdAt: DateTime.now().toUtc(),
    );
  }

  Future<bool> verify({
    required MasterPasswordRecord record,
    required String password,
  }) async {
    final verifier = await _deriveVerifier(
      password: password,
      salt: base64Decode(record.verifierSalt),
      iterations: record.verifierIterations,
    );

    return _constantTimeEquals(verifier, base64Decode(record.verifier));
  }

  Future<SecretKey> deriveVaultKey({
    required MasterPasswordRecord record,
    required String password,
  }) {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: record.encryptionIterations,
      bits: _keyBits,
    );

    return algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: base64Decode(record.encryptionSalt),
    );
  }

  String generateSessionSeed() {
    return base64UrlEncode(_randomBytes(32));
  }

  Future<List<int>> _deriveVerifier({
    required String password,
    required List<int> salt,
    required int iterations,
  }) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: _keyBits,
    );

    final secretKey = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    return secretKey.extractBytes();
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }

    var diff = 0;
    for (var index = 0; index < left.length; index++) {
      diff |= left[index] ^ right[index];
    }

    return diff == 0;
  }
}

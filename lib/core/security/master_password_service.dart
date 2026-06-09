import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'master_password_record.dart';

class MasterPasswordService {
  MasterPasswordService({
    int verifierIterations = _defaultIterations,
    int encryptionIterations = _defaultIterations,
    int argon2MemoryKiB = _defaultArgon2MemoryKiB,
    int argon2Parallelism = _defaultArgon2Parallelism,
    bool useFastTestKdf = false,
  })  : assert(
          !useFastTestKdf || _isRunningInFlutterTest(),
          'useFastTestKdf is only valid inside flutter_test. Use the .test() '
          'factory or guard the caller explicitly.',
        ),
        _verifierIterations = verifierIterations,
        _encryptionIterations = encryptionIterations,
        _argon2MemoryKiB = argon2MemoryKiB,
        _argon2Parallelism = argon2Parallelism,
        _useFastTestKdf = useFastTestKdf;

  factory MasterPasswordService.test() {
    return MasterPasswordService(
      verifierIterations: 1,
      encryptionIterations: 1,
      argon2MemoryKiB: 1024,
      useFastTestKdf: true,
    );
  }

  static const minimumLength = 12;
  static const _recordVersion = 2;
  static const _defaultIterations = 3;
  static const _keyBytes = 32;
  static const _defaultArgon2MemoryKiB = 65536;
  static const _defaultArgon2Parallelism = 1;
  static final _wrapAlgorithm = AesGcm.with256bits();

  /// True only when running under `package:flutter_test`. The Dart VM
  /// does not expose a "is this a test" flag, but the flutter test
  /// runner sets `FLUTTER_TEST=true` in the process environment, which
  /// is enough to keep the test KDF from ever being constructed in
  /// production.
  static bool _isRunningInFlutterTest() {
    final value = Platform.environment['FLUTTER_TEST'];
    return value == 'true' || value == '1';
  }

  final int _verifierIterations;
  final int _encryptionIterations;
  final int _argon2MemoryKiB;
  final int _argon2Parallelism;
  final bool _useFastTestKdf;

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
    final kekSalt = _randomBytes(16);
    final verifier = await _deriveVerifier(
      password: password,
      salt: verifierSalt,
      iterations: _verifierIterations,
    );
    final kek = await _deriveKek(
      password: password,
      salt: kekSalt,
      iterations: _encryptionIterations,
      memoryKiB: _argon2MemoryKiB,
      parallelism: _argon2Parallelism,
      outputBytes: _keyBytes,
    );
    final dekBytes = _randomBytes(_keyBytes);
    final dekWrap = await _wrapDek(dekBytes: dekBytes, kek: kek);
    final kdf = {
      'name': 'argon2id',
      'salt_b64': base64Encode(kekSalt),
      'memory_kib': _argon2MemoryKiB,
      'iterations': _encryptionIterations,
      'parallelism': _argon2Parallelism,
      'dk_len': _keyBytes,
    };

    return MasterPasswordRecord(
      version: _recordVersion,
      verifierIterations: _verifierIterations,
      verifierSalt: base64Encode(verifierSalt),
      verifier: base64Encode(verifier),
      encryptionIterations: _encryptionIterations,
      encryptionSalt: base64Encode(kekSalt),
      keyId: base64UrlEncode(_randomBytes(12)),
      createdAt: DateTime.now().toUtc(),
      kdf: kdf,
      dekWrap: dekWrap,
    );
  }

  Future<bool> verify({
    required MasterPasswordRecord record,
    required String password,
  }) async {
    final verifier = record.version < _recordVersion
        ? await _deriveLegacyVerifier(
            password: password,
            salt: base64Decode(record.verifierSalt),
            iterations: record.verifierIterations,
          )
        : await _deriveVerifier(
            password: password,
            salt: base64Decode(record.verifierSalt),
            iterations: record.verifierIterations,
          );

    return _constantTimeEquals(verifier, base64Decode(record.verifier));
  }

  Future<SecretKey> deriveVaultKey({
    required MasterPasswordRecord record,
    required String password,
  }) async {
    if (record.version < _recordVersion ||
        record.kdf == null ||
        record.dekWrap == null) {
      return _deriveLegacyVaultKey(record: record, password: password);
    }

    final kdf = record.kdf!;
    final dekWrap = record.dekWrap!;
    final kek = await _deriveKek(
      password: password,
      salt: base64Decode(kdf['salt_b64'] as String),
      iterations: kdf['iterations'] as int,
      memoryKiB: kdf['memory_kib'] as int,
      parallelism: kdf['parallelism'] as int,
      outputBytes: kdf['dk_len'] as int,
    );
    final dekBytes = await _unwrapDek(dekWrap: dekWrap, kek: kek);
    return SecretKey(dekBytes);
  }

  Future<SecretKey> _deriveLegacyVaultKey({
    required MasterPasswordRecord record,
    required String password,
  }) {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: record.encryptionIterations,
      bits: _keyBytes * 8,
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
    if (_useFastTestKdf) {
      return _deriveFastTestBytes(
        password: password,
        salt: salt,
        iterations: iterations,
      );
    }

    final algorithm = Argon2id(
      memory: _argon2MemoryKiB,
      parallelism: _argon2Parallelism,
      iterations: iterations,
      hashLength: _keyBytes,
    );

    final secretKey = await algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    return secretKey.extractBytes();
  }

  Future<List<int>> _deriveLegacyVerifier({
    required String password,
    required List<int> salt,
    required int iterations,
  }) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: _keyBytes * 8,
    );
    final secretKey = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  Future<SecretKey> _deriveKek({
    required String password,
    required List<int> salt,
    required int iterations,
    required int memoryKiB,
    required int parallelism,
    required int outputBytes,
  }) {
    if (_useFastTestKdf) {
      return Future.value(
        SecretKey(
          _deriveFastTestBytes(
            password: password,
            salt: salt,
            iterations: iterations,
          ).take(outputBytes).toList(growable: false),
        ),
      );
    }

    final algorithm = Argon2id(
      memory: memoryKiB,
      parallelism: parallelism,
      iterations: iterations,
      hashLength: outputBytes,
    );
    return algorithm.deriveKeyFromPassword(password: password, nonce: salt);
  }

  Future<Map<String, dynamic>> _wrapDek({
    required List<int> dekBytes,
    required SecretKey kek,
  }) async {
    final box = await _wrapAlgorithm.encrypt(dekBytes, secretKey: kek);
    return {
      'alg': 'AES-256-GCM',
      'nonce_b64': base64Encode(box.nonce),
      'ciphertext_b64': base64Encode(box.cipherText),
      'tag_b64': base64Encode(box.mac.bytes),
    };
  }

  Future<List<int>> _unwrapDek({
    required Map<String, dynamic> dekWrap,
    required SecretKey kek,
  }) {
    if (dekWrap['alg'] != 'AES-256-GCM') {
      throw StateError('Unsupported DEK wrap algorithm.');
    }
    return _wrapAlgorithm.decrypt(
      SecretBox(
        base64Decode(dekWrap['ciphertext_b64'] as String),
        nonce: base64Decode(dekWrap['nonce_b64'] as String),
        mac: Mac(base64Decode(dekWrap['tag_b64'] as String)),
      ),
      secretKey: kek,
    );
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  List<int> _deriveFastTestBytes({
    required String password,
    required List<int> salt,
    required int iterations,
  }) {
    final seed = <int>[
      ...utf8.encode(password),
      ...salt,
      iterations & 0xff,
      (iterations >> 8) & 0xff,
    ];
    final output = List<int>.filled(_keyBytes, 0);
    for (var round = 0; round < iterations + 1; round += 1) {
      for (var index = 0; index < output.length; index += 1) {
        final value = seed[(index + round) % seed.length];
        output[index] = (output[index] + value + index + round) & 0xff;
      }
    }
    return output;
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

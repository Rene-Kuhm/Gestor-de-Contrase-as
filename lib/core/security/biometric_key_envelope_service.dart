import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secure_storage_service.dart';

/// Envelope pattern: stores the vault DEK wrapped with a key that lives
/// behind platform-backed protection (Keychain on iOS, Keystore-backed
/// EncryptedSharedPreferences on Android).
///
/// On unlock we read the envelope, then unwrap the DEK after the user
/// authenticates with biometrics. The unwrapped DEK is fed into the
/// VaultSession the same way a password-derived key would be, so the
/// crypto service treats biometric and password unlocks uniformly.
///
/// Why an envelope and not the raw DEK:
/// - We never persist the DEK in clear, even on disk.
/// - Losing the secure storage (e.g. OS reinstall) means the envelope
///   is gone too, so the user is forced back to the master password.
/// - When the user changes the master password we re-wrap the DEK
///   through the same `wrapDek` path used for password keys, so the
///   envelope and the master password record stay in lock-step.
///
/// The actual `envelopeKey` can be implemented in two shapes:
///   - A direct AES-256 SecretKey (e.g. on a target without hardware
///     backing, like web or desktop).
///   - An RSA-2048 / Android KeyStore-backed keypair, where the
///     provider uses the public key to RSA-encrypt an AES-256 seed
///     and the platform BiometricPrompt unlocks the private key to
///     decrypt it on demand. The provider hides the difference behind
///     the same `SecretKey` surface.
class BiometricKeyEnvelopeService {
  BiometricKeyEnvelopeService({
    required SecureStorageService storage,
    Random? random,
  })  : _storage = storage,
        _random = random ?? Random.secure();

  /// Storage key for the wrapped DEK envelope. This blob is NOT itself
  /// protected by biometrics — it can be read from disk. It only becomes
  /// useful once the platform keychain/keystore gate is opened.
  static const envelopeStorageKey = 'vault_biometric_envelope_v1';

  final SecureStorageService _storage;
  final Random _random;
  static final AesGcm _algorithm = AesGcm.with256bits();
  static const _keyBytes = 32;

  /// Wraps [dekBytes] with [envelopeKey] and persists the result.
  /// The envelope on disk is bound to:
  ///   - a fresh salt per wrap, and
  ///   - a fresh nonce per wrap (so two enrollments are not identical).
  Future<void> enroll({
    required Uint8List dekBytes,
    required SecretKey envelopeKey,
  }) async {
    final salt = _randomBytes(_keyBytes);
    final derivedKey = await _hkdf(envelopeKey, salt);
    final box = await _algorithm.encrypt(dekBytes, secretKey: derivedKey);

    final envelope = {
      'version': 1,
      'alg': 'AES-256-GCM',
      'salt_b64': base64Encode(salt),
      'nonce_b64': base64Encode(box.nonce),
      'ciphertext_b64': base64Encode(box.cipherText),
      'tag_b64': base64Encode(box.mac.bytes),
    };

    await _storage.save(envelopeStorageKey, jsonEncode(envelope));
  }

  /// Unwraps the persisted envelope with [envelopeKey] and returns the
  /// original DEK bytes. Throws if no envelope exists.
  Future<Uint8List> unwrap({required SecretKey envelopeKey}) async {
    final raw = await _storage.read(envelopeStorageKey);
    if (raw == null || raw.isEmpty) {
      throw StateError('No biometric envelope is enrolled for this vault.');
    }

    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    if (envelope['alg'] != 'AES-256-GCM') {
      throw StateError('Unsupported biometric envelope algorithm.');
    }

    final salt = base64Decode(envelope['salt_b64'] as String);
    final derivedKey = await _hkdf(envelopeKey, salt);
    final box = SecretBox(
      base64Decode(envelope['ciphertext_b64'] as String),
      nonce: base64Decode(envelope['nonce_b64'] as String),
      mac: Mac(base64Decode(envelope['tag_b64'] as String)),
    );

    return Uint8List.fromList(
      await _algorithm.decrypt(box, secretKey: derivedKey),
    );
  }

  /// True if and only if an envelope is currently persisted. A truthy
  /// value does NOT prove the platform keychain/keystore is still
  /// available; we just know the wrapped DEK is on disk.
  Future<bool> isEnrolled() async {
    final raw = await _storage.read(envelopeStorageKey);
    return raw != null && raw.isNotEmpty;
  }

  /// Removes the envelope from disk. Safe to call when nothing exists.
  Future<void> clear() async {
    await _storage.delete(envelopeStorageKey);
  }

  Future<SecretKey> _hkdf(SecretKey inputKey, Uint8List salt) async {
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: _keyBytes,
    );
    return hkdf.deriveKey(
      secretKey: inputKey,
      nonce: salt,
    );
  }

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }
}

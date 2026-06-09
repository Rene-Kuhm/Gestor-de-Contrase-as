import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'biometric_unlock_service.dart';
import 'secure_storage_service.dart';

/// Android KeyStore-backed implementation of [BiometricEnvelopeKeyProvider].
///
/// Generates an RSA-2048 keypair in the AndroidKeyStore provider with
/// `setUserAuthenticationRequired(true)`. The private half is
/// hardware-backed and never leaves the secure element; using it
/// requires a fresh `BiometricPrompt`.
///
/// The flow the controller sees is symmetric:
///   * [acquireEnvelopeKey] runs *at enrollment time* with no prompt
///     (the public key is a public key). It returns a real
///     `SecretKey` backed by a freshly generated AES-256 seed.
///   * [releaseEnvelopeKey] runs *at unlock time* behind a
///     `BiometricPrompt` and returns the same `SecretKey`. The
///     platform is the only place that touches the private key.
///
/// The RSA-encrypted seed is persisted in [SecureStorageService] on
/// enrollment so the unlock side can hand it back to the platform.
class AndroidKeystoreEnvelopeKeyProvider
    implements BiometricEnvelopeKeyProvider {
  AndroidKeystoreEnvelopeKeyProvider({
    required SecureStorageService storage,
    MethodChannel? keystoreChannel,
    MethodChannel? biometricChannel,
    Random? random,
  })  : _storage = storage,
        _keystoreChannel =
            keystoreChannel ?? const MethodChannel(keystoreChannelName),
        _biometricChannel =
            biometricChannel ?? const MethodChannel(biometricChannelName),
        _random = random ?? Random.secure();

  static const keystoreChannelName = 'com.insyd.vaulta/keystore';
  static const biometricChannelName = 'com.insyd.vaulta/biometric';
  static const _encryptedSeedKey = 'vaulta_biometric_envelope_seed_v1';

  final SecureStorageService _storage;
  final MethodChannel _keystoreChannel;
  final MethodChannel _biometricChannel;
  final Random _random;

  @override
  Future<SecretKey?> acquireEnvelopeKey() async {
    if (!Platform.isAndroid) {
      debugPrint('[Vaulta/KeyStore] acquire skipped: not Android');
      return null;
    }
    if (!await isHardwareBackedBiometricAvailable()) {
      debugPrint('[Vaulta/KeyStore] acquire skipped: hardware-backed '
          'biometric not available on this device');
      return null;
    }

    try {
      await ensureKey();
    } on PlatformException catch (error) {
      debugPrint('[Vaulta/KeyStore] ensureKey failed: ${error.code} '
          '${error.message}');
      return null;
    } catch (error, stack) {
      debugPrint('[Vaulta/KeyStore] ensureKey unexpected: $error\n$stack');
      return null;
    }

    final seed = _randomBytes(32);
    final rsaEncrypted = await rsaEncryptSeed(seed);
    if (rsaEncrypted == null) {
      debugPrint('[Vaulta/KeyStore] rsaEncrypt returned null');
      return null;
    }

    // Persist the RSA-encrypted seed for the unlock path. We never
    // persist the plaintext seed.
    await _storage.save(
      _encryptedSeedKey,
      String.fromCharCodes(rsaEncrypted),
    );

    debugPrint('[Vaulta/KeyStore] acquire OK: '
        'envelope seed encrypted and persisted (${rsaEncrypted.length} bytes)');
    return SecretKey(seed);
  }

  @override
  Future<SecretKey?> releaseEnvelopeKey() async {
    if (!Platform.isAndroid) return null;
    if (!await isHardwareBackedBiometricAvailable()) {
      debugPrint('[Vaulta/KeyStore] release skipped: hardware not available');
      return null;
    }

    final stored = await _storage.read(_encryptedSeedKey);
    if (stored == null || stored.isEmpty) {
      debugPrint('[Vaulta/KeyStore] release skipped: no encrypted seed on disk');
      return null;
    }
    final ciphertext = Uint8List.fromList(
      stored.codeUnits,
    );

    final seed = await rsaDecryptSeedAuthorized(ciphertext);
    if (seed == null) {
      debugPrint('[Vaulta/KeyStore] release: rsaDecrypt returned null '
          '(user cancelled or platform rejected the private key)');
      return null;
    }
    debugPrint('[Vaulta/KeyStore] release OK: seed recovered '
        '(${seed.length} bytes)');
    return SecretKey(seed);
  }

  /// True if the platform reports the biometric-bound RSA key is
  /// available. We probe with `isAvailable` rather than calling
  /// `ensureKey` here, because we do not want to create the key
  /// until the user explicitly enrolls.
  Future<bool> isHardwareBackedBiometricAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _keystoreChannel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Generates the hardware-backed RSA keypair. Idempotent.
  Future<String> ensureKey() async {
    final alias = await _keystoreChannel.invokeMethod<String>('ensureKey');
    return alias ?? '';
  }

  /// Wipes the hardware-backed RSA keypair and the encrypted seed.
  /// The next call to `acquireEnvelopeKey` will return null until the
  /// user re-enrolls.
  Future<void> deleteKey() async {
    if (!Platform.isAndroid) return;
    try {
      await _keystoreChannel.invokeMethod<void>('deleteKey');
    } on PlatformException {
      // Best-effort: a missing alias is fine.
    }
    await _storage.delete(_encryptedSeedKey);
  }

  Future<Uint8List?> rsaEncryptSeed(Uint8List plaintext) async {
    if (!Platform.isAndroid) return null;
    final result = await _keystoreChannel.invokeMethod<Uint8List>(
      'rsaEncrypt',
      {'plaintext': plaintext},
    );
    return result;
  }

  /// Drives a full biometric unlock round-trip:
  ///   1. Asks the platform to open a BiometricPrompt.
  ///   2. The platform returns the same ciphertext (as a "go ahead"
  ///      signal — the private key is now authorized for this process).
  ///   3. We then invoke `rsaDecryptAuthorized` on the keystore channel
  ///      to actually unwrap the seed.
  Future<Uint8List?> rsaDecryptSeedAuthorized(Uint8List ciphertext) async {
    if (!Platform.isAndroid) return null;
    try {
      final authorized = await _biometricChannel.invokeMethod<Uint8List>(
        'requestDecryptAuthorization',
        {'ciphertext': ciphertext},
      );
      if (authorized == null) return null;

      final plaintext = await _keystoreChannel.invokeMethod<Uint8List>(
        'rsaDecryptAuthorized',
        {'ciphertext': authorized},
      );
      return plaintext;
    } on PlatformException catch (error) {
      if (error.code == 'USER_CANCELLED') {
        return null;
      }
      rethrow;
    }
  }

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }
}

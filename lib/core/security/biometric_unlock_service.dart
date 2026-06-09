import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'biometric_auth_service.dart';
import 'biometric_key_envelope_service.dart';
import 'master_password_record.dart';
import 'secure_storage_service.dart';
import 'vault_session.dart';

/// Outcome of a biometric unlock attempt. Distinguishes "user canceled",
/// "biometrics not enrolled", "no envelope on disk", and "platform
/// rejected the auth" from "we recovered the DEK and built a session".
sealed class BiometricUnlockOutcome {
  const BiometricUnlockOutcome();
}

class BiometricUnlockSuccess extends BiometricUnlockOutcome {
  const BiometricUnlockSuccess(this.session);
  final VaultSession session;
}

class BiometricUnlockRejected extends BiometricUnlockOutcome {
  const BiometricUnlockRejected(this.reason);
  final String reason;
}

class BiometricUnlockUnavailable extends BiometricUnlockOutcome {
  const BiometricUnlockUnavailable(this.reason);
  final String reason;
}

/// Orchestrates the biometric unlock path. The flow is:
///   1. Confirm the platform says biometrics are available and enrolled.
///   2. Confirm a wrapped DEK envelope exists in secure storage.
///   3. Prompt the user for biometrics via the platform gate.
///   4. Derive an envelope key from the platform-protected slot, unwrap
///      the DEK, and return a VaultSession the same shape as a
///      password-derived session would produce.
///
/// On non-mobile targets (web, desktop) this still runs, but step 1
/// reports the platform as unsupported and the service degrades to
/// "biometrics not available on this target" without exposing the
/// caller to a native plugin they cannot load.
class BiometricUnlockService {
  BiometricUnlockService({
    required SecureStorageService storage,
    required BiometricAuthService biometricAuthService,
    required BiometricKeyEnvelopeService envelopeService,
    BiometricEnvelopeKeyProvider? envelopeKeyProvider,
  }) : _storage = storage,
       _biometricAuthService = biometricAuthService,
       _envelopeService = envelopeService,
       _envelopeKeyProvider = envelopeKeyProvider ?? _defaultKeyProvider;

  static const envelopeKeySlotKey = 'vault_biometric_envelope_key_slot_v1';

  final SecureStorageService _storage;
  final BiometricAuthService _biometricAuthService;
  final BiometricKeyEnvelopeService _envelopeService;
  final BiometricEnvelopeKeyProvider _envelopeKeyProvider;

  /// Exposed so the controller can hand the same provider to its
  /// enrollment helper. Hiding this would force every callsite to
  /// build a parallel service.
  BiometricEnvelopeKeyProvider get envelopeKeyProvider => _envelopeKeyProvider;

  /// True when the platform reports biometrics are usable AND an
  /// envelope is enrolled on disk. The controller uses this to decide
  /// whether to surface the biometric unlock option.
  Future<bool> canAttemptUnlock() async {
    if (!await _isBiometricCapableTarget()) {
      return false;
    }
    final availability = await _biometricAuthService.getAvailability();
    if (!availability.canAuthenticate || !availability.hasEnrolledBiometrics) {
      return false;
    }
    return _envelopeService.isEnrolled();
  }

  /// Performs the full biometric unlock flow and returns either a
  /// session or a structured failure.
  Future<BiometricUnlockOutcome> unlock({
    required MasterPasswordRecord record,
  }) async {
    if (record.version < 2 || record.kdf == null || record.dekWrap == null) {
      return const BiometricUnlockUnavailable(
        'Tu master password es de una version anterior. Ingresa la contrasena para re-cifrar y luego podras activar biometria.',
      );
    }

    if (!await _isBiometricCapableTarget()) {
      return const BiometricUnlockUnavailable(
        'La biometria no esta disponible en este dispositivo.',
      );
    }

    final availability = await _biometricAuthService.getAvailability();
    if (!availability.canAuthenticate) {
      return const BiometricUnlockUnavailable(
        'La biometria no esta disponible en este dispositivo.',
      );
    }
    if (!availability.hasEnrolledBiometrics) {
      return const BiometricUnlockUnavailable(
        'No hay biometria registrada. Configura Face ID, Touch ID o huella y reintenta.',
      );
    }

    if (!await _envelopeService.isEnrolled()) {
      return const BiometricUnlockUnavailable(
        'Todavia no activaste el desbloqueo biometrico para este vault.',
      );
    }

    final authed = await _biometricAuthService.authenticateForUnlock();
    if (!authed) {
      return const BiometricUnlockRejected(
        'No pudimos verificar tu identidad. Ingresa la master password.',
      );
    }

    final envelopeKey = await _envelopeKeyProvider.releaseEnvelopeKey();
    if (envelopeKey == null) {
      return const BiometricUnlockRejected(
        'La plataforma rechazo la clave biometrica. Re-enrola biometria o usa la master password.',
      );
    }

    try {
      final dekBytes = await _envelopeService.unwrap(envelopeKey: envelopeKey);
      final session = VaultSession.v2(
        keyId: record.keyId,
        secretKey: SecretKey(dekBytes),
        kdf: record.kdf!,
        dekWrap: record.dekWrap!,
      );
      return BiometricUnlockSuccess(session);
    } on SecretBoxAuthenticationError {
      return const BiometricUnlockRejected(
        'La plataforma devolvio una clave inconsistente. Ingresa la master password y re-enrola biometria.',
      );
    } catch (error) {
      return BiometricUnlockRejected(
        'No pudimos recuperar tu sesion con biometria. Ingresa la master password. ($error)',
      );
    }
  }

  /// Wipes the envelope and the platform key slot reference. Called
  /// when biometrics are turned off, the master password changes, or
  /// a biometric unlock fails in a way that should not leave a stale
  /// envelope on disk.
  Future<void> invalidate() async {
    await _envelopeService.clear();
    await _storage.delete(envelopeKeySlotKey);
  }

  Future<bool> _isBiometricCapableTarget() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return true;
    }
    return false;
  }

  /// Default provider for non-Android targets (web, desktop, iOS in
  /// the future). It always reports that no envelope key is
  /// available, which makes the unlock service report "biometrics
  /// not available" instead of crashing.
  static final BiometricEnvelopeKeyProvider _defaultKeyProvider =
      _NoopEnvelopeKeyProvider();
}

class _NoopEnvelopeKeyProvider implements BiometricEnvelopeKeyProvider {
  @override
  Future<SecretKey?> acquireEnvelopeKey() async => null;

  @override
  Future<SecretKey?> releaseEnvelopeKey() async => null;
}

/// Abstract source for the platform-protected key that wraps the DEK.
///
/// Implementations must return a [SecretKey] that can be used
/// directly with `package:cryptography` (i.e. extractable bytes) or
/// null if the platform does not have a usable key slot. The
/// envelope service treats the returned key as opaque: it feeds it
/// into HKDF-SHA256 and uses the result to AES-256-GCM encrypt the
/// DEK.
///
/// On Android the provider is expected to:
///   1. Generate or load the hardware-backed RSA-2048 keypair.
///   2. Generate a fresh random AES-256 seed (the actual envelope
///      key).
///   3. RSA-OAEP-encrypt the seed with the public key and store the
///      ciphertext in secure storage (so it survives app restarts).
///   4. Return the *plaintext seed* to the envelope service.
///
/// On unlock, the provider's mirror [releaseKey] is given the same
/// ciphertext to RSA-decrypt with the private key (which requires a
/// fresh BiometricPrompt), yielding the same seed bytes. The two
/// halves of the round-trip are intentionally separate so that
/// enrollment can happen silently (no prompt) while unlock always
/// prompts.
abstract interface class BiometricEnvelopeKeyProvider {
  /// Returns the AES-256 envelope key as a usable [SecretKey], or
  /// null when the platform cannot provide one (no hardware backing,
  /// user has not enrolled biometrics, etc.).
  Future<SecretKey?> acquireEnvelopeKey();

  /// Returns the AES-256 envelope key after a fresh biometric
  /// authorization has been collected. Implementations are expected
  /// to block on the BiometricPrompt and only resolve once the user
  /// has authenticated.
  Future<SecretKey?> releaseEnvelopeKey();
}

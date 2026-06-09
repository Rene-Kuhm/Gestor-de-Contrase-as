import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'biometric_auth_service.dart';

/// Structured platform answer to "what can the biometric gate do
/// right now?". Mirrors the map returned by
/// `MainActivity.probeAvailability()` on Android.
class NativeBiometricCapability {
  const NativeBiometricCapability({
    required this.canUseStrong,
    required this.canUseWeak,
    required this.canUseStrongOrCredential,
    required this.canUseDeviceCredential,
    required this.strongErrorCode,
    required this.weakErrorCode,
    required this.strongOrCredentialErrorCode,
    required this.deviceCredentialErrorCode,
  });

  /// The user has a class-3 biometric enrolled AND the platform
  /// is willing to open a BiometricPrompt for it right now. Fingerprint
  /// on a TEE-equipped device is the typical case.
  final bool canUseStrong;

  /// The user has a class-2 biometric enrolled (face unlock on
  /// mid-range devices, typically). Not used by the current prompt
  /// but surfaced for diagnostics.
  final bool canUseWeak;

  /// True when the user can either use a strong biometric OR fall
  /// back to the device PIN / pattern / password. This is the flag
  /// the Dart side uses to decide whether the unlock button is
  /// usable.
  final bool canUseStrongOrCredential;

  /// True when the device has a PIN/pattern/password set but no
  /// biometric. The KeyStore-backed flow still cannot run without a
  /// biometric-bound RSA key, so this only matters for fallbacks.
  final bool canUseDeviceCredential;

  /// Raw platform code for the strong probe. Stable across releases
  /// (these are the BiometricManager.* constants on Android).
  final int strongErrorCode;
  final int weakErrorCode;
  final int strongOrCredentialErrorCode;
  final int deviceCredentialErrorCode;

  /// The most actionable code that explains why the user cannot
  /// unlock with biometrics right now. Returns null when the
  /// platform is willing to open a prompt.
  int? get blockingCode {
    if (canUseStrongOrCredential) return null;
    if (strongOrCredentialErrorCode != 0) {
      return strongOrCredentialErrorCode;
    }
    if (strongErrorCode != 0) return strongErrorCode;
    return weakErrorCode;
  }

  /// True when the only reason the gate is closed is that no
  /// biometric is enrolled — i.e. the user CAN fix it from the
  /// system settings. This is the flag the UI uses to render the
  /// "Set up biometrics" call-to-action.
  bool get needsEnrollment =>
      !canUseStrongOrCredential &&
      (strongOrCredentialErrorCode == 11 /* NONE_ENROLLED */ ||
          strongErrorCode == 11 ||
          weakErrorCode == 11);

  static const empty = NativeBiometricCapability(
    canUseStrong: false,
    canUseWeak: false,
    canUseStrongOrCredential: false,
    canUseDeviceCredential: false,
    strongErrorCode: -1,
    weakErrorCode: -1,
    strongOrCredentialErrorCode: -1,
    deviceCredentialErrorCode: -1,
  );
}

/// Android-only [BiometricAuthService] backed by the platform
/// `MethodChannel`s. The previous implementation mixed `local_auth`
/// (for the `canCheckBiometrics` gate) with a custom biometric
/// channel (for the actual prompt + KeyStore operation). The two
/// sources could disagree — e.g. `local_auth` would report
/// `canCheckBiometrics: true` while the native channel would fail
/// with `BIOMETRIC_ERROR_NONE_ENROLLED` — and the unlock button
/// would silently disappear.
///
/// This service uses the same native channel as the prompt itself,
/// so the gate and the prompt are guaranteed to agree.
///
/// The `authenticateForUnlock` method is intentionally a passive
/// availability check, not a prompt: the actual `BiometricPrompt` is
/// opened by [AndroidKeystoreEnvelopeKeyProvider.releaseEnvelopeKey]
/// which is invoked one step later in `BiometricUnlockService.unlock`.
/// This avoids the double-prompt bug where the user got one
/// `local_auth` prompt followed by a second `BiometricPrompt` for
/// the KeyStore operation.
class NativeBiometricAuthService implements BiometricAuthService {
  NativeBiometricAuthService({
    MethodChannel? biometricChannel,
  }) : _channel = biometricChannel ??
            const MethodChannel('com.insyd.vaulta/biometric');

  final MethodChannel _channel;

  @override
  Future<BiometricAvailability> getAvailability() async {
    if (!Platform.isAndroid) {
      return const BiometricAvailability(
        deviceSupported: false,
        canCheckBiometrics: false,
        availableBiometrics: <BiometricType>[],
      );
    }

    try {
      final cap = await probeCapability();
      if (!cap.canUseStrongOrCredential && !cap.canUseWeak) {
        return const BiometricAvailability(
          deviceSupported: false,
          canCheckBiometrics: false,
          availableBiometrics: <BiometricType>[],
        );
      }

      final biometrics = <BiometricType>[];
      if (cap.canUseStrong) {
        biometrics.add(BiometricType.strong);
        biometrics.add(BiometricType.fingerprint);
      }
      if (cap.canUseWeak) {
        biometrics.add(BiometricType.weak);
        biometrics.add(BiometricType.face);
      }
      return BiometricAvailability(
        deviceSupported: true,
        canCheckBiometrics: biometrics.isNotEmpty,
        availableBiometrics: biometrics,
      );
    } on PlatformException catch (error, stack) {
      debugPrint('[Vaulta/Biometric] probe failed: ${error.code} ${error.message}\n$stack');
      return const BiometricAvailability(
        deviceSupported: false,
        canCheckBiometrics: false,
        availableBiometrics: <BiometricType>[],
      );
    } catch (error, stack) {
      debugPrint('[Vaulta/Biometric] probe unexpected: $error\n$stack');
      return const BiometricAvailability(
        deviceSupported: false,
        canCheckBiometrics: false,
        availableBiometrics: <BiometricType>[],
      );
    }
  }

  /// Returns the raw platform capability. The unlock screen uses
  /// [NativeBiometricCapability.needsEnrollment] to decide whether
  /// to render the "Set up biometrics" CTA.
  Future<NativeBiometricCapability> probeCapability() async {
    if (!Platform.isAndroid) return NativeBiometricCapability.empty;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'probeAvailability',
      );
      if (raw == null) return NativeBiometricCapability.empty;
      return NativeBiometricCapability(
        canUseStrong: raw['canUseStrong'] == true,
        canUseWeak: raw['canUseWeak'] == true,
        canUseStrongOrCredential: raw['canUseStrongOrCredential'] == true,
        canUseDeviceCredential: raw['canUseDeviceCredential'] == true,
        strongErrorCode: (raw['strongCode'] as num?)?.toInt() ?? -1,
        weakErrorCode: (raw['weakCode'] as num?)?.toInt() ?? -1,
        strongOrCredentialErrorCode:
            (raw['strongOrCredentialCode'] as num?)?.toInt() ?? -1,
        deviceCredentialErrorCode:
            (raw['deviceCredentialCode'] as num?)?.toInt() ?? -1,
      );
    } on PlatformException catch (error, stack) {
      debugPrint('[Vaulta/Biometric] probe failed: ${error.code} ${error.message}\n$stack');
      return NativeBiometricCapability.empty;
    } catch (error, stack) {
      debugPrint('[Vaulta/Biometric] probe unexpected: $error\n$stack');
      return NativeBiometricCapability.empty;
    }
  }

  /// Opens the system biometric-enrollment settings. Returns true
  /// if a settings activity was launched, false otherwise.
  Future<bool> openBiometricEnrollment() async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('openBiometricEnrollment');
      return ok ?? false;
    } on PlatformException catch (error, stack) {
      debugPrint('[Vaulta/Biometric] enroll intent failed: ${error.code} ${error.message}\n$stack');
      return false;
    }
  }

  /// Passive check: returns true if the platform can open a prompt
  /// right now (with strong biometric OR device credential). Does
  /// NOT show a prompt — the actual prompt is opened by the
  /// KeyStore provider a few lines of code later.
  @override
  Future<bool> authenticateForUnlock() async {
    if (!Platform.isAndroid) return false;
    final cap = await probeCapability();
    return cap.canUseStrongOrCredential;
  }
}

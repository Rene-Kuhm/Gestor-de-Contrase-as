import 'dart:io';

import 'package:local_auth/local_auth.dart';

class BiometricAvailability {
  const BiometricAvailability({
    required this.deviceSupported,
    required this.canCheckBiometrics,
    required this.availableBiometrics,
  });

  final bool deviceSupported;
  final bool canCheckBiometrics;
  final List<BiometricType> availableBiometrics;

  bool get canAuthenticate => deviceSupported || canCheckBiometrics;

  bool get hasEnrolledBiometrics => availableBiometrics.isNotEmpty;

  String get label {
    if (availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID / reconocimiento facial';
    }

    if (availableBiometrics.contains(BiometricType.fingerprint) ||
        availableBiometrics.contains(BiometricType.strong)) {
      return 'huella o biometria fuerte';
    }

    if (availableBiometrics.contains(BiometricType.weak)) {
      return 'biometria del dispositivo';
    }

    if (Platform.isWindows) {
      return 'Windows Hello';
    }

    return 'autenticacion del dispositivo';
  }
}

abstract interface class BiometricAuthService {
  Future<BiometricAvailability> getAvailability();

  Future<bool> authenticateForUnlock();
}

class LocalBiometricAuthService implements BiometricAuthService {
  LocalBiometricAuthService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricAvailability> getAvailability() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      final availableBiometrics = await _auth.getAvailableBiometrics();

      return BiometricAvailability(
        deviceSupported: deviceSupported,
        canCheckBiometrics: canCheckBiometrics,
        availableBiometrics: availableBiometrics,
      );
    } on LocalAuthException {
      return const BiometricAvailability(
        deviceSupported: false,
        canCheckBiometrics: false,
        availableBiometrics: [],
      );
    }
  }

  @override
  Future<bool> authenticateForUnlock() async {
    try {
      return await _auth.authenticate(
        localizedReason:
            'Desbloquea Vaulta para recuperar tu sesion protegida.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (error) {
      if (error.code == LocalAuthExceptionCode.noBiometricsEnrolled ||
          error.code == LocalAuthExceptionCode.noBiometricHardware ||
          error.code ==
              LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
          error.code == LocalAuthExceptionCode.temporaryLockout ||
          error.code == LocalAuthExceptionCode.biometricLockout ||
          error.code == LocalAuthExceptionCode.userCanceled) {
        return false;
      }

      rethrow;
    }
  }
}

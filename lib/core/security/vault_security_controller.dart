import 'package:flutter/foundation.dart';

import 'biometric_auth_service.dart';
import 'master_password_record.dart';
import 'master_password_service.dart';
import 'secure_storage_service.dart';

enum VaultSecurityStage { loading, onboarding, locked, unlocked }

class VaultSecurityController extends ChangeNotifier {
  VaultSecurityController({
    required SecureStorageService storage,
    required MasterPasswordService masterPasswordService,
    required BiometricAuthService biometricAuthService,
  }) : _storage = storage,
       _masterPasswordService = masterPasswordService,
       _biometricAuthService = biometricAuthService;

  static const masterPasswordRecordKey = 'vault_master_password_record';
  static const biometricEnabledKey = 'vault_biometric_enabled';
  static const biometricSeedKey = 'vault_biometric_seed';

  final SecureStorageService _storage;
  final MasterPasswordService _masterPasswordService;
  final BiometricAuthService _biometricAuthService;

  VaultSecurityStage _stage = VaultSecurityStage.loading;
  BiometricAvailability _biometricAvailability = const BiometricAvailability(
    deviceSupported: false,
    canCheckBiometrics: false,
    availableBiometrics: [],
  );
  bool _biometricEnabled = false;
  bool _busy = false;
  String? _message;

  VaultSecurityStage get stage => _stage;

  BiometricAvailability get biometricAvailability => _biometricAvailability;

  bool get biometricEnabled => _biometricEnabled;

  bool get busy => _busy;

  String? get message => _message;

  bool get isUnlocked => _stage == VaultSecurityStage.unlocked;

  bool get canOfferBiometricToggle =>
      _biometricAvailability.canAuthenticate &&
      _biometricAvailability.hasEnrolledBiometrics;

  bool get canUnlockWithBiometrics =>
      _stage == VaultSecurityStage.locked &&
      _biometricEnabled &&
      canOfferBiometricToggle;

  Future<void> initialize() async {
    _setBusy(true);
    _message = null;

    try {
      _biometricAvailability = await _biometricAuthService.getAvailability();
      _biometricEnabled = await _storage.read(biometricEnabledKey) == 'true';

      final record = await _readRecord();
      _stage = record == null
          ? VaultSecurityStage.onboarding
          : VaultSecurityStage.locked;
    } catch (_) {
      _stage = VaultSecurityStage.onboarding;
      _message =
          'No pudimos leer el estado seguro del dispositivo. Reinicia la configuracion.';
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<bool> createMasterPassword({
    required String password,
    required String confirmation,
    required bool enableBiometrics,
  }) async {
    final validationError = _masterPasswordService.validate(password);
    if (validationError != null) {
      _message = validationError;
      notifyListeners();
      return false;
    }

    if (password != confirmation) {
      _message = 'La confirmacion no coincide con la master password.';
      notifyListeners();
      return false;
    }

    if (enableBiometrics && !canOfferBiometricToggle) {
      _message = 'La biometria todavia no esta disponible en este dispositivo.';
      notifyListeners();
      return false;
    }

    return _runBusy(() async {
      final record = await _masterPasswordService.createRecord(password);
      await _storage.save(masterPasswordRecordKey, record.encode());
      await _persistBiometricPreference(enableBiometrics);

      _message =
          'Master password creada. Tu sesion local queda protegida por el sistema.';
      _stage = VaultSecurityStage.unlocked;
      return true;
    });
  }

  Future<bool> unlockWithPassword(String password) async {
    return _runBusy(() async {
      final record = await _readRecord();
      if (record == null) {
        _stage = VaultSecurityStage.onboarding;
        _message = 'Todavia no configuraste una master password.';
        return false;
      }

      final matches = await _masterPasswordService.verify(
        record: record,
        password: password,
      );

      if (!matches) {
        _message = 'La master password no coincide.';
        return false;
      }

      if (_biometricEnabled && canOfferBiometricToggle) {
        await _ensureBiometricSeed();
      }

      _message = 'Vaulta desbloqueada.';
      _stage = VaultSecurityStage.unlocked;
      return true;
    });
  }

  Future<bool> unlockWithBiometrics() async {
    if (!canUnlockWithBiometrics) {
      _message = 'La biometria no esta lista para este equipo.';
      notifyListeners();
      return false;
    }

    return _runBusy(() async {
      final seed = await _storage.read(biometricSeedKey);
      if (seed == null || seed.isEmpty) {
        _message =
            'Primero desbloquea con tu master password para vincular biometria.';
        return false;
      }

      final authenticated = await _biometricAuthService.authenticateForUnlock();
      if (!authenticated) {
        _message = 'Autenticacion cancelada o no disponible.';
        return false;
      }

      _message = 'Sesion restaurada con biometria del sistema.';
      _stage = VaultSecurityStage.unlocked;
      return true;
    });
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled && !canOfferBiometricToggle) {
      _message = 'No hay biometria configurada en este dispositivo.';
      notifyListeners();
      return;
    }

    await _runBusy(() async {
      await _persistBiometricPreference(enabled);
      _message = enabled
          ? 'Biometria activada para sesiones locales.'
          : 'Biometria desactivada. Solo queda la master password.';
      return true;
    });
  }

  Future<void> lock() async {
    _stage = VaultSecurityStage.locked;
    _message = 'Vaulta bloqueada.';
    notifyListeners();
  }

  Future<void> _persistBiometricPreference(bool enabled) async {
    _biometricEnabled = enabled;
    await _storage.save(biometricEnabledKey, enabled.toString());

    if (enabled) {
      await _ensureBiometricSeed();
      return;
    }

    await _storage.delete(biometricSeedKey);
  }

  Future<void> _ensureBiometricSeed() async {
    final currentSeed = await _storage.read(biometricSeedKey);
    if (currentSeed != null && currentSeed.isNotEmpty) {
      return;
    }

    await _storage.save(
      biometricSeedKey,
      _masterPasswordService.generateSessionSeed(),
    );
  }

  Future<MasterPasswordRecord?> _readRecord() async {
    final raw = await _storage.read(masterPasswordRecordKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return MasterPasswordRecord.decode(raw);
  }

  Future<bool> _runBusy(Future<bool> Function() action) async {
    _setBusy(true);
    try {
      return await action();
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  void _setBusy(bool value) {
    _busy = value;
  }
}

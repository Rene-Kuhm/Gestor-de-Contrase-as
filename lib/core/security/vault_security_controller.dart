import 'package:flutter/widgets.dart';

import 'biometric_auth_service.dart';
import 'master_password_record.dart';
import 'master_password_service.dart';
import 'secure_storage_service.dart';
import 'vault_session.dart';

typedef VaultRekeyEntries = Future<void> Function({
  required VaultSession sourceSession,
  required VaultSession targetSession,
});

enum VaultSecurityStage { loading, onboarding, locked, unlocked }

class VaultSecurityController extends ChangeNotifier {
  VaultSecurityController({
    required SecureStorageService storage,
    required MasterPasswordService masterPasswordService,
    required BiometricAuthService biometricAuthService,
    VaultRekeyEntries? rekeyEntries,
  }) : _storage = storage,
       _masterPasswordService = masterPasswordService,
       _biometricAuthService = biometricAuthService,
       _rekeyEntries = rekeyEntries ?? _unsupportedRekey;

  static const masterPasswordRecordKey = 'vault_master_password_record';
  static const biometricEnabledKey = 'vault_biometric_enabled';
  static const biometricSeedKey = 'vault_biometric_seed';
  static const autoLockOnBackgroundEnabledKey =
      'vault_auto_lock_on_background_enabled';

  final SecureStorageService _storage;
  final MasterPasswordService _masterPasswordService;
  final BiometricAuthService _biometricAuthService;
  final VaultRekeyEntries _rekeyEntries;

  VaultSecurityStage _stage = VaultSecurityStage.loading;
  BiometricAvailability _biometricAvailability = const BiometricAvailability(
    deviceSupported: false,
    canCheckBiometrics: false,
    availableBiometrics: [],
  );
  bool _biometricEnabled = false;
  bool _busy = false;
  String? _message;
  VaultSession? _vaultSession;
  bool _autoLockOnBackgroundEnabled = true;

  VaultSecurityStage get stage => _stage;

  BiometricAvailability get biometricAvailability => _biometricAvailability;

  bool get biometricEnabled => _biometricEnabled;

  bool get busy => _busy;

  String? get message => _message;

  VaultSession? get vaultSession => _vaultSession;

  bool get autoLockOnBackgroundEnabled => _autoLockOnBackgroundEnabled;

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
      _autoLockOnBackgroundEnabled =
          await _readBool(
            key: autoLockOnBackgroundEnabledKey,
            fallback: true,
          ) ??
          true;

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
      _vaultSession = VaultSession(
        keyId: record.keyId,
        secretKey: await _masterPasswordService.deriveVaultKey(
          record: record,
          password: password,
        ),
      );
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

      _vaultSession = VaultSession(
        keyId: record.keyId,
        secretKey: await _masterPasswordService.deriveVaultKey(
          record: record,
          password: password,
        ),
      );

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

      if (_vaultSession == null) {
        _message =
            'La biometria solo puede reabrir una sesion que ya derivo la clave del vault en memoria. Tras cerrar la app, volve a entrar con master password.';
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

  Future<void> lock({String? reason}) async {
    _vaultSession = null;
    _stage = VaultSecurityStage.locked;
    _message = reason ?? 'Vaulta bloqueada.';
    notifyListeners();
  }

  Future<void> setAutoLockOnBackgroundEnabled(bool enabled) async {
    await _runBusy(() async {
      _autoLockOnBackgroundEnabled = enabled;
      await _storage.save(autoLockOnBackgroundEnabledKey, enabled.toString());
      _message = enabled
          ? 'Auto-lock al ir a background activado.'
          : 'Auto-lock al ir a background desactivado.';
      return true;
    });
  }

  Future<bool> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    if (!isUnlocked || _vaultSession == null) {
      _message = 'Desbloquea Vaulta antes de cambiar la master password.';
      notifyListeners();
      return false;
    }

    final validationError = _masterPasswordService.validate(newPassword);
    if (validationError != null) {
      _message = validationError;
      notifyListeners();
      return false;
    }

    if (newPassword != confirmation) {
      _message = 'La confirmacion no coincide con la nueva master password.';
      notifyListeners();
      return false;
    }

    if (currentPassword == newPassword) {
      _message = 'La nueva master password debe ser distinta de la actual.';
      notifyListeners();
      return false;
    }

    return _runBusy(() async {
      final currentRecord = await _readRecord();
      if (currentRecord == null) {
        _stage = VaultSecurityStage.onboarding;
        _message = 'Todavia no configuraste una master password.';
        return false;
      }

      final matches = await _masterPasswordService.verify(
        record: currentRecord,
        password: currentPassword,
      );

      if (!matches) {
        _message = 'La master password actual no coincide.';
        return false;
      }

      final sourceSession = _vaultSession;
      if (sourceSession == null) {
        _stage = VaultSecurityStage.locked;
        _message =
            'No hay una sesion de vault valida en memoria. Volve a desbloquear.';
        return false;
      }

      if (sourceSession.keyId != currentRecord.keyId) {
        _vaultSession = null;
        _stage = VaultSecurityStage.locked;
        _message =
            'La sesion activa no coincide con la clave maestra vigente. Volve a desbloquear antes de reintentar.';
        return false;
      }

      final newRecord = await _masterPasswordService.createRecord(newPassword);
      final targetSession = VaultSession(
        keyId: newRecord.keyId,
        secretKey: await _masterPasswordService.deriveVaultKey(
          record: newRecord,
          password: newPassword,
        ),
      );

      try {
        await _rekeyEntries(
          sourceSession: sourceSession,
          targetSession: targetSession,
        );
      } catch (_) {
        _message =
            'No pudimos completar el re-cifrado del vault. Se mantuvo tu clave actual para evitar inconsistencias.';
        return false;
      }

      try {
        await _storage.save(masterPasswordRecordKey, newRecord.encode());
      } catch (_) {
        var rollbackSucceeded = false;
        try {
          await _rekeyEntries(
            sourceSession: targetSession,
            targetSession: sourceSession,
          );
          rollbackSucceeded = true;
        } catch (_) {
          rollbackSucceeded = false;
        }

        if (!rollbackSucceeded) {
          _vaultSession = null;
          _stage = VaultSecurityStage.locked;
          _message =
              'Fallo al persistir la nueva master password y no pudimos confirmar rollback completo. Vaulta queda bloqueada por seguridad.';
          return false;
        }

        _message =
            'No pudimos guardar la nueva master password. Se mantuvo tu clave actual para evitar inconsistencias.';
        return false;
      }

      _vaultSession = targetSession;
      _message =
          'Master password actualizada y vault re-cifrado con una nueva clave.';
      return true;
    });
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (!isUnlocked) {
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_autoLockOnBackgroundEnabled) {
          await lock(
            reason:
                'Vaulta bloqueada automaticamente al salir de primer plano.',
          );
        }
        return;
      case AppLifecycleState.resumed:
        return;
    }
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

  Future<bool?> _readBool({required String key, required bool fallback}) async {
    final rawValue = await _storage.read(key);
    if (rawValue == null) {
      return fallback;
    }

    if (rawValue == 'true') {
      return true;
    }

    if (rawValue == 'false') {
      return false;
    }

    return fallback;
  }

  static Future<void> _unsupportedRekey({
    required VaultSession sourceSession,
    required VaultSession targetSession,
  }) async {
    throw UnsupportedError('Vault rekeying operation is not configured.');
  }
}

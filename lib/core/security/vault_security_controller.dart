import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'biometric_auth_service.dart';
import 'biometric_key_envelope_service.dart';
import 'biometric_unlock_service.dart';
import 'master_password_record.dart';
import 'master_password_service.dart';
import 'native_biometric_auth_service.dart';
import 'secure_storage_service.dart';
import 'vault_session.dart';

typedef VaultRekeyEntries =
    Future<void> Function({
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
    BiometricKeyEnvelopeService? biometricEnvelopeService,
    BiometricUnlockService? biometricUnlockService,
  }) : _storage = storage,
       _masterPasswordService = masterPasswordService,
       _biometricAuthService = biometricAuthService,
       _rekeyEntries = rekeyEntries ?? _unsupportedRekey,
       _biometricEnvelopeService = biometricEnvelopeService ??
           BiometricKeyEnvelopeService(storage: storage),
       _biometricUnlockService = biometricUnlockService;

  static const masterPasswordRecordKey = 'vault_master_password_record';
  static const biometricEnabledKey = 'vault_biometric_enabled';
  static const autoLockOnBackgroundEnabledKey =
      'vault_auto_lock_on_background_enabled';
  static const idleTimeoutSecondsKey = 'vault_idle_timeout_seconds';
  static const defaultIdleTimeoutSeconds = 300;
  static const _interactionResetThrottle = Duration(milliseconds: 750);

  final SecureStorageService _storage;
  final MasterPasswordService _masterPasswordService;
  final BiometricAuthService _biometricAuthService;
  final VaultRekeyEntries _rekeyEntries;
  final BiometricKeyEnvelopeService _biometricEnvelopeService;
  final BiometricUnlockService? _biometricUnlockService;

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
  int _idleTimeoutSeconds = defaultIdleTimeoutSeconds;
  Timer? _idleTimer;
  DateTime? _lastInteractionAt;
  /// Cached state of the wrapped-DEK envelope on disk. Refreshed on
  /// initialize, after every successful enrollment, and after every
  /// successful biometric unlock. The unlock screen uses this to
  /// decide whether to render the "Activate biometric unlock" CTA
  /// without having to hit the secure storage on every build.
  bool _envelopeEnrolled = false;

  VaultSecurityStage get stage => _stage;

  BiometricAvailability get biometricAvailability => _biometricAvailability;

  bool get biometricEnabled => _biometricEnabled;

  /// True when the wrapped-DEK envelope is currently persisted. The
  /// unlock screen renders the one-tap biometric-setup CTA when
  /// the user has the preference on (or the device has biometrics
  /// enrolled and the user has not turned it on yet) but this
  /// envelope is missing — the two conditions are not the same.
  bool get isBiometricEnvelopeEnrolled => _envelopeEnrolled;

  bool get busy => _busy;

  String? get message => _message;

  VaultSession? get vaultSession => _vaultSession;

  bool get autoLockOnBackgroundEnabled => _autoLockOnBackgroundEnabled;

  int get idleTimeoutSeconds => _idleTimeoutSeconds;

  Duration? get idleTimeout =>
      _idleTimeoutSeconds <= 0 ? null : Duration(seconds: _idleTimeoutSeconds);

  bool get isUnlocked => _stage == VaultSecurityStage.unlocked;

  bool get canOfferBiometricToggle =>
      _biometricAvailability.canAuthenticate &&
      _biometricAvailability.hasEnrolledBiometrics;

  /// True when there is a real path to a biometric unlock on this
  /// device: the platform supports it, biometrics are enrolled, AND
  /// a wrapped-DEK envelope exists on disk for this vault.
  ///
  /// The flag is computed on demand because the platform keychain
  /// state can change between app launches and we never want to show
  /// a biometric button that would just fail.
  Future<bool> canUnlockWithBiometrics() async {
    final unlocker = _biometricUnlockService;
    if (unlocker == null) {
      debugPrint('[Vaulta] canUnlock: no unlocker wired up');
      return false;
    }
    final result = await unlocker.canAttemptUnlock();
    debugPrint('[Vaulta] canUnlock=$result '
        '(enrolled=${_biometricAvailability.hasEnrolledBiometrics}, '
        'canAuth=${_biometricAvailability.canAuthenticate}, '
        'flag=$_biometricEnabled)');
    return result;
  }

  /// True when the unlock screen should *offer* a biometric button.
  /// This is broader than [canUnlockWithBiometrics]: it returns true
  /// as long as the device can authenticate with biometrics AND the
  /// user has the preference on. The actual unlock might still fail
  /// (e.g. no envelope on disk yet) and the controller will explain
  /// the reason in the message.
  ///
  /// The unlock screen uses this to decide whether to render the
  /// fingerprint button. Hiding the button entirely when enrollment
  /// failed silently in the past was a UX trap: the user flipped the
  /// toggle and saw nothing happen.
  bool get canOfferBiometricUnlockButton {
    if (!_biometricEnabled) return false;
    if (!canOfferBiometricToggle) return false;
    return _biometricUnlockService != null;
  }

  /// Single source of truth for the "you have to unlock with the
  /// master password once before biometrics will work" hint. The
  /// proactive unlock-screen banner and the post-failure message
  /// both reference this constant so the user only sees the line
  /// once, no matter which path surfaced it.
  static const biometricNeedsPasswordFirstMessage =
      'Toca el boton "Activar desbloqueo biometrico" abajo para '
      'preparar tu huella. La master password no se guarda ni se envia '
      'a ningun servidor.';

  /// Latest human-readable status of the biometric unlock path, for
  /// the unlock screen to surface when the button is offered but the
  /// underlying envelope is not yet on disk. Returns null when there
  /// is nothing useful to say.
  Future<String?> biometricUnlockStatusMessage() async {
    if (!canOfferBiometricUnlockButton) return null;
    if (await _biometricEnvelopeService.isEnrolled()) {
      return null;
    }
    return biometricNeedsPasswordFirstMessage;
  }

  /// Returns the raw native platform capability, when the active
  /// [BiometricAuthService] is a [NativeBiometricAuthService].
  /// Falls back to [NativeBiometricCapability.empty] on other
  /// targets so the UI never has to special-case platforms.
  Future<NativeBiometricCapability> probeBiometricCapability() async {
    final service = _biometricAuthService;
    if (service is NativeBiometricAuthService) {
      return service.probeCapability();
    }
    return NativeBiometricCapability.empty;
  }

  /// Opens the system biometric-enrollment settings. Returns true
  /// if the intent was launched, false otherwise. The settings
  /// screen uses this to deep-link the user into the platform setup
  /// when [NativeBiometricCapability.needsEnrollment] is true.
  Future<bool> openBiometricEnrollment() async {
    final service = _biometricAuthService;
    if (service is NativeBiometricAuthService) {
      return service.openBiometricEnrollment();
    }
    return false;
  }

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
      _idleTimeoutSeconds =
          await _readInt(
            key: idleTimeoutSecondsKey,
            fallback: defaultIdleTimeoutSeconds,
            min: 0,
          ) ??
          defaultIdleTimeoutSeconds;

      final record = await _readRecord();
      _envelopeEnrolled = await _biometricEnvelopeService.isEnrolled();
      _stage = record == null
          ? VaultSecurityStage.onboarding
          : VaultSecurityStage.locked;

      // If the user previously turned biometrics on but the platform
      // enrollment is gone (e.g. they removed their fingerprint from
      // the device or wiped the keystore), drop the preference so the
      // UI does not lie about what's available. The wrapped envelope
      // is also wiped because without the platform-protected key it
      // is useless.
      if (_biometricEnabled && !canOfferBiometricToggle) {
        _biometricEnabled = false;
        await _storage.save(biometricEnabledKey, 'false');
        await _biometricEnvelopeService.clear();
      }
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
      _vaultSession = VaultSession.v2(
        keyId: record.keyId,
        secretKey: await _masterPasswordService.deriveVaultKey(
          record: record,
          password: password,
        ),
        kdf: record.kdf!,
        dekWrap: record.dekWrap!,
      );
      await _storage.save(masterPasswordRecordKey, record.encode());
      await _persistBiometricPreference(enableBiometrics);
      await _enrollBiometricEnvelopeIfNeeded(record);

      _message =
          'Master password creada. Tu sesion local queda protegida por el sistema.';
      _stage = VaultSecurityStage.unlocked;
      _restartIdleTimer();
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

      final sourceSession = VaultSession(
        keyId: record.keyId,
        secretKey: await _masterPasswordService.deriveVaultKey(
          record: record,
          password: password,
        ),
        kdf: record.kdf,
        dekWrap: record.dekWrap,
      );

      var activeRecord = record;
      var activeSession = sourceSession;
      if (record.version < 2 || record.kdf == null || record.dekWrap == null) {
        final migratedRecord = await _masterPasswordService.createRecord(
          password,
        );
        final migratedSession = VaultSession.v2(
          keyId: migratedRecord.keyId,
          secretKey: await _masterPasswordService.deriveVaultKey(
            record: migratedRecord,
            password: password,
          ),
          kdf: migratedRecord.kdf!,
          dekWrap: migratedRecord.dekWrap!,
        );
        await _rekeyEntries(
          sourceSession: sourceSession,
          targetSession: migratedSession,
        );
        await _storage.save(masterPasswordRecordKey, migratedRecord.encode());
        activeRecord = migratedRecord;
        activeSession = migratedSession;
        // Re-enroll the envelope after migration so the new DEK is the
        // one wrapped on disk, not the v1 derived key.
        await _enrollBiometricEnvelopeIfNeeded(activeRecord);
      }

      _vaultSession = activeSession;

      // Always try to (re)enroll the biometric envelope on a fresh
      // unlock. The enrollment is silent (no biometric prompt) and
      // only persists the wrapped DEK + RSA-encrypted seed. If the
      // platform cannot provide a key slot (e.g. user removed their
      // fingerprint from the device between unlocks) the call is a
      // no-op and the unlock button will simply not appear next time.
      if (!await _biometricEnvelopeService.isEnrolled() &&
          _biometricEnabled &&
          canOfferBiometricToggle) {
        debugPrint('[Vaulta] envelope missing, retrying enrollment');
        await _enrollBiometricEnvelopeIfNeeded(activeRecord);
      }
      _envelopeEnrolled = await _biometricEnvelopeService.isEnrolled();

      _message = activeRecord == record
          ? 'Vaulta desbloqueada.'
          : 'Vaulta desbloqueada y migrada a cifrado v2.';
      _stage = VaultSecurityStage.unlocked;
      _restartIdleTimer();
      return true;
    });
  }

  Future<bool> unlockWithBiometrics() async {
    final unlocker = _biometricUnlockService;
    if (unlocker == null) {
      _message =
          'El desbloqueo biometrico todavia no esta conectado en este dispositivo.';
      notifyListeners();
      return false;
    }

    return _runBusy(() async {
      final record = await _readRecord();
      if (record == null) {
        _stage = VaultSecurityStage.onboarding;
        _message = 'Todavia no configuraste una master password.';
        return false;
      }

      final outcome = await unlocker.unlock(record: record);
      switch (outcome) {
        case BiometricUnlockSuccess(:final session):
          _vaultSession = session;
          _stage = VaultSecurityStage.unlocked;
          _envelopeEnrolled = true;
          _message = 'Vaulta desbloqueada con biometria.';
          _restartIdleTimer();
          return true;
        case BiometricUnlockNeedsPasswordFirst(:final reason):
          // The unlock screen already shows
          // [biometricNeedsPasswordFirstMessage] as the proactive
          // banner. Repeating it in [message] would render two
          // identical banners stacked on top of each other, which
          // is exactly the layout the user reported in the bug
          // capture. We leave [message] null so the unlock screen
          // renders only the proactive banner.
          _message = null;
          debugPrint('[Vaulta] biometric unlock needs password-first '
              'enrollment: $reason');
          return false;
        case BiometricUnlockRejected(:final reason):
          _message = reason;
          // A rejection that looks like a stale envelope should be
          // cleared so the next attempt is a clean password unlock
          // and the user is not stuck retrying a broken path.
          if (reason.contains('inconsistente') ||
              reason.contains('rechazo')) {
            await unlocker.invalidate();
            _biometricEnabled = false;
            await _storage.save(biometricEnabledKey, 'false');
          }
          return false;
        case BiometricUnlockUnavailable(:final reason):
          _message = reason;
          return false;
      }
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
      if (enabled) {
        final record = await _readRecord();
        if (record != null) {
          await _enrollBiometricEnvelopeIfNeeded(record);
        }
        _message =
            'Biometria activada. La proxima vez podras desbloquear Vaulta con tu biometria.';
      } else {
        await _biometricEnvelopeService.clear();
        _message = 'Biometria desactivada. Solo queda la master password.';
      }
      return true;
    });
  }

  Future<void> lock({String? reason}) async {
    _cancelIdleTimer();
    _lastInteractionAt = null;
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

  Future<void> setIdleTimeoutSeconds(int seconds) async {
    if (seconds < 0) {
      return;
    }

    await _runBusy(() async {
      _idleTimeoutSeconds = seconds;
      await _storage.save(idleTimeoutSecondsKey, seconds.toString());
      if (_idleTimeoutSeconds == 0) {
        _cancelIdleTimer();
        _message = 'Auto-lock por inactividad desactivado.';
      } else {
        _restartIdleTimer();
        _message =
            'Auto-lock por inactividad activado (${_formatIdleTimeoutLabel(_idleTimeoutSeconds)}).';
      }
      return true;
    });
  }

  void registerUserInteraction() {
    if (!isUnlocked || _idleTimeoutSeconds == 0) {
      return;
    }

    final now = DateTime.now();
    final lastInteractionAt = _lastInteractionAt;
    if (lastInteractionAt != null &&
        now.difference(lastInteractionAt) < _interactionResetThrottle) {
      return;
    }

    _lastInteractionAt = now;
    _restartIdleTimer();
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
      final targetSession = VaultSession.v2(
        keyId: newRecord.keyId,
        secretKey: await _masterPasswordService.deriveVaultKey(
          record: newRecord,
          password: newPassword,
        ),
        kdf: newRecord.kdf!,
        dekWrap: newRecord.dekWrap!,
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
      // The DEK changed, so any previous biometric envelope is stale
      // and would unwrap to the wrong key. Wipe it and re-enroll under
      // the new DEK if the user still has biometrics enabled.
      await _biometricEnvelopeService.clear();
      await _enrollBiometricEnvelopeIfNeeded(newRecord);
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
        _cancelIdleTimer();
        if (_autoLockOnBackgroundEnabled) {
          await lock(
            reason:
                'Vaulta bloqueada automaticamente al salir de primer plano.',
          );
        }
        return;
      case AppLifecycleState.resumed:
        _restartIdleTimer();
        return;
    }
  }

  @override
  void dispose() {
    _cancelIdleTimer();
    super.dispose();
  }

  Future<void> _persistBiometricPreference(bool enabled) async {
    _biometricEnabled = enabled;
    await _storage.save(biometricEnabledKey, enabled.toString());
  }

  /// Enrolls the wrapped-DEK envelope if biometrics are enabled on
  /// this device and the platform reports a usable key slot. Silently
  /// no-ops when any precondition is missing — the unlock UI will
  /// surface the explanation.
  Future<void> _enrollBiometricEnvelopeIfNeeded(
    MasterPasswordRecord record,
  ) async {
    if (!_biometricEnabled) {
      debugPrint('[Vaulta] enroll skipped: biometricEnabled=false');
      return;
    }
    if (!canOfferBiometricToggle) {
      debugPrint('[Vaulta] enroll skipped: no biometric available '
          '(canAuth=${_biometricAvailability.canAuthenticate}, '
          'enrolled=${_biometricAvailability.hasEnrolledBiometrics})');
      return;
    }
    if (record.version < 2 || record.kdf == null || record.dekWrap == null) {
      debugPrint('[Vaulta] enroll skipped: record is not v2');
      return;
    }

    final unlocker = _biometricUnlockService;
    if (unlocker == null) {
      debugPrint('[Vaulta] enroll skipped: no unlock service');
      return;
    }

    final dekBytes = await _unwrapCurrentDek(record);
    if (dekBytes == null) {
      debugPrint('[Vaulta] enroll: no DEK in current session');
      return;
    }

    await _enrollEnvelopeWithDek(
      unlocker: unlocker,
      dekBytes: dekBytes,
    );
  }

  /// Shared enrollment implementation that takes the DEK as a
  /// parameter. Used by [_enrollBiometricEnvelopeIfNeeded] (which
  /// reads the DEK out of the active session) and by
  /// [setupBiometricFromPassword] (which derives a one-shot DEK
  /// without unlocking the vault).
  Future<bool> _enrollEnvelopeWithDek({
    required BiometricUnlockService unlocker,
    required Uint8List dekBytes,
  }) async {
    SecretKey? envelopeKey;
    try {
      envelopeKey = await unlocker.envelopeKeyProvider.acquireEnvelopeKey();
    } catch (error, stack) {
      debugPrint('[Vaulta] enroll: provider threw $error\n$stack');
      envelopeKey = null;
    }
    if (envelopeKey == null) {
      debugPrint('[Vaulta] enroll: provider returned null key '
          '(platform cannot back the envelope on this device)');
      return false;
    }
    try {
      await _biometricEnvelopeService.enroll(
        dekBytes: dekBytes,
        envelopeKey: envelopeKey,
      );
      debugPrint('[Vaulta] enroll: envelope persisted');
      return true;
    } catch (error, stack) {
      debugPrint('[Vaulta] enroll: enroll() failed $error\n$stack');
      return false;
    }
  }

  /// One-shot setup flow used by the unlock screen when the user
  /// wants to enable biometric unlock for the first time but the
  /// vault is still locked. We verify the master password (without
  /// unlocking), derive a throwaway DEK, enroll the wrapped-DEK
  /// envelope, and flip the biometric preference on. The vault
  /// stays locked — the user is still on the unlock screen and can
  /// choose to enter with their password or wait for the next
  /// unlock where the fingerprint will already work.
  ///
  /// Returns `true` on success and writes a friendly `_message`.
  /// Returns `false` on any failure (no record, no biometric, wrong
  /// password, missing v2 metadata, enrollment failure) and writes
  /// a specific `_message` for the UI.
  Future<bool> setupBiometricFromPassword(String password) async {
    return _runBusy(() async {
      final record = await _readRecord();
      if (record == null) {
        _message = 'Todavia no configuraste una master password.';
        return false;
      }

      if (!canOfferBiometricToggle) {
        _message = 'No hay biometria configurada en este dispositivo.';
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

      if (record.version < 2 || record.kdf == null || record.dekWrap == null) {
        _message = 'Tu master password es de una version anterior. '
            'Desbloquea una vez para migrar y vuelve a intentar.';
        return false;
      }

      final unlocker = _biometricUnlockService;
      if (unlocker == null) {
        _message = 'El desbloqueo biometrico no esta conectado '
            'en este dispositivo.';
        return false;
      }

      final session = VaultSession.v2(
        keyId: record.keyId,
        secretKey: await _masterPasswordService.deriveVaultKey(
          record: record,
          password: password,
        ),
        kdf: record.kdf!,
        dekWrap: record.dekWrap!,
      );
      final dekBytes = Uint8List.fromList(await session.secretKey.extractBytes());

      final enrolled = await _enrollEnvelopeWithDek(
        unlocker: unlocker,
        dekBytes: dekBytes,
      );
      if (!enrolled) {
        _message = 'No pudimos preparar la huella en este dispositivo. '
            'Reintenta o usa la master password.';
        return false;
      }

      await _persistBiometricPreference(true);
      _envelopeEnrolled = true;
      _message = 'Listo. La proxima vez podras desbloquear Vaulta con tu huella.';
      // Drop the throwaway session — we are NOT unlocking the vault.
      return true;
    });
  }

  Future<Uint8List?> _unwrapCurrentDek(MasterPasswordRecord record) async {
    final session = _vaultSession;
    if (session == null || session.keyId != record.keyId) {
      return null;
    }
    final bytes = await session.secretKey.extractBytes();
    return Uint8List.fromList(bytes);
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

  Future<int?> _readInt({
    required String key,
    required int fallback,
    int? min,
  }) async {
    final rawValue = await _storage.read(key);
    if (rawValue == null) {
      return fallback;
    }

    final parsed = int.tryParse(rawValue);
    if (parsed == null) {
      return fallback;
    }

    if (min != null && parsed < min) {
      return fallback;
    }

    return parsed;
  }

  void _restartIdleTimer() {
    _cancelIdleTimer();

    final timeout = idleTimeout;
    if (timeout == null || !isUnlocked) {
      return;
    }

    _lastInteractionAt = DateTime.now();

    _idleTimer = Timer(timeout, () {
      if (!isUnlocked) {
        return;
      }

      unawaited(
        lock(reason: 'Vaulta bloqueada automaticamente por inactividad.'),
      );
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  String _formatIdleTimeoutLabel(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }

    final minutes = seconds ~/ 60;
    return '$minutes min';
  }

  static Future<void> _unsupportedRekey({
    required VaultSession sourceSession,
    required VaultSession targetSession,
  }) async {
    throw UnsupportedError('Vault rekeying operation is not configured.');
  }
}

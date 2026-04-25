// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Vaulta';

  @override
  String get navVault => 'Vault';

  @override
  String get navAccess => 'Acceso';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get languageSectionTitle => 'Idioma';

  @override
  String get languageSelectorLabel => 'Idioma de la app';

  @override
  String get languageEnglish => 'Ingles';

  @override
  String get languageSpanish => 'Espanol';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsLocalUnlockPostureTitle => 'Postura de desbloqueo local';

  @override
  String get settingsLocalUnlockPostureDescription => 'Vaulta guarda el estado sensible en Keychain / Keystore. La biometria solo valida presencia local; el vault bloqueado sigue requiriendo master password.';

  @override
  String get settingsMasterPasswordCreated => 'Master password creada';

  @override
  String get settingsBiometricsAvailable => 'Biometria disponible';

  @override
  String get settingsBiometricsEnabled => 'Biometria activada';

  @override
  String get settingsUnlockWithBiometrics => 'Usar biometria como verificacion local';

  @override
  String settingsBiometricSupportedSubtitle(Object biometricLabel) {
    return 'Usa $biometricLabel como verificacion local mientras el vault esta abierto. Vaulta no persiste una clave recuperable para desbloqueo biometrico.';
  }

  @override
  String get settingsBiometricUnavailableSubtitle => 'No hay biometria configurada o soportada en este entorno.';

  @override
  String get settingsAutoLockBackgroundTitle => 'Auto-lock al pasar a background';

  @override
  String get settingsAutoLockBackgroundSubtitle => 'Bloquea Vaulta automaticamente si la app queda inactive, paused o detached.';

  @override
  String get settingsIdleTimeoutLabel => 'Auto-lock por inactividad en foreground';

  @override
  String get settingsLockNow => 'Bloquear ahora';

  @override
  String get settingsChangeMasterPassword => 'Cambiar master password';

  @override
  String get settingsSessionsTitle => 'Dispositivos y sesiones';

  @override
  String get settingsSessionsSubtitle => 'Podes revocar un equipo puntual o cortar el resto de sesiones activas.';

  @override
  String get settingsSessionsRefresh => 'Refrescar sesiones';

  @override
  String get settingsRevokeOtherDevices => 'Revocar todas las otras sesiones';

  @override
  String get settingsRevokeDevice => 'Revocar dispositivo';

  @override
  String get settingsRevokeCurrentDeviceTitle => 'Revocar este dispositivo?';

  @override
  String get settingsRevokeCurrentDeviceBody => 'Revocar el dispositivo actual va a bloquear esta sesion inmediatamente. Vas a tener que desbloquear de nuevo para continuar.';

  @override
  String get settingsRevokeNow => 'Revocar ahora';

  @override
  String get settingsRevokeDeviceError => 'No pudimos revocar este dispositivo. Reintenta en unos segundos.';

  @override
  String get settingsRevokedAllTitle => 'Sesion revocada en todos los dispositivos';

  @override
  String get settingsRevokedAllBody => 'El acceso de tu cuenta fue revocado para todas las sesiones. Este dispositivo se va a bloquear por seguridad.';

  @override
  String get settingsCurrentDeviceRevokedTitle => 'Dispositivo actual revocado';

  @override
  String get settingsCurrentDeviceRevokedBody => 'Este dispositivo ya no tiene una sesion activa. Vaulta se va a bloquear por seguridad.';

  @override
  String get settingsNoDevices => 'No hay dispositivos registrados para este usuario.';

  @override
  String get settingsCurrentDeviceLabel => 'Este dispositivo';

  @override
  String get settingsSessionStatusActive => 'Activa';

  @override
  String get settingsSessionStatusRevoked => 'Revocada';

  @override
  String get settingsDeviceNeverSeen => 'Sin actividad registrada';

  @override
  String get settingsDeviceRevokedMessage => 'Dispositivo revocado correctamente.';

  @override
  String get settingsRevokeOthersDone => 'Se revocaron las otras sesiones activas.';

  @override
  String get settingsRoadmapTitle => 'Roadmap de seguridad de plataforma';

  @override
  String get settingsRoadmapNotes => 'Los items del vault usan ADR-001 v2: Argon2id deriva una KEK desde la master password y una DEK aleatoria cifra entradas con AES-256-GCM. El desbloqueo biometrico sin master password requiere una implementacion futura con claves vinculadas al hardware.';

  @override
  String get settingsSecureStorage => 'Almacenamiento seguro';

  @override
  String get settingsBiometricUnlock => 'Recovery biometrico de clave';

  @override
  String get settingsHardwareBackedKeys => 'Claves con respaldo de hardware';

  @override
  String get settingsVaultEncryptionReady => 'Cifrado del vault conectado end-to-end';

  @override
  String get idleNever => 'Nunca';

  @override
  String get idleDisabled => 'Desactivado';

  @override
  String get idleOneMinute => '1 minuto';

  @override
  String get idleFiveMinutes => '5 minutos';

  @override
  String get idleFifteenMinutes => '15 minutos';

  @override
  String get idleStrict => 'Estricto';

  @override
  String get idleRecommended => 'Recomendado';

  @override
  String get idleRelaxed => 'Relajado';

  @override
  String get changeMasterPasswordTitle => 'Cambiar master password';

  @override
  String get changeMasterPasswordCurrent => 'Master password actual';

  @override
  String get changeMasterPasswordNew => 'Nueva master password';

  @override
  String get changeMasterPasswordConfirm => 'Confirmar nueva master password';

  @override
  String get changeMasterPasswordHint => 'Este cambio vuelve a cifrar todo el vault con una clave nueva.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get apply => 'Aplicar';

  @override
  String get masterPasswordUpdatedSuccess => 'Master password actualizada correctamente.';

  @override
  String get changeMasterPasswordErrorFallback => 'No pudimos cambiar la master password. Revisa los datos e intenta de nuevo.';

  @override
  String get securityOnboardingEyebrow => 'Onboarding seguro';

  @override
  String get securityOnboardingTitle => 'Creamos tu llave maestra sin atajos peligrosos.';

  @override
  String get securityOnboardingSubtitle => 'La master password valida acceso local y deriva la clave que cifra los items del vault.';

  @override
  String get securityMasterPasswordTitle => 'Master password';

  @override
  String get securityMasterPasswordDescription => 'Pedimos 12+ caracteres con mezcla real. Nada de guardar la clave en texto plano.';

  @override
  String get securityCreateMasterPassword => 'Crear master password';

  @override
  String get securityConfirmMasterPassword => 'Confirmar master password';

  @override
  String get securityChecklistHash => 'Argon2id para verificar la master password.';

  @override
  String get securityChecklistDerive => 'Argon2id deriva una KEK que desenvuelve una DEK aleatoria del vault.';

  @override
  String get securityChecklistEncrypt => 'Items locales cifrados con AES-256-GCM y record guardado con Keychain / Keystore.';

  @override
  String get securityEnableBiometrics => 'Habilitar biometria local';

  @override
  String securityBiometricAvailable(Object biometricLabel) {
    return 'Habilita $biometricLabel como verificacion local. Vaulta no guarda una clave recuperable del vault, asi que un vault bloqueado sigue necesitando la master password.';
  }

  @override
  String get securityBiometricUnavailable => 'No detectamos biometria disponible. Igual vas a poder entrar con tu master password.';

  @override
  String get securityCreateSecureAccess => 'Crear acceso seguro al vault';

  @override
  String get securityUnlockEyebrow => 'Desbloquear';

  @override
  String get securityUnlockTitle => 'Tu vault queda cerrado hasta validar identidad real.';

  @override
  String securityUnlockBiometricSubtitle(Object biometricLabel) {
    return 'Desbloquea con tu master password. La biometria no la reemplaza en esta release.';
  }

  @override
  String get securityUnlockPasswordSubtitle => 'Usa tu master password para recuperar acceso.';

  @override
  String get securityProtectedAccess => 'Acceso protegido';

  @override
  String get securityUnlockVault => 'Desbloquear vault';

  @override
  String get securityBiometricButton => 'Biometria';

  @override
  String get dashboardDecryptError => 'Vaulta no pudo descifrar el vault local en este momento.';

  @override
  String get dashboardDecryptErrorAdvice => 'Bloquea y desbloquea de nuevo con tu master password, despues reintenta. Ocultamos el detalle para no filtrar estado sensible.';

  @override
  String get entryDetailTitle => 'Detalle de entrada';

  @override
  String get entryEditTooltip => 'Editar entrada';

  @override
  String get entryDeleteTooltip => 'Eliminar entrada';

  @override
  String get entryUsernameLabel => 'Usuario';

  @override
  String get entryWebsiteLabel => 'Sitio web';

  @override
  String get entryStrengthLabel => 'Fortaleza';

  @override
  String get entryUpdatedLabel => 'Actualizado';

  @override
  String get entrySecretTitle => 'Secreto';

  @override
  String get entryShowSecret => 'Mostrar';

  @override
  String get entryHideSecret => 'Ocultar';

  @override
  String get copySecret => 'Copiar secreto';

  @override
  String get secretCopiedLocally => 'Secreto copiado localmente. El portapapeles se limpia pronto si no cambia.';

  @override
  String get clipboardCleared => 'Portapapeles limpiado.';

  @override
  String get entryNotesTitle => 'Notas';

  @override
  String get entryDeleteDialogTitle => 'Eliminar entrada?';

  @override
  String get entryDeleteDialogBody => 'Esto elimina el registro cifrado del vault local. El recovery remoto no esta disponible en modo offline.';

  @override
  String get entryDeleteConfirm => 'Eliminar';

  @override
  String get retry => 'Reintentar';

  @override
  String get newEntry => 'Nueva entrada';

  @override
  String get entryCreatedMessage => 'Entrada cifrada creada.';

  @override
  String get vaultUpdatedMessage => 'Vault actualizado de forma local.';

  @override
  String get dashboardSubtitle => 'Tu centro de control cifrado';

  @override
  String get dashboardHeroTitle => 'Protegido por hardware del sistema';

  @override
  String get dashboardHeroBody => 'El vault local cifra cada entrada con AES-256-GCM. CRUD local, busqueda, filtros y generador de passwords estan listos; el sync remoto queda opcional y experimental.';

  @override
  String dashboardPillTrustedDevices(int count) {
    return '$count dispositivos confiables';
  }

  @override
  String get dashboardPillSyncEnabled => 'Sync seguro activo';

  @override
  String get dashboardPillSyncDisabled => 'Vault cifrado offline';

  @override
  String dashboardPillWeakNeedRotation(int count) {
    return '$count passwords necesitan rotacion';
  }

  @override
  String get securityScore => 'Puntaje de seguridad';

  @override
  String get vaultEntries => 'Entradas del vault';

  @override
  String get weakPasswords => 'Passwords debiles';

  @override
  String get reusedItems => 'Items reutilizados';

  @override
  String get trustedDevices => 'Dispositivos confiables';

  @override
  String get priorityActions => 'Acciones prioritarias';

  @override
  String get dashboardQuickActionsSummary => 'Ahora el vault es real: alta, edicion, detalle y borrado con cifrado preservado end-to-end.';

  @override
  String get createEncryptedEntry => 'Crear entrada cifrada';

  @override
  String get createEncryptedEntrySubtitle => 'Agrega nuevas credenciales y guardalas cifradas en reposo.';

  @override
  String get planNextHardeningStep => 'Planificar siguiente hardening';

  @override
  String get dashboardRoadmapSyncEnabled => 'El sync remoto es experimental y requiere una sesion Supabase configurada.';

  @override
  String get dashboardRoadmapSyncDisabled => 'Release offline-first: vault local, busqueda, filtros y generador funcionan sin sync cloud.';

  @override
  String get vaultEntriesSectionTitle => 'Entradas del vault';

  @override
  String get searchVault => 'Buscar titulo, usuario o sitio';

  @override
  String get filter => 'Filtro';

  @override
  String get filterAllEntries => 'Todas las entradas';

  @override
  String get filterWeakOnly => 'Solo passwords debiles';

  @override
  String get filterWithNotes => 'Entradas con notas';

  @override
  String get resetFilters => 'Restablecer filtros';

  @override
  String get noResultsTitle => 'Ninguna entrada coincide con los filtros';

  @override
  String get noResultsSubtitle => 'Proba otra busqueda o reinicia filtros para ver todo otra vez.';

  @override
  String get emptyVaultTitle => 'Tu vault esta vacio';

  @override
  String get emptyVaultSubtitle => 'Crea tu primera entrada y Vaulta la cifra antes de persistirla.';

  @override
  String get createFirstEntry => 'Crear primera entrada';

  @override
  String itemsTotal(int count) {
    return '$count total';
  }

  @override
  String itemsShownOfTotal(int shown, int total) {
    return '$shown visibles - $total total';
  }

  @override
  String get editorTitleEdit => 'Editar entrada';

  @override
  String get editorTitleNew => 'Nueva entrada';

  @override
  String get editorIdentityTitle => 'Identidad';

  @override
  String get editorTitleLabel => 'Titulo';

  @override
  String get editorTitleHint => 'GitHub, banco, Wi-Fi...';

  @override
  String get editorTitleValidation => 'Dale un titulo claro a esta entrada.';

  @override
  String get editorUsernameLabel => 'Usuario o email';

  @override
  String get editorUsernameValidation => 'Agrega el identificador de la cuenta.';

  @override
  String get editorCategoryLabel => 'Categoria';

  @override
  String get editorCategoryWork => 'Trabajo';

  @override
  String get editorCategoryFinance => 'Finanzas';

  @override
  String get editorCategoryPersonal => 'Personal';

  @override
  String get editorCategoryInfrastructure => 'Infraestructura';

  @override
  String get editorSecretTitle => 'Secreto';

  @override
  String get editorSecretDescription => 'Vaulta recalcula la fortaleza localmente antes de recifrar la entrada.';

  @override
  String get editorSecretLabel => 'Password o secreto';

  @override
  String get editorSecretRequiredValidation => 'Guarda un secreto real, no un campo vacio.';

  @override
  String get editorSecretMinValidation => 'Usa al menos 8 caracteres.';

  @override
  String get editorGeneratorTitle => 'Generador de passwords';

  @override
  String editorGeneratorChars(int count) {
    return '$count caracteres';
  }

  @override
  String get editorGenerateInsert => 'Generar e insertar';

  @override
  String get editorWebsiteLabel => 'Sitio web o app';

  @override
  String get editorWebsiteHint => 'https://ejemplo.com';

  @override
  String get editorNotesLabel => 'Notas';

  @override
  String get editorNotesHint => 'Codigos de recuperacion, contexto, recordatorios...';

  @override
  String get editorSaveChanges => 'Guardar cambios';

  @override
  String get editorCreateEntry => 'Crear entrada';

  @override
  String get editorGeneratorSetRequired => 'Elegi al menos un set de caracteres para generar.';

  @override
  String get editorGeneratedInserted => 'Password generada e insertada.';

  @override
  String get syncConflictsTitle => 'Conflictos de sincronizacion';

  @override
  String get syncConflictsSubtitle => 'Un cambio remoto llego mientras tu edicion local estaba pendiente. Elegi qué version conservar.';

  @override
  String get syncConflictsEmpty => 'Sin conflictos pendientes. Todo sincronizado.';

  @override
  String syncConflictsBannerLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'conflictos',
      one: 'conflicto',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count $_temp0 de sync pendiente$_temp1';
  }

  @override
  String get syncConflictsBannerAction => 'Revisar';

  @override
  String get syncConflictLocalVersion => 'Tu version';

  @override
  String get syncConflictRemoteVersion => 'Version remota';

  @override
  String get syncConflictKeepLocal => 'Quedarme con la mia';

  @override
  String get syncConflictKeepRemote => 'Usar la remota';

  @override
  String get syncConflictKindUpsert => 'Conflicto de edicion';

  @override
  String get syncConflictKindDelete => 'Conflicto de borrado';

  @override
  String get biometricSlotExpired => 'El desbloqueo biometrico con clave del vault no esta habilitado en esta release. Ingresa tu master password.';

  @override
  String get biometricUnlockSuccess => 'Verificacion biometrica aceptada.';
}

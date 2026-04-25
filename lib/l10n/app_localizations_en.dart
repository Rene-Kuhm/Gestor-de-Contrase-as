// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Vaulta';

  @override
  String get navVault => 'Vault';

  @override
  String get navAccess => 'Access';

  @override
  String get navSettings => 'Settings';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageSelectorLabel => 'App language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLocalUnlockPostureTitle => 'Local unlock posture';

  @override
  String get settingsLocalUnlockPostureDescription => 'Vaulta keeps sensitive state in Keychain / Keystore and uses device biometrics when available.';

  @override
  String get settingsMasterPasswordCreated => 'Master password created';

  @override
  String get settingsBiometricsAvailable => 'Biometrics available';

  @override
  String get settingsBiometricsEnabled => 'Biometrics enabled';

  @override
  String get settingsUnlockWithBiometrics => 'Unlock with biometrics';

  @override
  String settingsBiometricSupportedSubtitle(Object biometricLabel) {
    return 'Use $biometricLabel as a local UX check. Vault keys are never stored for biometric recovery.';
  }

  @override
  String get settingsBiometricUnavailableSubtitle => 'Biometrics are not configured or supported in this environment.';

  @override
  String get settingsAutoLockBackgroundTitle => 'Auto-lock on background';

  @override
  String get settingsAutoLockBackgroundSubtitle => 'Locks Vaulta automatically if the app becomes inactive, paused, or detached.';

  @override
  String get settingsIdleTimeoutLabel => 'Foreground idle auto-lock';

  @override
  String get settingsLockNow => 'Lock now';

  @override
  String get settingsChangeMasterPassword => 'Change master password';

  @override
  String get settingsSessionsTitle => 'Devices and sessions';

  @override
  String get settingsSessionsSubtitle => 'You can revoke one device or cut every other active session.';

  @override
  String get settingsSessionsRefresh => 'Refresh sessions';

  @override
  String get settingsRevokeOtherDevices => 'Revoke all other sessions';

  @override
  String get settingsRevokeDevice => 'Revoke device';

  @override
  String get settingsNoDevices => 'No registered devices for this user.';

  @override
  String get settingsCurrentDeviceLabel => 'This device';

  @override
  String get settingsSessionStatusActive => 'Active';

  @override
  String get settingsSessionStatusRevoked => 'Revoked';

  @override
  String get settingsDeviceNeverSeen => 'No activity recorded';

  @override
  String get settingsDeviceRevokedMessage => 'Device revoked successfully.';

  @override
  String get settingsRevokeOthersDone => 'Other active sessions were revoked.';

  @override
  String get settingsRoadmapTitle => 'Platform security roadmap';

  @override
  String get settingsRoadmapNotes => 'Vault items use ADR-001 v2: Argon2id derives a KEK from the master password, a random DEK encrypts entries with AES-256-GCM, and biometrics never persist a recoverable vault key.';

  @override
  String get settingsSecureStorage => 'Secure storage';

  @override
  String get settingsBiometricUnlock => 'Biometric unlock';

  @override
  String get settingsHardwareBackedKeys => 'Hardware-backed keys';

  @override
  String get settingsVaultEncryptionReady => 'Vault item encryption wired end-to-end';

  @override
  String get idleNever => 'Never';

  @override
  String get idleDisabled => 'Disabled';

  @override
  String get idleOneMinute => '1 minute';

  @override
  String get idleFiveMinutes => '5 minutes';

  @override
  String get idleFifteenMinutes => '15 minutes';

  @override
  String get idleStrict => 'Strict';

  @override
  String get idleRecommended => 'Recommended';

  @override
  String get idleRelaxed => 'Relaxed';

  @override
  String get changeMasterPasswordTitle => 'Change master password';

  @override
  String get changeMasterPasswordCurrent => 'Current master password';

  @override
  String get changeMasterPasswordNew => 'New master password';

  @override
  String get changeMasterPasswordConfirm => 'Confirm new master password';

  @override
  String get changeMasterPasswordHint => 'This re-encrypts the entire vault with a new key.';

  @override
  String get cancel => 'Cancel';

  @override
  String get apply => 'Apply';

  @override
  String get masterPasswordUpdatedSuccess => 'Master password updated successfully.';

  @override
  String get changeMasterPasswordErrorFallback => 'We could not change the master password. Review the data and try again.';

  @override
  String get securityOnboardingEyebrow => 'Secure onboarding';

  @override
  String get securityOnboardingTitle => 'We create your master key with no dangerous shortcuts.';

  @override
  String get securityOnboardingSubtitle => 'The master password validates local access and derives the key that encrypts vault items.';

  @override
  String get securityMasterPasswordTitle => 'Master password';

  @override
  String get securityMasterPasswordDescription => 'Use 12+ characters with real variety. Never store this key in plaintext.';

  @override
  String get securityCreateMasterPassword => 'Create master password';

  @override
  String get securityConfirmMasterPassword => 'Confirm master password';

  @override
  String get securityChecklistHash => 'Argon2id verifies the master password.';

  @override
  String get securityChecklistDerive => 'Argon2id derives a KEK that unwraps a random vault DEK.';

  @override
  String get securityChecklistEncrypt => 'Local items are encrypted with AES-256-GCM and records are stored with Keychain / Keystore.';

  @override
  String get securityEnableBiometrics => 'Enable local biometrics';

  @override
  String securityBiometricAvailable(Object biometricLabel) {
    return 'Use $biometricLabel as a local UX check; master password remains the cryptographic fallback.';
  }

  @override
  String get securityBiometricUnavailable => 'No biometrics detected. You can still unlock with your master password.';

  @override
  String get securityCreateSecureAccess => 'Create secure vault access';

  @override
  String get securityUnlockEyebrow => 'Unlock';

  @override
  String get securityUnlockTitle => 'Your vault stays closed until real identity is verified.';

  @override
  String securityUnlockBiometricSubtitle(Object biometricLabel) {
    return 'Unlock with master password or $biometricLabel.';
  }

  @override
  String get securityUnlockPasswordSubtitle => 'Use your master password to recover access.';

  @override
  String get securityProtectedAccess => 'Protected access';

  @override
  String get securityUnlockVault => 'Unlock vault';

  @override
  String get securityBiometricButton => 'Biometric';

  @override
  String get dashboardDecryptError => 'Vaulta could not decrypt the local vault right now.';

  @override
  String get retry => 'Retry';

  @override
  String get newEntry => 'New entry';

  @override
  String get entryCreatedMessage => 'Encrypted entry created.';

  @override
  String get vaultUpdatedMessage => 'Vault updated locally.';

  @override
  String get dashboardSubtitle => 'Your encrypted control room';

  @override
  String get dashboardHeroTitle => 'Protected by system hardware';

  @override
  String get dashboardHeroBody => 'The local vault already encrypts every entry with AES-256-GCM. Real local CRUD is ready; search, tags, generator, and reliable sync are still pending.';

  @override
  String dashboardPillTrustedDevices(int count) {
    return '$count devices trusted';
  }

  @override
  String get dashboardPillSyncEnabled => 'Secure sync on';

  @override
  String get dashboardPillSyncDisabled => 'Offline encrypted vault';

  @override
  String dashboardPillWeakNeedRotation(int count) {
    return '$count passwords need rotation';
  }

  @override
  String get securityScore => 'Security score';

  @override
  String get vaultEntries => 'Vault entries';

  @override
  String get weakPasswords => 'Weak passwords';

  @override
  String get reusedItems => 'Reused items';

  @override
  String get trustedDevices => 'Trusted devices';

  @override
  String get priorityActions => 'Priority actions';

  @override
  String get dashboardQuickActionsSummary => 'The vault is now real: create, edit, view details, and delete with encryption preserved end-to-end.';

  @override
  String get createEncryptedEntry => 'Create encrypted entry';

  @override
  String get createEncryptedEntrySubtitle => 'Add new credentials and store them encrypted at rest.';

  @override
  String get planNextHardeningStep => 'Plan next hardening step';

  @override
  String get dashboardRoadmapSyncEnabled => 'Sync is on the roadmap, but trust boundaries still need design.';

  @override
  String get dashboardRoadmapSyncDisabled => 'Search, tags, generator, and attachments remain intentionally out of scope.';

  @override
  String get vaultEntriesSectionTitle => 'Vault entries';

  @override
  String get searchVault => 'Search title, username, or website';

  @override
  String get filter => 'Filter';

  @override
  String get filterAllEntries => 'All entries';

  @override
  String get filterWeakOnly => 'Weak passwords only';

  @override
  String get filterWithNotes => 'Entries with notes';

  @override
  String get resetFilters => 'Reset filters';

  @override
  String get noResultsTitle => 'No entries match your current filters';

  @override
  String get noResultsSubtitle => 'Try a different query or reset filters to see all items again.';

  @override
  String get emptyVaultTitle => 'Your vault is empty';

  @override
  String get emptyVaultSubtitle => 'Create your first entry and Vaulta encrypts it before persisting.';

  @override
  String get createFirstEntry => 'Create first entry';

  @override
  String itemsTotal(int count) {
    return '$count total';
  }

  @override
  String itemsShownOfTotal(int shown, int total) {
    return '$shown shown - $total total';
  }

  @override
  String get editorTitleEdit => 'Edit entry';

  @override
  String get editorTitleNew => 'New entry';

  @override
  String get editorIdentityTitle => 'Identity';

  @override
  String get editorTitleLabel => 'Title';

  @override
  String get editorTitleHint => 'GitHub, banking, Wi-Fi...';

  @override
  String get editorTitleValidation => 'Give this entry a clear title.';

  @override
  String get editorUsernameLabel => 'Username or email';

  @override
  String get editorUsernameValidation => 'Add the account identifier.';

  @override
  String get editorCategoryLabel => 'Category';

  @override
  String get editorCategoryWork => 'Work';

  @override
  String get editorCategoryFinance => 'Finance';

  @override
  String get editorCategoryPersonal => 'Personal';

  @override
  String get editorCategoryInfrastructure => 'Infrastructure';

  @override
  String get editorSecretTitle => 'Secret';

  @override
  String get editorSecretDescription => 'Vaulta recalculates strength locally before re-encrypting the entry.';

  @override
  String get editorSecretLabel => 'Password or secret';

  @override
  String get editorSecretRequiredValidation => 'Store a real secret, not an empty field.';

  @override
  String get editorSecretMinValidation => 'Use at least 8 characters.';

  @override
  String get editorGeneratorTitle => 'Password generator';

  @override
  String editorGeneratorChars(int count) {
    return '$count chars';
  }

  @override
  String get editorGenerateInsert => 'Generate and insert';

  @override
  String get editorWebsiteLabel => 'Website or app';

  @override
  String get editorWebsiteHint => 'https://example.com';

  @override
  String get editorNotesLabel => 'Notes';

  @override
  String get editorNotesHint => 'Recovery codes, context, reminders...';

  @override
  String get editorSaveChanges => 'Save changes';

  @override
  String get editorCreateEntry => 'Create entry';

  @override
  String get editorGeneratorSetRequired => 'Choose at least one character set to generate.';

  @override
  String get editorGeneratedInserted => 'Generated password inserted.';

  @override
  String get syncConflictsTitle => 'Sync conflicts';

  @override
  String get syncConflictsSubtitle => 'A remote change arrived while your local edit was pending. Choose which version to keep.';

  @override
  String get syncConflictsEmpty => 'No pending conflicts. Everything is in sync.';

  @override
  String syncConflictsBannerLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'conflicts',
      one: 'conflict',
    );
    return '$count sync $_temp0 pending';
  }

  @override
  String get syncConflictsBannerAction => 'Review';

  @override
  String get syncConflictLocalVersion => 'Your version';

  @override
  String get syncConflictRemoteVersion => 'Remote version';

  @override
  String get syncConflictKeepLocal => 'Keep mine';

  @override
  String get syncConflictKeepRemote => 'Use remote';

  @override
  String get syncConflictKindUpsert => 'Edit conflict';

  @override
  String get syncConflictKindDelete => 'Delete conflict';

  @override
  String get biometricSlotExpired => 'Biometric slot expired. Enter your master password once to re-enable biometric unlock.';

  @override
  String get biometricUnlockSuccess => 'Vault unlocked with biometrics.';
}

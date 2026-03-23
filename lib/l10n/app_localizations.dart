import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Vaulta'**
  String get appTitle;

  /// No description provided for @navVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get navVault;

  /// No description provided for @navAccess.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get navAccess;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @languageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSectionTitle;

  /// No description provided for @languageSelectorLabel.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageSelectorLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLocalUnlockPostureTitle.
  ///
  /// In en, this message translates to:
  /// **'Local unlock posture'**
  String get settingsLocalUnlockPostureTitle;

  /// No description provided for @settingsLocalUnlockPostureDescription.
  ///
  /// In en, this message translates to:
  /// **'Vaulta keeps sensitive state in Keychain / Keystore and uses device biometrics when available.'**
  String get settingsLocalUnlockPostureDescription;

  /// No description provided for @settingsMasterPasswordCreated.
  ///
  /// In en, this message translates to:
  /// **'Master password created'**
  String get settingsMasterPasswordCreated;

  /// No description provided for @settingsBiometricsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Biometrics available'**
  String get settingsBiometricsAvailable;

  /// No description provided for @settingsBiometricsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometrics enabled'**
  String get settingsBiometricsEnabled;

  /// No description provided for @settingsUnlockWithBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get settingsUnlockWithBiometrics;

  /// No description provided for @settingsBiometricSupportedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use {biometricLabel} to reopen the local session. If device biometric recovery remains valid, it also works after app restart.'**
  String settingsBiometricSupportedSubtitle(Object biometricLabel);

  /// No description provided for @settingsBiometricUnavailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Biometrics are not configured or supported in this environment.'**
  String get settingsBiometricUnavailableSubtitle;

  /// No description provided for @settingsAutoLockBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock on background'**
  String get settingsAutoLockBackgroundTitle;

  /// No description provided for @settingsAutoLockBackgroundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Locks Vaulta automatically if the app becomes inactive, paused, or detached.'**
  String get settingsAutoLockBackgroundSubtitle;

  /// No description provided for @settingsIdleTimeoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Foreground idle auto-lock'**
  String get settingsIdleTimeoutLabel;

  /// No description provided for @settingsLockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get settingsLockNow;

  /// No description provided for @settingsChangeMasterPassword.
  ///
  /// In en, this message translates to:
  /// **'Change master password'**
  String get settingsChangeMasterPassword;

  /// No description provided for @settingsSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices and sessions'**
  String get settingsSessionsTitle;

  /// No description provided for @settingsSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can revoke one device or cut every other active session.'**
  String get settingsSessionsSubtitle;

  /// No description provided for @settingsSessionsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh sessions'**
  String get settingsSessionsRefresh;

  /// No description provided for @settingsRevokeOtherDevices.
  ///
  /// In en, this message translates to:
  /// **'Revoke all other sessions'**
  String get settingsRevokeOtherDevices;

  /// No description provided for @settingsRevokeDevice.
  ///
  /// In en, this message translates to:
  /// **'Revoke device'**
  String get settingsRevokeDevice;

  /// No description provided for @settingsNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No registered devices for this user.'**
  String get settingsNoDevices;

  /// No description provided for @settingsCurrentDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get settingsCurrentDeviceLabel;

  /// No description provided for @settingsSessionStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get settingsSessionStatusActive;

  /// No description provided for @settingsSessionStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get settingsSessionStatusRevoked;

  /// No description provided for @settingsDeviceNeverSeen.
  ///
  /// In en, this message translates to:
  /// **'No activity recorded'**
  String get settingsDeviceNeverSeen;

  /// No description provided for @settingsDeviceRevokedMessage.
  ///
  /// In en, this message translates to:
  /// **'Device revoked successfully.'**
  String get settingsDeviceRevokedMessage;

  /// No description provided for @settingsRevokeOthersDone.
  ///
  /// In en, this message translates to:
  /// **'Other active sessions were revoked.'**
  String get settingsRevokeOthersDone;

  /// No description provided for @settingsRoadmapTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform security roadmap'**
  String get settingsRoadmapTitle;

  /// No description provided for @settingsRoadmapNotes.
  ///
  /// In en, this message translates to:
  /// **'Vault items are encrypted with AES-256-GCM using a PBKDF2-HMAC-SHA256-derived key from the master password. The key stays only in memory for the current session; reliable sync and biometric recovery across restarts are still pending.'**
  String get settingsRoadmapNotes;

  /// No description provided for @settingsSecureStorage.
  ///
  /// In en, this message translates to:
  /// **'Secure storage'**
  String get settingsSecureStorage;

  /// No description provided for @settingsBiometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock'**
  String get settingsBiometricUnlock;

  /// No description provided for @settingsHardwareBackedKeys.
  ///
  /// In en, this message translates to:
  /// **'Hardware-backed keys'**
  String get settingsHardwareBackedKeys;

  /// No description provided for @settingsVaultEncryptionReady.
  ///
  /// In en, this message translates to:
  /// **'Vault item encryption wired end-to-end'**
  String get settingsVaultEncryptionReady;

  /// No description provided for @idleNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get idleNever;

  /// No description provided for @idleDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get idleDisabled;

  /// No description provided for @idleOneMinute.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get idleOneMinute;

  /// No description provided for @idleFiveMinutes.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get idleFiveMinutes;

  /// No description provided for @idleFifteenMinutes.
  ///
  /// In en, this message translates to:
  /// **'15 minutes'**
  String get idleFifteenMinutes;

  /// No description provided for @idleStrict.
  ///
  /// In en, this message translates to:
  /// **'Strict'**
  String get idleStrict;

  /// No description provided for @idleRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get idleRecommended;

  /// No description provided for @idleRelaxed.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get idleRelaxed;

  /// No description provided for @changeMasterPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change master password'**
  String get changeMasterPasswordTitle;

  /// No description provided for @changeMasterPasswordCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current master password'**
  String get changeMasterPasswordCurrent;

  /// No description provided for @changeMasterPasswordNew.
  ///
  /// In en, this message translates to:
  /// **'New master password'**
  String get changeMasterPasswordNew;

  /// No description provided for @changeMasterPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm new master password'**
  String get changeMasterPasswordConfirm;

  /// No description provided for @changeMasterPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'This re-encrypts the entire vault with a new key.'**
  String get changeMasterPasswordHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @masterPasswordUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Master password updated successfully.'**
  String get masterPasswordUpdatedSuccess;

  /// No description provided for @changeMasterPasswordErrorFallback.
  ///
  /// In en, this message translates to:
  /// **'We could not change the master password. Review the data and try again.'**
  String get changeMasterPasswordErrorFallback;

  /// No description provided for @securityOnboardingEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Secure onboarding'**
  String get securityOnboardingEyebrow;

  /// No description provided for @securityOnboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'We create your master key with no dangerous shortcuts.'**
  String get securityOnboardingTitle;

  /// No description provided for @securityOnboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The master password validates local access and derives the key that encrypts vault items.'**
  String get securityOnboardingSubtitle;

  /// No description provided for @securityMasterPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Master password'**
  String get securityMasterPasswordTitle;

  /// No description provided for @securityMasterPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Use 12+ characters with real variety. Never store this key in plaintext.'**
  String get securityMasterPasswordDescription;

  /// No description provided for @securityCreateMasterPassword.
  ///
  /// In en, this message translates to:
  /// **'Create master password'**
  String get securityCreateMasterPassword;

  /// No description provided for @securityConfirmMasterPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm master password'**
  String get securityConfirmMasterPassword;

  /// No description provided for @securityChecklistHash.
  ///
  /// In en, this message translates to:
  /// **'PBKDF2-HMAC-SHA256 verifies the master password.'**
  String get securityChecklistHash;

  /// No description provided for @securityChecklistDerive.
  ///
  /// In en, this message translates to:
  /// **'A separate PBKDF2-HMAC-SHA256 derives the vault key.'**
  String get securityChecklistDerive;

  /// No description provided for @securityChecklistEncrypt.
  ///
  /// In en, this message translates to:
  /// **'Local items are encrypted with AES-256-GCM and records are stored with Keychain / Keystore.'**
  String get securityChecklistEncrypt;

  /// No description provided for @securityEnableBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Enable local biometrics'**
  String get securityEnableBiometrics;

  /// No description provided for @securityBiometricAvailable.
  ///
  /// In en, this message translates to:
  /// **'Link {biometricLabel} for quick unlock on this device.'**
  String securityBiometricAvailable(Object biometricLabel);

  /// No description provided for @securityBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No biometrics detected. You can still unlock with your master password.'**
  String get securityBiometricUnavailable;

  /// No description provided for @securityCreateSecureAccess.
  ///
  /// In en, this message translates to:
  /// **'Create secure vault access'**
  String get securityCreateSecureAccess;

  /// No description provided for @securityUnlockEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get securityUnlockEyebrow;

  /// No description provided for @securityUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Your vault stays closed until real identity is verified.'**
  String get securityUnlockTitle;

  /// No description provided for @securityUnlockBiometricSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with master password or {biometricLabel}.'**
  String securityUnlockBiometricSubtitle(Object biometricLabel);

  /// No description provided for @securityUnlockPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your master password to recover access.'**
  String get securityUnlockPasswordSubtitle;

  /// No description provided for @securityProtectedAccess.
  ///
  /// In en, this message translates to:
  /// **'Protected access'**
  String get securityProtectedAccess;

  /// No description provided for @securityUnlockVault.
  ///
  /// In en, this message translates to:
  /// **'Unlock vault'**
  String get securityUnlockVault;

  /// No description provided for @securityBiometricButton.
  ///
  /// In en, this message translates to:
  /// **'Biometric'**
  String get securityBiometricButton;

  /// No description provided for @dashboardDecryptError.
  ///
  /// In en, this message translates to:
  /// **'Vaulta could not decrypt the local vault right now.'**
  String get dashboardDecryptError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @newEntry.
  ///
  /// In en, this message translates to:
  /// **'New entry'**
  String get newEntry;

  /// No description provided for @entryCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Encrypted entry created.'**
  String get entryCreatedMessage;

  /// No description provided for @vaultUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Vault updated locally.'**
  String get vaultUpdatedMessage;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your encrypted control room'**
  String get dashboardSubtitle;

  /// No description provided for @dashboardHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Protected by system hardware'**
  String get dashboardHeroTitle;

  /// No description provided for @dashboardHeroBody.
  ///
  /// In en, this message translates to:
  /// **'The local vault already encrypts every entry with AES-256-GCM. Real local CRUD is ready; search, tags, generator, and reliable sync are still pending.'**
  String get dashboardHeroBody;

  /// No description provided for @dashboardPillTrustedDevices.
  ///
  /// In en, this message translates to:
  /// **'{count} devices trusted'**
  String dashboardPillTrustedDevices(int count);

  /// No description provided for @dashboardPillSyncEnabled.
  ///
  /// In en, this message translates to:
  /// **'Secure sync on'**
  String get dashboardPillSyncEnabled;

  /// No description provided for @dashboardPillSyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Offline encrypted vault'**
  String get dashboardPillSyncDisabled;

  /// No description provided for @dashboardPillWeakNeedRotation.
  ///
  /// In en, this message translates to:
  /// **'{count} passwords need rotation'**
  String dashboardPillWeakNeedRotation(int count);

  /// No description provided for @securityScore.
  ///
  /// In en, this message translates to:
  /// **'Security score'**
  String get securityScore;

  /// No description provided for @vaultEntries.
  ///
  /// In en, this message translates to:
  /// **'Vault entries'**
  String get vaultEntries;

  /// No description provided for @weakPasswords.
  ///
  /// In en, this message translates to:
  /// **'Weak passwords'**
  String get weakPasswords;

  /// No description provided for @reusedItems.
  ///
  /// In en, this message translates to:
  /// **'Reused items'**
  String get reusedItems;

  /// No description provided for @trustedDevices.
  ///
  /// In en, this message translates to:
  /// **'Trusted devices'**
  String get trustedDevices;

  /// No description provided for @priorityActions.
  ///
  /// In en, this message translates to:
  /// **'Priority actions'**
  String get priorityActions;

  /// No description provided for @dashboardQuickActionsSummary.
  ///
  /// In en, this message translates to:
  /// **'The vault is now real: create, edit, view details, and delete with encryption preserved end-to-end.'**
  String get dashboardQuickActionsSummary;

  /// No description provided for @createEncryptedEntry.
  ///
  /// In en, this message translates to:
  /// **'Create encrypted entry'**
  String get createEncryptedEntry;

  /// No description provided for @createEncryptedEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add new credentials and store them encrypted at rest.'**
  String get createEncryptedEntrySubtitle;

  /// No description provided for @planNextHardeningStep.
  ///
  /// In en, this message translates to:
  /// **'Plan next hardening step'**
  String get planNextHardeningStep;

  /// No description provided for @dashboardRoadmapSyncEnabled.
  ///
  /// In en, this message translates to:
  /// **'Sync is on the roadmap, but trust boundaries still need design.'**
  String get dashboardRoadmapSyncEnabled;

  /// No description provided for @dashboardRoadmapSyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Search, tags, generator, and attachments remain intentionally out of scope.'**
  String get dashboardRoadmapSyncDisabled;

  /// No description provided for @vaultEntriesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault entries'**
  String get vaultEntriesSectionTitle;

  /// No description provided for @searchVault.
  ///
  /// In en, this message translates to:
  /// **'Search title, username, or website'**
  String get searchVault;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @filterAllEntries.
  ///
  /// In en, this message translates to:
  /// **'All entries'**
  String get filterAllEntries;

  /// No description provided for @filterWeakOnly.
  ///
  /// In en, this message translates to:
  /// **'Weak passwords only'**
  String get filterWeakOnly;

  /// No description provided for @filterWithNotes.
  ///
  /// In en, this message translates to:
  /// **'Entries with notes'**
  String get filterWithNotes;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get resetFilters;

  /// No description provided for @noResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No entries match your current filters'**
  String get noResultsTitle;

  /// No description provided for @noResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different query or reset filters to see all items again.'**
  String get noResultsSubtitle;

  /// No description provided for @emptyVaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Your vault is empty'**
  String get emptyVaultTitle;

  /// No description provided for @emptyVaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first entry and Vaulta encrypts it before persisting.'**
  String get emptyVaultSubtitle;

  /// No description provided for @createFirstEntry.
  ///
  /// In en, this message translates to:
  /// **'Create first entry'**
  String get createFirstEntry;

  /// No description provided for @itemsTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String itemsTotal(int count);

  /// No description provided for @itemsShownOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{shown} shown - {total} total'**
  String itemsShownOfTotal(int shown, int total);

  /// No description provided for @editorTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get editorTitleEdit;

  /// No description provided for @editorTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New entry'**
  String get editorTitleNew;

  /// No description provided for @editorIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get editorIdentityTitle;

  /// No description provided for @editorTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get editorTitleLabel;

  /// No description provided for @editorTitleHint.
  ///
  /// In en, this message translates to:
  /// **'GitHub, banking, Wi-Fi...'**
  String get editorTitleHint;

  /// No description provided for @editorTitleValidation.
  ///
  /// In en, this message translates to:
  /// **'Give this entry a clear title.'**
  String get editorTitleValidation;

  /// No description provided for @editorUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username or email'**
  String get editorUsernameLabel;

  /// No description provided for @editorUsernameValidation.
  ///
  /// In en, this message translates to:
  /// **'Add the account identifier.'**
  String get editorUsernameValidation;

  /// No description provided for @editorCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get editorCategoryLabel;

  /// No description provided for @editorCategoryWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get editorCategoryWork;

  /// No description provided for @editorCategoryFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get editorCategoryFinance;

  /// No description provided for @editorCategoryPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get editorCategoryPersonal;

  /// No description provided for @editorCategoryInfrastructure.
  ///
  /// In en, this message translates to:
  /// **'Infrastructure'**
  String get editorCategoryInfrastructure;

  /// No description provided for @editorSecretTitle.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get editorSecretTitle;

  /// No description provided for @editorSecretDescription.
  ///
  /// In en, this message translates to:
  /// **'Vaulta recalculates strength locally before re-encrypting the entry.'**
  String get editorSecretDescription;

  /// No description provided for @editorSecretLabel.
  ///
  /// In en, this message translates to:
  /// **'Password or secret'**
  String get editorSecretLabel;

  /// No description provided for @editorSecretRequiredValidation.
  ///
  /// In en, this message translates to:
  /// **'Store a real secret, not an empty field.'**
  String get editorSecretRequiredValidation;

  /// No description provided for @editorSecretMinValidation.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get editorSecretMinValidation;

  /// No description provided for @editorGeneratorTitle.
  ///
  /// In en, this message translates to:
  /// **'Password generator'**
  String get editorGeneratorTitle;

  /// No description provided for @editorGeneratorChars.
  ///
  /// In en, this message translates to:
  /// **'{count} chars'**
  String editorGeneratorChars(int count);

  /// No description provided for @editorGenerateInsert.
  ///
  /// In en, this message translates to:
  /// **'Generate and insert'**
  String get editorGenerateInsert;

  /// No description provided for @editorWebsiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Website or app'**
  String get editorWebsiteLabel;

  /// No description provided for @editorWebsiteHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com'**
  String get editorWebsiteHint;

  /// No description provided for @editorNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get editorNotesLabel;

  /// No description provided for @editorNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Recovery codes, context, reminders...'**
  String get editorNotesHint;

  /// No description provided for @editorSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get editorSaveChanges;

  /// No description provided for @editorCreateEntry.
  ///
  /// In en, this message translates to:
  /// **'Create entry'**
  String get editorCreateEntry;

  /// No description provided for @editorGeneratorSetRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one character set to generate.'**
  String get editorGeneratorSetRequired;

  /// No description provided for @editorGeneratedInserted.
  ///
  /// In en, this message translates to:
  /// **'Generated password inserted.'**
  String get editorGeneratedInserted;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}

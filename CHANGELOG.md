# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Security

- **Biometric unlock envelope.** Vaulta can now enroll a per-vault
  biometric unlock path. The vault DEK is wrapped with HKDF-SHA256
  over a platform-protected key slot, and only the wrapped envelope is
  persisted on disk. On Android the platform-protected key is an
  RSA-2048 keypair in AndroidKeyStore with
  `setUserAuthenticationRequired(true)` and, on API 30+,
  `setUserAuthenticationParameters(0, AUTH_BIOMETRIC_STRONG)` so the
  private key is released only after a fresh `BiometricPrompt` per
  decrypt. The prompt authenticator set is `BIOMETRIC_STRONG`
  because the operation is bound to a `CryptoObject`; Android device
  credential fallback remains a master-password recovery path rather
  than a KeyStore decrypt path. On non-Android targets the biometric
  vault unlock is reported as unavailable rather than silently
  failing. The platform key provider is pluggable so an iOS Secure
  Enclave binding can be added without touching the controller. If the
  platform reports biometrics are no longer enrolled, Vaulta
  automatically clears both the preference and the envelope.

- **Single source of biometric truth.** The availability check and
  the `BiometricPrompt` itself now share one channel
  (`com.insyd.vaulta/biometric`). The previous implementation mixed
  `local_auth` for the gate and a custom MethodChannel for the
  prompt; on devices with weak biometrics the two would disagree
  and the unlock button would silently disappear. Only Android uses
  the new native vault-unlock service today; iOS / desktop / web keep
  the master-password path until equivalent bindings are added.

- **VaultSession invariant.** The session class now requires `kdf` and
  `dekWrap` to be either both present or both absent. A new
  `VaultSession.v2(...)` factory refuses to build a v2 session with
  missing wrap metadata, so the crypto service never receives a
  session that cannot be unwrapped.

- **Test KDF guard.** `MasterPasswordService` now asserts at
  construction that the fast test KDF is only enabled while running
  under `flutter_test` (`FLUTTER_TEST` env var). The fast KDF can
  never be enabled in a production binary by accident.

- **Master password record migration.** v1 records (PBKDF2-derived
  key) are migrated to the v2 envelope (Argon2id KEK + AES-256-GCM
  wrapped DEK) automatically the first time a user unlocks with their
  master password. The biometric envelope is re-enrolled under the new
  DEK in the same pass.

### Changed

- **Brand attribution.** The locked/onboarding screens now show a
  small `Tecnodespegue.com` footer, and Settings includes an About
  section crediting René Kuhm as founder of Tecnodespegue.
- **Android system icon coverage.** The Android manifest now declares
  Vaulta's adaptive icon, round icon, and themed monochrome icon for
  the app, launcher activity, and AndroidX biometric fallback activity.
  `MainActivity` also reapplies a Vaulta task bitmap after Flutter
  initializes so Samsung/Android system surfaces stop falling back to
  stale/default task icons.
- **Launcher cache bust.** Android now exposes Vaulta through a
  dedicated `.VaultaLauncherActivity` alias instead of using
  `.MainActivity` directly as the launcher component, forcing Samsung
  One UI Launcher to resolve a fresh component/icon pair after upgrades.
- **Adaptive icon framing.** The Android foreground and monochrome
  launcher vectors were redrawn inside the adaptive-icon safe zone so
  Samsung launchers do not crop the Vaulta lock toward the bottom edge.
- **Legacy launcher PNG refresh.** Android legacy `mipmap-*`
  launcher PNGs now use the same centered Vaulta geometry as the
  adaptive icon, covering Samsung/theme fallback paths that rasterize
  legacy resources.
- **Icon parity with app UI.** Android launcher, task, and biometric
  resources now mirror the in-app `VaultaLogomark`: dark surface,
  crimson lock body, paper shackle, and gold key slot.
- **Vault entry cards.** Saved credentials now render as richer cards
  with category icons, metadata chips, strength badges, update time,
  and an affordance to open the detail view.
- **Brand.** The `redesign/brand/*.svg` assets are now wired up as
  the launcher icon on Android, iOS, macOS, Windows and web. The
  vault icon stays the crimson padlock with the gold keyhole.
- **Auto-lock by default.** Background auto-lock and idle auto-lock
  remain on by default. The locked-state UI now reflects the real
  biometric availability instead of a hard-coded "false".
- **Biometric library upgrade.** `androidx.biometric` moves from
  `1.2.0-alpha05` to `1.4.0-alpha07` to pick up the bug fixes that
  the alpha05 line was missing on compileSdk 36 (notably the
  removal of the deprecated `setUserAuthenticationValidityDuration`
  from the public surface).
- **Biometric prompt is now localized.** Copy that used to be
  hardcoded Spanish in `MainActivity.kt` now lives in
  `res/values/strings.xml` and `res/values-en/strings.xml`.
- **CHANGELOG discipline.** This file is now kept in sync with
  notable security-relevant changes from each iteration.
- **OTA updates.** A new "Actualizaciones" section in Settings lets
  the user check for and install a newer signed release APK over the
  air (no uninstall, no Play Store, no data loss when the signing key
  is stable). A GitHub Actions workflow
  (`.github/workflows/dev-apk-release.yml`) rebuilds the signed APK on
  every push to `master` and overwrites the `dev-latest` GitHub
  Release. The app also auto-checks
  silently after unlock and surfaces a SnackBar with an
  "Actualizar" action when a newer build is available.

### Fixed

- **Biometric unlock no longer calls the privileged AndroidX
  biometric-logo API.** The prompt now relies on the app icon that
  AndroidX shows automatically, avoiding the
  `SET_BIOMETRIC_DIALOG_ADVANCED` permission path reserved for
  privileged apps.
- **OTA checks now compare the installed app version against the
  version published in the GitHub Release body.** Opening Android's
  installer is no longer treated as proof that the APK was installed,
  so cancelled or rejected installs won't make the app claim it is
  up to date.
- **OTA update checks no longer run network on Android's main
  thread.** `UpdateChannel` now performs GitHub release queries and
  APK downloads on a background executor, then posts the result back
  to Flutter. This fixes the `NetworkOnMainThreadException` that made
  the Settings screen report "up to date" even when the check had
  actually failed.
- **OTA errors are no longer disguised as "up to date".** Platform
  failures now surface to the update UI as an error banner, while the
  silent dashboard check still logs and stays quiet.
- `unlockWithBiometrics` no longer returns a hard-coded `false`. When
  no envelope is enrolled the controller explains why and points the
  user at the master password path; when an envelope is present and
  biometrics succeed, the controller actually unwraps the DEK and
  builds a `VaultSession` the same way a password unlock would.
- **Biometric unlock button would silently vanish** on devices
  whose only biometric is class-2 (face unlock). The app now separates
  capability probing from KeyStore decrypt eligibility: Android
  vault-key decrypt requires `BIOMETRIC_STRONG`, while weaker biometric
  or credential-only devices stay on the master-password path with a
  clear message.
- **No prompt for "no biometric enrolled"** is no longer
  indistinguishable from "no hardware". The native probe now
  reports the exact `BiometricManager` reason code (`NO_HARDWARE`,
  `NONE_ENROLLED`, `HW_UNAVAILABLE`, `SECURITY_UPDATE_REQUIRED`,
  `UNSUPPORTED`, `LOCKOUT`, `LOCKOUT_PERMANENT`, `TIMEOUT`,
  `USER_CANCELLED`), and the Dart side turns `NONE_ENROLLED` into
  a deep-link to `Settings.ACTION_BIOMETRIC_ENROLL` (API 30+) or
  `Settings.ACTION_SECURITY_SETTINGS` on older devices, surfaced
  from both the unlock screen and the settings screen.
- **Double biometric prompt** during unlock. The previous
  `LocalBiometricAuthService.authenticateForUnlock` was opening a
  `local_auth` prompt before the native `BiometricPrompt` for the
  KeyStore operation fired. The new
  `NativeBiometricAuthService.authenticateForUnlock` is a passive
  availability check; the actual prompt is opened once, by the
  KeyStore provider's `releaseEnvelopeKey`.
- **"Key permanently invalidated" was reported as a generic
  error.** The new `KeyPermanentlyInvalidatedException` is mapped
  to `BIOMETRIC_LOCKOUT_PERMANENT` so the UI can ask the user to
  re-enroll instead of looping on a stale key.

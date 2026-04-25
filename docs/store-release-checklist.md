# Vaulta final store submission checklist

This checklist tracks the external assets, secrets, accounts, and policy decisions required before submitting Vaulta to Google Play, Apple App Store, Mac App Store, and obvious desktop/web distribution channels. It intentionally does **not** contain secrets.

## Repository-ready configuration already present

- App name/label: `Vaulta` on Android, iOS, macOS, and web.
- Android package/application ID: `com.insyd.gestor_contrasenas`.
- iOS/macOS bundle ID: `com.insyd.gestorContrasenas`.
- Flutter version source: `pubspec.yaml` `version: 1.0.0+1`.
- Android release signing does not fall back to debug signing; see `docs/android-release-signing.md`.
- Android backup/data extraction is disabled for local vault data.
- Android cleartext traffic is disabled.
- iOS/macOS biometric usage strings explain local verification and master-password requirement.
- macOS sandbox allows outbound network access for optional Supabase sync.
- Supabase sync remains optional and only initializes when `SUPABASE_URL` and `SUPABASE_ANON_KEY` are supplied with `--dart-define`.

## Google Play blockers

- [ ] Create/verify Play Console app for package `com.insyd.gestor_contrasenas`.
- [ ] Generate Android upload keystore locally/CI and keep it outside the repo.
- [ ] Configure one signing path: `android/key.properties` (gitignored/local) or CI `VAULTA_UPLOAD_*` variables.
- [ ] Decide whether Supabase sync is enabled. If yes, pass `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...` from CI only.
- [ ] Complete Play Data Safety: user-provided password-vault data is sensitive; local entries are encrypted; if Supabase sync is enabled, encrypted snapshots/device IDs/session metadata may be transmitted to Supabase.
- [ ] Provide privacy policy URL, support URL/email, app category (`Productivity` or `Tools`), screenshots, feature graphic, store descriptions, and release notes.
- [ ] Confirm target SDK requirements at submission time.
- [ ] Confirm encryption/export compliance statements for password-management cryptography.

## Apple App Store / TestFlight blockers

- [ ] Register Bundle ID `com.insyd.gestorContrasenas` or intentionally change all platform IDs before release.
- [ ] Configure signing team, certificates, provisioning profiles, and App Store Connect app record outside the repo.
- [ ] Complete App Privacy questionnaire: sensitive user vault data; local encryption; optional Supabase encrypted sync metadata if enabled; no tracking unless SDKs are added later.
- [ ] Provide privacy policy URL, support URL, category (`Productivity` or `Utilities`), screenshots, app icon, store copy, and release notes.
- [ ] Explain in App Review notes that biometrics are local presence verification only; locked vault still requires the master password.
- [ ] Answer export compliance/encryption questions for AES-256-GCM/Argon2id password-vault cryptography.

## Mac App Store / desktop blockers

- [ ] Decide whether macOS distribution is Mac App Store, notarized direct download, or both.
- [ ] Configure Developer ID / Mac App Store certificates and provisioning outside the repo.
- [ ] Verify sandbox entitlements match release behavior. Current release sandbox allows outbound network client access for optional Supabase sync.
- [ ] Provide desktop screenshots, category, description, support URL, privacy policy URL.
- [ ] Confirm encryption/export compliance.

## Web distribution blockers

- [ ] Choose production domain and hosting.
- [ ] Publish reviewed privacy policy and update metadata/store listings with the final public URL.
- [ ] Decide whether web release may enable Supabase sync; if yes, configure environment at build/deploy time without committing secrets.
- [ ] Verify PWA icons, theme color, manifest, caching behavior, and offline messaging.

## Security/release review before submission

- [ ] Run `flutter analyze` and `flutter test` before every release candidate.
- [ ] Manual QA: vault create/unlock/lock, CRUD, search, password generation, biometric local verification, and optional sync.
- [ ] Review `docs/architecture/ADR-001-crypto.md`, `ADR-002-sync.md`, and `ADR-003-session-revocation.md` for user-facing claims.
- [ ] Avoid claiming third-party audit, breach monitoring, autofill, passkeys, or biometric unlock without master password unless implemented and verified.

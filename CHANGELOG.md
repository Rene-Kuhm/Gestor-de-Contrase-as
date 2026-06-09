# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Security

- **Biometric unlock envelope.** Vaulta can now enroll a per-vault
  biometric unlock path. The vault DEK is wrapped with HKDF-SHA256
  over a platform-protected key slot, and only the wrapped envelope is
  persisted on disk. The unwrap step runs after a successful
  `local_auth` prompt. On non-mobile targets the unlock is reported
  as unavailable rather than silently failing. The platform key
  provider is pluggable so a real Android Keystore / iOS Secure Enclave
  binding can be dropped in without touching the controller. If the
  platform reports biometrics are no longer enrolled, Vaulta
  automatically clears both the preference and the envelope.

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

- **Brand.** The `redesign/brand/*.svg` assets are now wired up as
  the launcher icon on Android, iOS, macOS, Windows and web. The
  vault icon stays the crimson padlock with the gold keyhole.
- **Auto-lock by default.** Background auto-lock and idle auto-lock
  remain on by default. The locked-state UI now reflects the real
  biometric availability instead of a hard-coded "false".
- **CHANGELOG discipline.** This file is now kept in sync with
  notable security-relevant changes from each iteration.

### Fixed

- `unlockWithBiometrics` no longer returns a hard-coded `false`. When
  no envelope is enrolled the controller explains why and points the
  user at the master password path; when an envelope is present and
  biometrics succeed, the controller actually unwraps the DEK and
  builds a `VaultSession` the same way a password unlock would.

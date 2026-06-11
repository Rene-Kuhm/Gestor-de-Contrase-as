# Threat model

> Honest description of what Vaulta defends against, what it does
> not, and the residual risks the user accepts by choosing this
> product. Written for an external auditor, but also useful to
> the user when deciding whether Vaulta fits their threat profile.

## What we defend against

The primary threat we defend against is **device compromise with
seizure while the app is locked**: an attacker (e.g. a thief who
picked up an unlocked phone, a border agent, a curious coworker)
gets physical access to a powered-on device with the app in the
background. The defender is the master password, optionally
backed by a hardware-bound biometric envelope.

Concretely, against this threat we defend:

- **Offline decryption of the vault blob.** The blob is
  AES-256-GCM encrypted with a per-vault random DEK. The DEK is
  in turn encrypted with a KEK derived from the master password
  via Argon2id. Without the password, recovering the DEK requires
  brute-forcing Argon2id, which is intentionally expensive.
- **Direct extraction of the DEK from secure storage.** On
  Android, the wrapped DEK is persisted in
  EncryptedSharedPreferences (Keystore-backed). On iOS, in
  Keychain. On Windows, in Credential Manager. These are
  not perfect (a rooted device can read them), but on an
  unmodified OS they raise the bar.
- **Biometric replay.** On Android, the private RSA key used to
  unwrap the DEK is bound to the BiometricPrompt and cannot be
  used without a fresh user presence check.
- **Sync replay / split-brain.** The sync protocol uses CAS
  (version-based) + tombstone + idempotency-key dedup. A
  malicious or replayed sync message cannot make a stale
  mutation win against a newer remote version.
- **Cross-device session leak.** Per-device revocation
  (`ADR-003` + `device_session_revocation_service.dart`) lets the
  user "log out everywhere" or revoke a specific device
  remotely, and the local session is invalidated the next time
  the lifecycle checks.
- **Tampering with the encrypted blob.** Each blob carries a
  GCM authentication tag. Any modification fails decryption and
  the load path surfaces a `FormatException` instead of silently
  accepting corrupted data.

## What we explicitly do NOT defend against

These are **known limitations** documented here so the user can
decide whether Vaulta is appropriate for their use case:

- **A compromised device with the master password in memory.**
  If the attacker has root + the master password is currently
  typed in (or just was), the DEK is in memory. Cold-boot
  attacks are partially mitigated (DEK is held in `VaultSession`
  which lives in process memory; the master password itself is
  not persisted), but we do not try to detect the breach.
- **A compromised OS keychain / secure storage.** On rooted
  Android or jailbroken iOS, the wrapped-DEK envelope is
  readable. The Argon2id layer still protects the plaintext
  DEK as long as the master password is not also compromised.
- **Forward secrecy on sync.** The same DEK encrypts all
  payloads. Compromising the DEK compromises every payload
  ever shipped under it. Rekeying (master password change)
  rotates the DEK, but old ciphertexts remain readable to anyone
  with the old DEK.
- **Side channels (timing, cache, EM).** Argon2id is
  constant-time per the spec, but the Dart / Flutter / FFI
  layers around it are not formally side-channel analyzed.
- **Quantum attackers.** AES-256-GCM and Argon2id are
  classical; Grover's algorithm halves AES key strength, but
  we are not using PQ primitives.
- **Hardware keyloggers / compromised keyboards.** If the
  master password is captured at entry (e.g. a keylogger on a
  rooted device), no amount of crypto defends against the
  resulting plaintext. This is a general limitation of all
  password-based systems.
- **Coercion.** The master password is single-factor. A
  physical-coercion attacker who forces the user to type it has
  the same access as the user. (Mitigations like duress
  passwords are out of scope for the current release.)
- **Audit log of unlock attempts.** The local app does not
  maintain a tamper-evident log of unlock attempts or
  configuration changes. Sync-side revocations are recorded in
  the backend but the user cannot review them locally.
- **Replay of a leaked ciphertext.** If an attacker exfiltrates
  an old encrypted blob, they can keep trying to brute-force
  Argon2id forever; we do not rotate the KDF salt or invalidate
  the ciphertext on the user side. (Re-keying the master
  password does rotate the wrap, but the old wrapped-DEK
  envelope is not proactively wiped.)
- **Timing oracles in the sync protocol.** Sync operations do
  constant work per round, but the queue dispatch has timing
  variations based on queue length that could in theory leak
  information about mutation rate. We do not believe this is
  exploitable in practice but flag it for completeness.

## Trust model

We **trust**:

- The user to choose a strong master password.
- The OS-provided secure storage (Android Keystore / iOS Keychain
  / Windows Credential Manager) to be intact.
- On Android, the device's TEE / StrongBox to actually hold
  the RSA private key (we use `setUserAuthenticationRequired`,
  but the device's hardware backing is OS-managed).
- The Dart / Flutter runtime to not leak memory to the JS bridge
  or to background isolates (we use the `cryptography` package
  with `SecretKey` which holds bytes; the package's own
  hardening is outside our control).
- The `package:meta`, `package:uuid`, `package:cryptography`
  packages from pub.dev (no supply-chain attack mitigation
  beyond pub.dev's signed-publishers model).

We **do not trust**:

- The filesystem to be free of leaked ciphertexts (mitigated
  only by OS-level disk encryption, which is the user's
  responsibility).
- The backend (Supabase) with the master password or the DEK;
  the server only ever sees AES-256-GCM ciphertext, but a
  backend compromise leaks all ciphertexts to the attacker.
- The user's network: TLS is the OS's responsibility. We do
  not add an extra application-layer crypto layer.
- The other devices in the sync group: a compromised device
  with a valid DEK can push arbitrary ciphertexts; the CAS
  mechanism catches version conflicts but cannot detect a
  malicious device pushing "correct" ciphertexts that decrypt
  to attacker-chosen plaintext for a known record id.

## Residual risk acceptance

The user accepts the following risks by choosing Vaulta for the
MVP:

1. No third-party crypto review (this is the gap that
   `vaulta-audit-external` is meant to close — see CRYPTO.md
   for the audit index).
2. Single-factor master password (no U2F, no hardware token).
3. The biometric unlock path on Android is a UX shortcut, not
   a crypto-binding guarantee. (`local_auth` does not bind
   keys to hardware by itself; the RSA-2048 wrapping in
   `AndroidKeystoreEnvelopeKeyProvider` does, but a compromised
   Keystore breaks the chain.)
4. Sync is disabled by default; the user has to opt in to
   Supabase sync, which moves the trust boundary to include
   the backend.

## What a security review should check (questions for the auditor)

1. Are the Argon2id parameters (64 MiB, 3 iterations, parallelism 1)
   appropriate for 2026+ mobile and desktop hardware? Should
   they be raised?
2. Is the AES-GCM nonce generation actually unique across
   concurrent encryptions, given the Dart isolate model and
   the way `package:cryptography` handles random nonces?
3. Does the DEK live in any place that could be exfiltrated
   by a sandboxed app on a non-rooted device (e.g. process
   memory dumps readable by other apps via /proc)?
4. Does the Android KeyStore RSA-2048 actually leverage the
   secure element on the target device classes (Pixel 6/7/8,
   Samsung Galaxy S22+, etc.)?
5. Is the v1 → v2 migration path safe against a downgrade
   attack (an attacker who has a v1 blob and the user's
   password tries to re-introduce v1)?
6. Is the sync CAS protocol safe against a backend that
   lies about record versions (e.g. a malicious Supabase
   operator)?
7. Does the biometric envelope survive a Keystore wipe (e.g.
   user changes device PIN)? If yes, how does the user
   recover their vault?

The answers to these belong in the audit report, not in
this document.

## How to update this document

This is not a decision record (those are ADRs). It is a
**statement of the current threat model**. Update it whenever:

- A new threat class is added (e.g. a new feature, a new
  attack surface).
- A defense is added or removed (changes what we defend
  against).
- A new residual risk is identified (e.g. discovered in a
  bug report or in an external review).

Updating this file does not require an ADR; just commit with
a clear message describing the change.
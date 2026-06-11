/// Snapshot of the security capabilities the current platform can
/// offer. Computed once at startup by `VaultSecurityController` and
/// surfaced through the security screen so the UI can explain to the
/// user what works and what doesn't on this device.
class PlatformSecurityPlan {
  /// Creates a [PlatformSecurityPlan]. All flags default to `false`;
  /// [notes] is free-form text shown verbatim in the UI (typically the
  /// diagnostic message from the last failed capability check).
  const PlatformSecurityPlan({
    required this.secureStorage,
    required this.biometricUnlock,
    required this.hardwareBackedKeys,
    required this.vaultEncryptionReady,
    required this.notes,
  });

  /// True when the OS can persist small secrets in a protected store
  /// (Android Keystore, iOS Keychain, Windows Credential Manager, etc.).
  final bool secureStorage;

  /// True when biometric/PIN prompt is wired and usable on this device.
  final bool biometricUnlock;

  /// True when at least one path uses a hardware-backed key (e.g.
  /// Android KeyStore RSA-2048 wrapping).
  final bool hardwareBackedKeys;

  /// True when all the pieces required to encrypt the vault are in
  /// place (Argon2id KDF, AES-GCM crypto service, secure storage).
  final bool vaultEncryptionReady;

  /// Free-form explanation of the current state. Empty string when
  /// everything is healthy.
  final String notes;
}

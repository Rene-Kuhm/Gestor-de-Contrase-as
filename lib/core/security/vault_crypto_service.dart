/// Encrypts and decrypts individual vault item payloads using a
/// per-item key (either a [VaultSession] or a raw [SecretKey]). The
/// returned ciphertext is a self-describing JSON envelope (version +
/// algorithm + nonce + tag + keyId) so the format can evolve without
/// breaking older payloads.
abstract interface class VaultCryptoService {
  /// Encrypts [plaintext] with [secretKey] and tags the result with
  /// [keyId] (the vault's current key identifier, used at decrypt time
  /// to detect rekeying).
  Future<String> encrypt({
    required String plaintext,
    required Object secretKey,
    required String keyId,
  });

  /// Decrypts [ciphertext] with [secretKey], asserting that the
  /// embedded keyId matches [expectedKeyId]. A mismatch throws because
  /// it means the vault was rekeyed and the stored payload needs to be
  /// re-encrypted with the current key.
  Future<String> decrypt({
    required String ciphertext,
    required Object secretKey,
    required String expectedKeyId,
  });
}

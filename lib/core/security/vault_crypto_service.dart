abstract interface class VaultCryptoService {
  Future<String> encrypt({
    required String plaintext,
    required Object secretKey,
    required String keyId,
  });

  Future<String> decrypt({
    required String ciphertext,
    required Object secretKey,
    required String expectedKeyId,
  });
}

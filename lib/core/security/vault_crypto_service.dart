abstract interface class VaultCryptoService {
  Future<String> encrypt({
    required String plaintext,
    required String masterKeyId,
  });

  Future<String> decrypt({
    required String ciphertext,
    required String masterKeyId,
  });
}

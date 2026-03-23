import 'vault_crypto_service.dart';

class DeferredVaultCryptoService implements VaultCryptoService {
  const DeferredVaultCryptoService();

  static const _message =
      'Vault item encryption is intentionally not wired yet. Integrate an audited envelope-encryption flow before persisting real secrets.';

  @override
  Future<String> decrypt({
    required String ciphertext,
    required String masterKeyId,
  }) {
    throw StateError(_message);
  }

  @override
  Future<String> encrypt({
    required String plaintext,
    required String masterKeyId,
  }) {
    throw StateError(_message);
  }
}

import 'package:cryptography/cryptography.dart';

class VaultSession {
  const VaultSession({required this.keyId, required this.secretKey});

  final String keyId;
  final SecretKey secretKey;
}

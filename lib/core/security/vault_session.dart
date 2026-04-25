import 'package:cryptography/cryptography.dart';

class VaultSession {
  const VaultSession({
    required this.keyId,
    required this.secretKey,
    this.kdf,
    this.dekWrap,
  });

  final String keyId;

  /// v2: random per-vault DEK. Legacy v1 sessions may still hold the
  /// password-derived key until the next unlock/rekey migration completes.
  final SecretKey secretKey;
  final Map<String, dynamic>? kdf;
  final Map<String, dynamic>? dekWrap;

  bool get isV2 => kdf != null && dekWrap != null;
}

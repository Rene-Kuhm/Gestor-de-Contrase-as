import 'package:cryptography/cryptography.dart';

/// In-memory handle to an unlocked vault.
///
/// v1 (legacy): the secret key is the password-derived key itself.
/// v2 (current): the secret key is a random 32-byte DEK that lives only
/// in memory. The DEK is wrapped under a KEK derived from the master
/// password; the wrap parameters are stored in [kdf] and [dekWrap] so
/// the controller can re-derive the KEK on unlock and unwrap the DEK.
///
/// Invariant: a v2 session is never constructed without both [kdf] and
/// [dekWrap] set. Use [VaultSession.v1] or [VaultSession.v2] instead of
/// the default constructor in production code. The default constructor
/// is kept only for deserialization paths (e.g. tests of legacy data).
class VaultSession {
  /// Direct constructor. Prefer [VaultSession.v1] or [VaultSession.v2]
  /// in production code; the default constructor stays for legacy
  /// deserialization paths where [kdf]/[dekWrap] may be absent.
  const VaultSession({
    required this.keyId,
    required this.secretKey,
    this.kdf,
    this.dekWrap,
  }) : assert(
          (kdf == null) == (dekWrap == null),
          'kdf and dekWrap must be either both present or both absent',
        );

  /// Builds a v2 session. Throws [ArgumentError] if either [kdf] or
  /// [dekWrap] is missing — there is no way to recover the DEK without
  /// both, and silently building a partial session is exactly the bug
  /// this constructor exists to prevent.
  factory VaultSession.v2({
    required String keyId,
    required SecretKey secretKey,
    required Map<String, dynamic> kdf,
    required Map<String, dynamic> dekWrap,
  }) {
    if (kdf.isEmpty) {
      throw ArgumentError.value(kdf, 'kdf', 'kdf must not be empty');
    }
    if (dekWrap.isEmpty) {
      throw ArgumentError.value(dekWrap, 'dekWrap', 'dekWrap must not be empty');
    }
    return VaultSession(
      keyId: keyId,
      secretKey: secretKey,
      kdf: kdf,
      dekWrap: dekWrap,
    );
  }

  /// Builds a legacy v1 session where the secret key is the
  /// password-derived key. Used during the v1->v2 migration window.
  factory VaultSession.v1({
    required String keyId,
    required SecretKey secretKey,
  }) {
    return VaultSession(keyId: keyId, secretKey: secretKey);
  }

  /// Identifier of the key this session was built with. Used by the
  /// crypto service at decrypt time to detect rekeying.
  final String keyId;

  /// v2: random per-vault DEK. Legacy v1 sessions may still hold the
  /// password-derived key until the next unlock/rekey migration completes.
  final SecretKey secretKey;

  /// KDF parameters used to derive the KEK (Argon2id memory, iterations,
  /// parallelism, salt). Non-null for v2 sessions, `null` for v1.
  final Map<String, dynamic>? kdf;

  /// Wrapped DEK envelope (ciphertext + nonce + tag of the DEK under
  /// the KEK). Non-null for v2 sessions, `null` for v1.
  final Map<String, dynamic>? dekWrap;

  /// True if this session is the v2 shape (both kdf and dekWrap set).
  bool get isV2 => kdf != null && dekWrap != null;
}

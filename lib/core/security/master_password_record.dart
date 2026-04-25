import 'dart:convert';

class MasterPasswordRecord {
  const MasterPasswordRecord({
    required this.version,
    required this.verifierIterations,
    required this.verifierSalt,
    required this.verifier,
    required this.encryptionIterations,
    required this.encryptionSalt,
    required this.keyId,
    required this.createdAt,
    this.kdf,
    this.dekWrap,
  });

  final int version;
  final int verifierIterations;
  final String verifierSalt;
  final String verifier;
  final int encryptionIterations;
  final String encryptionSalt;
  final String keyId;
  final DateTime createdAt;
  final Map<String, dynamic>? kdf;
  final Map<String, dynamic>? dekWrap;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'verifierIterations': verifierIterations,
      'verifierSalt': verifierSalt,
      'verifier': verifier,
      'encryptionIterations': encryptionIterations,
      'encryptionSalt': encryptionSalt,
      'keyId': keyId,
      'createdAt': createdAt.toIso8601String(),
      if (kdf != null) 'kdf': kdf,
      if (dekWrap != null) 'dek_wrap': dekWrap,
    };
  }

  factory MasterPasswordRecord.fromJson(Map<String, dynamic> json) {
    final verifierIterations =
        (json['verifierIterations'] ?? json['iterations']) as int;
    final verifierSalt = (json['verifierSalt'] ?? json['salt']) as String;
    final encryptionIterations =
        (json['encryptionIterations'] ?? verifierIterations) as int;
    final encryptionSalt = (json['encryptionSalt'] ?? verifierSalt) as String;

    return MasterPasswordRecord(
      version: json['version'] as int,
      verifierIterations: verifierIterations,
      verifierSalt: verifierSalt,
      verifier: json['verifier'] as String,
      encryptionIterations: encryptionIterations,
      encryptionSalt: encryptionSalt,
      keyId: (json['keyId'] ?? 'legacy-master-password') as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      kdf: (json['kdf'] as Map?)?.cast<String, dynamic>(),
      dekWrap: (json['dek_wrap'] as Map?)?.cast<String, dynamic>(),
    );
  }

  String encode() => jsonEncode(toJson());

  factory MasterPasswordRecord.decode(String source) {
    return MasterPasswordRecord.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }
}

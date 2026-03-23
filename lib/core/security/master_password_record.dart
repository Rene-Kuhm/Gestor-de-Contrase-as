import 'dart:convert';

class MasterPasswordRecord {
  const MasterPasswordRecord({
    required this.version,
    required this.iterations,
    required this.salt,
    required this.verifier,
    required this.createdAt,
  });

  final int version;
  final int iterations;
  final String salt;
  final String verifier;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'iterations': iterations,
      'salt': salt,
      'verifier': verifier,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MasterPasswordRecord.fromJson(Map<String, dynamic> json) {
    return MasterPasswordRecord(
      version: json['version'] as int,
      iterations: json['iterations'] as int,
      salt: json['salt'] as String,
      verifier: json['verifier'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String encode() => jsonEncode(toJson());

  factory MasterPasswordRecord.decode(String source) {
    return MasterPasswordRecord.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }
}

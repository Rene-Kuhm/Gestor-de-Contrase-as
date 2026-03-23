enum SyncConflictOperationKind { upsert, delete }

enum SyncConflictResolution { keepLocal, keepRemote }

class SyncConflictSnapshot {
  const SyncConflictSnapshot({
    required this.version,
    this.keyVersion,
    this.ciphertext,
    this.nonce,
    this.aad,
    this.deletedAt,
    this.updatedAt,
  });

  final int? version;
  final int? keyVersion;
  final String? ciphertext;
  final String? nonce;
  final String? aad;
  final DateTime? deletedAt;
  final DateTime? updatedAt;

  factory SyncConflictSnapshot.fromJson(Map<String, dynamic> json) {
    return SyncConflictSnapshot(
      version: json['version'] as int?,
      keyVersion: json['keyVersion'] as int?,
      ciphertext: json['ciphertext'] as String?,
      nonce: json['nonce'] as String?,
      aad: json['aad'] as String?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String).toUtc(),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'keyVersion': keyVersion,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'aad': aad,
      'deletedAt': deletedAt?.toUtc().toIso8601String(),
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    };
  }
}

class SyncConflictRecord {
  const SyncConflictRecord({
    required this.id,
    required this.opId,
    required this.localRecordId,
    required this.remoteRecordId,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.lastResultCode,
    this.message,
    this.expectedVersion,
    this.currentVersion,
    this.localSnapshot,
    this.remoteSnapshot,
  });

  final String id;
  final String opId;
  final String localRecordId;
  final String remoteRecordId;
  final SyncConflictOperationKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastResultCode;
  final String? message;
  final int? expectedVersion;
  final int? currentVersion;
  final SyncConflictSnapshot? localSnapshot;
  final SyncConflictSnapshot? remoteSnapshot;

  SyncConflictRecord copyWith({
    DateTime? updatedAt,
    String? lastResultCode,
    String? message,
    int? expectedVersion,
    int? currentVersion,
    SyncConflictSnapshot? localSnapshot,
    SyncConflictSnapshot? remoteSnapshot,
  }) {
    return SyncConflictRecord(
      id: id,
      opId: opId,
      localRecordId: localRecordId,
      remoteRecordId: remoteRecordId,
      kind: kind,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastResultCode: lastResultCode ?? this.lastResultCode,
      message: message ?? this.message,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      currentVersion: currentVersion ?? this.currentVersion,
      localSnapshot: localSnapshot ?? this.localSnapshot,
      remoteSnapshot: remoteSnapshot ?? this.remoteSnapshot,
    );
  }

  factory SyncConflictRecord.fromJson(Map<String, dynamic> json) {
    return SyncConflictRecord(
      id: json['id'] as String,
      opId: json['opId'] as String,
      localRecordId: json['localRecordId'] as String,
      remoteRecordId: json['remoteRecordId'] as String,
      kind: _kindFromString(json['kind'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      lastResultCode: json['lastResultCode'] as String?,
      message: json['message'] as String?,
      expectedVersion: json['expectedVersion'] as int?,
      currentVersion: json['currentVersion'] as int?,
      localSnapshot: json['localSnapshot'] == null
          ? null
          : SyncConflictSnapshot.fromJson(
              json['localSnapshot'] as Map<String, dynamic>,
            ),
      remoteSnapshot: json['remoteSnapshot'] == null
          ? null
          : SyncConflictSnapshot.fromJson(
              json['remoteSnapshot'] as Map<String, dynamic>,
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'opId': opId,
      'localRecordId': localRecordId,
      'remoteRecordId': remoteRecordId,
      'kind': kind.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'lastResultCode': lastResultCode,
      'message': message,
      'expectedVersion': expectedVersion,
      'currentVersion': currentVersion,
      'localSnapshot': localSnapshot?.toJson(),
      'remoteSnapshot': remoteSnapshot?.toJson(),
    };
  }

  static SyncConflictOperationKind _kindFromString(String raw) {
    return switch (raw) {
      'upsert' => SyncConflictOperationKind.upsert,
      'delete' => SyncConflictOperationKind.delete,
      _ => SyncConflictOperationKind.upsert,
    };
  }
}

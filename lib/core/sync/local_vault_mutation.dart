class LocalVaultMutation {
  const LocalVaultMutation._({
    required this.kind,
    required this.localRecordId,
    required this.occurredAt,
    this.ciphertext,
    this.nonce,
    this.aad,
    this.keyVersion,
  });

  factory LocalVaultMutation.upsert({
    required String localRecordId,
    required String ciphertext,
    required String nonce,
    String? aad,
    required int keyVersion,
    required DateTime occurredAt,
  }) {
    return LocalVaultMutation._(
      kind: LocalVaultMutationKind.upsert,
      localRecordId: localRecordId,
      ciphertext: ciphertext,
      nonce: nonce,
      aad: aad,
      keyVersion: keyVersion,
      occurredAt: occurredAt,
    );
  }

  factory LocalVaultMutation.delete({
    required String localRecordId,
    required DateTime occurredAt,
  }) {
    return LocalVaultMutation._(
      kind: LocalVaultMutationKind.delete,
      localRecordId: localRecordId,
      occurredAt: occurredAt,
    );
  }

  final LocalVaultMutationKind kind;
  final String localRecordId;
  final String? ciphertext;
  final String? nonce;
  final String? aad;
  final int? keyVersion;
  final DateTime occurredAt;
}

enum LocalVaultMutationKind { upsert, delete }

abstract interface class LocalVaultMutationSink {
  Future<void> onLocalMutation(LocalVaultMutation mutation);
}

class RelayLocalVaultMutationSink implements LocalVaultMutationSink {
  LocalVaultMutationSink? _delegate;

  void attach(LocalVaultMutationSink delegate) {
    _delegate = delegate;
  }

  @override
  Future<void> onLocalMutation(LocalVaultMutation mutation) async {
    final delegate = _delegate;
    if (delegate == null) {
      return;
    }

    await delegate.onLocalMutation(mutation);
  }
}

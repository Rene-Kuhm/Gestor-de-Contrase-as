import 'package:flutter/foundation.dart';

typedef SyncDiagnosticsHook = void Function(SyncDiagnosticEvent event);

class SyncDiagnosticEvent {
  const SyncDiagnosticEvent({
    required this.scope,
    required this.operation,
    required this.code,
    required this.message,
    required this.retriable,
    required this.timestamp,
    this.attempt,
    this.maxAttempts,
    this.errorType,
    this.metadata = const <String, Object?>{},
  });

  final String scope;
  final String operation;
  final String code;
  final String message;
  final bool retriable;
  final DateTime timestamp;
  final int? attempt;
  final int? maxAttempts;
  final String? errorType;
  final Map<String, Object?> metadata;
}

final class SyncStatusCodes {
  static const casConflict = 'cas_conflict';
  static const idempotencyMismatch = 'idempotency_mismatch';
  static const revokedSessionOrDevice = 'revoked_session_or_device';
  static const offlineNetworkError = 'offline_network_error';
  static const transportError = 'transport_error';
  static const unknown = 'unknown';
}

String syncMessageForCode(String code, {String? fallback}) {
  return switch (code) {
    SyncStatusCodes.casConflict =>
      'Conflicto de version detectado. Se requiere resolucion manual.',
    SyncStatusCodes.idempotencyMismatch =>
      'La operacion remota no coincide con la llave de idempotencia y se freno para evitar corrupcion.',
    SyncStatusCodes.revokedSessionOrDevice =>
      'La sesion o dispositivo fue revocado remotamente.',
    SyncStatusCodes.offlineNetworkError =>
      'No hay conectividad con el servidor de sync.',
    SyncStatusCodes.transportError =>
      fallback ?? 'Fallo de transporte durante sync.',
    _ => fallback ?? 'Fallo de sincronizacion no clasificado.',
  };
}

enum SyncErrorDisposition { transient, definitive }

SyncErrorDisposition classifySyncError(Object error) {
  if (_looksDefinitive(error)) {
    return SyncErrorDisposition.definitive;
  }
  if (_looksTransient(error)) {
    return SyncErrorDisposition.transient;
  }
  return SyncErrorDisposition.definitive;
}

String syncErrorCode(Object error) {
  if (_looksRevocation(error)) {
    return SyncStatusCodes.revokedSessionOrDevice;
  }
  if (_looksTransient(error)) {
    return SyncStatusCodes.offlineNetworkError;
  }
  return SyncStatusCodes.transportError;
}

void emitSyncDiagnostic({
  required String scope,
  required String operation,
  required String code,
  required String message,
  required bool retriable,
  required DateTime timestamp,
  SyncDiagnosticsHook? hook,
  int? attempt,
  int? maxAttempts,
  Object? error,
  Map<String, Object?> metadata = const <String, Object?>{},
}) {
  final event = SyncDiagnosticEvent(
    scope: scope,
    operation: operation,
    code: code,
    message: message,
    retriable: retriable,
    timestamp: timestamp.toUtc(),
    attempt: attempt,
    maxAttempts: maxAttempts,
    errorType: error?.runtimeType.toString(),
    metadata: metadata,
  );

  final payload = <String, Object?>{
    'scope': event.scope,
    'operation': event.operation,
    'code': event.code,
    'retriable': event.retriable,
    'attempt': event.attempt,
    'maxAttempts': event.maxAttempts,
    'errorType': event.errorType,
    'message': event.message,
    'metadata': event.metadata,
  };
  debugPrint('[sync][diag] $payload');
  hook?.call(event);
}

bool _looksTransient(Object error) {
  final text = _errorText(error);
  final statusCode = _statusCodeFrom(error);
  if (statusCode != null) {
    if (statusCode == 408 || statusCode == 429 || statusCode >= 500) {
      return true;
    }
    if (statusCode == 401 || statusCode == 403 || statusCode == 409) {
      return false;
    }
  }

  if (_containsAny(text, _transientHints)) {
    return true;
  }

  final type = error.runtimeType.toString().toLowerCase();
  return _containsAny(type, _transientTypeHints);
}

bool _looksDefinitive(Object error) {
  final text = _errorText(error);
  final statusCode = _statusCodeFrom(error);
  if (statusCode != null &&
      (statusCode == 401 || statusCode == 403 || statusCode == 409)) {
    return true;
  }

  return _containsAny(text, _definitiveHints);
}

bool _looksRevocation(Object error) {
  final text = _errorText(error);
  return _containsAny(text, _revocationHints);
}

int? _statusCodeFrom(Object error) {
  final dynamic dynamicError = error;
  final candidates = <Object?>[
    _safeRead(() => dynamicError.statusCode),
    _safeRead(() => dynamicError.status),
  ];
  for (final candidate in candidates) {
    if (candidate is int) {
      return candidate;
    }
    if (candidate is num) {
      return candidate.toInt();
    }
    if (candidate is String) {
      final parsed = int.tryParse(candidate);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

String _errorText(Object error) {
  final dynamic dynamicError = error;
  final parts = <String>[
    error.toString(),
    _safeRead(() => dynamicError.message)?.toString() ?? '',
    _safeRead(() => dynamicError.code)?.toString() ?? '',
    _safeRead(() => dynamicError.details)?.toString() ?? '',
    _safeRead(() => dynamicError.hint)?.toString() ?? '',
  ];
  return parts.join(' ').toLowerCase();
}

T? _safeRead<T>(T Function() reader) {
  try {
    return reader();
  } catch (_) {
    return null;
  }
}

bool _containsAny(String source, List<String> needles) {
  for (final needle in needles) {
    if (source.contains(needle)) {
      return true;
    }
  }
  return false;
}

const _transientHints = <String>[
  'offline',
  'network',
  'socket',
  'connection reset',
  'connection refused',
  'timed out',
  'timeout',
  'temporarily unavailable',
  'temporary failure',
  'too many requests',
  'rate limit',
  'service unavailable',
  'gateway timeout',
];

const _transientTypeHints = <String>[
  'timeout',
  'socket',
  'network',
  'clientexception',
  'postgrestexception',
];

const _definitiveHints = <String>[
  'unauth',
  'forbidden',
  'access denied',
  'invalid device',
  'idempotency_mismatch',
  'cas_conflict',
  'version mismatch',
  'revoked',
];

const _revocationHints = <String>[
  'revoked_device',
  'revoked_all',
  'session_revoked',
  'device_revoked',
  'revoked',
];

/// Platform-agnostic key/value storage for small secrets (DEK envelopes,
/// locale code, device id, etc.). Implementations must use OS-protected
/// storage where available — see [FlutterSecureStorageService] for the
/// production backend.
abstract interface class SecureStorageService {
  /// Persists [value] under [key]. Overwrites any previous value.
  Future<void> save(String key, String value);

  /// Returns the value stored under [key], or `null` if absent.
  Future<String?> read(String key);

  /// Removes the entry under [key]. No-op if the key is already absent.
  Future<void> delete(String key);
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_service.dart';

/// Production [SecureStorageService] backed by `flutter_secure_storage`.
/// On Android the values land in the EncryptedSharedPreferences
/// (Keystore-wrapped); on iOS in the Keychain; on Windows in the
/// Credential Manager. Linux uses libsecret.
class FlutterSecureStorageService implements SecureStorageService {
  /// Optional [storage] override for tests. Defaults to a platform
  /// default [FlutterSecureStorage] instance.
  FlutterSecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _iosOptions = IOSOptions(
    accountName: 'VaultaSecureState',
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  );

  static const _androidOptions = AndroidOptions();

  static const _linuxOptions = LinuxOptions();

  static const _windowsOptions = WindowsOptions(
    useBackwardCompatibility: false,
  );

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) {
    return _storage.delete(
      key: key,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
      lOptions: _linuxOptions,
      wOptions: _windowsOptions,
    );
  }

  @override
  Future<String?> read(String key) {
    return _storage.read(
      key: key,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
      lOptions: _linuxOptions,
      wOptions: _windowsOptions,
    );
  }

  @override
  Future<void> save(String key, String value) {
    return _storage.write(
      key: key,
      value: value,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
      lOptions: _linuxOptions,
      wOptions: _windowsOptions,
    );
  }
}

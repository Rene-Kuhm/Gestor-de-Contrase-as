import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_service.dart';

class FlutterSecureStorageService implements SecureStorageService {
  FlutterSecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _iosOptions = IOSOptions(
    accountName: 'VaultaSecureState',
    accessibility: KeychainAccessibility.first_unlock_this_device,
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

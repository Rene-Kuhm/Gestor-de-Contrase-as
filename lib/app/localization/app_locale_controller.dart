import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../core/security/secure_storage_service.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController({required SecureStorageService storage})
    : _storage = storage;

  static const localeCodeKey = 'app_locale_code';

  final SecureStorageService _storage;

  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> initialize() async {
    final storedCode = await _storage.read(localeCodeKey);
    if (storedCode == null || storedCode.isEmpty) {
      _locale = null;
      return;
    }

    _locale = Locale(storedCode);
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;

    if (locale == null) {
      await _storage.delete(localeCodeKey);
    } else {
      await _storage.save(localeCodeKey, locale.languageCode);
    }

    notifyListeners();
  }
}

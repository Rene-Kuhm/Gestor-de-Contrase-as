import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../core/security/secure_storage_service.dart';

/// Holds the user's currently-selected app locale (or `null` when
/// the system locale should be used) and persists it to secure
/// storage. Exposed to the UI via [ChangeNotifier] so [MaterialApp]
/// re-renders when the user switches languages from settings.
///
/// Wire one of these into the app shell at startup and call
/// [initialize] before the first build; the controller is the
/// authoritative source for which [Locale] the app should render
/// in, falling back to the platform default when no preference is
/// stored.
class AppLocaleController extends ChangeNotifier {
  /// Builds a controller backed by the supplied secure [storage].
  /// Use a single instance per app process; multiple instances
  /// will fight over the same persisted key.
  AppLocaleController({required SecureStorageService storage})
    : _storage = storage;

  /// Secure storage key for the persisted locale language code
  /// (e.g. `"en"`, `"es"`). Absent means "follow the system locale".
  static const localeCodeKey = 'app_locale_code';

  final SecureStorageService _storage;

  /// Currently-selected locale, or `null` when the system locale
  /// should be used. Read by [MaterialApp.locale].
  Locale? _locale;

  /// Currently-selected locale, or `null` when the system locale
  /// should be used. Read by [MaterialApp.locale].
  Locale? get locale => _locale;

  /// Loads the persisted preference into memory. Call once at app
  /// startup, before the first build. Safe to call again — the
  /// second call re-reads the persisted value.
  Future<void> initialize() async {
    final storedCode = await _storage.read(localeCodeKey);
    if (storedCode == null || storedCode.isEmpty) {
      _locale = null;
      return;
    }

    _locale = Locale(storedCode);
  }

  /// Sets the app locale. Pass `null` to clear the preference and
  /// revert to the system locale. Persists to secure storage and
  /// notifies listeners so [MaterialApp] rebuilds.
  ///
  /// The persistence write is awaited (not fire-and-forget) so the
  /// caller can chain a follow-up that assumes the new locale is
  /// durable (e.g. closing the settings sheet).
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

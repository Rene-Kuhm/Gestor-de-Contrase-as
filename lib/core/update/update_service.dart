import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../security/secure_storage_service.dart';

/// Information about a release the platform fetched from GitHub.
class UpdateInfo {
  const UpdateInfo({
    required this.available,
    required this.tagName,
    required this.apkUrl,
    required this.changelog,
    required this.publishedAt,
    required this.releaseId,
    required this.currentVersion,
  });

  final bool available;
  final String tagName;
  final String apkUrl;
  final String changelog;
  final String publishedAt;

  /// GitHub release id. Monotonically increases every time the
  /// `dev-latest` release is overwritten, so it is a reliable way to
  /// tell a brand-new build apart from one the user has already
  /// dismissed the SnackBar for.
  final int releaseId;
  final String currentVersion;

  /// Result the platform returned when no update is available.
  /// We still keep the optional metadata so the UI can explain why
  /// (no release yet, HTTP error, missing .apk asset).
  const UpdateInfo.notAvailable({
    required this.currentVersion,
    this.tagName = '',
    this.apkUrl = '',
    this.changelog = '',
    this.publishedAt = '',
    this.releaseId = 0,
  }) : available = false;
}

/// Bridge to the native [UpdateChannel] hosted in
/// `com.insyd.gestor_contrasenas.UpdateChannel`.
///
/// The native side does the heavy lifting (HTTP request to the
/// GitHub Releases API, APK download to filesDir, FileProvider
/// intent for the system installer) so this Dart wrapper is just a
/// thin facade that translates the MethodChannel payload into a
/// typed [UpdateInfo] and surfaces a friendlier exception for the
/// settings screen.
///
/// Update gating happens here, not on the native side: the channel
/// always returns the latest `dev-latest` metadata (when it can),
/// and we compare the returned `releaseId` against the value
/// persisted in [SecureStorageService] the last time the user
/// actually installed a build. If they match, the SnackBar stays
/// quiet — no more "update available" nag every single time the
/// app reopens.
class UpdateService {
  UpdateService({
    required this.owner,
    required this.repo,
    SecureStorageService? storage,
    MethodChannel? channel,
  })  : _storage = storage,
        _channel = channel ??
            const MethodChannel('com.insyd.vaulta/update');

  static const _lastSeenReleaseIdKey = 'vaulta_last_seen_release_id_v1';

  final String owner;
  final String repo;
  final SecureStorageService? _storage;
  final MethodChannel _channel;

  /// Returns the release id we last persisted as "installed by the
  /// user", or 0 if we have never recorded one. Exposed for the
  /// Settings screen so it can show the user *which* build they
  /// are currently running against.
  Future<int> lastSeenReleaseId() async {
    final storage = _storage;
    if (storage == null) return 0;
    final raw = await storage.read(_lastSeenReleaseIdKey);
    if (raw == null || raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  /// Persists the latest `releaseId` so the next `checkForUpdate`
  /// call treats it as already installed. Called from
  /// [markInstalled] after a successful APK install.
  Future<void> markInstalled(int releaseId) async {
    final storage = _storage;
    if (storage == null) return;
    if (releaseId <= 0) return;
    await storage.save(_lastSeenReleaseIdKey, releaseId.toString());
  }

  /// Reads the running app's version (CFBundleShortVersionString on
  /// iOS, versionName on Android). Wrapped in a try/catch so the
  /// settings screen can render a fallback label if the platform
  /// channel is unavailable.
  Future<String> currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (error, stack) {
      debugPrint('[Vaulta/Update] PackageInfo failed: $error\n$stack');
      return 'unknown';
    }
  }

  /// Asks the platform to query the GitHub Releases API for the
  /// `dev-latest` tag and returns a structured [UpdateInfo].
  ///
  /// If the platform reports an `available` release but the
  /// `releaseId` matches the one we already showed the user, we
  /// flip `available` back to false — the silent check fires on
  /// every dashboard open, and we never want a stale SnackBar.
  Future<UpdateInfo> checkForUpdate() async {
    final current = await currentVersion();
    if (!Platform.isAndroid) {
      // OTA updates are only wired for Android in this build.
      return UpdateInfo.notAvailable(currentVersion: current);
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'checkForUpdate',
        {
          'owner': owner,
          'repo': repo,
          'currentVersion': current,
        },
      );
      if (raw == null) {
        return UpdateInfo.notAvailable(currentVersion: current);
      }
      final available = raw['available'] == true;
      final releaseId = (raw['releaseId'] as num?)?.toInt() ?? 0;
      if (!available) {
        return UpdateInfo.notAvailable(
          currentVersion: current,
          tagName: (raw['tagName'] as String?) ?? '',
          publishedAt: (raw['publishedAt'] as String?) ?? '',
          releaseId: releaseId,
        );
      }
      // Idempotent gate: if the user has already installed (or
      // dismissed) this exact build id, do not nag.
      final lastSeen = await lastSeenReleaseId();
      if (releaseId != 0 && lastSeen == releaseId) {
        debugPrint('[Vaulta/Update] check: releaseId=$releaseId already '
            'seen; treating as up-to-date');
        return UpdateInfo(
          available: false,
          tagName: (raw['tagName'] as String?) ?? '',
          apkUrl: (raw['apkUrl'] as String?) ?? '',
          changelog: (raw['changelog'] as String?) ?? '',
          publishedAt: (raw['publishedAt'] as String?) ?? '',
          releaseId: releaseId,
          currentVersion: current,
        );
      }
      return UpdateInfo(
        available: true,
        tagName: (raw['tagName'] as String?) ?? '',
        apkUrl: (raw['apkUrl'] as String?) ?? '',
        changelog: (raw['changelog'] as String?) ?? '',
        publishedAt: (raw['publishedAt'] as String?) ?? '',
        releaseId: releaseId,
        currentVersion: current,
      );
    } on PlatformException catch (error, stack) {
      debugPrint('[Vaulta/Update] check failed: ${error.code} '
          '${error.message}\n$stack');
      return UpdateInfo.notAvailable(currentVersion: current);
    }
  }

  /// Streams the APK to the platform's private files directory.
  /// Returns the absolute path of the cached APK.
  Future<String> downloadApk(UpdateInfo info) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('OTA updates are only wired for Android.');
    }
    final path = await _channel.invokeMethod<String>(
      'downloadApk',
      {'apkUrl': info.apkUrl},
    );
    if (path == null || path.isEmpty) {
      throw StateError('Downloaded APK path was empty.');
    }
    return path;
  }

  /// Fires ACTION_VIEW on the system installer for the previously
  /// downloaded APK. Returns true if the installer activity was
  /// launched.
  Future<bool> openInstallPrompt(String filePath) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('OTA updates are only wired for Android.');
    }
    final ok = await _channel.invokeMethod<bool>(
      'openInstallPrompt',
      {'filePath': filePath},
    );
    return ok ?? false;
  }
}

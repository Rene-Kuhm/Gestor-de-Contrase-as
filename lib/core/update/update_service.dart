import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../security/secure_storage_service.dart';

/// Information about a release the platform fetched from GitHub.
class UpdateInfo {
  /// Builds a fully populated [UpdateInfo] from a platform response.
  const UpdateInfo({
    required this.available,
    required this.tagName,
    required this.apkUrl,
    required this.changelog,
    required this.publishedAt,
    required this.releaseId,
    required this.currentVersion,
    this.remoteVersion = '',
    this.buildFingerprint = '',
  });

  /// True when the platform found a release that the running build
  /// is older than.
  final bool available;

  /// Git tag (e.g. `v1.0.22`). Empty when not available.
  final String tagName;

  /// Signed APK URL. Empty when not available.
  final String apkUrl;

  /// Markdown changelog body. Empty when not available.
  final String changelog;

  /// ISO-8601 publish timestamp. Empty when not available.
  final String publishedAt;

  /// GitHub release id. Monotonically increases every time the
  /// `dev-latest` release is overwritten, so it is a reliable way to
  /// tell a brand-new build apart from one the user has already
  /// dismissed the SnackBar for.
  final int releaseId;

  /// Cleaned-up remote version string (e.g. `1.0.22`). Empty when
  /// not available or not parseable from the changelog.
  final String remoteVersion;

  /// The version the user is currently running.
  final String currentVersion;

  /// Build fingerprint (CI build hash). Used to dedupe prompts when
  /// the same build is re-published without a version bump.
  final String buildFingerprint;

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
    this.remoteVersion = '',
    this.buildFingerprint = '',
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
  /// Builds an [UpdateService] bound to the GitHub [owner]/[repo]
  /// (e.g. `Rene-Kuhm`/`vaulta`) and an optional
  /// [storage] for install-state persistence plus an optional
  /// [channel] override for tests.
  UpdateService({
    required this.owner,
    required this.repo,
    SecureStorageService? storage,
    MethodChannel? channel,
  }) : _storage = storage,
       _channel = channel ?? const MethodChannel('com.insyd.vaulta/update');

  /// Secure storage key for the last releaseId the user installed.
  static const _lastSeenReleaseIdKey = 'vaulta_last_seen_release_id_v1';

  /// Secure storage key for the last build fingerprint the user was
  /// shown a SnackBar for.
  static const _lastSeenBuildFingerprintKey =
      'vaulta_last_seen_update_build_v1';

  /// GitHub owner (org or user) hosting the releases.
  final String owner;

  /// GitHub repo name. Together with [owner] it pins the channel.
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

  /// Persists the latest `releaseId` for diagnostics. We don't use
  /// this as an install signal because opening Android's installer
  /// does not guarantee the user accepted or that Android installed
  /// the APK.
  Future<void> markInstalled(int releaseId) async {
    final storage = _storage;
    if (storage == null) return;
    if (releaseId <= 0) return;
    await storage.save(_lastSeenReleaseIdKey, releaseId.toString());
  }

  /// Returns the last build fingerprint the user was prompted for,
  /// or empty string if we have never prompted them. Used by
  /// [AppShell] to decide whether to re-show the SnackBar after a
  /// session restart.
  Future<String> lastSeenBuildFingerprint() async {
    final storage = _storage;
    if (storage == null) return '';
    return await storage.read(_lastSeenBuildFingerprintKey) ?? '';
  }

  /// Records [info.buildFingerprint] as "already prompted" so the
  /// next [checkForUpdate] call does not re-show the SnackBar for
  /// the same build. Only called when the fingerprint is non-empty
  /// to avoid polluting the storage with empty placeholders.
  Future<void> markBuildPrompted(UpdateInfo info) async {
    final storage = _storage;
    if (storage == null) return;
    final fingerprint = info.buildFingerprint;
    if (fingerprint.isNotEmpty) {
      await storage.save(_lastSeenBuildFingerprintKey, fingerprint);
    }
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
        {'owner': owner, 'repo': repo, 'currentVersion': current},
      );
      if (raw == null) {
        return UpdateInfo.notAvailable(currentVersion: current);
      }
      final available = raw['available'] == true;
      final releaseId = (raw['releaseId'] as num?)?.toInt() ?? 0;
      final changelog = (raw['changelog'] as String?) ?? '';
      final remoteVersion =
          ((raw['remoteVersion'] as String?) ?? '').trim().isNotEmpty
          ? ((raw['remoteVersion'] as String?) ?? '').trim()
          : _remoteVersionFromChangelog(changelog);
      if (!available) {
        return UpdateInfo.notAvailable(
          currentVersion: current,
          tagName: (raw['tagName'] as String?) ?? '',
          publishedAt: (raw['publishedAt'] as String?) ?? '',
          releaseId: releaseId,
          remoteVersion: remoteVersion,
        );
      }
      final buildFingerprint = (raw['buildFingerprint'] as String?) ?? '';
      if (remoteVersion.isNotEmpty &&
          !_isRemoteVersionNewer(remoteVersion, current)) {
        return UpdateInfo(
          available: false,
          tagName: (raw['tagName'] as String?) ?? '',
          apkUrl: (raw['apkUrl'] as String?) ?? '',
          changelog: changelog,
          publishedAt: (raw['publishedAt'] as String?) ?? '',
          releaseId: releaseId,
          remoteVersion: remoteVersion,
          currentVersion: current,
          buildFingerprint: buildFingerprint,
        );
      }
      return UpdateInfo(
        available: true,
        tagName: (raw['tagName'] as String?) ?? '',
        apkUrl: (raw['apkUrl'] as String?) ?? '',
        changelog: changelog,
        publishedAt: (raw['publishedAt'] as String?) ?? '',
        releaseId: releaseId,
        remoteVersion: remoteVersion,
        currentVersion: current,
        buildFingerprint: buildFingerprint,
      );
    } on PlatformException catch (error, stack) {
      debugPrint(
        '[Vaulta/Update] check failed: ${error.code} '
        '${error.message}\n$stack',
      );
      throw StateError(
        'No pudimos comprobar actualizaciones '
        '(${error.code}: ${error.message ?? 'sin detalle'}).',
      );
    }
  }

  String _remoteVersionFromChangelog(String changelog) {
    return remoteVersionFromChangelogForTest(changelog);
  }

  bool _isRemoteVersionNewer(String remote, String current) {
    return isRemoteVersionNewerForTest(remote, current);
  }

  /// Streams the APK to the platform's private files directory.
  /// Returns the absolute path of the cached APK.
  Future<String> downloadApk(UpdateInfo info) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('OTA updates are only wired for Android.');
    }
    final path = await _channel.invokeMethod<String>('downloadApk', {
      'apkUrl': info.apkUrl,
    });
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
    final ok = await _channel.invokeMethod<bool>('openInstallPrompt', {
      'filePath': filePath,
    });
    return ok ?? false;
  }
}

/// Extracts a version string (e.g. `1.0.22`) from a changelog body.
/// Looks for either a `Vaulta version:` or a generic `Version:`
/// line. Test-only because production code goes through the native
/// channel which already returns the version.
@visibleForTesting
String remoteVersionFromChangelogForTest(String changelog) {
  final match = RegExp(
    r'(?:Vaulta\s+version|Version):\s*([0-9A-Za-z.+-]+)',
    caseSensitive: false,
  ).firstMatch(changelog);
  return match?.group(1)?.trim() ?? '';
}

/// Returns true when [remote] is a newer semver than [current],
/// using a simple major.minor.patch+buildNumber compare. Test-only.
@visibleForTesting
bool isRemoteVersionNewerForTest(String remote, String current) {
  final remoteParts = parseVersionForTest(remote);
  final currentParts = parseVersionForTest(current);
  if (remoteParts == null || currentParts == null) {
    return remote != current;
  }
  for (var i = 0; i < 3; i++) {
    final diff = remoteParts.nameParts[i] - currentParts.nameParts[i];
    if (diff != 0) return diff > 0;
  }
  return remoteParts.buildNumber > currentParts.buildNumber;
}

/// Parses `name+buildNumber` into a structure that the version
/// comparator can walk. Test-only.
@visibleForTesting
({List<int> nameParts, int buildNumber})? parseVersionForTest(String value) {
  final pieces = value.trim().split('+');
  if (pieces.isEmpty) return null;
  final nameParts = pieces.first.split('.').map(int.tryParse).toList();
  if (nameParts.length != 3 || nameParts.any((part) => part == null)) {
    return null;
  }
  final buildNumber = pieces.length > 1 ? int.tryParse(pieces[1]) : 0;
  if (buildNumber == null) return null;
  return (nameParts: nameParts.cast<int>(), buildNumber: buildNumber);
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Information about a release the platform fetched from GitHub.
class UpdateInfo {
  const UpdateInfo({
    required this.available,
    required this.tagName,
    required this.apkUrl,
    required this.changelog,
    required this.publishedAt,
    required this.currentVersion,
  });

  final bool available;
  final String tagName;
  final String apkUrl;
  final String changelog;
  final String publishedAt;
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
class UpdateService {
  UpdateService({
    required this.owner,
    required this.repo,
    MethodChannel? channel,
  }) : _channel = channel ??
            const MethodChannel('com.insyd.vaulta/update');

  final String owner;
  final String repo;
  final MethodChannel _channel;

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
  /// `dev-latest` tag and return a structured [UpdateInfo]. The
  /// native side does the HTTP work.
  Future<UpdateInfo> checkForUpdate() async {
    if (!Platform.isAndroid) {
      // OTA updates are only wired for Android in this build.
      return UpdateInfo.notAvailable(currentVersion: await currentVersion());
    }
    final current = await currentVersion();
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
      if (!available) {
        return UpdateInfo.notAvailable(
          currentVersion: current,
          tagName: (raw['tagName'] as String?) ?? '',
        );
      }
      return UpdateInfo(
        available: true,
        tagName: (raw['tagName'] as String?) ?? '',
        apkUrl: (raw['apkUrl'] as String?) ?? '',
        changelog: (raw['changelog'] as String?) ?? '',
        publishedAt: (raw['publishedAt'] as String?) ?? '',
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

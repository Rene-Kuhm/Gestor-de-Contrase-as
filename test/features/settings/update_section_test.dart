// Widget test that exercises the UpdateSection "Buscar actualizaciones"
// button end-to-end. Verifies the button changes the visible state
// (spinner, success banner, or error banner) so a "silent no-op" can
// never reach a real device again.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_contrasenas/core/update/update_service.dart';
import 'package:gestor_contrasenas/features/settings/presentation/update_section.dart';

void main() {
  testWidgets('Buscar actualizaciones button enters checking state immediately '
      'after tap, then resolves to updateAvailable when the service '
      'returns available=true', (tester) async {
    final pending = Completer<UpdateInfo>();
    final service = _StubUpdateService(checkResult: pending.future);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: UpdateSection(service: service)),
        ),
      ),
    );

    // Initial state: the button label must be exactly the action we
    // expect, never null or a spinner.
    expect(find.text('Buscar actualizaciones'), findsOneWidget);

    // Tap. The synchronous setState must flip us into checking
    // *before* the async gap closes, so the spinner must appear
    // in the same frame the tap is dispatched.
    await tester.tap(find.text('Buscar actualizaciones'));
    await tester.pump();

    // While the future is pending, the button should be a busy
    // button with a CircularProgressIndicator and no tap handler.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Buscando...'), findsOneWidget);
    expect(service.checkForUpdateCallCount, 1);

    // Now resolve the future and drain the second setState.
    pending.complete(
      UpdateInfo(
        available: true,
        tagName: 'dev-latest',
        apkUrl: 'https://example.com/app-debug.apk',
        changelog: 'test changelog',
        publishedAt: '2026-06-09T18:00:00Z',
        releaseId: 12345,
        currentVersion: '1.0.1+2',
        buildFingerprint: '12345:99:2026-06-09T18:00:00Z:123456',
      ),
    );
    await tester.pumpAndSettle();

    // After resolving with available=true we must show the
    // changelog panel, not silently fall back to up-to-date.
    expect(find.text('Nueva version dev-latest'), findsOneWidget);
    expect(find.text('test changelog'), findsOneWidget);
  });

  testWidgets('button resolves to upToDate banner when service returns '
      'available=false', (tester) async {
    final service = _StubUpdateService(
      checkResult: Future.value(
        UpdateInfo.notAvailable(currentVersion: '1.0.1+2'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: UpdateSection(service: service)),
        ),
      ),
    );

    await tester.tap(find.text('Buscar actualizaciones'));
    await tester.pumpAndSettle();

    // The "ya estás al día" banner is the only way a no-op button
    // tap becomes a clear, non-misleading signal.
    expect(find.textContaining('Ya estas al dia'), findsOneWidget);
  });

  testWidgets('button resolves to error banner when the service throws', (
    tester,
  ) async {
    final service = _ThrowingUpdateService(
      error: StateError('native channel not registered'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: UpdateSection(service: service)),
        ),
      ),
    );

    await tester.tap(find.text('Buscar actualizaciones'));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos comprobar actualizaciones'), findsOneWidget);
    expect(
      find.textContaining('native channel not registered'),
      findsOneWidget,
    );
  });

  testWidgets(
    'download flow does not mark build prompted when installer fails to open',
    (tester) async {
      final service = _StubUpdateService(
        checkResult: Future.value(
          const UpdateInfo(
            available: true,
            tagName: 'dev-latest',
            apkUrl: 'https://example.com/app-debug.apk',
            changelog: 'test changelog',
            publishedAt: '2026-06-09T18:00:00Z',
            releaseId: 12345,
            currentVersion: '1.0.1+2',
            buildFingerprint: '12345:99:2026-06-09T18:00:00Z:123456',
          ),
        ),
        installPromptResult: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: UpdateSection(service: service)),
          ),
        ),
      );

      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descargar e instalar'));
      await tester.pumpAndSettle();

      expect(service.downloadCallCount, 1);
      expect(service.openInstallPromptCallCount, 1);
      expect(service.markBuildPromptedCallCount, 0);
      expect(
        find.textContaining('No pudimos abrir el instalador'),
        findsOneWidget,
      );
    },
  );
}

class _StubUpdateService implements UpdateService {
  _StubUpdateService({
    required this.checkResult,
    this.installPromptResult = true,
  });

  final Future<UpdateInfo> checkResult;
  final bool installPromptResult;
  int checkForUpdateCallCount = 0;
  int downloadCallCount = 0;
  int openInstallPromptCallCount = 0;
  int markBuildPromptedCallCount = 0;

  @override
  String get owner => 'Rene-Kuhm';

  @override
  String get repo => 'Gestor-de-Contrase-as';

  @override
  Future<UpdateInfo> checkForUpdate() async {
    checkForUpdateCallCount++;
    return checkResult;
  }

  @override
  Future<String> currentVersion() async => '1.0.1+2';

  @override
  Future<String> downloadApk(UpdateInfo info) async {
    downloadCallCount++;
    return '/tmp/app-debug.apk';
  }

  @override
  Future<String> lastSeenBuildFingerprint() async => '';

  @override
  Future<int> lastSeenReleaseId() async => 0;

  @override
  Future<void> markInstalled(int releaseId) async {}

  @override
  Future<void> markBuildPrompted(UpdateInfo info) async {
    markBuildPromptedCallCount++;
  }

  @override
  Future<bool> openInstallPrompt(String filePath) async {
    openInstallPromptCallCount++;
    return installPromptResult;
  }
}

class _ThrowingUpdateService implements UpdateService {
  _ThrowingUpdateService({required this.error});

  final Object error;

  @override
  String get owner => 'Rene-Kuhm';

  @override
  String get repo => 'Gestor-de-Contrase-as';

  @override
  Future<UpdateInfo> checkForUpdate() async {
    throw error;
  }

  @override
  Future<String> currentVersion() async => '1.0.1+2';

  @override
  Future<String> downloadApk(UpdateInfo info) async => '/tmp/app-debug.apk';

  @override
  Future<String> lastSeenBuildFingerprint() async => '';

  @override
  Future<int> lastSeenReleaseId() async => 0;

  @override
  Future<void> markInstalled(int releaseId) async {}

  @override
  Future<void> markBuildPrompted(UpdateInfo info) async {}

  @override
  Future<bool> openInstallPrompt(String filePath) async => true;
}

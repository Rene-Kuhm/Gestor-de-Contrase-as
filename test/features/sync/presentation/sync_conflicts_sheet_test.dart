import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gestor_contrasenas/core/sync/sync_conflict.dart';
import 'package:gestor_contrasenas/core/sync/sync_conflict_resolver.dart';
import 'package:gestor_contrasenas/features/sync/presentation/sync_conflicts_sheet.dart';
import 'package:gestor_contrasenas/l10n/app_localizations.dart';

class _EmptyConflictResolver implements SyncConflictResolver {
  @override
  Future<List<SyncConflictRecord>> readPendingConflicts() async => const [];

  @override
  Future<SyncConflictResolveResult> resolve({
    required String conflictId,
    required SyncConflictResolution resolution,
  }) async => const SyncConflictResolveResult(ok: true, message: 'ok');
}

void main() {
  testWidgets('SyncConflictsSheet shows empty state when no conflicts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () =>
                    showSyncConflictsSheet(
                      context: context,
                      resolver: _EmptyConflictResolver(),
                    ),
                child: const Text('Open conflicts'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open conflicts'));
    await tester.pumpAndSettle();

    expect(find.text('Sync conflicts'), findsOneWidget);
    expect(
      find.text('No pending conflicts. Everything is in sync.'),
      findsOneWidget,
    );

    await _disposeTree(tester);
  });
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

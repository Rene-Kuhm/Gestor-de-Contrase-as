import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_contrasenas/core/security/vault_repository.dart';
import 'package:gestor_contrasenas/features/vault/application/vault_import_models.dart';
import 'package:gestor_contrasenas/features/vault/domain/vault_item.dart';
import 'package:gestor_contrasenas/features/vault/domain/vault_summary.dart';
import 'package:gestor_contrasenas/features/vault/presentation/vault_import_screen.dart';

void main() {
  testWidgets('Importar entradas button saves importable candidates', (
    tester,
  ) async {
    final item = _item(id: 'candidate', title: 'GitHub');
    final repository = _ImportTestRepository();
    VaultImportResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<VaultImportResult>(
                    MaterialPageRoute(
                      builder: (_) => VaultImportScreen(
                        repository: repository,
                        existingItems: const [],
                        initialPreview: VaultImportPreview(
                          source: VaultImportSource.genericCsv,
                          candidates: [
                            VaultImportCandidate(
                              item: item,
                              source: VaultImportSource.genericCsv,
                              row: 2,
                            ),
                          ],
                          rejected: const [],
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Abrir importador'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir importador'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('Importar 1 entradas'), findsOneWidget);

    await tester.tap(find.text('Importar 1 entradas'));
    await tester.pumpAndSettle();

    expect(repository.savedItems, [item]);
    expect(result?.imported, 1);
    expect(result?.skippedDuplicates, 0);
  });

  testWidgets('Importar entradas skips duplicates found before saving', (
    tester,
  ) async {
    final existing = _item(id: 'existing', title: 'GitHub');
    final duplicate = _item(id: 'candidate', title: 'GitHub');
    final repository = _ImportTestRepository(initialItems: [existing]);
    VaultImportResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<VaultImportResult>(
                    MaterialPageRoute(
                      builder: (_) => VaultImportScreen(
                        repository: repository,
                        existingItems: const [],
                        initialPreview: VaultImportPreview(
                          source: VaultImportSource.genericCsv,
                          candidates: [
                            VaultImportCandidate(
                              item: duplicate,
                              source: VaultImportSource.genericCsv,
                              row: 2,
                            ),
                          ],
                          rejected: const [],
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Abrir importador'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir importador'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar 1 entradas'));
    await tester.pumpAndSettle();

    expect(repository.savedItems, isEmpty);
    expect(result?.imported, 0);
    expect(result?.skippedDuplicates, 1);
  });
}

VaultItem _item({required String id, required String title}) {
  return VaultItem(
    id: id,
    title: title,
    username: 'leo@example.com',
    secret: 'StrongPass!2026',
    category: VaultCategory.work,
    strengthScore: 90,
    lastUpdatedLabel: 'Updated now',
    website: 'https://github.com',
  );
}

class _ImportTestRepository implements VaultRepository {
  _ImportTestRepository({List<VaultItem> initialItems = const []})
    : _items = List<VaultItem>.of(initialItems);

  final List<VaultItem> _items;
  final List<VaultItem> savedItems = [];

  @override
  Future<void> deleteItem(String id) async {}

  @override
  Future<VaultItem?> fetchItemById(String id) async {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<List<VaultItem>> fetchItems() async => List<VaultItem>.of(_items);

  @override
  Future<VaultSummary> fetchSummary() async {
    return VaultSummary(
      totalItems: _items.length,
      weakItems: 0,
      reusedItems: 0,
      securityScore: 90,
      connectedDevices: 1,
      syncEnabled: false,
    );
  }

  @override
  Future<VaultItem> saveItem(VaultItem item) async {
    savedItems.add(item);
    _items.add(item);
    return item;
  }
}

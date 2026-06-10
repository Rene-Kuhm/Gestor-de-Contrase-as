import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_contrasenas/features/vault/application/vault_import_parser.dart';
import 'package:gestor_contrasenas/features/vault/domain/vault_item.dart';

void main() {
  group('VaultImportParser', () {
    test('maps generic CSV columns into Vaulta items', () {
      final preview = VaultImportParser().parse(
        fileName: 'passwords.csv',
        content: [
          'title,username,password,url,notes,category',
          'GitHub,leo@example.com,StrongPass!2026,https://github.com,Token backup,Work',
          'Bank,finance@example.com,BankPass!2026,https://bank.test,,Finance',
        ].join('\n'),
        existingItems: const [],
      );

      expect(preview.importableCount, 2);
      expect(preview.rejectedCount, 0);
      expect(preview.candidates.first.item.title, 'GitHub');
      expect(preview.candidates.first.item.username, 'leo@example.com');
      expect(preview.candidates.first.item.secret, 'StrongPass!2026');
      expect(preview.candidates.first.item.website, 'https://github.com');
      expect(preview.candidates.first.item.category, VaultCategory.work);
      expect(preview.candidates.last.item.category, VaultCategory.finance);
    });

    test('handles quoted CSV values exported from spreadsheet tools', () {
      final preview = VaultImportParser().parse(
        fileName: 'notion-passwords.csv',
        content:
            'Name,Email,Password,URL,Notes\n"Notion, Workspace","team@vaulta.app","S3cret!2026","https://notion.so","Shared, internal"',
        existingItems: const [],
      );

      expect(preview.importableCount, 1);
      final item = preview.candidates.single.item;
      expect(item.title, 'Notion, Workspace');
      expect(item.notes, 'Shared, internal');
    });

    test('handles semicolon separated CSV from regional spreadsheet exports', () {
      final preview = VaultImportParser().parse(
        fileName: 'excel.csv',
        content:
            'title;username;password;url;category\nPortal;user@vaulta.app;Portal!2026;https://portal.test;Personal',
        existingItems: const [],
      );

      expect(preview.importableCount, 1);
      expect(preview.candidates.single.item.title, 'Portal');
      expect(preview.candidates.single.item.website, 'https://portal.test');
    });

    test('detects duplicates using title username and website', () {
      const existing = VaultItem(
        id: 'existing',
        title: 'GitHub',
        username: 'leo@example.com',
        secret: 'old',
        category: VaultCategory.work,
        strengthScore: 80,
        lastUpdatedLabel: 'Updated now',
        website: 'https://github.com',
      );

      final preview = VaultImportParser().parse(
        fileName: 'chrome.csv',
        content:
            'name,url,username,password\nGitHub,https://github.com,leo@example.com,StrongPass!2026',
        existingItems: const [existing],
      );

      expect(preview.candidates.single.isDuplicate, isTrue);
      expect(preview.importableCount, 0);
    });

    test('maps Bitwarden-style JSON exports', () {
      final preview = VaultImportParser().parse(
        fileName: 'bitwarden_export.json',
        content: '''
{
  "items": [
    {
      "name": "GitLab",
      "folder": "Infrastructure",
      "notes": "Deploy key",
      "login": {
        "username": "deploy@vaulta.app",
        "password": "Deploy!2026",
        "uris": [{"uri": "https://gitlab.com"}]
      }
    }
  ]
}
''',
        existingItems: const [],
      );

      expect(preview.importableCount, 1);
      final item = preview.candidates.single.item;
      expect(item.title, 'GitLab');
      expect(item.username, 'deploy@vaulta.app');
      expect(item.secret, 'Deploy!2026');
      expect(item.category, VaultCategory.infrastructure);
    });

    test('rejects rows without recognizable credentials', () {
      final preview = VaultImportParser().parse(
        fileName: 'bad.csv',
        content: 'foo,bar\nhello,world',
        existingItems: const [],
      );

      expect(preview.importableCount, 0);
      expect(preview.rejectedCount, 1);
    });
  });
}

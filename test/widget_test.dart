import 'package:flutter_test/flutter_test.dart';

import 'package:gestor_contrasenas/app/bootstrap/password_manager_app.dart';
import 'package:gestor_contrasenas/core/security/demo_vault_repository.dart';

void main() {
  testWidgets('renders vault dashboard shell', (tester) async {
    await tester.pumpWidget(
      PasswordManagerApp(repository: DemoVaultRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vaulta'), findsOneWidget);
    expect(find.text('Your encrypted control room'), findsOneWidget);
    expect(find.text('Vault'), findsOneWidget);
  });
}

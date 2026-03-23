import 'package:flutter/material.dart';

import '../../core/security/demo_vault_repository.dart';
import '../../features/home/presentation/app_shell.dart';
import '../theme/app_theme.dart';

void runPasswordManagerApp() {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = DemoVaultRepository();

  runApp(PasswordManagerApp(repository: repository));
}

class PasswordManagerApp extends StatelessWidget {
  const PasswordManagerApp({super.key, required this.repository});

  final DemoVaultRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vaulta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: AppShell(repository: repository),
    );
  }
}

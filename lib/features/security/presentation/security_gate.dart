import 'package:flutter/material.dart';

import '../../../app/design_system/app_panel.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/security/vault_security_controller.dart';
import '../../home/presentation/app_shell.dart';

class SecurityGate extends StatelessWidget {
  const SecurityGate({
    super.key,
    required this.controller,
    required this.child,
  });

  final VaultSecurityController controller;
  final AppShell child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return switch (controller.stage) {
          VaultSecurityStage.loading => _SecurityScaffold(
            child: const Center(child: CircularProgressIndicator()),
          ),
          VaultSecurityStage.onboarding => _OnboardingScreen(
            controller: controller,
          ),
          VaultSecurityStage.locked => _UnlockScreen(controller: controller),
          VaultSecurityStage.unlocked => child,
        };
      },
    );
  }
}

class _OnboardingScreen extends StatefulWidget {
  const _OnboardingScreen({required this.controller});

  final VaultSecurityController controller;

  @override
  State<_OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<_OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _enableBiometrics = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return _SecurityScaffold(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const _BrandHero(
              eyebrow: 'Onboarding seguro',
              title: 'Creamos tu llave maestra sin atajos peligrosos.',
              subtitle:
                  'La master password valida el acceso local. El contenido del vault todavia no se cifra aca, asi que queda preparado sin inventar criptografia casera.',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Master password',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Pedimos 12+ caracteres con mezcla real. Nada de guardar la clave en texto plano.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Create master password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _confirmationController,
                      obscureText: _obscureConfirmation,
                      decoration: InputDecoration(
                        labelText: 'Confirm master password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmation = !_obscureConfirmation;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmation
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SecurityChecklist(
                      items: [
                        'PBKDF2-HMAC-SHA256 para verificar la master password.',
                        'Salt aleatoria y record guardado con Keychain / Keystore.',
                        'Nada de derivar cifrado propio hasta integrar vault encryption auditado.',
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _enableBiometrics,
                      onChanged: controller.canOfferBiometricToggle
                          ? (value) {
                              setState(() => _enableBiometrics = value);
                            }
                          : null,
                      title: const Text('Habilitar biometria local'),
                      subtitle: Text(
                        controller.canOfferBiometricToggle
                            ? 'Vincula ${controller.biometricAvailability.label} para desbloqueo rapido del dispositivo actual.'
                            : 'No detectamos biometria disponible. Igual vas a poder entrar con tu master password.',
                      ),
                    ),
                    if (controller.message case final message?) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _StatusBanner(message: message),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: controller.busy ? null : _submit,
                      icon: controller.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.shield_rounded),
                      label: const Text('Create secure vault access'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final created = await widget.controller.createMasterPassword(
      password: _passwordController.text,
      confirmation: _confirmationController.text,
      enableBiometrics: _enableBiometrics,
    );

    if (created && mounted) {
      FocusScope.of(context).unfocus();
    }
  }
}

class _UnlockScreen extends StatefulWidget {
  const _UnlockScreen({required this.controller});

  final VaultSecurityController controller;

  @override
  State<_UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<_UnlockScreen> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return _SecurityScaffold(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _BrandHero(
              eyebrow: 'Unlock',
              title: 'Tu vault queda cerrado hasta validar identidad real.',
              subtitle: controller.canUnlockWithBiometrics
                  ? 'Podes entrar con master password o ${controller.biometricAvailability.label}. La biometria restaura solo la sesion local del dispositivo confiable.'
                  : 'Usa tu master password para recuperar acceso. La biometria queda lista cuando el dispositivo la soporte y la vincules.',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Protected access',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onSubmitted: (_) => _unlockWithPassword(),
                    decoration: InputDecoration(
                      labelText: 'Master password',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: controller.busy
                              ? null
                              : _unlockWithPassword,
                          child: controller.busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Unlock vault'),
                        ),
                      ),
                      if (controller.canUnlockWithBiometrics) ...[
                        const SizedBox(width: AppSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: controller.busy
                              ? null
                              : _unlockWithBiometrics,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Biometric'),
                        ),
                      ],
                    ],
                  ),
                  if (controller.message case final message?) ...[
                    const SizedBox(height: AppSpacing.md),
                    _StatusBanner(message: message),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppPanel(
              child: _SecurityChecklist(
                items: [
                  'El registro de acceso vive en almacenamiento seguro del sistema.',
                  'La biometria usa LocalAuthentication; no reemplaza cifrado fuerte del vault.',
                  'El cifrado completo de items queda pendiente hasta integrar una libreria auditada extremo a extremo.',
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlockWithPassword() async {
    await widget.controller.unlockWithPassword(_passwordController.text);
    if (mounted && widget.controller.isUnlocked) {
      FocusScope.of(context).unfocus();
      _passwordController.clear();
    }
  }

  Future<void> _unlockWithBiometrics() async {
    await widget.controller.unlockWithBiometrics();
  }
}

class _SecurityScaffold extends StatelessWidget {
  const _SecurityScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.brightness == Brightness.dark
                  ? const Color(0xFF0D1C28)
                  : const Color(0xFFE2F6F1),
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -30,
              child: _GlowOrb(
                color: AppColors.mint.withValues(alpha: 0.24),
                size: 220,
              ),
            ),
            Positioned(
              bottom: -100,
              left: -60,
              child: _GlowOrb(
                color: AppColors.ocean.withValues(alpha: 0.12),
                size: 240,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            eyebrow,
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Vaulta',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SecurityChecklist extends StatelessWidget {
  const _SecurityChecklist({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.verified_user_rounded,
                    size: 18,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cloud,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.ink),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

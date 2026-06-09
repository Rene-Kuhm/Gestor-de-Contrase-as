import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/design_system/app_panel.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/security/native_biometric_auth_service.dart';
import '../../../core/security/vault_security_controller.dart';
import '../../../core/sync/device_registration_service.dart';

class SecurityGate extends StatefulWidget {
  const SecurityGate({
    super.key,
    required this.controller,
    required this.child,
    this.deviceSyncLifecycle,
  });

  final VaultSecurityController controller;
  final Widget child;
  final DeviceSyncLifecycle? deviceSyncLifecycle;

  @override
  State<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends State<SecurityGate>
    with WidgetsBindingObserver {
  late VaultSecurityStage _lastStage;
  bool _canOfferBiometricButton = false;

  @override
  void initState() {
    super.initState();
    _lastStage = widget.controller.stage;
    widget.controller.addListener(_handleSecurityStageChange);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshBiometricUnlockAvailability());
  }

  @override
  void didUpdateWidget(covariant SecurityGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }

    oldWidget.controller.removeListener(_handleSecurityStageChange);
    widget.controller.addListener(_handleSecurityStageChange);
    _lastStage = widget.controller.stage;
  }

  Future<void> _refreshBiometricUnlockAvailability() async {
    final nextOffer = widget.controller.canOfferBiometricUnlockButton;
    if (!mounted) return;
    if (nextOffer != _canOfferBiometricButton) {
      setState(() => _canOfferBiometricButton = nextOffer);
    }
  }

  void _handleSecurityStageChange() {
    final currentStage = widget.controller.stage;
    final movedToUnlocked =
        _lastStage != VaultSecurityStage.unlocked &&
        currentStage == VaultSecurityStage.unlocked;
    final movedToLocked =
        _lastStage != VaultSecurityStage.locked &&
        currentStage == VaultSecurityStage.locked;
    _lastStage = currentStage;

    // Biometric availability can change after lock/unlock, after the
    // user toggles the preference, or after the platform reports a
    // new enrollment. Always re-check when the stage moves.
    if (movedToLocked || movedToUnlocked) {
      unawaited(_refreshBiometricUnlockAvailability());
    }

    if (!movedToUnlocked) {
      return;
    }

    final lifecycle = widget.deviceSyncLifecycle;
    if (lifecycle == null) {
      return;
    }

    _runLifecycleAction(lifecycle.onSessionStarted());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller.handleAppLifecycleState(state);

    final lifecycle = widget.deviceSyncLifecycle;
    if (state == AppLifecycleState.resumed &&
        widget.controller.isUnlocked &&
        lifecycle != null) {
      _runLifecycleAction(lifecycle.onAppResumed());
    }
  }

  void _runLifecycleAction(Future<void> action) {
    unawaited(action.catchError((_) {}));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleSecurityStageChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return switch (widget.controller.stage) {
          VaultSecurityStage.loading => _SecurityScaffold(
            child: const Center(child: CircularProgressIndicator()),
          ),
          VaultSecurityStage.onboarding => _OnboardingScreen(
            controller: widget.controller,
          ),
          VaultSecurityStage.locked => _UnlockScreen(
            controller: widget.controller,
          ),
          VaultSecurityStage.unlocked => Focus(
            canRequestFocus: false,
            onKeyEvent: (_, _) {
              widget.controller.registerUserInteraction();
              return KeyEventResult.ignored;
            },
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                widget.controller.registerUserInteraction();
              },
              onPointerMove: (_) {
                widget.controller.registerUserInteraction();
              },
              onPointerSignal: (_) {
                widget.controller.registerUserInteraction();
              },
              onPointerPanZoomStart: (_) {
                widget.controller.registerUserInteraction();
              },
              child: widget.child,
            ),
          ),
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final controller = widget.controller;

    return _SecurityScaffold(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _BrandHero(
              eyebrow: l10n.securityOnboardingEyebrow,
              title: l10n.securityOnboardingTitle,
              subtitle: l10n.securityOnboardingSubtitle,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.securityMasterPasswordTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.securityMasterPasswordDescription,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: l10n.securityCreateMasterPassword,
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
                        labelText: l10n.securityConfirmMasterPassword,
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
                        l10n.securityChecklistHash,
                        l10n.securityChecklistDerive,
                        l10n.securityChecklistEncrypt,
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _enableBiometrics,
                        onChanged: controller.canOfferBiometricToggle
                            ? (value) {
                                setState(() => _enableBiometrics = value);
                              }
                            : null,
                        title: Text(l10n.securityEnableBiometrics),
                        subtitle: Text(
                          controller.canOfferBiometricToggle
                              ? l10n.securityBiometricAvailable(
                                  controller.biometricAvailability.label,
                                )
                              : l10n.securityBiometricUnavailable,
                        ),
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
                      label: Text(l10n.securityCreateSecureAccess),
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
  // Whether the unlock screen should *render* the biometric button.
  // The button is offered whenever biometrics are enabled and the
  // device supports them — even if the envelope is not yet on disk.
  // The unlock itself can still fail with a clear message, and the
  // user is no longer left wondering why the button disappeared.
  bool _canOfferBiometricButton = false;
  String? _biometricStatusMessage;
  // Rich platform capability, used to render a "Set up biometrics"
  // CTA when the device lost its enrollment between launches.
  NativeBiometricCapability _biometricCapability =
      NativeBiometricCapability.empty;
  bool _enrollingBiometric = false;
  bool _settingUpBiometric = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
    unawaited(_refreshBiometricUnlockAvailability());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _passwordController.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    unawaited(_refreshBiometricUnlockAvailability());
  }

  Future<void> _refreshBiometricUnlockAvailability() async {
    final nextOffer = widget.controller.canOfferBiometricUnlockButton;
    final nextMessage = await widget.controller.biometricUnlockStatusMessage();
    final nextCap = await widget.controller.probeBiometricCapability();
    if (!mounted) return;
    final capChanged =
        nextCap.canUseStrongOrCredential !=
                _biometricCapability.canUseStrongOrCredential ||
            nextCap.canUseStrong != _biometricCapability.canUseStrong ||
            nextCap.canUseWeak != _biometricCapability.canUseWeak ||
            nextCap.needsEnrollment != _biometricCapability.needsEnrollment;
    if (nextOffer != _canOfferBiometricButton ||
        nextMessage != _biometricStatusMessage ||
        capChanged) {
      setState(() {
        _canOfferBiometricButton = nextOffer;
        _biometricStatusMessage = nextMessage;
        _biometricCapability = nextCap;
      });
    }
  }

  Future<void> _openBiometricEnrollment() async {
    if (_enrollingBiometric) return;
    setState(() => _enrollingBiometric = true);
    try {
      final ok = await widget.controller.openBiometricEnrollment();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.biometricEnrollUnavailable)),
        );
      }
      // Re-probe a few seconds later in case the user came back from
      // the system settings with a fresh biometric enrolled.
      await Future<void>.delayed(const Duration(seconds: 1));
      await _refreshBiometricUnlockAvailability();
    } finally {
      if (mounted) {
        setState(() => _enrollingBiometric = false);
      }
    }
  }

  /// One-shot biometric-enrollment flow. Opens a small dialog that
  /// asks the user to confirm the master password (without unlocking
  /// the vault) and writes the wrapped-DEK envelope so the next
  /// unlock can use the fingerprint button.
  Future<void> _openBiometricSetupDialog() async {
    if (_settingUpBiometric) return;
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _SetupBiometricDialog(),
    );
    if (password == null || password.isEmpty || !mounted) {
      return;
    }
    setState(() => _settingUpBiometric = true);
    try {
      final ok = await widget.controller.setupBiometricFromPassword(password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? widget.controller.message ??
                    context.l10n.securitySetupBiometricSuccess
                : widget.controller.message ??
                    context.l10n.securitySetupBiometricError,
          ),
        ),
      );
      await _refreshBiometricUnlockAvailability();
    } finally {
      if (mounted) {
        setState(() => _settingUpBiometric = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final controller = widget.controller;

    return _SecurityScaffold(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _BrandHero(
              eyebrow: l10n.securityUnlockEyebrow,
              title: l10n.securityUnlockTitle,
              subtitle: _canOfferBiometricButton
                  ? l10n.securityUnlockBiometricSubtitle(
                      controller.biometricAvailability.label,
                    )
                  : l10n.securityUnlockPasswordSubtitle,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.securityProtectedAccess,
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
                      labelText: l10n.securityMasterPasswordTitle,
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
                              : Text(l10n.securityUnlockVault),
                        ),
                      ),
                      if (_canOfferBiometricButton) ...[
                        const SizedBox(width: AppSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: controller.busy
                              ? null
                              : _unlockWithBiometrics,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: Text(l10n.securityBiometricButton),
                        ),
                      ],
                    ],
                  ),
                  if (_biometricStatusMessage case final statusMessage?) ...[
                    const SizedBox(height: AppSpacing.md),
                    _StatusBanner(message: statusMessage),
                  ],
                  if (controller.message case final message?) ...[
                    const SizedBox(height: AppSpacing.md),
                    _StatusBanner(message: message),
                  ],
                  // The device has biometrics enrolled and the user
                  // has not turned biometric unlock on yet. Surface a
                  // one-tap setup CTA that opens a password dialog,
                  // verifies the master password, and writes the
                  // wrapped-DEK envelope without unlocking the vault.
                  if (!widget.controller.biometricEnabled &&
                      controller.canOfferBiometricToggle) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SetupBiometricButton(
                      label: l10n.securitySetupBiometricCta,
                      busy: _settingUpBiometric,
                      onPressed: _openBiometricSetupDialog,
                    ),
                  ],
                  // The user enabled biometrics at some point but the
                  // platform now reports NONE_ENROLLED — most likely
                  // they removed their fingerprint from the device or
                  // wiped the keystore. Show a CTA so they can re-add
                  // it without going through Settings.
                  if (!_canOfferBiometricButton &&
                      widget.controller.biometricEnabled &&
                      _biometricCapability.needsEnrollment) ...[
                    const SizedBox(height: AppSpacing.md),
                    _BiometricEnrollInline(
                      title: l10n.biometricEnrollCta,
                      actionLabel: l10n.biometricEnrollAction,
                      busy: _enrollingBiometric,
                      onAction: _openBiometricEnrollment,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: _SecurityChecklist(
                items: [
                  l10n.securityChecklistHash,
                  l10n.securityChecklistDerive,
                  l10n.securityChecklistEncrypt,
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
    if (mounted) {
      unawaited(_refreshBiometricUnlockAvailability());
    }
  }

  Future<void> _unlockWithBiometrics() async {
    await widget.controller.unlockWithBiometrics();
    if (mounted) {
      unawaited(_refreshBiometricUnlockAvailability());
    }
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
    final l10n = context.l10n;
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
          l10n.appTitle,
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

/// Compact "biometric is enabled but not enrolled" CTA used in the
/// unlock screen. Different from the banner in settings_screen so
/// it fits in the narrower unlock layout — single row, primary
/// action on the right.
class _BiometricEnrollInline extends StatelessWidget {
  const _BiometricEnrollInline({
    required this.title,
    required this.actionLabel,
    required this.busy,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final bool busy;
  final VoidCallback onAction;

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
          const Icon(Icons.fingerprint_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: busy ? null : onAction,
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

/// Filled-tonal CTA rendered on the unlock screen when the device
/// has biometrics enrolled but the user has not turned biometric
/// unlock on yet. Tapping it opens [_SetupBiometricDialog].
class _SetupBiometricButton extends StatelessWidget {
  const _SetupBiometricButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.fingerprint_rounded),
        label: Text(label),
      ),
    );
  }
}

/// Modal dialog that asks for the master password so the controller
/// can derive a one-shot DEK and write the wrapped-DEK envelope
/// without unlocking the vault. Returns the entered password, or
/// null if the user cancels.
class _SetupBiometricDialog extends StatefulWidget {
  const _SetupBiometricDialog();

  @override
  State<_SetupBiometricDialog> createState() => _SetupBiometricDialogState();
}

class _SetupBiometricDialogState extends State<_SetupBiometricDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _passwordController.text;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.securitySetupBiometricDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.securitySetupBiometricDialogBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.securityMasterPasswordTitle,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscure = !_obscure);
                  },
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.securitySetupBiometricDialogCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.securitySetupBiometricDialogAction),
        ),
      ],
    );
  }
}

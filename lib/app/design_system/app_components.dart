// ignore_for_file: prefer_const_declarations

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Pill-shaped tag used on hero cards. Three semantic tints so the
/// dashboard can read at a glance (status / sync state / weak
/// passwords) without changing the wording.
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.icon,
    this.tint = AppPillTint.neutral,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final AppPillTint tint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _resolve(tint, isDark);
    final hPad = compact ? 10.0 : 12.0;
    final vPad = compact ? 5.0 : 7.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: colors.stroke, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  _PillColors _resolve(AppPillTint tint, bool isDark) {
    switch (tint) {
      case AppPillTint.neutral:
        return _PillColors(
          fill: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          stroke: isDark ? AppColors.borderDark : AppColors.borderLight,
          foreground: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        );
      case AppPillTint.crimson:
        return _PillColors(
          fill: AppColors.crimson.withValues(alpha: isDark ? 0.18 : 0.12),
          stroke: AppColors.crimson.withValues(alpha: isDark ? 0.35 : 0.28),
          foreground: isDark
              ? AppColors.crimsonBright
              : AppColors.crimson,
        );
      case AppPillTint.success:
        return _PillColors(
          fill: AppColors.success.withValues(alpha: 0.18),
          stroke: AppColors.success.withValues(alpha: 0.32),
          foreground: isDark
              ? AppColors.success
              : const Color(0xFF1F7A5C),
        );
      case AppPillTint.warning:
        return _PillColors(
          fill: AppColors.warning.withValues(alpha: 0.18),
          stroke: AppColors.warning.withValues(alpha: 0.32),
          foreground: isDark
              ? AppColors.warning
              : const Color(0xFF8A5A14),
        );
      case AppPillTint.danger:
        return _PillColors(
          fill: AppColors.danger.withValues(alpha: 0.18),
          stroke: AppColors.danger.withValues(alpha: 0.32),
          foreground: isDark
              ? AppColors.crimsonBright
              : AppColors.danger,
        );
    }
  }
}

enum AppPillTint { neutral, crimson, success, warning, danger }

class _PillColors {
  const _PillColors({
    required this.fill,
    required this.stroke,
    required this.foreground,
  });
  final Color fill;
  final Color stroke;
  final Color foreground;
}

/// Status banner used across the app for "info" / "success" /
/// "warning" / "danger" messaging. Replaces the dozen ad-hoc
/// `Container` banners that used to live in each screen.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.icon,
    this.tone = AppBannerTone.info,
    this.action,
  });

  final String message;
  final IconData? icon;
  final AppBannerTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colors = _resolve(tone, isDark);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.stroke, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon ?? colors.defaultIcon, color: colors.foreground, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }

  _BannerColors _resolve(AppBannerTone tone, bool isDark) {
    final accent = switch (tone) {
      AppBannerTone.info => isDark ? AppColors.info : const Color(0xFF395A78),
      AppBannerTone.success => AppColors.success,
      AppBannerTone.warning => AppColors.warning,
      AppBannerTone.danger => AppColors.danger,
    };
    return _BannerColors(
      fill: accent.withValues(alpha: isDark ? 0.10 : 0.08),
      stroke: accent.withValues(alpha: isDark ? 0.28 : 0.22),
      foreground: isDark
          ? accent
          : (tone == AppBannerTone.warning
                ? const Color(0xFF8A5A14)
                : (tone == AppBannerTone.danger
                      ? AppColors.danger
                      : (tone == AppBannerTone.info
                            ? const Color(0xFF1F3F5A)
                            : const Color(0xFF1F7A5C)))),
      defaultIcon: switch (tone) {
        AppBannerTone.info => Icons.info_outline_rounded,
        AppBannerTone.success => Icons.check_circle_outline_rounded,
        AppBannerTone.warning => Icons.warning_amber_rounded,
        AppBannerTone.danger => Icons.error_outline_rounded,
      },
    );
  }
}

enum AppBannerTone { info, success, warning, danger }

class _BannerColors {
  const _BannerColors({
    required this.fill,
    required this.stroke,
    required this.foreground,
    required this.defaultIcon,
  });
  final Color fill;
  final Color stroke;
  final Color foreground;
  final IconData defaultIcon;
}

/// Section header used on every screen. Replaces the dozen ad-hoc
/// `Row` headers with a title + optional trailing action.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.crimsonBright,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
              ],
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

/// Hero surface used on the login / onboarding / lock screens. Owns
/// the dark gradient + ambient orbs so every gate looks consistent.
class AppHeroBackground extends StatelessWidget {
  const AppHeroBackground({
    super.key,
    required this.child,
    this.intensity = 1.0,
  });

  final Widget child;

  /// 0..1. Lets the dashboard dial the ambient orbs down vs the
  /// login screen which dials them up.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = intensity.clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF120A0C), AppColors.backgroundDark, AppColors.backgroundDark]
              : const [Color(0xFFF8EDE8), AppColors.backgroundLight, AppColors.backgroundLight],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -60,
            child: _Orb(
              color: AppColors.crimson.withValues(alpha: 0.30 * scale),
              size: 320,
            ),
          ),
          Positioned(
            top: 200 * scale,
            left: -100,
            child: _Orb(
              color: AppColors.crimsonDeep.withValues(alpha: 0.28 * scale),
              size: 280,
            ),
          ),
          Positioned(
            bottom: -100,
            right: 80,
            child: _Orb(
              color: AppColors.gold.withValues(alpha: 0.14 * scale),
              size: 200,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});
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

/// Subtle grid of dots drawn over the hero surface to add texture
/// without competing with content. Optional.
class AppHeroGrid extends StatelessWidget {
  const AppHeroGrid({super.key, this.opacity = 0.05});
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GridPainter(opacity: opacity),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    const step = 28.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

/// Square "monogram" block that renders the Vaulta logomark at a
/// given size. Tints follow the brand: crimson body, paper shackle
/// in dark mode, ink shackle in light mode, gold accent.
class VaultaLogomark extends StatelessWidget {
  const VaultaLogomark({
    super.key,
    this.size = 56,
    this.backgroundColor,
  });

  final double size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ??
        (isDark ? AppColors.surfaceDarkHigh : AppColors.surfaceLight);
    final ink = isDark ? AppColors.paperDark : AppColors.ink;
    final crimson = AppColors.crimson;
    final gold = AppColors.gold;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: CustomPaint(
        painter: _LogomarkPainter(
          crimson: crimson,
          gold: gold,
          ink: ink,
        ),
      ),
    );
  }
}

class _LogomarkPainter extends CustomPainter {
  _LogomarkPainter({
    required this.crimson,
    required this.gold,
    required this.ink,
  });

  final Color crimson;
  final Color gold;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 120;
    canvas.save();
    canvas.translate(0, 0);
    canvas.scale(scale);

    // Body
    final body = Path()
      ..moveTo(36, 52)
      ..lineTo(30, 58)
      ..lineTo(30, 100)
      ..lineTo(90, 100)
      ..lineTo(90, 58)
      ..lineTo(84, 52)
      ..close();
    final bodyPaint = Paint()..color = crimson;
    canvas.drawPath(body, bodyPaint);

    // Shackle
    final shackle = Path()
      ..moveTo(42, 52)
      ..lineTo(42, 30)
      ..lineTo(60, 48)
      ..lineTo(78, 30)
      ..lineTo(78, 52);
    final shacklePaint = Paint()
      ..color = ink
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..style = PaintingStyle.stroke;
    canvas.drawPath(shackle, shacklePaint);

    // Gold accents
    final bar = Paint()..color = gold;
    canvas.drawRect(const Rect.fromLTWH(40, 70, 40, 2.5), bar);
    canvas.drawRect(const Rect.fromLTWH(56, 78, 8, 8), bar);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogomarkPainter oldDelegate) {
    return oldDelegate.crimson != crimson ||
        oldDelegate.gold != gold ||
        oldDelegate.ink != ink;
  }
}

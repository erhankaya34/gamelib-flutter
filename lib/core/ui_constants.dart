import 'package:flutter/material.dart';

/// Neo-Brutalist Gaming UI Constants
/// Consistent design system across the app
class UIConstants {
  // Background colors
  static const Color bgPrimary = Color(0xFF0a0a0f);
  static const Color bgSecondary = Color(0xFF12121a);
  static const Color bgTertiary = Color(0xFF1a1a2e);
  static const Color bgElevated = Color(0xFF16213e);

  // Accent colors
  static const Color accentPurple = Color(0xFF6366f1);
  static const Color accentViolet = Color(0xFF8b5cf6);
  static const Color accentPink = Color(0xFFa855f7);
  static const Color accentGreen = Color(0xFF10b981);
  static const Color accentGreenLight = Color(0xFF34d399);
  static const Color accentYellow = Color(0xFFf59e0b);
  static const Color accentYellowLight = Color(0xFFfbbf24);
  static const Color accentRed = Color(0xFFef4444);
  static const Color accentRedLight = Color(0xFFf87171);
  static const Color accentSteam = Color(0xFF66c0f4);
  static const Color bgSteam = Color(0xFF1b2838);

  // PLAYBACK Fire theme colors
  static const Color fireOrange = Color(0xFFFF6B35);
  static const Color fireRed = Color(0xFFE63946);
  static const Color fireYellow = Color(0xFFFFB627);
  static const Color fireGlow = Color(0xFFFF9F1C);
  static const Color fireDarkBg = Color(0xFF0D0D0D);
  static const Color fireEmber = Color(0xFFFF4D00);

  // Platform color (unified for all platforms: Steam, PlayStation, Epic, etc.)
  static const Color accentPlatform = Color(0xFF66c0f4);

  // Legacy PlayStation colors (deprecated - use accentPlatform instead)
  @Deprecated('Use accentPlatform instead for unified platform colors')
  static const Color accentPlayStation = Color(0xFF66c0f4);
  @Deprecated('Use accentPlatform instead for unified platform colors')
  static const Color accentPlayStationLight = Color(0xFF66c0f4);

  // Text colors
  static const Color textPrimary = Colors.white;
  static Color textSecondary = Colors.white.withOpacity(0.7);
  static Color textMuted = Colors.white.withOpacity(0.5);
  static Color textDimmed = Colors.white.withOpacity(0.3);

  // Gradients
  static const purpleGradient = [Color(0xFF6366f1), Color(0xFF8b5cf6)];
  static const violetGradient = [Color(0xFF8b5cf6), Color(0xFFa855f7)];
  static const greenGradient = [Color(0xFF10b981), Color(0xFF34d399)];
  static const yellowGradient = [Color(0xFFf59e0b), Color(0xFFfbbf24)];
  static const redGradient = [Color(0xFFef4444), Color(0xFFf87171)];
  static const steamGradient = [Color(0xFF66c0f4), Color(0xFF4fa8d5)];
  static const platformGradient = [Color(0xFF66c0f4), Color(0xFF4fa8d5)];
  static const fireGradient = [Color(0xFFFF6B35), Color(0xFFE63946)];
  static const fireGlowGradient = [Color(0xFFFFB627), Color(0xFFFF6B35), Color(0xFFE63946)];
  @Deprecated('Use platformGradient instead for unified platform colors')
  static const playstationGradient = [Color(0xFF66c0f4), Color(0xFF4fa8d5)];

  // Spacing
  static const double pagePadding = 20.0;
  static const double cardPadding = 16.0;
  static const double itemSpacing = 12.0;
  static const double sectionSpacing = 24.0;

  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 14.0;
  static const double radiusLarge = 20.0;
  static const double radiusXLarge = 24.0;

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 400);
  static const Duration animSlow = Duration(milliseconds: 600);
}

/// Section header with accent bar
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.accentColor = UIConstants.accentPurple,
    this.action,
  });

  final String title;
  final Color accentColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.pagePadding,
        vertical: UIConstants.itemSpacing,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Gradient icon button
class GradientIconButton extends StatelessWidget {
  const GradientIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.gradient = UIConstants.purpleGradient,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final List<Color> gradient;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}

/// Glass-morphism card
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(UIConstants.cardPadding),
      decoration: BoxDecoration(
        color: UIConstants.bgSecondary,
        borderRadius: BorderRadius.circular(borderRadius ?? UIConstants.radiusLarge),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.05),
        ),
      ),
      child: child,
    );
  }
}

/// Empty state widget
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (iconColor ?? UIConstants.accentPurple).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: (iconColor ?? UIConstants.accentPurple).withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading state widget
class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: UIConstants.accentPurple,
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stat card with gradient icon
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.gradient,
  });

  final String value;
  final String label;
  final IconData icon;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UIConstants.cardPadding),
      decoration: BoxDecoration(
        color: UIConstants.bgSecondary,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(
          color: gradient[0].withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1,
              shadows: [
                Shadow(
                  color: gradient[0].withOpacity(0.5),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

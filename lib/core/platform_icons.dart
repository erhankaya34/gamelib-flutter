import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Platform types supported by the app
enum GamePlatform {
  steam,
  playstation,
  epic,
  xbox,
  nintendo,
  valorant,
}

/// Unified platform color used for all gaming platforms
/// This ensures a consistent look across Steam, PlayStation, Epic, etc.
/// Updated to use fire theme orange color for consistency
const Color _platformActiveColor = Color(0xFFFF6B35); // fireOrange
const Color _platformInactiveColor = Color(0xFF3d4450);

/// Platform configuration with colors, icons, and labels
class PlatformConfig {
  final GamePlatform platform;
  final String name;
  final IconData? icon;
  final bool useCustomIcon; // For platforms without FA icons (Epic Games)
  final Color activeColor;
  final Color inactiveColor;

  const PlatformConfig({
    required this.platform,
    required this.name,
    this.icon,
    this.useCustomIcon = false,
    required this.activeColor,
    required this.inactiveColor,
  });

  /// Steam platform configuration
  static const steam = PlatformConfig(
    platform: GamePlatform.steam,
    name: 'Steam',
    icon: FontAwesomeIcons.steam,
    activeColor: _platformActiveColor,
    inactiveColor: _platformInactiveColor,
  );

  /// PlayStation platform configuration
  static const playstation = PlatformConfig(
    platform: GamePlatform.playstation,
    name: 'PlayStation',
    icon: FontAwesomeIcons.playstation,
    activeColor: _platformActiveColor,
    inactiveColor: _platformInactiveColor,
  );

  /// Epic Games platform configuration - uses custom "E" icon
  static const epic = PlatformConfig(
    platform: GamePlatform.epic,
    name: 'Epic Games',
    useCustomIcon: true, // Uses custom "E" text icon
    activeColor: _platformActiveColor,
    inactiveColor: _platformInactiveColor,
  );

  /// Xbox platform configuration
  static const xbox = PlatformConfig(
    platform: GamePlatform.xbox,
    name: 'Xbox',
    icon: FontAwesomeIcons.xbox,
    activeColor: _platformActiveColor,
    inactiveColor: _platformInactiveColor,
  );

  /// Nintendo platform configuration
  static const nintendo = PlatformConfig(
    platform: GamePlatform.nintendo,
    name: 'Nintendo',
    icon: FontAwesomeIcons.gamepad,
    activeColor: _platformActiveColor,
    inactiveColor: _platformInactiveColor,
  );

  /// Valorant platform configuration - uses custom logo
  static const valorant = PlatformConfig(
    platform: GamePlatform.valorant,
    name: 'Valorant',
    useCustomIcon: true,
    activeColor: _platformActiveColor, // fireOrange for consistency
    inactiveColor: _platformInactiveColor,
  );

  /// Get all main platforms for display
  static List<PlatformConfig> get mainPlatforms => [
        steam,
        playstation,
        valorant,
        epic,
        xbox,
      ];

  /// Get platform config by type
  static PlatformConfig fromType(GamePlatform type) {
    switch (type) {
      case GamePlatform.steam:
        return steam;
      case GamePlatform.playstation:
        return playstation;
      case GamePlatform.epic:
        return epic;
      case GamePlatform.xbox:
        return xbox;
      case GamePlatform.nintendo:
        return nintendo;
      case GamePlatform.valorant:
        return valorant;
    }
  }
}

/// Platform icon widget with active/inactive states
class PlatformIcon extends StatelessWidget {
  const PlatformIcon({
    super.key,
    required this.platform,
    required this.isActive,
    this.size = 20,
    this.showLabel = false,
  });

  final PlatformConfig platform;
  final bool isActive;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? platform.activeColor : Colors.white.withOpacity(0.2);

    Widget iconWidget;

    // Handle custom icons (like Epic Games or Valorant)
    if (platform.useCustomIcon) {
      if (platform.platform == GamePlatform.valorant) {
        iconWidget = ValorantIcon(size: size, color: color);
      } else {
        iconWidget = _EpicGamesIcon(size: size, color: color);
      }
    } else {
      iconWidget = FaIcon(
        platform.icon,
        size: size,
        color: color,
      );
    }

    if (showLabel) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: 4),
          Text(
            platform.name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      );
    }

    return iconWidget;
  }
}

/// Custom Epic Games official logo widget
/// Based on the official SVG from Simple Icons (epicgames.svg)
class _EpicGamesIcon extends StatelessWidget {
  const _EpicGamesIcon({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _EpicGamesLogoPainter(color: color),
      ),
    );
  }
}

/// Custom painter for Epic Games official logo
/// Based on the official SVG from Simple Icons (epicgames.svg)
class _EpicGamesLogoPainter extends CustomPainter {
  _EpicGamesLogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    final path = Path();

    // Main shape - outer border with rounded corners
    path.moveTo(3.537 * scaleX, 0 * scaleY);
    _cubicTo(path, scaleX, scaleY, 2.165, 0, 1.66, 0.506, 1.66, 1.879);
    path.lineTo(1.66 * scaleX, 18.44 * scaleY);
    _addArc(path, scaleX, scaleY, 0.02, 0.433);
    _cubicTo(path, scaleX, scaleY, 1.691, 18.873, 1.697, 19.163, 1.976, 19.493);
    _cubicTo(path, scaleX, scaleY, 2.003, 19.526, 2.287, 19.738, 2.287, 19.738);
    _cubicTo(path, scaleX, scaleY, 2.44, 19.813, 2.545, 19.868, 2.717, 19.938);
    path.lineTo(11.052 * scaleX, 23.429 * scaleY);
    _cubicTo(path, scaleX, scaleY, 11.485, 23.628, 11.666, 23.705, 11.98, 23.699);
    path.lineTo(11.982 * scaleX, 23.699 * scaleY);
    _cubicTo(path, scaleX, scaleY, 12.296, 23.705, 12.477, 23.628, 12.91, 23.429);
    path.lineTo(21.245 * scaleX, 19.937 * scaleY);
    _cubicTo(path, scaleX, scaleY, 21.417, 19.867, 21.522, 19.813, 21.675, 19.737);
    _cubicTo(path, scaleX, scaleY, 21.675, 19.737, 21.959, 19.526, 21.986, 19.494);
    _cubicTo(path, scaleX, scaleY, 22.266, 19.164, 22.271, 18.873, 22.302, 18.574);
    _addArc(path, scaleX, scaleY, 0.02, -0.434);
    path.lineTo(22.322 * scaleX, 1.879 * scaleY);
    _cubicTo(path, scaleX, scaleY, 22.322, 0.506, 21.816, 0, 20.444, 0);
    path.close();

    // Letter E (top left)
    path.moveTo(4.717 * scaleX, 3.19 * scaleY);
    path.lineTo(7.831 * scaleX, 3.19 * scaleY);
    path.lineTo(7.831 * scaleX, 4.464 * scaleY);
    path.lineTo(6.117 * scaleX, 4.464 * scaleY);
    path.lineTo(6.117 * scaleX, 7.067 * scaleY);
    path.lineTo(7.765 * scaleX, 7.067 * scaleY);
    path.lineTo(7.765 * scaleX, 8.342 * scaleY);
    path.lineTo(6.117 * scaleX, 8.342 * scaleY);
    path.lineTo(6.117 * scaleX, 11.116 * scaleY);
    path.lineTo(7.857 * scaleX, 11.116 * scaleY);
    path.lineTo(7.857 * scaleX, 12.391 * scaleY);
    path.lineTo(4.717 * scaleX, 12.391 * scaleY);
    path.close();

    // Letter P
    path.moveTo(8.533 * scaleX, 3.19 * scaleY);
    path.lineTo(10.731 * scaleX, 3.19 * scaleY);
    _cubicTo(path, scaleX, scaleY, 11.869, 3.19, 12.431, 3.754, 12.431, 4.898);
    path.lineTo(12.431 * scaleX, 7.343 * scaleY);
    _cubicTo(path, scaleX, scaleY, 12.431, 8.487, 11.869, 9.053, 10.731, 9.053);
    path.lineTo(9.932 * scaleX, 9.053 * scaleY);
    path.lineTo(9.932 * scaleX, 12.391 * scaleY);
    path.lineTo(8.532 * scaleX, 12.391 * scaleY);
    path.close();

    // Letter P inner
    path.moveTo(9.932 * scaleX, 4.425 * scaleY);
    path.lineTo(9.932 * scaleX, 7.817 * scaleY);
    path.lineTo(10.507 * scaleX, 7.817 * scaleY);
    _cubicTo(path, scaleX, scaleY, 10.861, 7.817, 11.03, 7.646, 11.03, 7.277);
    path.lineTo(11.03 * scaleX, 4.965 * scaleY);
    _cubicTo(path, scaleX, scaleY, 11.03, 4.597, 10.86, 4.425, 10.507, 4.425);
    path.close();

    // Letter I
    path.moveTo(13.063 * scaleX, 3.19 * scaleY);
    path.lineTo(14.463 * scaleX, 3.19 * scaleY);
    path.lineTo(14.463 * scaleX, 12.391 * scaleY);
    path.lineTo(13.063 * scaleX, 12.391 * scaleY);
    path.close();

    // Letter C
    path.moveTo(16.903 * scaleX, 3.11 * scaleY);
    path.lineTo(17.583 * scaleX, 3.11 * scaleY);
    _cubicTo(path, scaleX, scaleY, 18.721, 3.11, 19.271, 3.663, 19.271, 4.806);
    path.lineTo(19.271 * scaleX, 6.686 * scaleY);
    path.lineTo(17.897 * scaleX, 6.686 * scaleY);
    path.lineTo(17.897 * scaleX, 4.886 * scaleY);
    _cubicTo(path, scaleX, scaleY, 17.897, 4.517, 17.727, 4.346, 17.374, 4.346);
    path.lineTo(17.139 * scaleX, 4.346 * scaleY);
    _cubicTo(path, scaleX, scaleY, 16.772, 4.346, 16.602, 4.516, 16.602, 4.885);
    path.lineTo(16.602 * scaleX, 10.695 * scaleY);
    _cubicTo(path, scaleX, scaleY, 16.602, 11.064, 16.772, 11.235, 17.139, 11.235);
    path.lineTo(17.401 * scaleX, 11.235 * scaleY);
    _cubicTo(path, scaleX, scaleY, 17.754, 11.235, 17.924, 11.064, 17.924, 10.695);
    path.lineTo(17.924 * scaleX, 8.619 * scaleY);
    path.lineTo(19.297 * scaleX, 8.619 * scaleY);
    path.lineTo(19.297 * scaleX, 10.762 * scaleY);
    _cubicTo(path, scaleX, scaleY, 19.297, 11.906, 18.735, 12.472, 17.597, 12.472);
    path.lineTo(16.903 * scaleX, 12.472 * scaleY);
    _cubicTo(path, scaleX, scaleY, 15.765, 12.472, 15.203, 11.906, 15.203, 10.762);
    path.lineTo(15.203 * scaleX, 4.82 * scaleY);
    _cubicTo(path, scaleX, scaleY, 15.203, 3.676, 15.765, 3.111, 16.903, 3.11);
    path.close();

    // Bottom arrow
    path.moveTo(3.968 * scaleX, 21.812 * scaleY);
    path.lineTo(11.982 * scaleX, 21.812 * scaleY);
    path.lineTo(7.892 * scaleX, 23.16 * scaleY);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _cubicTo(Path path, double scaleX, double scaleY,
      double x1, double y1, double x2, double y2, double x3, double y3) {
    path.cubicTo(
      x1 * scaleX, y1 * scaleY,
      x2 * scaleX, y2 * scaleY,
      x3 * scaleX, y3 * scaleY,
    );
  }

  void _addArc(Path path, double scaleX, double scaleY, double dx, double dy) {
    // Simplified arc as relative line
    path.relativeLineTo(dx * scaleX, dy * scaleY);
  }

  @override
  bool shouldRepaint(covariant _EpicGamesLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Custom Valorant icon widget
/// Renders the official Valorant logo
/// Public version for use across the app
class ValorantIcon extends StatelessWidget {
  const ValorantIcon({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ValorantLogoCustomPainter(color: color),
      ),
    );
  }
}

/// Custom painter for Valorant official logo
/// Based on the official SVG from Simple Icons (valorant.svg)
class _ValorantLogoCustomPainter extends CustomPainter {
  _ValorantLogoCustomPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    // Right side path
    final path1 = Path();
    path1.moveTo(23.792 * scaleX, 2.152 * scaleY);
    path1.cubicTo(
      23.752 * scaleX, 2.182 * scaleY,
      23.712 * scaleX, 2.212 * scaleY,
      23.694 * scaleX, 2.235 * scaleY,
    );
    path1.cubicTo(
      20.31 * scaleX, 6.465 * scaleY,
      16.925 * scaleX, 10.695 * scaleY,
      13.544 * scaleX, 14.925 * scaleY,
    );
    path1.cubicTo(
      13.437 * scaleX, 15.018 * scaleY,
      13.519 * scaleX, 15.213 * scaleY,
      13.663 * scaleX, 15.19 * scaleY,
    );
    path1.cubicTo(
      16.102 * scaleX, 15.193 * scaleY,
      18.54 * scaleX, 15.19 * scaleY,
      20.979 * scaleX, 15.191 * scaleY,
    );
    path1.cubicTo(
      21.212 * scaleX, 15.191 * scaleY,
      21.427 * scaleX, 15.08 * scaleY,
      21.531 * scaleX, 14.941 * scaleY,
    );
    path1.cubicTo(
      22.305 * scaleX, 13.974 * scaleY,
      23.081 * scaleX, 13.007 * scaleY,
      23.855 * scaleX, 12.038 * scaleY,
    );
    path1.cubicTo(
      23.931 * scaleX, 11.87 * scaleY,
      23.999 * scaleX, 11.69 * scaleY,
      23.999 * scaleX, 11.548 * scaleY,
    );
    path1.lineTo(23.999 * scaleX, 2.318 * scaleY);
    path1.cubicTo(
      24.015 * scaleX, 2.208 * scaleY,
      23.899 * scaleX, 2.112 * scaleY,
      23.795 * scaleX, 2.151 * scaleY,
    );
    path1.close();

    // Left side path
    final path2 = Path();
    path2.moveTo(0.077 * scaleX, 2.166 * scaleY);
    path2.cubicTo(
      0.0 * scaleX, 2.204 * scaleY,
      0.003 * scaleX, 2.298 * scaleY,
      0.001 * scaleX, 2.371 * scaleY,
    );
    path2.lineTo(0.001 * scaleX, 11.596 * scaleY);
    path2.cubicTo(
      0.001 * scaleX, 11.776 * scaleY,
      0.06 * scaleX, 11.916 * scaleY,
      0.159 * scaleX, 12.059 * scaleY,
    );
    path2.lineTo(7.799 * scaleX, 21.609 * scaleY);
    path2.cubicTo(
      7.919 * scaleX, 21.761 * scaleY,
      8.107 * scaleX, 21.859 * scaleY,
      8.304 * scaleX, 21.856 * scaleY,
    );
    path2.lineTo(15.669 * scaleX, 21.856 * scaleY);
    path2.cubicTo(
      15.811 * scaleX, 21.876 * scaleY,
      15.891 * scaleX, 21.682 * scaleY,
      15.785 * scaleX, 21.591 * scaleY,
    );
    path2.cubicTo(
      10.661 * scaleX, 15.176 * scaleY,
      5.526 * scaleX, 8.766 * scaleY,
      0.4 * scaleX, 2.35 * scaleY,
    );
    path2.cubicTo(
      0.32 * scaleX, 2.256 * scaleY,
      0.226 * scaleX, 2.078 * scaleY,
      0.078 * scaleX, 2.166 * scaleY,
    );
    path2.close();

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _ValorantLogoCustomPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Row of platform icons showing which platforms a game is in
/// Note: Valorant is excluded as it's a game, not a distribution platform
class PlatformIconRow extends StatelessWidget {
  const PlatformIconRow({
    super.key,
    required this.activePlatforms,
    this.iconSize = 14,
    this.spacing = 8,
  });

  final Set<GamePlatform> activePlatforms;
  final double iconSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    // Filter out Valorant - it's a game, not a platform for other games
    final gamePlatforms = PlatformConfig.mainPlatforms
        .where((p) => p.platform != GamePlatform.valorant)
        .toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: gamePlatforms.map((platform) {
        final isActive = activePlatforms.contains(platform.platform);
        return Padding(
          padding: EdgeInsets.only(right: spacing),
          child: PlatformIcon(
            platform: platform,
            isActive: isActive,
            size: iconSize,
          ),
        );
      }).toList(),
    );
  }
}

/// Profile platform connection badges
class ProfilePlatformBadges extends StatelessWidget {
  const ProfilePlatformBadges({
    super.key,
    required this.connectedPlatforms,
  });

  final Set<GamePlatform> connectedPlatforms;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: PlatformConfig.mainPlatforms.map((platform) {
        final isConnected = connectedPlatforms.contains(platform.platform);
        final color = isConnected
            ? platform.activeColor
            : Colors.white.withOpacity(0.2);

        Widget iconWidget;
        if (platform.useCustomIcon) {
          if (platform.platform == GamePlatform.valorant) {
            iconWidget = ValorantIcon(size: 24, color: color);
          } else {
            iconWidget = _EpicGamesIcon(size: 24, color: color);
          }
        } else {
          iconWidget = FaIcon(
            platform.icon,
            size: 24,
            color: color,
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected
                  ? platform.activeColor.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: isConnected
                    ? platform.activeColor.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                width: 2,
              ),
            ),
            child: iconWidget,
          ),
        );
      }).toList(),
    );
  }
}

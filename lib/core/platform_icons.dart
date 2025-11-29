import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Platform types supported by the app
enum GamePlatform {
  steam,
  playstation,
  epic,
  xbox,
  nintendo,
}

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
    activeColor: Color(0xFF66c0f4),
    inactiveColor: Color(0xFF3d4450),
  );

  /// PlayStation platform configuration
  static const playstation = PlatformConfig(
    platform: GamePlatform.playstation,
    name: 'PlayStation',
    icon: FontAwesomeIcons.playstation,
    activeColor: Color(0xFF003791),
    inactiveColor: Color(0xFF2a2a3a),
  );

  /// Epic Games platform configuration - uses custom "E" icon
  static const epic = PlatformConfig(
    platform: GamePlatform.epic,
    name: 'Epic Games',
    useCustomIcon: true, // Uses custom "E" text icon
    activeColor: Color(0xFFFFFFFF), // Epic white
    inactiveColor: Color(0xFF2a2a2a),
  );

  /// Xbox platform configuration
  static const xbox = PlatformConfig(
    platform: GamePlatform.xbox,
    name: 'Xbox',
    icon: FontAwesomeIcons.xbox,
    activeColor: Color(0xFF107c10),
    inactiveColor: Color(0xFF1e3a1e),
  );

  /// Nintendo platform configuration
  static const nintendo = PlatformConfig(
    platform: GamePlatform.nintendo,
    name: 'Nintendo',
    icon: FontAwesomeIcons.gamepad,
    activeColor: Color(0xFFe60012),
    inactiveColor: Color(0xFF3a1a1a),
  );

  /// Get all main platforms for display
  static List<PlatformConfig> get mainPlatforms => [
        steam,
        playstation,
        epic,
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

    // Handle custom icons (like Epic Games "E")
    if (platform.useCustomIcon) {
      iconWidget = _EpicGamesIcon(size: size, color: color);
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

/// Custom Epic Games "E" icon widget
/// Mimics the official Epic Games logo style
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
      child: Center(
        child: Text(
          'E',
          style: TextStyle(
            fontSize: size * 0.85,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Row of platform icons showing which platforms a game is in
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: PlatformConfig.mainPlatforms.map((platform) {
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
          iconWidget = _EpicGamesIcon(size: 24, color: color);
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

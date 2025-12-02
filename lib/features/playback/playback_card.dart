/// PLAYBACK Card Widget - Fire Theme Edition
///
/// 9:16 story formatında premium oyuncu kartı.
/// Alev animasyonları, ember efektleri ve ateş teması ile.

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/ui_constants.dart';
import '../../models/game_log.dart';
import 'playback_stats.dart';

/// 9:16 formatında PLAYBACK kartı - Fire Theme
class PlaybackCard extends StatefulWidget {
  const PlaybackCard({
    super.key,
    required this.stats,
    required this.username,
    this.avatarUrl,
  });

  final PlaybackStats stats;
  final String username;
  final String? avatarUrl;

  @override
  State<PlaybackCard> createState() => _PlaybackCardState();
}

class _PlaybackCardState extends State<PlaybackCard>
    with TickerProviderStateMixin {
  late AnimationController _flameController;
  late AnimationController _emberController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _emberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flameController.dispose();
    _emberController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D0D0D),
              Color(0xFF1A0A0A),
              Color(0xFF0D0D0D),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: UIConstants.fireOrange.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: UIConstants.fireOrange.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: UIConstants.fireRed.withOpacity(0.1),
              blurRadius: 60,
              spreadRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Animated flame background
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _flameController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _FlameBackgroundPainter(
                        progress: _flameController.value,
                      ),
                    );
                  },
                ),
              ),

              // Ember particles
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _emberController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _EmberParticlesPainter(
                        progress: _emberController.value,
                      ),
                    );
                  },
                ),
              ),

              // Gradient overlay for readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0D0D0D).withOpacity(0.7),
                        const Color(0xFF0D0D0D).withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _FireHeader(
                      username: widget.username,
                      avatarUrl: widget.avatarUrl,
                      period: widget.stats.period,
                      pulseController: _pulseController,
                    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),

                    const SizedBox(height: 10),

                    // Scrollable middle content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Archetype Badge (Hero section)
                            _FireArchetypeBadge(
                              archetype: widget.stats.archetype,
                              pulseController: _pulseController,
                            ).animate().fadeIn(duration: 600.ms, delay: 200.ms).scale(
                                  begin: const Offset(0.8, 0.8),
                                  curve: Curves.easeOutBack,
                                ),

                            const SizedBox(height: 10),

                            // Main Stats
                            _FireMainStats(stats: widget.stats)
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 400.ms)
                                .slideX(begin: -0.1),

                            const SizedBox(height: 8),

                            // Additional Archetypes
                            if (widget.stats.additionalArchetypes.isNotEmpty) ...[
                              _FireAdditionalArchetypes(
                                archetypes: widget.stats.additionalArchetypes,
                              ).animate().fadeIn(duration: 500.ms, delay: 450.ms),
                              const SizedBox(height: 8),
                            ],

                            // Top Genres
                            if (widget.stats.topGenres.isNotEmpty) ...[
                              _FireTopGenres(
                                genres: widget.stats.topGenres,
                                totalHours: widget.stats.totalHours,
                              ).animate().fadeIn(duration: 500.ms, delay: 480.ms),
                              const SizedBox(height: 8),
                            ],

                            // Top 5 Most Played Games
                            if (widget.stats.topPlayedGames.isNotEmpty) ...[
                              _FireTopGames(games: widget.stats.topPlayedGames)
                                  .animate()
                                  .fadeIn(duration: 500.ms, delay: 500.ms),
                              const SizedBox(height: 8),
                            ],

                            // Platform Distribution (compact)
                            if (widget.stats.platformStats.isNotEmpty) ...[
                              _FirePlatformDistribution(
                                stats: widget.stats,
                                flameController: _flameController,
                              ).animate().fadeIn(duration: 500.ms, delay: 520.ms),
                              const SizedBox(height: 8),
                            ],

                            // Extra Stats Row (Average Rating & Period Stats)
                            _FireExtraStats(stats: widget.stats)
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 540.ms),

                            const SizedBox(height: 8),

                            // Fun Comparison
                            _FireFunComparison(text: widget.stats.funComparison)
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 560.ms)
                                .shimmer(
                                  duration: 2000.ms,
                                  color: UIConstants.fireYellow.withOpacity(0.3),
                                ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Footer (fixed at bottom)
                    _FireFooter(pulseController: _pulseController)
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 600.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// FLAME BACKGROUND PAINTER
// ============================================

class _FlameBackgroundPainter extends CustomPainter {
  _FlameBackgroundPainter({required this.progress});

  final double progress;

  // Organic smoke wisp configurations
  static final List<_SmokeWisp> _wisps = List.generate(6, (i) => _SmokeWisp(i));

  @override
  void paint(Canvas canvas, Size size) {
    final pulseIntensity = 0.25 + 0.1 * math.sin(progress * math.pi * 2);

    // Layer 1: Deep ambient warmth from bottom
    final ambientPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 1.3),
        radius: 1.2,
        colors: [
          UIConstants.fireRed.withOpacity(pulseIntensity * 0.5),
          UIConstants.fireOrange.withOpacity(pulseIntensity * 0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), ambientPaint);

    // Layer 2: Soft core glow
    final corePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 1.5),
        radius: 0.5,
        colors: [
          UIConstants.fireYellow.withOpacity(pulseIntensity * 0.35),
          UIConstants.fireOrange.withOpacity(pulseIntensity * 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), corePaint);

    // Layer 3: Organic smoke wisps rising
    for (final wisp in _wisps) {
      _drawSmokeWisp(canvas, size, wisp, progress);
    }

    // Layer 4: Radial vignette
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: [
          Colors.transparent,
          Colors.transparent,
          UIConstants.fireDarkBg.withOpacity(0.25),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
  }

  void _drawSmokeWisp(Canvas canvas, Size size, _SmokeWisp wisp, double time) {
    final wispProgress = (time * wisp.speed + wisp.delay) % 1.0;
    final easedProgress = _smoothstep(0.0, 1.0, wispProgress);

    final startY = size.height * 1.05;
    final endY = size.height * -0.15;
    final currentY = startY + (endY - startY) * easedProgress;

    // Organic drift with layered sine waves
    final drift1 = math.sin(wispProgress * math.pi * 2.5 + wisp.phase) * wisp.driftAmount;
    final drift2 = math.sin(wispProgress * math.pi * 5 + wisp.phase * 1.7) * wisp.driftAmount * 0.25;
    final totalDrift = (drift1 + drift2) * size.width * 0.12;
    final currentX = wisp.startX * size.width + totalDrift;

    // Smooth opacity lifecycle
    double opacity = wisp.baseOpacity;
    if (wispProgress < 0.12) {
      opacity *= _smoothstep(0.0, 0.12, wispProgress);
    } else if (wispProgress > 0.55) {
      opacity *= 1.0 - _smoothstep(0.55, 1.0, wispProgress);
    }

    // Dynamic size - expand then dissipate
    final sizeMultiplier = 1.0 + math.sin(wispProgress * math.pi) * 0.6;
    final currentWidth = wisp.width * sizeMultiplier * size.width;
    final currentHeight = wisp.height * sizeMultiplier * size.height;

    if (opacity > 0.008) {
      final wispPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.5,
          colors: [
            wisp.color.withOpacity((opacity * 0.7).clamp(0.0, 1.0)),
            wisp.color.withOpacity((opacity * 0.35).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(
          Rect.fromCenter(center: Offset(currentX, currentY), width: currentWidth, height: currentHeight),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentWidth * 0.25);

      canvas.drawOval(
        Rect.fromCenter(center: Offset(currentX, currentY), width: currentWidth, height: currentHeight),
        wispPaint,
      );
    }
  }

  double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  @override
  bool shouldRepaint(covariant _FlameBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Smoke wisp configuration for organic animation
class _SmokeWisp {
  _SmokeWisp(int seed) {
    final random = math.Random(seed * 7919);
    startX = 0.2 + random.nextDouble() * 0.6;
    delay = random.nextDouble();
    width = 0.18 + random.nextDouble() * 0.22;
    height = 0.1 + random.nextDouble() * 0.14;
    baseOpacity = 0.06 + random.nextDouble() * 0.08;
    driftAmount = 0.35 + random.nextDouble() * 0.45;
    speed = 0.18 + random.nextDouble() * 0.22;
    phase = random.nextDouble() * math.pi * 2;
    color = [
      UIConstants.fireOrange,
      UIConstants.fireRed,
      const Color(0xFF8B4513),
    ][random.nextInt(3)];
  }

  late final double startX;
  late final double delay;
  late final double width;
  late final double height;
  late final double baseOpacity;
  late final double driftAmount;
  late final double speed;
  late final double phase;
  late final Color color;
}

// ============================================
// EMBER PARTICLES PAINTER
// ============================================

class _EmberParticlesPainter extends CustomPainter {
  _EmberParticlesPainter({required this.progress});

  final double progress;
  static final List<_Ember> _embers = List.generate(20, (i) => _Ember(i));

  @override
  void paint(Canvas canvas, Size size) {
    for (final ember in _embers) {
      // Calculate position with smooth easing
      final lifeProgress = (progress * ember.speed + ember.delay) % 1.0;

      // Ease out for natural deceleration as it rises
      final easedProgress = 1.0 - math.pow(1.0 - lifeProgress, 2);

      // Start from bottom, rise up
      final startY = size.height + 20;
      final endY = -30.0;
      final currentY = startY + (endY - startY) * easedProgress;

      // Organic horizontal drift
      final drift = math.sin(lifeProgress * math.pi * 3 + ember.phase) * ember.driftAmount * 25;
      final currentX = ember.startX * size.width + drift;

      // Fade in at start, fade out at end
      double opacity = ember.baseOpacity;
      if (lifeProgress < 0.1) {
        opacity *= lifeProgress / 0.1;
      } else if (lifeProgress > 0.7) {
        opacity *= (1.0 - lifeProgress) / 0.3;
      }

      // Scale down as it rises
      final currentSize = ember.size * (1.0 - easedProgress * 0.5);

      if (opacity > 0.01 && currentSize > 0.5) {
        // Outer glow
        final glowPaint = Paint()
          ..color = ember.color.withOpacity((opacity * 0.4).clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentSize * 2);
        canvas.drawCircle(Offset(currentX, currentY), currentSize * 1.5, glowPaint);

        // Main ember body
        final bodyPaint = Paint()
          ..color = ember.color.withOpacity(opacity.clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentSize * 0.3);
        canvas.drawCircle(Offset(currentX, currentY), currentSize, bodyPaint);

        // Hot bright core
        final corePaint = Paint()
          ..color = UIConstants.fireYellow.withOpacity((opacity * 0.9).clamp(0.0, 1.0));
        canvas.drawCircle(Offset(currentX, currentY), currentSize * 0.4, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EmberParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Ember {
  _Ember(int seed) {
    final random = math.Random(seed * 31337);
    startX = 0.1 + random.nextDouble() * 0.8; // Keep away from edges
    delay = random.nextDouble();
    size = 2.0 + random.nextDouble() * 3.0;
    baseOpacity = 0.4 + random.nextDouble() * 0.4;
    driftAmount = 0.3 + random.nextDouble() * 0.7;
    speed = 0.5 + random.nextDouble() * 0.5;
    phase = random.nextDouble() * math.pi * 2;
    color = [
      UIConstants.fireOrange,
      UIConstants.fireYellow,
      UIConstants.fireGlow,
    ][random.nextInt(3)];
  }

  late final double startX;
  late final double delay;
  late final double size;
  late final double baseOpacity;
  late final double driftAmount;
  late final double speed;
  late final double phase;
  late final Color color;
}

// ============================================
// FIRE HEADER
// ============================================

class _FireHeader extends StatelessWidget {
  const _FireHeader({
    required this.username,
    required this.avatarUrl,
    required this.period,
    required this.pulseController,
  });

  final String username;
  final String? avatarUrl;
  final PlaybackPeriod period;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar with fire ring
        AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            return Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    UIConstants.fireOrange,
                    UIConstants.fireYellow,
                    UIConstants.fireRed,
                    UIConstants.fireOrange,
                  ],
                  transform: GradientRotation(pulseController.value * math.pi * 2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: UIConstants.fireOrange.withOpacity(0.4 + pulseController.value * 0.2),
                    blurRadius: 12 + pulseController.value * 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0D0D0D),
                ),
                padding: const EdgeInsets.all(2),
                child: avatarUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _defaultAvatar(),
                        ),
                      )
                    : _defaultAvatar(),
              ),
            );
          },
        ),
        const SizedBox(width: 12),

        // Username & Period
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      UIConstants.fireOrange.withOpacity(0.3),
                      UIConstants.fireRed.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: UIConstants.fireOrange.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  period.shortName,
                  style: TextStyle(
                    color: UIConstants.fireYellow,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),

        // PLAYBACK Logo with fire glow
        AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      UIConstants.fireYellow,
                      UIConstants.fireOrange,
                      UIConstants.fireRed,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'PLAYBACK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: UIConstants.fireOrange.withOpacity(0.6 + pulseController.value * 0.4),
                          blurRadius: 10 + pulseController.value * 5,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: UIConstants.fireOrange,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${DateTime.now().year}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: UIConstants.fireGradient,
        ),
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 24),
    );
  }
}

// ============================================
// FIRE ARCHETYPE BADGE
// ============================================

class _FireArchetypeBadge extends StatelessWidget {
  const _FireArchetypeBadge({
    required this.archetype,
    required this.pulseController,
  });

  final PlayerArchetype archetype;
  final AnimationController pulseController;

  IconData _getArchetypeIcon() {
    switch (archetype) {
      // Tür bazlı
      case PlayerArchetype.strategist:
        return Icons.psychology_rounded;
      case PlayerArchetype.adventurer:
        return Icons.explore_rounded;
      case PlayerArchetype.competitor:
        return Icons.sports_esports_rounded;
      case PlayerArchetype.indieHunter:
        return Icons.brush_rounded;
      case PlayerArchetype.actionJunkie:
        return Icons.flash_on_rounded;
      case PlayerArchetype.horrorMaster:
        return Icons.sentiment_very_dissatisfied_rounded;
      case PlayerArchetype.puzzleGenius:
        return Icons.extension_rounded;
      case PlayerArchetype.sportsFanatic:
        return Icons.sports_soccer_rounded;
      case PlayerArchetype.simGuru:
        return Icons.precision_manufacturing_rounded;
      case PlayerArchetype.retroGamer:
        return Icons.gamepad_rounded;
      case PlayerArchetype.sandboxArchitect:
        return Icons.architecture_rounded;
      case PlayerArchetype.roguelikeExpert:
        return Icons.replay_rounded;
      case PlayerArchetype.mobaWarrior:
        return Icons.shield_rounded;
      // Davranış bazlı
      case PlayerArchetype.completionist:
        return Icons.emoji_events_rounded;
      case PlayerArchetype.storyteller:
        return Icons.auto_stories_rounded;
      case PlayerArchetype.marathoner:
        return Icons.timer_rounded;
      case PlayerArchetype.collector:
        return Icons.collections_rounded;
      case PlayerArchetype.hoarder:
        return Icons.inventory_2_rounded;
      case PlayerArchetype.libraryBaron:
        return Icons.library_books_rounded;
      case PlayerArchetype.grandLibrarian:
        return Icons.account_balance_rounded;
      case PlayerArchetype.speedrunner:
        return Icons.speed_rounded;
      case PlayerArchetype.patientGamer:
        return Icons.hourglass_bottom_rounded;
      case PlayerArchetype.dayOneGamer:
        return Icons.new_releases_rounded;
      case PlayerArchetype.loyalFan:
        return Icons.loyalty_rounded;
      case PlayerArchetype.varietySeeker:
        return Icons.color_lens_rounded;
      case PlayerArchetype.socialGamer:
        return Icons.groups_rounded;
      case PlayerArchetype.soloWolf:
        return Icons.person_rounded;
      case PlayerArchetype.unfinishedBusiness:
        return Icons.pending_actions_rounded;
      case PlayerArchetype.backlogWarrior:
        return Icons.checklist_rounded;
      // Puanlama bazlı
      case PlayerArchetype.harshCritic:
        return Icons.gavel_rounded;
      case PlayerArchetype.positivePlayer:
        return Icons.favorite_rounded;
      case PlayerArchetype.hiddenGemHunter:
        return Icons.diamond_rounded;
      case PlayerArchetype.aaaLover:
        return Icons.star_rounded;
      case PlayerArchetype.underdogSupporter:
        return Icons.thumb_up_rounded;
      case PlayerArchetype.pickyPalate:
        return Icons.wine_bar_rounded;
      case PlayerArchetype.ratingExpert:
        return Icons.analytics_rounded;
      // Platform bazlı
      case PlayerArchetype.multiPlatform:
        return Icons.devices_rounded;
      case PlayerArchetype.steamLoyal:
        return FontAwesomeIcons.steam;
      case PlayerArchetype.playstationFan:
        return FontAwesomeIcons.playstation;
      case PlayerArchetype.pcMasterRace:
        return Icons.computer_rounded;
      case PlayerArchetype.consoleKing:
        return Icons.tv_rounded;
      case PlayerArchetype.riotWarrior:
        return Icons.local_fire_department_rounded;
      // Fallback
      case PlayerArchetype.gamer:
        return Icons.videogame_asset_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                UIConstants.fireRed.withOpacity(0.2),
                UIConstants.fireOrange.withOpacity(0.15),
                UIConstants.fireDarkBg.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: UIConstants.fireOrange.withOpacity(0.4 + pulseController.value * 0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: UIConstants.fireOrange.withOpacity(0.2 + pulseController.value * 0.1),
                blurRadius: 16 + pulseController.value * 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon with fire halo
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 60 + pulseController.value * 4,
                    height: 60 + pulseController.value * 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          UIConstants.fireOrange.withOpacity(0.3),
                          UIConstants.fireRed.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Icon container
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          UIConstants.fireYellow,
                          UIConstants.fireOrange,
                          UIConstants.fireRed,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: UIConstants.fireOrange.withOpacity(0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _getArchetypeIcon(),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Archetype name
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          UIConstants.fireYellow,
                          UIConstants.fireOrange,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        archetype.displayName.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              color: UIConstants.fireOrange.withOpacity(0.8),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Description
                    Text(
                      archetype.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================
// FIRE MAIN STATS
// ============================================

class _FireMainStats extends StatelessWidget {
  const _FireMainStats({required this.stats});

  final PlaybackStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FireStatBox(
            icon: Icons.local_fire_department_rounded,
            value: stats.totalHours.toStringAsFixed(0),
            label: 'SAAT',
            gradient: [UIConstants.fireYellow, UIConstants.fireOrange],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FireStatBox(
            icon: Icons.videogame_asset_rounded,
            value: stats.totalGames.toString(),
            label: 'OYUN',
            gradient: [UIConstants.fireOrange, UIConstants.fireRed],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FireStatBox(
            icon: Icons.military_tech_rounded,
            value: '${stats.completionRate.toStringAsFixed(0)}%',
            label: 'BİTİRME',
            gradient: [UIConstants.fireRed, const Color(0xFFB91C1C)],
          ),
        ),
      ],
    );
  }
}

class _FireStatBox extends StatelessWidget {
  const _FireStatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.gradient,
  });

  final IconData icon;
  final String value;
  final String label;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: gradient[0].withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: gradient[0].withOpacity(0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// FIRE PLATFORM DISTRIBUTION
// ============================================

class _FirePlatformDistribution extends StatelessWidget {
  const _FirePlatformDistribution({
    required this.stats,
    required this.flameController,
  });

  final PlaybackStats stats;
  final AnimationController flameController;

  @override
  Widget build(BuildContext context) {
    final steamPercent = stats.steamPercentage;
    final psnPercent = stats.playstationPercentage;
    final riotPercent = stats.riotPercentage;
    final otherPercent = 100 - steamPercent - psnPercent - riotPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.devices_rounded,
              color: UIConstants.fireOrange,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              'PLATFORM DAĞILIMI',
              style: TextStyle(
                color: UIConstants.fireOrange,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Animated fire progress bar
        AnimatedBuilder(
          animation: flameController,
          builder: (context, child) {
            return Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        if (steamPercent > 0)
                          Expanded(
                            flex: steamPercent.round(),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    UIConstants.fireYellow,
                                    UIConstants.fireYellow.withOpacity(0.7),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (psnPercent > 0)
                          Expanded(
                            flex: psnPercent.round(),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    UIConstants.fireOrange,
                                    UIConstants.fireOrange.withOpacity(0.7),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (riotPercent > 0)
                          Expanded(
                            flex: riotPercent.round(),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    UIConstants.fireRed,
                                    UIConstants.fireRed.withOpacity(0.7),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (otherPercent > 0)
                          Expanded(
                            flex: otherPercent.round(),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    UIConstants.fireDarkBg.withOpacity(0.4),
                                    UIConstants.fireDarkBg.withOpacity(0.2),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Shimmer effect
                    Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.2),
                              Colors.transparent,
                            ],
                            stops: [
                              (flameController.value - 0.2).clamp(0.0, 1.0),
                              flameController.value,
                              (flameController.value + 0.2).clamp(0.0, 1.0),
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcATop,
                        child: Container(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),

        // Labels
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            if (stats.platformStats['steam'] != null)
              _FirePlatformLabel(
                icon: FontAwesomeIcons.steam,
                color: UIConstants.fireYellow,
                label: 'Steam',
                hours: stats.platformStats['steam']!.hours,
              ),
            if (stats.platformStats['playstation'] != null)
              _FirePlatformLabel(
                icon: FontAwesomeIcons.playstation,
                color: UIConstants.fireOrange,
                label: 'PSN',
                hours: stats.platformStats['playstation']!.hours,
              ),
            if (stats.platformStats['riot'] != null)
              _FirePlatformLabel(
                icon: Icons.sports_esports_rounded,
                color: UIConstants.fireRed,
                label: 'Riot',
                hours: stats.platformStats['riot']!.hours,
              ),
          ],
        ),
      ],
    );
  }
}

class _FirePlatformLabel extends StatelessWidget {
  const _FirePlatformLabel({
    required this.icon,
    required this.color,
    required this.label,
    required this.hours,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double hours;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FaIcon(icon, color: color, size: 10),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ${hours.toStringAsFixed(0)}s',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================
// FIRE TOP GENRES
// ============================================

class _FireTopGenres extends StatelessWidget {
  const _FireTopGenres({
    required this.genres,
    required this.totalHours,
  });

  final List<GenreStat> genres;
  final double totalHours;

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();

    final maxHours = genres.first.hours;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.category_rounded,
              color: UIConstants.fireOrange,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              'EN ÇOK OYNANAN TÜRLER',
              style: TextStyle(
                color: UIConstants.fireOrange,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...genres.asMap().entries.map((entry) {
          final index = entry.key;
          final genre = entry.value;
          final percent = maxHours > 0 ? (genre.hours / maxHours) : 0.0;

          final gradients = [
            [UIConstants.fireYellow, UIConstants.fireOrange],
            [UIConstants.fireOrange, UIConstants.fireRed],
            [UIConstants.fireRed, const Color(0xFFB91C1C)],
          ];

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FireGenreBar(
              name: genre.name,
              hours: genre.hours,
              percent: percent,
              gradient: gradients[index % gradients.length],
            ),
          );
        }),
      ],
    );
  }
}

class _FireGenreBar extends StatelessWidget {
  const _FireGenreBar({
    required this.name,
    required this.hours,
    required this.percent,
    required this.gradient,
  });

  final String name;
  final double hours;
  final double percent;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${hours.toStringAsFixed(0)}s',
              style: TextStyle(
                color: gradient[0],
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percent,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================
// FIRE FUN COMPARISON
// ============================================

class _FireFunComparison extends StatelessWidget {
  const _FireFunComparison({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            UIConstants.fireYellow.withOpacity(0.15),
            UIConstants.fireOrange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: UIConstants.fireYellow.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [UIConstants.fireYellow, UIConstants.fireOrange],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: UIConstants.fireYellow,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// FIRE FOOTER
// ============================================

class _FireFooter extends StatelessWidget {
  const _FireFooter({required this.pulseController});

  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: UIConstants.fireOrange.withOpacity(0.5 + pulseController.value * 0.3),
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              'GameLib ile oluşturuldu',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.local_fire_department_rounded,
              color: UIConstants.fireOrange.withOpacity(0.5 + pulseController.value * 0.3),
              size: 14,
            ),
          ],
        );
      },
    );
  }
}

// ============================================
// FIRE HIGHLIGHT ROW (Most Played + Favorite Genre)
// ============================================

class _FireHighlightRow extends StatelessWidget {
  const _FireHighlightRow({required this.stats});

  final PlaybackStats stats;

  @override
  Widget build(BuildContext context) {
    final mostPlayed = stats.mostPlayedGame;
    final topGenre = stats.topGenres.isNotEmpty ? stats.topGenres.first : null;

    return Row(
      children: [
        // Most Played Game
        if (mostPlayed != null)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A0A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: UIConstants.fireYellow.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Game Cover Thumbnail
                  Container(
                    width: 36,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: UIConstants.fireOrange.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: mostPlayed.game.coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: mostPlayed.game.coverUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: UIConstants.fireDarkBg,
                                child: Icon(
                                  Icons.videogame_asset,
                                  color: UIConstants.fireOrange,
                                  size: 18,
                                ),
                              ),
                            )
                          : Container(
                              color: UIConstants.fireDarkBg,
                              child: Icon(
                                Icons.videogame_asset,
                                color: UIConstants.fireOrange,
                                size: 18,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EN ÇOK',
                          style: TextStyle(
                            color: UIConstants.fireYellow.withOpacity(0.8),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mostPlayed.game.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${mostPlayed.playtimeHours.toStringAsFixed(0)} saat',
                          style: TextStyle(
                            color: UIConstants.fireYellow,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (mostPlayed != null && topGenre != null)
          const SizedBox(width: 8),

        // Favorite Genre
        if (topGenre != null)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A0A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: UIConstants.fireOrange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [UIConstants.fireOrange, UIConstants.fireRed],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.category_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FAVORİ TÜR',
                          style: TextStyle(
                            color: UIConstants.fireOrange.withOpacity(0.8),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          topGenre.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${topGenre.gameCount} oyun',
                          style: TextStyle(
                            color: UIConstants.fireOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================
// FIRE EXTRA STATS (Rating + Period Stats)
// ============================================

class _FireExtraStats extends StatelessWidget {
  const _FireExtraStats({required this.stats});

  final PlaybackStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Average Rating
        if (stats.avgRating > 0)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A0A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: UIConstants.fireYellow.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: UIConstants.fireYellow,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stats.avgRating.toStringAsFixed(1),
                          style: TextStyle(
                            color: UIConstants.fireYellow,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'ORT. PUAN',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 6,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (stats.avgRating > 0) const SizedBox(width: 8),

        // New Games This Period
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0A0A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: UIConstants.fireOrange.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_rounded,
                  color: UIConstants.fireOrange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stats.newGamesThisPeriod}',
                        style: TextStyle(
                          color: UIConstants.fireOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _getPeriodLabel(stats.period),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 6,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Dropped or Wishlist count
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0A0A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: UIConstants.fireRed.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  stats.wishlistCount > stats.droppedGamesCount
                      ? Icons.bookmark_rounded
                      : Icons.cancel_rounded,
                  color: stats.wishlistCount > stats.droppedGamesCount
                      ? UIConstants.accentPurple
                      : UIConstants.fireRed,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stats.wishlistCount > stats.droppedGamesCount ? stats.wishlistCount : stats.droppedGamesCount}',
                        style: TextStyle(
                          color: stats.wishlistCount > stats.droppedGamesCount
                              ? UIConstants.accentPurple
                              : UIConstants.fireRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        stats.wishlistCount > stats.droppedGamesCount
                            ? 'İSTEK'
                            : 'BIRAKILAN',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 6,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getPeriodLabel(PlaybackPeriod period) {
    switch (period) {
      case PlaybackPeriod.allTime:
        return 'TOPLAM OYUN';
      case PlaybackPeriod.yearly:
        return 'BU YIL';
      case PlaybackPeriod.monthly:
        return 'BU AY';
    }
  }
}

// ============================================
// ADDITIONAL ARCHETYPES
// ============================================

class _FireAdditionalArchetypes extends StatelessWidget {
  const _FireAdditionalArchetypes({required this.archetypes});

  final List<PlayerArchetype> archetypes;

  IconData _getIconForArchetype(PlayerArchetype archetype) {
    switch (archetype) {
      // Tür bazlı
      case PlayerArchetype.strategist:
        return Icons.psychology_rounded;
      case PlayerArchetype.adventurer:
        return Icons.explore_rounded;
      case PlayerArchetype.competitor:
        return Icons.sports_esports_rounded;
      case PlayerArchetype.indieHunter:
        return Icons.brush_rounded;
      case PlayerArchetype.actionJunkie:
        return Icons.flash_on_rounded;
      case PlayerArchetype.horrorMaster:
        return Icons.sentiment_very_dissatisfied_rounded;
      case PlayerArchetype.puzzleGenius:
        return Icons.extension_rounded;
      case PlayerArchetype.sportsFanatic:
        return Icons.sports_soccer_rounded;
      case PlayerArchetype.simGuru:
        return Icons.precision_manufacturing_rounded;
      case PlayerArchetype.retroGamer:
        return Icons.gamepad_rounded;
      case PlayerArchetype.sandboxArchitect:
        return Icons.architecture_rounded;
      case PlayerArchetype.roguelikeExpert:
        return Icons.replay_rounded;
      case PlayerArchetype.mobaWarrior:
        return Icons.shield_rounded;
      // Davranış bazlı
      case PlayerArchetype.completionist:
        return Icons.emoji_events_rounded;
      case PlayerArchetype.storyteller:
        return Icons.auto_stories_rounded;
      case PlayerArchetype.marathoner:
        return Icons.timer_rounded;
      case PlayerArchetype.collector:
        return Icons.collections_rounded;
      case PlayerArchetype.hoarder:
        return Icons.inventory_2_rounded;
      case PlayerArchetype.libraryBaron:
        return Icons.library_books_rounded;
      case PlayerArchetype.grandLibrarian:
        return Icons.account_balance_rounded;
      case PlayerArchetype.speedrunner:
        return Icons.speed_rounded;
      case PlayerArchetype.patientGamer:
        return Icons.hourglass_bottom_rounded;
      case PlayerArchetype.dayOneGamer:
        return Icons.new_releases_rounded;
      case PlayerArchetype.loyalFan:
        return Icons.loyalty_rounded;
      case PlayerArchetype.varietySeeker:
        return Icons.color_lens_rounded;
      case PlayerArchetype.socialGamer:
        return Icons.groups_rounded;
      case PlayerArchetype.soloWolf:
        return Icons.person_rounded;
      case PlayerArchetype.unfinishedBusiness:
        return Icons.pending_actions_rounded;
      case PlayerArchetype.backlogWarrior:
        return Icons.checklist_rounded;
      // Puanlama bazlı
      case PlayerArchetype.harshCritic:
        return Icons.gavel_rounded;
      case PlayerArchetype.positivePlayer:
        return Icons.favorite_rounded;
      case PlayerArchetype.hiddenGemHunter:
        return Icons.diamond_rounded;
      case PlayerArchetype.aaaLover:
        return Icons.star_rounded;
      case PlayerArchetype.underdogSupporter:
        return Icons.thumb_up_rounded;
      case PlayerArchetype.pickyPalate:
        return Icons.wine_bar_rounded;
      case PlayerArchetype.ratingExpert:
        return Icons.analytics_rounded;
      // Platform bazlı
      case PlayerArchetype.multiPlatform:
        return Icons.devices_rounded;
      case PlayerArchetype.steamLoyal:
        return FontAwesomeIcons.steam;
      case PlayerArchetype.playstationFan:
        return FontAwesomeIcons.playstation;
      case PlayerArchetype.pcMasterRace:
        return Icons.computer_rounded;
      case PlayerArchetype.consoleKing:
        return Icons.tv_rounded;
      case PlayerArchetype.riotWarrior:
        return Icons.local_fire_department_rounded;
      // Fallback
      case PlayerArchetype.gamer:
        return Icons.videogame_asset_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (archetypes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.psychology_rounded,
              color: UIConstants.fireOrange.withOpacity(0.8),
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              'DİĞER ÖZELLİKLERİN',
              style: TextStyle(
                color: UIConstants.fireOrange.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Each archetype as a detailed card
        ...archetypes.asMap().entries.map((entry) {
          final index = entry.key;
          final archetype = entry.value;
          // Alternating subtle color variations
          final isEven = index % 2 == 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isEven ? UIConstants.fireOrange : UIConstants.fireRed)
                        .withOpacity(0.12),
                    (isEven ? UIConstants.fireRed : UIConstants.fireOrange)
                        .withOpacity(0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: UIConstants.fireOrange.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon with glow effect
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          UIConstants.fireYellow.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _getIconForArchetype(archetype),
                        color: UIConstants.fireYellow,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          archetype.displayName,
                          style: TextStyle(
                            color: UIConstants.fireYellow,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          archetype.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ============================================
// TOP 5 MOST PLAYED GAMES
// ============================================

class _FireTopGames extends StatelessWidget {
  const _FireTopGames({required this.games});

  final List<GameLog> games;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) return const SizedBox.shrink();

    // Sadece playtime > 0 olanları göster
    final gamesWithPlaytime = games.where((g) => g.playtimeMinutes > 0).take(5).toList();
    if (gamesWithPlaytime.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: UIConstants.fireYellow,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              'EN ÇOK OYNADIĞIN',
              style: TextStyle(
                color: UIConstants.fireYellow,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...gamesWithPlaytime.asMap().entries.map((entry) {
          final index = entry.key;
          final game = entry.value;
          final hours = game.playtimeHours;

          final colors = [
            UIConstants.fireYellow,
            UIConstants.fireOrange,
            UIConstants.fireRed,
            UIConstants.fireRed.withOpacity(0.8),
            UIConstants.fireRed.withOpacity(0.6),
          ];

          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors[index], colors[index].withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    game.game.name,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${hours.toStringAsFixed(1)}s',
                  style: TextStyle(
                    color: colors[index],
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

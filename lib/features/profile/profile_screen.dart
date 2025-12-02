/// Profile Screen - Fire Theme Edition
///
/// PLAYBACK kartı ile uyumlu ateş temalı profil ekranı.
/// Alev animasyonları, ember efektleri ve ateş renk paleti.

import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/logger.dart';
import '../../core/ui_constants.dart';
import '../../data/friend_repository.dart';
import '../../data/game_repository.dart';
import '../../data/profile_repository.dart';
import '../../data/playstation_library_sync_service.dart';
import '../../data/steam_library_sync_service.dart';
import '../../data/supabase_client.dart';
import '../../data/valorant_service.dart';
import '../../models/game_log.dart';
import '../auth/auth_controller.dart';
import '../friends/friend_search_dialog.dart';
import '../library/library_controller.dart';
import '../playstation_link/playstation_link_dialog.dart';
import '../steam_library/steam_library_provider.dart';
import '../steam_link/steam_link_dialog.dart';
import '../valorant_link/valorant_link_dialog.dart';
import '../playback/playback_screen.dart';
import 'profile_edit_screen.dart';

// Provider for user stats
final userStatsProvider = FutureProvider((ref) async {
  final session = ref.watch(authProvider).valueOrNull;
  if (session == null) return null;

  final repo = ref.read(gameRepositoryProvider);
  return repo.fetchUserStats(session.user.id);
});

// Provider for all badges
final allBadgesProvider = FutureProvider((ref) async {
  final repo = ref.read(gameRepositoryProvider);
  return repo.fetchAllBadges();
});

// Provider for current user's username
final currentUsernameProvider = FutureProvider<String>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return profile?['username'] as String? ?? 'Oyuncu';
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
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
    final session = ref.watch(authProvider).valueOrNull;
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.valueOrNull;
    final username = profile?['username'] as String? ?? 'Oyuncu';
    final steamData = profile?['steam_data'] as Map<String, dynamic>?;
    final steamId = profile?['steam_id'] as String?;
    final steamAvatarUrl = steamData?['profile_image_url'] as String?;
    final steamLibraryAsync = ref.watch(steamLibraryProvider);
    final collection = ref.watch(libraryControllerProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // Layer 1: Animated Flame Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _flameController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ProfileFlameBackgroundPainter(
                    progress: _flameController.value,
                  ),
                );
              },
            ),
          ),

          // Layer 2: Ember Particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _emberController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ProfileEmberPainter(
                    progress: _emberController.value,
                  ),
                );
              },
            ),
          ),

          // Layer 3: Gradient Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0D0D0D).withOpacity(0.5),
                      const Color(0xFF0D0D0D).withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Main Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Fire Profile Header
              SliverToBoxAdapter(
                child: _FireProfileHeader(
                  username: username,
                  avatarUrl: steamAvatarUrl,
                  steamId: steamId,
                  isLoggedIn: session != null,
                  pulseController: _pulseController,
                  flameController: _flameController,
                  onEdit: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                    );
                  },
                ),
              ),

              // Fire Stats Grid
              SliverToBoxAdapter(
                child: _FireStatsGrid(
                  collection: collection,
                  pulseController: _pulseController,
                ),
              ),

              // Most Played Section
              SliverToBoxAdapter(
                child: Builder(builder: (context) {
                  final gamesWithPlaytime = collection
                      .where((g) => g.playtimeMinutes > 0)
                      .toList();
                  if (gamesWithPlaytime.isEmpty) return const SizedBox.shrink();
                  final mostPlayed = gamesWithPlaytime.reduce(
                    (a, b) => a.playtimeMinutes > b.playtimeMinutes ? a : b,
                  );
                  return _FireMostPlayedCard(game: mostPlayed);
                }),
              ),

              // Platform Connections Section
              SliverToBoxAdapter(
                child: _FirePlatformConnectionsSection(
                  steamId: steamId,
                  psnId: profile?['psn_id'] as String?,
                  riotPuuid: profile?['riot_puuid'] as String?,
                  steamLibraryAsync: steamLibraryAsync,
                ),
              ),

              // Friends Section
              if (session != null)
                SliverToBoxAdapter(
                  child: _FireFriendsSection(),
                ),

              // Logout Button
              if (session != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: _FireLogoutButton(ref: ref),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================
// FLAME BACKGROUND PAINTER
// ============================================

class _ProfileFlameBackgroundPainter extends CustomPainter {
  _ProfileFlameBackgroundPainter({required this.progress});

  final double progress;

  // Organic smoke wisps
  static final List<_ProfileSmokeWisp> _wisps = List.generate(7, (i) => _ProfileSmokeWisp(i));

  @override
  void paint(Canvas canvas, Size size) {
    final pulseIntensity = 0.22 + 0.1 * math.sin(progress * math.pi * 2);

    // Layer 1: Deep ambient warmth from bottom
    final ambientPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 1.4),
        radius: 1.3,
        colors: [
          UIConstants.fireRed.withOpacity(pulseIntensity * 0.45),
          UIConstants.fireOrange.withOpacity(pulseIntensity * 0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), ambientPaint);

    // Layer 2: Soft core glow
    final corePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 1.8),
        radius: 0.6,
        colors: [
          UIConstants.fireYellow.withOpacity(pulseIntensity * 0.3),
          UIConstants.fireOrange.withOpacity(pulseIntensity * 0.12),
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
        radius: 1.15,
        colors: [
          Colors.transparent,
          Colors.transparent,
          UIConstants.fireDarkBg.withOpacity(0.28),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
  }

  void _drawSmokeWisp(Canvas canvas, Size size, _ProfileSmokeWisp wisp, double time) {
    final wispProgress = (time * wisp.speed + wisp.delay) % 1.0;
    final easedProgress = _smoothstep(0.0, 1.0, wispProgress);

    final startY = size.height * 1.08;
    final endY = size.height * -0.18;
    final currentY = startY + (endY - startY) * easedProgress;

    // Organic drift with layered sine waves
    final drift1 = math.sin(wispProgress * math.pi * 2.2 + wisp.phase) * wisp.driftAmount;
    final drift2 = math.sin(wispProgress * math.pi * 4.5 + wisp.phase * 1.6) * wisp.driftAmount * 0.28;
    final totalDrift = (drift1 + drift2) * size.width * 0.14;
    final currentX = wisp.startX * size.width + totalDrift;

    // Smooth opacity lifecycle
    double opacity = wisp.baseOpacity;
    if (wispProgress < 0.14) {
      opacity *= _smoothstep(0.0, 0.14, wispProgress);
    } else if (wispProgress > 0.58) {
      opacity *= 1.0 - _smoothstep(0.58, 1.0, wispProgress);
    }

    // Dynamic size - expand then dissipate
    final sizeMultiplier = 1.0 + math.sin(wispProgress * math.pi) * 0.55;
    final currentWidth = wisp.width * sizeMultiplier * size.width;
    final currentHeight = wisp.height * sizeMultiplier * size.height;

    if (opacity > 0.006) {
      final wispPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.5,
          colors: [
            wisp.color.withOpacity((opacity * 0.65).clamp(0.0, 1.0)),
            wisp.color.withOpacity((opacity * 0.32).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
          stops: const [0.0, 0.38, 1.0],
        ).createShader(
          Rect.fromCenter(center: Offset(currentX, currentY), width: currentWidth, height: currentHeight),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentWidth * 0.28);

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
  bool shouldRepaint(covariant _ProfileFlameBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Smoke wisp configuration for profile screen
class _ProfileSmokeWisp {
  _ProfileSmokeWisp(int seed) {
    final random = math.Random(seed * 8123);
    startX = 0.18 + random.nextDouble() * 0.64;
    delay = random.nextDouble();
    width = 0.16 + random.nextDouble() * 0.2;
    height = 0.09 + random.nextDouble() * 0.12;
    baseOpacity = 0.05 + random.nextDouble() * 0.07;
    driftAmount = 0.32 + random.nextDouble() * 0.48;
    speed = 0.16 + random.nextDouble() * 0.2;
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

class _ProfileEmberPainter extends CustomPainter {
  _ProfileEmberPainter({required this.progress});

  final double progress;
  static final List<_ProfileEmber> _embers = List.generate(15, (i) => _ProfileEmber(i));

  @override
  void paint(Canvas canvas, Size size) {
    for (final ember in _embers) {
      final lifeProgress = (progress * ember.speed + ember.delay) % 1.0;
      final easedProgress = 1.0 - math.pow(1.0 - lifeProgress, 2);

      final startY = size.height + 20;
      final endY = -30.0;
      final currentY = startY + (endY - startY) * easedProgress;

      final drift = math.sin(lifeProgress * math.pi * 3 + ember.phase) * ember.driftAmount * 25;
      final currentX = ember.startX * size.width + drift;

      double opacity = ember.baseOpacity;
      if (lifeProgress < 0.1) {
        opacity *= lifeProgress / 0.1;
      } else if (lifeProgress > 0.7) {
        opacity *= (1.0 - lifeProgress) / 0.3;
      }

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
  bool shouldRepaint(covariant _ProfileEmberPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ProfileEmber {
  _ProfileEmber(int seed) {
    final random = math.Random(seed * 31337);
    startX = 0.1 + random.nextDouble() * 0.8;
    delay = random.nextDouble();
    size = 2.0 + random.nextDouble() * 2.5;
    baseOpacity = 0.3 + random.nextDouble() * 0.4;
    driftAmount = 0.3 + random.nextDouble() * 0.7;
    speed = 0.4 + random.nextDouble() * 0.4;
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
// FIRE PROFILE HEADER
// ============================================

class _FireProfileHeader extends StatelessWidget {
  const _FireProfileHeader({
    required this.username,
    required this.avatarUrl,
    required this.steamId,
    required this.isLoggedIn,
    required this.pulseController,
    required this.flameController,
    required this.onEdit,
  });

  final String username;
  final String? avatarUrl;
  final String? steamId;
  final bool isLoggedIn;
  final AnimationController pulseController;
  final AnimationController flameController;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title with fire accent bar
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 4,
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    UIConstants.fireYellow,
                                    Color.lerp(
                                      UIConstants.fireOrange,
                                      UIConstants.fireRed,
                                      pulseController.value,
                                    )!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: UIConstants.fireOrange.withOpacity(0.5 + pulseController.value * 0.3),
                                    blurRadius: 8 + pulseController.value * 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              UIConstants.fireYellow,
                              UIConstants.fireOrange,
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'PROFİL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Action buttons
                    if (isLoggedIn)
                      Row(
                        children: [
                          // PLAYBACK button with fire effect
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PlaybackScreen(),
                                  fullscreenDialog: true,
                                ),
                              );
                            },
                            child: AnimatedBuilder(
                              animation: pulseController,
                              builder: (context, child) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        UIConstants.fireOrange.withOpacity(0.4),
                                        UIConstants.fireRed.withOpacity(0.3),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: UIConstants.fireOrange.withOpacity(0.4 + pulseController.value * 0.2),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: UIConstants.fireOrange.withOpacity(0.3 + pulseController.value * 0.2),
                                        blurRadius: 12 + pulseController.value * 8,
                                        spreadRadius: -2,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        color: UIConstants.fireYellow,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      ShaderMask(
                                        shaderCallback: (bounds) => LinearGradient(
                                          colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                                        ).createShader(bounds),
                                        child: const Text(
                                          'PLAYBACK',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Edit button
                          GestureDetector(
                            onTap: onEdit,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: UIConstants.fireOrange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: UIConstants.fireOrange.withOpacity(0.3),
                                ),
                              ),
                              child: Icon(
                                Icons.edit_rounded,
                                color: UIConstants.fireOrange,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const Spacer(),

              // Avatar and username
              Row(
                children: [
                  // Animated Avatar with fire ring
                  AnimatedBuilder(
                    animation: flameController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer rotating fire ring
                          Transform.rotate(
                            angle: flameController.value * math.pi * 2,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    UIConstants.fireYellow.withOpacity(0.8),
                                    UIConstants.fireOrange.withOpacity(0.8),
                                    UIConstants.fireRed.withOpacity(0.8),
                                    UIConstants.fireOrange.withOpacity(0.8),
                                    UIConstants.fireYellow.withOpacity(0.8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Inner counter-rotating ring
                          Transform.rotate(
                            angle: -flameController.value * math.pi * 2 * 0.5,
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: UIConstants.fireOrange.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                          // Glow effect
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: UIConstants.fireOrange.withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          // Avatar container
                          Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF0D0D0D),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: ClipOval(
                              child: avatarUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => _defaultAvatar(),
                                    )
                                  : _defaultAvatar(),
                            ),
                          ),
                          // Online indicator with fire glow
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: AnimatedBuilder(
                              animation: pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF0D0D0D),
                                    border: Border.all(color: const Color(0xFF0D0D0D), width: 3),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: UIConstants.fireOrange.withOpacity(0.5 + pulseController.value * 0.3),
                                          blurRadius: 6 + pulseController.value * 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(width: 20),

                  // Username and badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Platform connection icons
                        Row(
                          children: [
                            _FirePlatformIcon(
                              icon: FontAwesomeIcons.steam,
                              isConnected: steamId != null,
                              activeColor: UIConstants.fireOrange,
                              pulseController: pulseController,
                            ),
                            const SizedBox(width: 6),
                            Consumer(
                              builder: (context, ref, child) {
                                final psnId = ref.watch(currentProfileProvider).valueOrNull?['psn_id'] as String?;
                                return _FirePlatformIcon(
                                  icon: FontAwesomeIcons.playstation,
                                  isConnected: psnId != null,
                                  activeColor: UIConstants.fireOrange,
                                  pulseController: pulseController,
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            Consumer(
                              builder: (context, ref, child) {
                                final riotPuuid = ref.watch(currentProfileProvider).valueOrNull?['riot_puuid'] as String?;
                                return _FirePlatformIcon(
                                  icon: FontAwesomeIcons.gamepad,
                                  isConnected: riotPuuid != null,
                                  activeColor: UIConstants.fireOrange,
                                  pulseController: pulseController,
                                  useValorantIcon: true,
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            _FirePlatformIcon(
                              icon: FontAwesomeIcons.gamepad,
                              isConnected: false,
                              activeColor: UIConstants.fireOrange,
                              pulseController: pulseController,
                              useEpicIcon: true,
                            ),
                            const SizedBox(width: 6),
                            _FirePlatformIcon(
                              icon: FontAwesomeIcons.xbox,
                              isConnected: false,
                              activeColor: UIConstants.fireOrange,
                              pulseController: pulseController,
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Username with fire glow effect
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFFFF7ED), Colors.white],
                          ).createShader(bounds),
                          child: Text(
                            username,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              shadows: [
                                Shadow(
                                  color: UIConstants.fireOrange.withOpacity(0.5),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Status badge with fire theme
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                UIConstants.fireOrange.withOpacity(0.2),
                                UIConstants.fireYellow.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: UIConstants.fireOrange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: UIConstants.fireOrange.withOpacity(0.5),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Çevrimiçi',
                                style: TextStyle(
                                  color: UIConstants.fireYellow,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 800.ms);
  }

  Widget _defaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: UIConstants.fireGradient,
        ),
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 44),
    );
  }
}

// ============================================
// FIRE PLATFORM ICON
// ============================================

class _FirePlatformIcon extends StatelessWidget {
  const _FirePlatformIcon({
    required this.icon,
    required this.isConnected,
    required this.activeColor,
    required this.pulseController,
    this.useValorantIcon = false,
    this.useEpicIcon = false,
  });

  final IconData icon;
  final bool isConnected;
  final Color activeColor;
  final AnimationController pulseController;
  final bool useValorantIcon;
  final bool useEpicIcon;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final glowIntensity = isConnected ? 0.3 + pulseController.value * 0.2 : 0.0;
        final iconColor = isConnected ? activeColor : Colors.white.withOpacity(0.25);

        Widget iconWidget;
        if (useValorantIcon) {
          iconWidget = CustomPaint(
            size: const Size(12, 12),
            painter: _ValorantLogoPainter(color: iconColor),
          );
        } else if (useEpicIcon) {
          iconWidget = CustomPaint(
            size: const Size(12, 12),
            painter: _EpicLogoPainter(color: iconColor),
          );
        } else {
          iconWidget = FaIcon(icon, size: 12, color: iconColor);
        }

        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: isConnected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      activeColor.withOpacity(0.25),
                      activeColor.withOpacity(0.12),
                    ],
                  )
                : null,
            color: isConnected ? null : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isConnected
                  ? activeColor.withOpacity(0.4)
                  : Colors.white.withOpacity(0.08),
              width: 1,
            ),
            boxShadow: isConnected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(glowIntensity),
                      blurRadius: 8 + pulseController.value * 4,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Center(child: iconWidget),
        );
      },
    );
  }
}

// ============================================
// FIRE STATS GRID
// ============================================

class _FireStatsGrid extends ConsumerWidget {
  const _FireStatsGrid({
    required this.collection,
    required this.pulseController,
  });

  final List<GameLog> collection;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combinedAsync = ref.watch(combinedLibraryProvider);

    return combinedAsync.when(
      data: (combinedGames) {
        final stats = ref.watch(libraryStatsProvider);
        final totalGames = stats.gameCount;
        final totalHours = stats.totalHours.round();
        final ratingCount = combinedGames.where((e) => e.log.rating != null).length;
        final achievements = (stats.totalHours * 0.2).round();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _FireStatCard(
                      value: totalGames.toString(),
                      label: 'Oyun',
                      icon: Icons.sports_esports_rounded,
                      gradientColors: [UIConstants.fireYellow, UIConstants.fireOrange],
                      delay: 0,
                      pulseController: pulseController,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FireStatCard(
                      value: _formatHours(totalHours),
                      label: 'Saat',
                      icon: Icons.local_fire_department_rounded,
                      gradientColors: [UIConstants.fireOrange, UIConstants.fireRed],
                      delay: 100,
                      pulseController: pulseController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _FireStatCard(
                      value: ratingCount.toString(),
                      label: 'Değerlendirme',
                      icon: Icons.star_rounded,
                      gradientColors: [UIConstants.fireGlow, UIConstants.fireYellow],
                      delay: 200,
                      pulseController: pulseController,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FireStatCard(
                      value: achievements.toString(),
                      label: 'Başarım',
                      icon: Icons.emoji_events_rounded,
                      gradientColors: [UIConstants.fireRed, const Color(0xFFB91C1C)],
                      delay: 300,
                      pulseController: pulseController,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Center(child: CircularProgressIndicator(color: UIConstants.fireOrange)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _formatHours(int hours) {
    if (hours >= 1000) {
      return '${(hours / 1000).toStringAsFixed(1)}K';
    }
    return hours.toString();
  }
}

class _FireStatCard extends StatelessWidget {
  const _FireStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.gradientColors,
    required this.delay,
    required this.pulseController,
  });

  final String value;
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final int delay;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradientColors[0].withOpacity(0.15),
                gradientColors[1].withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: gradientColors[0].withOpacity(0.3 + pulseController.value * 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 16),
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
                      color: gradientColors[0].withOpacity(0.5),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn(
      delay: Duration(milliseconds: delay),
      duration: 500.ms,
    ).slideY(begin: 0.1, end: 0);
  }
}

// ============================================
// FIRE MOST PLAYED CARD
// ============================================

class _FireMostPlayedCard extends StatelessWidget {
  const _FireMostPlayedCard({required this.game});

  final GameLog game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              UIConstants.fireOrange.withOpacity(0.15),
              UIConstants.fireRed.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: UIConstants.fireOrange.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: UIConstants.fireOrange.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Subtle background glow
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      UIConstants.fireOrange.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Game cover with fire glow
                  Container(
                    width: 60,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: UIConstants.fireOrange.withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: game.game.coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: game.game.coverUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _defaultCover(),
                            )
                          : _defaultCover(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Game info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge with fire gradient
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: UIConstants.fireOrange.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: const Text(
                            'EN ÇOK OYNANAN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Game name
                        Text(
                          game.game.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Playtime with fire icon
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    UIConstants.fireYellow.withOpacity(0.2),
                                    UIConstants.fireOrange.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.local_fire_department_rounded,
                                size: 12,
                                color: UIConstants.fireYellow,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${game.playtimeHours.toStringAsFixed(1)} saat',
                              style: TextStyle(
                                color: UIConstants.fireYellow,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: 400.ms, duration: 500.ms)
        .slideY(begin: 0.08, end: 0);
  }

  Widget _defaultCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: UIConstants.fireGradient,
        ),
      ),
      child: const Icon(
        Icons.sports_esports_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

// ============================================
// FIRE PLATFORM CONNECTIONS SECTION
// ============================================

class _FirePlatformConnectionsSection extends ConsumerWidget {
  const _FirePlatformConnectionsSection({
    required this.steamId,
    required this.psnId,
    required this.riotPuuid,
    required this.steamLibraryAsync,
  });

  final String? steamId;
  final String? psnId;
  final String? riotPuuid;
  final AsyncValue<List<GameLog>> steamLibraryAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with fire gradient line
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                  ),
                  borderRadius: BorderRadius.circular(1.5),
                  boxShadow: [
                    BoxShadow(
                      color: UIConstants.fireOrange.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                ).createShader(bounds),
                child: Text(
                  'PLATFORMLAR',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Platform cards
          _FirePlatformCard(
            icon: FontAwesomeIcons.steam,
            name: 'Steam',
            isConnected: steamId != null,
            activeColor: UIConstants.fireOrange,
            onConnect: () => showSteamLinkDialog(context),
            onSync: steamId != null ? () => _syncSteam(context, ref, steamId!) : null,
          ),
          const SizedBox(height: 8),
          _FirePlatformCard(
            icon: FontAwesomeIcons.playstation,
            name: 'PlayStation',
            isConnected: psnId != null,
            activeColor: UIConstants.fireOrange,
            onConnect: () => showPlayStationLinkDialog(context),
            onSync: psnId != null ? () => _syncPlayStation(context, ref) : null,
          ),
          const SizedBox(height: 8),
          _FirePlatformCard(
            icon: FontAwesomeIcons.gamepad,
            name: 'Valorant',
            isConnected: riotPuuid != null,
            activeColor: UIConstants.fireOrange,
            onConnect: () => showValorantLinkDialog(context),
            onSync: riotPuuid != null ? () => _syncValorant(context, ref) : null,
            useValorantIcon: true,
          ),
          const SizedBox(height: 8),
          _FirePlatformCard(
            icon: FontAwesomeIcons.gamepad,
            name: 'Epic Games',
            isConnected: false,
            activeColor: UIConstants.fireOrange,
            isComingSoon: true,
            useEpicIcon: true,
          ),
          const SizedBox(height: 8),
          _FirePlatformCard(
            icon: FontAwesomeIcons.xbox,
            name: 'Xbox',
            isConnected: false,
            activeColor: UIConstants.fireOrange,
            isComingSoon: true,
          ),
        ],
      ),
    ).animate()
        .fadeIn(delay: 500.ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Future<void> _syncSteam(BuildContext context, WidgetRef ref, String steamId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Row(
          children: [
            CircularProgressIndicator(color: UIConstants.fireOrange),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Steam kütüphanesi senkronize ediliyor...',
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final userId = ref.read(supabaseProvider).auth.currentUser?.id;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      appLogger.info('Profile: Starting manual Steam library sync');
      final syncService = ref.read(steamLibrarySyncServiceProvider);
      final result = await syncService.syncFullLibrary(userId, steamId);

      ref.invalidate(steamLibraryProvider);
      ref.invalidate(libraryControllerProvider);
      ref.invalidate(currentProfileProvider);

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.imported + result.updated} oyun senkronize edildi!'),
            backgroundColor: UIConstants.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e, stack) {
      appLogger.error('Profile: Failed to sync Steam library', e, stack);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: UIConstants.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _syncPlayStation(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Row(
          children: [
            CircularProgressIndicator(color: UIConstants.fireOrange),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'PlayStation kütüphanesi senkronize ediliyor...',
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final userId = ref.read(supabaseProvider).auth.currentUser?.id;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      final profile = ref.read(currentProfileProvider).valueOrNull;
      final accessToken = profile?['psn_access_token'] as String?;
      final refreshToken = profile?['psn_refresh_token'] as String?;

      if (accessToken == null || refreshToken == null) {
        throw Exception('PlayStation token bulunamadı');
      }

      appLogger.info('Profile: Starting manual PlayStation library sync');
      final syncService = ref.read(playstationLibrarySyncServiceProvider);
      final result = await syncService.syncFullLibrary(userId, accessToken, refreshToken);

      ref.invalidate(playstationLibraryProvider);
      ref.invalidate(steamLibraryProvider);
      ref.invalidate(libraryControllerProvider);
      ref.invalidate(currentProfileProvider);

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.imported + result.updated} oyun senkronize edildi!'),
            backgroundColor: UIConstants.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e, stack) {
      appLogger.error('Profile: Failed to sync PlayStation library', e, stack);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: UIConstants.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _syncValorant(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Row(
          children: [
            CircularProgressIndicator(color: UIConstants.fireOrange),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Valorant istatistikleri güncelleniyor...',
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final userId = ref.read(supabaseProvider).auth.currentUser?.id;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      final profile = ref.read(currentProfileProvider).valueOrNull;
      final riotId = profile?['riot_id'] as String?;
      final riotRegion = profile?['riot_region'] as String? ?? 'eu';

      if (riotId == null) {
        throw Exception('Riot ID bulunamadı');
      }

      // Parse name and tag from riot_id (format: "Name#TAG")
      final parts = riotId.split('#');
      if (parts.length != 2) {
        throw Exception('Geçersiz Riot ID formatı');
      }
      final name = parts[0];
      final tag = parts[1];

      appLogger.info('Profile: Starting manual Valorant sync for $name#$tag');
      final valorantService = ref.read(valorantServiceProvider);

      // Fetch fresh profile data from Henrik API
      final valorantProfile = await valorantService.getFullProfile(name, tag, region: riotRegion);

      if (valorantProfile == null) {
        throw Exception('Valorant profili bulunamadı');
      }

      // Calculate playtime from account level
      final accountLevel = valorantProfile.account.accountLevel ?? 0;
      final playtimeMinutes = valorantService.calculatePlaytimeFromLevel(accountLevel);

      // Update profile with fresh data
      await ref.read(supabaseProvider).from('profiles').update({
        'riot_data': valorantProfile.toJson(),
      }).eq('id', userId);

      // Update Valorant game_log entry if exists
      const valorantIgdbId = 126459;

      // Check if Valorant entry exists
      final existingLogs = await ref.read(supabaseProvider)
          .from('game_logs')
          .select()
          .eq('user_id', userId)
          .eq('game_id', valorantIgdbId)
          .limit(1);

      if ((existingLogs as List).isNotEmpty) {
        // Update existing entry
        await ref.read(supabaseProvider).from('game_logs').update({
          'playtime_minutes': playtimeMinutes,
          'riot_ranked_data': valorantProfile.mmr?.toJson(),
          'last_synced_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId).eq('game_id', valorantIgdbId);
        appLogger.info('Profile: Updated Valorant game_log with $playtimeMinutes minutes');
      }

      // Invalidate providers to refresh UI
      ref.invalidate(riotLibraryProvider);
      ref.invalidate(combinedLibraryProvider);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(valorantProfileProvider);

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Valorant istatistikleri güncellendi! (${(playtimeMinutes / 60).toStringAsFixed(1)} saat)'),
            backgroundColor: UIConstants.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e, stack) {
      appLogger.error('Profile: Failed to sync Valorant', e, stack);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: UIConstants.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

class _FirePlatformCard extends StatelessWidget {
  const _FirePlatformCard({
    required this.icon,
    required this.name,
    required this.isConnected,
    required this.activeColor,
    this.onConnect,
    this.onSync,
    this.isComingSoon = false,
    this.useValorantIcon = false,
    this.useEpicIcon = false,
  });

  final IconData icon;
  final String name;
  final bool isConnected;
  final Color activeColor;
  final VoidCallback? onConnect;
  final VoidCallback? onSync;
  final bool isComingSoon;
  final bool useValorantIcon;
  final bool useEpicIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isConnected
              ? [
                  activeColor.withOpacity(0.15),
                  activeColor.withOpacity(0.08),
                ]
              : [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.03),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected
              ? activeColor.withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: isConnected
            ? [
                BoxShadow(
                  color: activeColor.withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Platform icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: isConnected
                  ? LinearGradient(
                      colors: [
                        activeColor.withOpacity(0.3),
                        activeColor.withOpacity(0.15),
                      ],
                    )
                  : null,
              color: isConnected ? null : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: isConnected
                  ? Border.all(color: activeColor.withOpacity(0.3))
                  : null,
              boxShadow: isConnected
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Center(child: _buildPlatformIcon()),
          ),
          const SizedBox(width: 12),

          // Platform info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isConnected ? Colors.white : Colors.white.withOpacity(0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isConnected) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: UIConstants.fireOrange.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      isComingSoon
                          ? 'Yakında'
                          : isConnected
                              ? 'Bağlı'
                              : 'Bağlı değil',
                      style: TextStyle(
                        color: isComingSoon
                            ? UIConstants.fireYellow
                            : isConnected
                                ? UIConstants.fireOrange
                                : Colors.white.withOpacity(0.3),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action button
          if (!isComingSoon)
            GestureDetector(
              onTap: isConnected ? onSync : onConnect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isConnected
                      ? null
                      : LinearGradient(colors: [activeColor, activeColor.withOpacity(0.8)]),
                  color: isConnected ? activeColor.withOpacity(0.15) : null,
                  borderRadius: BorderRadius.circular(8),
                  border: isConnected
                      ? Border.all(color: activeColor.withOpacity(0.3))
                      : null,
                  boxShadow: isConnected
                      ? null
                      : [
                          BoxShadow(
                            color: activeColor.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: -2,
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.sync_rounded : Icons.link_rounded,
                      size: 14,
                      color: isConnected ? activeColor : Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? 'Sync' : 'Bağla',
                      style: TextStyle(
                        color: isConnected ? activeColor : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: UIConstants.fireYellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: UIConstants.fireYellow.withOpacity(0.2)),
              ),
              child: Text(
                'Yakında',
                style: TextStyle(
                  color: UIConstants.fireYellow,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlatformIcon() {
    final iconColor = isConnected ? activeColor : Colors.white.withOpacity(0.25);

    if (useValorantIcon) {
      return CustomPaint(
        size: const Size(18, 18),
        painter: _ValorantLogoPainter(color: iconColor),
      );
    } else if (useEpicIcon) {
      return CustomPaint(
        size: const Size(18, 18),
        painter: _EpicLogoPainter(color: iconColor),
      );
    } else {
      return FaIcon(icon, size: 18, color: iconColor);
    }
  }
}

// ============================================
// FIRE FRIENDS SECTION
// ============================================

class _FireFriendsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);
    final pendingAsync = ref.watch(pendingRequestsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [UIConstants.fireOrange, UIConstants.fireRed],
                      ),
                      borderRadius: BorderRadius.circular(1.5),
                      boxShadow: [
                        BoxShadow(
                          color: UIConstants.fireOrange.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [UIConstants.fireOrange, UIConstants.fireRed],
                    ).createShader(bounds),
                    child: Text(
                      'ARKADAŞLAR',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => const FriendSearchDialog(),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [UIConstants.fireOrange, UIConstants.fireRed],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: UIConstants.fireOrange.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Ekle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Pending requests
          pendingAsync.when(
            data: (requests) {
              if (requests.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  ...requests.map((req) => _FirePendingRequestCard(request: req)),
                  const SizedBox(height: 12),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Friends list
          friendsAsync.when(
            data: (friends) {
              if (friends.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        UIConstants.fireOrange.withOpacity(0.08),
                        UIConstants.fireRed.withOpacity(0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: UIConstants.fireOrange.withOpacity(0.15)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 36,
                          color: UIConstants.fireOrange.withOpacity(0.3),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Henüz arkadaş yok',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: friends.map((f) => _FireFriendCard(friend: f)).toList(),
              );
            },
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(color: UIConstants.fireOrange, strokeWidth: 2),
              ),
            ),
            error: (e, _) => Center(
              child: Text(
                'Yüklenemedi: $e',
                style: TextStyle(color: UIConstants.fireRed, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ).animate()
        .fadeIn(delay: 600.ms, duration: 400.ms)
        .slideY(begin: 0.08, end: 0);
  }
}

class _FirePendingRequestCard extends ConsumerWidget {
  const _FirePendingRequestCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = request['username'] as String;
    final userId = request['user_id'] as String;
    final friendshipId = request['friendship_id'] as String;

    Future<void> acceptRequest() async {
      try {
        final repo = ref.read(friendRepositoryProvider);
        await repo.acceptFriendRequest(friendshipId, userId);
        ref.invalidate(friendsListProvider);
        ref.invalidate(pendingRequestsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$username arkadaş olarak eklendi!'),
              backgroundColor: UIConstants.accentGreen,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: UIConstants.accentRed),
          );
        }
      }
    }

    Future<void> rejectRequest() async {
      try {
        final repo = ref.read(friendRepositoryProvider);
        await repo.rejectFriendRequest(friendshipId);
        ref.invalidate(pendingRequestsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: UIConstants.accentRed),
          );
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            UIConstants.fireYellow.withOpacity(0.12),
            UIConstants.fireOrange.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UIConstants.fireYellow.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  UIConstants.fireYellow.withOpacity(0.3),
                  UIConstants.fireOrange.withOpacity(0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(Icons.person_rounded, color: UIConstants.fireYellow, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              username,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: acceptRequest,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [UIConstants.accentGreen.withOpacity(0.3), UIConstants.accentGreen.withOpacity(0.2)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.check_rounded, size: 14, color: UIConstants.accentGreen),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: rejectRequest,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.close_rounded, size: 14, color: Colors.white.withOpacity(0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FireFriendCard extends ConsumerWidget {
  const _FireFriendCard({required this.friend});

  final Map<String, dynamic> friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = friend['username'] as String;
    final friendId = friend['id'] as String;

    Future<void> removeFriend() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A0A0A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Arkadaşlıktan Çıkar', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Text(
            '$username arkadaş listenden çıkarılacak.',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal', style: TextStyle(fontSize: 13)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: UIConstants.fireRed),
              child: const Text('Çıkar', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      try {
        final repo = ref.read(friendRepositoryProvider);
        await repo.removeFriend(friendId);
        ref.invalidate(friendsListProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: UIConstants.accentRed),
          );
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            UIConstants.fireOrange.withOpacity(0.08),
            UIConstants.fireRed.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UIConstants.fireOrange.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  UIConstants.fireOrange.withOpacity(0.3),
                  UIConstants.fireRed.withOpacity(0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(Icons.person_rounded, color: UIConstants.fireOrange, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              username,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: removeFriend,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.person_remove_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// FIRE LOGOUT BUTTON
// ============================================

class _FireLogoutButton extends StatelessWidget {
  const _FireLogoutButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ref.read(authControllerProvider.notifier).signOut(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              UIConstants.fireRed.withOpacity(0.15),
              UIConstants.fireRed.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UIConstants.fireRed.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, size: 16, color: UIConstants.fireRed.withOpacity(0.8)),
            const SizedBox(width: 8),
            Text(
              'Çıkış Yap',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: UIConstants.fireRed.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 700.ms, duration: 400.ms);
  }
}

// ============================================
// CUSTOM PAINTERS FOR PLATFORM LOGOS
// ============================================

class _ValorantLogoPainter extends CustomPainter {
  _ValorantLogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    final path1 = Path();
    path1.moveTo(23.792 * scaleX, 2.152 * scaleY);
    path1.cubicTo(23.752 * scaleX, 2.182 * scaleY, 23.712 * scaleX, 2.212 * scaleY, 23.694 * scaleX, 2.235 * scaleY);
    path1.cubicTo(20.31 * scaleX, 6.465 * scaleY, 16.925 * scaleX, 10.695 * scaleY, 13.544 * scaleX, 14.925 * scaleY);
    path1.cubicTo(13.437 * scaleX, 15.018 * scaleY, 13.519 * scaleX, 15.213 * scaleY, 13.663 * scaleX, 15.19 * scaleY);
    path1.cubicTo(16.102 * scaleX, 15.193 * scaleY, 18.54 * scaleX, 15.19 * scaleY, 20.979 * scaleX, 15.191 * scaleY);
    path1.cubicTo(21.212 * scaleX, 15.191 * scaleY, 21.427 * scaleX, 15.08 * scaleY, 21.531 * scaleX, 14.941 * scaleY);
    path1.cubicTo(22.305 * scaleX, 13.974 * scaleY, 23.081 * scaleX, 13.007 * scaleY, 23.855 * scaleX, 12.038 * scaleY);
    path1.cubicTo(23.931 * scaleX, 11.87 * scaleY, 23.999 * scaleX, 11.69 * scaleY, 23.999 * scaleX, 11.548 * scaleY);
    path1.lineTo(23.999 * scaleX, 2.318 * scaleY);
    path1.cubicTo(24.015 * scaleX, 2.208 * scaleY, 23.899 * scaleX, 2.112 * scaleY, 23.795 * scaleX, 2.151 * scaleY);
    path1.close();

    final path2 = Path();
    path2.moveTo(0.077 * scaleX, 2.166 * scaleY);
    path2.cubicTo(0.0 * scaleX, 2.204 * scaleY, 0.003 * scaleX, 2.298 * scaleY, 0.001 * scaleX, 2.371 * scaleY);
    path2.lineTo(0.001 * scaleX, 11.596 * scaleY);
    path2.cubicTo(0.001 * scaleX, 11.776 * scaleY, 0.06 * scaleX, 11.916 * scaleY, 0.159 * scaleX, 12.059 * scaleY);
    path2.lineTo(7.799 * scaleX, 21.609 * scaleY);
    path2.cubicTo(7.919 * scaleX, 21.761 * scaleY, 8.107 * scaleX, 21.859 * scaleY, 8.304 * scaleX, 21.856 * scaleY);
    path2.lineTo(15.669 * scaleX, 21.856 * scaleY);
    path2.cubicTo(15.811 * scaleX, 21.876 * scaleY, 15.891 * scaleX, 21.682 * scaleY, 15.785 * scaleX, 21.591 * scaleY);
    path2.cubicTo(10.661 * scaleX, 15.176 * scaleY, 5.526 * scaleX, 8.766 * scaleY, 0.4 * scaleX, 2.35 * scaleY);
    path2.cubicTo(0.32 * scaleX, 2.256 * scaleY, 0.226 * scaleX, 2.078 * scaleY, 0.078 * scaleX, 2.166 * scaleY);
    path2.close();

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _ValorantLogoPainter oldDelegate) => oldDelegate.color != color;
}

class _EpicLogoPainter extends CustomPainter {
  _EpicLogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    final path = Path();
    path.moveTo(3.537 * scaleX, 0 * scaleY);
    path.cubicTo(2.165 * scaleX, 0 * scaleY, 1.66 * scaleX, 0.506 * scaleY, 1.66 * scaleX, 1.879 * scaleY);
    path.lineTo(1.66 * scaleX, 18.44 * scaleY);
    path.lineTo(1.68 * scaleX, 18.873 * scaleY);
    path.cubicTo(1.691 * scaleX, 18.873 * scaleY, 1.697 * scaleX, 19.163 * scaleY, 1.976 * scaleX, 19.493 * scaleY);
    path.cubicTo(2.003 * scaleX, 19.526 * scaleY, 2.287 * scaleX, 19.738 * scaleY, 2.287 * scaleX, 19.738 * scaleY);
    path.cubicTo(2.44 * scaleX, 19.813 * scaleY, 2.545 * scaleX, 19.868 * scaleY, 2.717 * scaleX, 19.938 * scaleY);
    path.lineTo(11.052 * scaleX, 23.429 * scaleY);
    path.cubicTo(11.485 * scaleX, 23.628 * scaleY, 11.666 * scaleX, 23.705 * scaleY, 11.98 * scaleX, 23.699 * scaleY);
    path.cubicTo(12.296 * scaleX, 23.705 * scaleY, 12.477 * scaleX, 23.628 * scaleY, 12.91 * scaleX, 23.429 * scaleY);
    path.lineTo(21.245 * scaleX, 19.937 * scaleY);
    path.cubicTo(21.417 * scaleX, 19.867 * scaleY, 21.522 * scaleX, 19.813 * scaleY, 21.675 * scaleX, 19.737 * scaleY);
    path.cubicTo(21.675 * scaleX, 19.737 * scaleY, 21.959 * scaleX, 19.526 * scaleY, 21.986 * scaleX, 19.494 * scaleY);
    path.cubicTo(22.266 * scaleX, 19.164 * scaleY, 22.271 * scaleX, 18.873 * scaleY, 22.302 * scaleX, 18.574 * scaleY);
    path.lineTo(22.322 * scaleX, 18.14 * scaleY);
    path.lineTo(22.322 * scaleX, 1.879 * scaleY);
    path.cubicTo(22.322 * scaleX, 0.506 * scaleY, 21.816 * scaleX, 0 * scaleY, 20.444 * scaleX, 0 * scaleY);
    path.close();

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

    path.moveTo(8.533 * scaleX, 3.19 * scaleY);
    path.lineTo(10.731 * scaleX, 3.19 * scaleY);
    path.cubicTo(11.869 * scaleX, 3.19 * scaleY, 12.431 * scaleX, 3.754 * scaleY, 12.431 * scaleX, 4.898 * scaleY);
    path.lineTo(12.431 * scaleX, 7.343 * scaleY);
    path.cubicTo(12.431 * scaleX, 8.487 * scaleY, 11.869 * scaleX, 9.053 * scaleY, 10.731 * scaleX, 9.053 * scaleY);
    path.lineTo(9.932 * scaleX, 9.053 * scaleY);
    path.lineTo(9.932 * scaleX, 12.391 * scaleY);
    path.lineTo(8.532 * scaleX, 12.391 * scaleY);
    path.close();

    path.moveTo(9.932 * scaleX, 4.425 * scaleY);
    path.lineTo(9.932 * scaleX, 7.817 * scaleY);
    path.lineTo(10.507 * scaleX, 7.817 * scaleY);
    path.cubicTo(10.861 * scaleX, 7.817 * scaleY, 11.03 * scaleX, 7.646 * scaleY, 11.03 * scaleX, 7.277 * scaleY);
    path.lineTo(11.03 * scaleX, 4.965 * scaleY);
    path.cubicTo(11.03 * scaleX, 4.597 * scaleY, 10.86 * scaleX, 4.425 * scaleY, 10.507 * scaleX, 4.425 * scaleY);
    path.close();

    path.moveTo(13.063 * scaleX, 3.19 * scaleY);
    path.lineTo(14.463 * scaleX, 3.19 * scaleY);
    path.lineTo(14.463 * scaleX, 12.391 * scaleY);
    path.lineTo(13.063 * scaleX, 12.391 * scaleY);
    path.close();

    path.moveTo(16.903 * scaleX, 3.11 * scaleY);
    path.lineTo(17.583 * scaleX, 3.11 * scaleY);
    path.cubicTo(18.721 * scaleX, 3.11 * scaleY, 19.271 * scaleX, 3.663 * scaleY, 19.271 * scaleX, 4.806 * scaleY);
    path.lineTo(19.271 * scaleX, 6.686 * scaleY);
    path.lineTo(17.897 * scaleX, 6.686 * scaleY);
    path.lineTo(17.897 * scaleX, 4.886 * scaleY);
    path.cubicTo(17.897 * scaleX, 4.517 * scaleY, 17.727 * scaleX, 4.346 * scaleY, 17.374 * scaleX, 4.346 * scaleY);
    path.lineTo(17.139 * scaleX, 4.346 * scaleY);
    path.cubicTo(16.772 * scaleX, 4.346 * scaleY, 16.602 * scaleX, 4.516 * scaleY, 16.602 * scaleX, 4.885 * scaleY);
    path.lineTo(16.602 * scaleX, 10.695 * scaleY);
    path.cubicTo(16.602 * scaleX, 11.064 * scaleY, 16.772 * scaleX, 11.235 * scaleY, 17.139 * scaleX, 11.235 * scaleY);
    path.lineTo(17.401 * scaleX, 11.235 * scaleY);
    path.cubicTo(17.754 * scaleX, 11.235 * scaleY, 17.924 * scaleX, 11.064 * scaleY, 17.924 * scaleX, 10.695 * scaleY);
    path.lineTo(17.924 * scaleX, 8.619 * scaleY);
    path.lineTo(19.297 * scaleX, 8.619 * scaleY);
    path.lineTo(19.297 * scaleX, 10.762 * scaleY);
    path.cubicTo(19.297 * scaleX, 11.906 * scaleY, 18.735 * scaleX, 12.472 * scaleY, 17.597 * scaleX, 12.472 * scaleY);
    path.lineTo(16.903 * scaleX, 12.472 * scaleY);
    path.cubicTo(15.765 * scaleX, 12.472 * scaleY, 15.203 * scaleX, 11.906 * scaleY, 15.203 * scaleX, 10.762 * scaleY);
    path.lineTo(15.203 * scaleX, 4.82 * scaleY);
    path.cubicTo(15.203 * scaleX, 3.676 * scaleY, 15.765 * scaleX, 3.111 * scaleY, 16.903 * scaleX, 3.11 * scaleY);
    path.close();

    path.moveTo(3.968 * scaleX, 21.812 * scaleY);
    path.lineTo(11.982 * scaleX, 21.812 * scaleY);
    path.lineTo(7.892 * scaleX, 23.16 * scaleY);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EpicLogoPainter oldDelegate) => oldDelegate.color != color;
}

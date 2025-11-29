import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/logger.dart';
import '../../core/platform_icons.dart';
import '../../core/theme.dart';
import '../../core/ui_constants.dart';
import '../../data/friend_repository.dart';
import '../../data/game_repository.dart';
import '../../data/profile_repository.dart';
import '../../data/steam_library_sync_service.dart';
import '../../data/supabase_client.dart';
import '../../models/game_log.dart';
import '../auth/auth_controller.dart';
import '../friends/friend_search_dialog.dart';
import '../library/library_controller.dart';
import '../steam_library/steam_library_provider.dart';
import '../steam_link/steam_link_dialog.dart';
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

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.valueOrNull;
    final username = profile?['username'] as String? ?? 'Oyuncu';
    final steamData = profile?['steam_data'] as Map<String, dynamic>?;
    final steamId = profile?['steam_id'] as String?;

    // Steam profil resmi - direkt steam_data'dan al
    final steamAvatarUrl = steamData?['profile_image_url'] as String?;

    final steamLibraryAsync = ref.watch(steamLibraryProvider);
    final collection = ref.watch(libraryControllerProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0f),
      body: CustomScrollView(
        slivers: [
          // Immersive Header
          SliverToBoxAdapter(
            child: _ProfileHeader(
              username: username,
              avatarUrl: steamAvatarUrl,
              steamId: steamId,
              isLoggedIn: session != null,
              onEdit: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                );
              },
            ),
          ),

          // Stats Grid
          SliverToBoxAdapter(
            child: _StatsGrid(
              steamLibraryAsync: steamLibraryAsync,
              collection: collection,
            ),
          ),

          // Most Played Section
          SliverToBoxAdapter(
            child: steamLibraryAsync.when(
              data: (games) {
                if (games.isEmpty) return const SizedBox.shrink();
                final mostPlayed = games.reduce(
                  (a, b) => a.playtimeMinutes > b.playtimeMinutes ? a : b,
                );
                return _MostPlayedCard(game: mostPlayed);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // Platform Connections Section
          SliverToBoxAdapter(
            child: _PlatformConnectionsSection(
              steamId: steamId,
              steamLibraryAsync: steamLibraryAsync,
            ),
          ),

          // Friends Section
          if (session != null)
            SliverToBoxAdapter(
              child: _FriendsSection(),
            ),

          // Logout Button
          if (session != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: _LogoutButton(ref: ref),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================
// PROFILE HEADER
// ============================================

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.username,
    required this.avatarUrl,
    required this.steamId,
    required this.isLoggedIn,
    required this.onEdit,
  });

  final String username;
  final String? avatarUrl;
  final String? steamId;
  final bool isLoggedIn;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1a1a2e),
            Color(0xFF16213e),
            Color(0xFF0f0f1a),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Geometric pattern background
          Positioned.fill(
            child: CustomPaint(
              painter: _GeometricPatternPainter(),
            ),
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0a0a0f).withOpacity(0.8),
                    const Color(0xFF0a0a0f),
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
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
                        // Title with accent bar
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366f1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'PROFİL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                        // Edit button
                        if (isLoggedIn)
                          GestureDetector(
                            onTap: onEdit,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Avatar and username
                  Row(
                    children: [
                      // Avatar with glow effect
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366f1).withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF6366f1),
                                Color(0xFF8b5cf6),
                                Color(0xFFa855f7),
                              ],
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF0a0a0f),
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: const Color(0xFF1a1a2e),
                              backgroundImage: avatarUrl != null
                                  ? CachedNetworkImageProvider(avatarUrl!)
                                  : null,
                              child: avatarUrl == null
                                  ? const Icon(
                                      Icons.person_rounded,
                                      size: 44,
                                      color: Color(0xFF6366f1),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Username and badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Platform connection icons
                            Row(
                              children: [
                                _ProfilePlatformIcon(
                                  icon: FontAwesomeIcons.steam,
                                  isConnected: steamId != null,
                                  activeColor: const Color(0xFF66c0f4),
                                ),
                                const SizedBox(width: 8),
                                _ProfilePlatformIcon(
                                  icon: FontAwesomeIcons.playstation,
                                  isConnected: false, // PlayStation not yet implemented
                                  activeColor: const Color(0xFF003791),
                                ),
                                const SizedBox(width: 8),
                                _ProfilePlatformIcon(
                                  icon: FontAwesomeIcons.gamepad, // Epic placeholder
                                  isConnected: false, // Epic not yet implemented
                                  activeColor: Colors.white,
                                  label: 'E', // Epic Games label
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Username
                            Text(
                              username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
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
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

// Geometric pattern painter
class _GeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6366f1).withOpacity(0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw diagonal lines
    for (var i = -10; i < 20; i++) {
      final startX = i * 40.0;
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height, size.height),
        paint,
      );
    }

    // Draw some accent circles
    final accentPaint = Paint()
      ..color = const Color(0xFF8b5cf6).withOpacity(0.05)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      60,
      accentPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.7),
      40,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================
// STATS GRID
// ============================================

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.steamLibraryAsync,
    required this.collection,
  });

  final AsyncValue<List<GameLog>> steamLibraryAsync;
  final List<GameLog> collection;

  @override
  Widget build(BuildContext context) {
    return steamLibraryAsync.when(
      data: (steamGames) {
        // Toplam oyun sayısı (Steam + Manual koleksiyon)
        final totalGames = steamGames.length +
            collection.where((g) => g.source != 'steam').length;

        // Toplam oynama saati
        final totalMinutes = steamGames.fold<int>(
          0, (sum, game) => sum + game.playtimeMinutes,
        );
        final totalHours = (totalMinutes / 60).round();

        // Değerlendirme sayısı
        final ratingCount = collection.where((g) => g.rating != null).length;

        // Başarım sayısı (Steam data'dan - tahmini)
        final achievements = (totalMinutes / 60 * 0.2).round();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      value: totalGames.toString(),
                      label: 'Oyun',
                      icon: Icons.sports_esports_rounded,
                      gradient: const [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                      delay: 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      value: _formatHours(totalHours),
                      label: 'Saat',
                      icon: Icons.schedule_rounded,
                      gradient: const [Color(0xFF10b981), Color(0xFF34d399)],
                      delay: 100,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      value: ratingCount.toString(),
                      label: 'Değerlendirme',
                      icon: Icons.star_rounded,
                      gradient: const [Color(0xFFf59e0b), Color(0xFFfbbf24)],
                      delay: 200,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      value: achievements.toString(),
                      label: 'Başarım',
                      icon: Icons.emoji_events_rounded,
                      gradient: const [Color(0xFFef4444), Color(0xFFf87171)],
                      delay: 300,
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
        child: _StatsLoading(),
      ),
      error: (_, __) => _buildBasicStats(),
    );
  }

  String _formatHours(int hours) {
    if (hours >= 1000) {
      return '${(hours / 1000).toStringAsFixed(1)}K';
    }
    return hours.toString();
  }

  Widget _buildBasicStats() {
    final totalGames = collection.length;
    final ratingCount = collection.where((g) => g.rating != null).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: totalGames.toString(),
                  label: 'Oyun',
                  icon: Icons.sports_esports_rounded,
                  gradient: const [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                  delay: 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: '0',
                  label: 'Saat',
                  icon: Icons.schedule_rounded,
                  gradient: const [Color(0xFF10b981), Color(0xFF34d399)],
                  delay: 100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: ratingCount.toString(),
                  label: 'Değerlendirme',
                  icon: Icons.star_rounded,
                  gradient: const [Color(0xFFf59e0b), Color(0xFFfbbf24)],
                  delay: 200,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: '0',
                  label: 'Başarım',
                  icon: Icons.emoji_events_rounded,
                  gradient: const [Color(0xFFef4444), Color(0xFFf87171)],
                  delay: 300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCardSkeleton()),
            const SizedBox(width: 12),
            Expanded(child: _StatCardSkeleton()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCardSkeleton()),
            const SizedBox(width: 12),
            Expanded(child: _StatCardSkeleton()),
          ],
        ),
      ],
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.delay,
  });

  final String value;
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12121a),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gradient[0].withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon with gradient background
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),

          const SizedBox(height: 16),

          // Value
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
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

          // Label
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: delay),
      duration: 400.ms,
    ).slideY(begin: 0.1, end: 0);
  }
}

// ============================================
// MOST PLAYED CARD
// ============================================

class _MostPlayedCard extends StatelessWidget {
  const _MostPlayedCard({required this.game});

  final GameLog game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1a1a2e),
              const Color(0xFF0f0f1a),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF6366f1).withOpacity(0.2),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background image
              if (game.game.coverUrl != null)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: game.game.coverUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),

              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF0a0a0f).withOpacity(0.95),
                        const Color(0xFF0a0a0f).withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Game cover
                    Container(
                      width: 80,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: game.game.coverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: game.game.coverUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: const Color(0xFF1a1a2e),
                                  child: const Icon(
                                    Icons.sports_esports_rounded,
                                    color: Color(0xFF6366f1),
                                  ),
                                ),
                              )
                            : Container(
                                color: const Color(0xFF1a1a2e),
                                child: const Icon(
                                  Icons.sports_esports_rounded,
                                  color: Color(0xFF6366f1),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Game info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'EN ÇOK OYNANAN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 8),

                          // Playtime
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: const Color(0xFF10b981),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${game.playtimeHours.toStringAsFixed(1)} saat',
                                style: const TextStyle(
                                  color: Color(0xFF10b981),
                                  fontSize: 15,
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
      ),
    ).animate()
        .fadeIn(delay: 400.ms, duration: 500.ms)
        .slideY(begin: 0.1, end: 0);
  }
}

// ============================================
// PROFILE PLATFORM ICON (for header)
// ============================================

class _ProfilePlatformIcon extends StatelessWidget {
  const _ProfilePlatformIcon({
    required this.icon,
    required this.isConnected,
    required this.activeColor,
    this.label,
  });

  final IconData icon;
  final bool isConnected;
  final Color activeColor;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isConnected
            ? activeColor.withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected
              ? activeColor.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: label != null
            ? Text(
                label!,
                style: TextStyle(
                  color: isConnected ? activeColor : Colors.white.withOpacity(0.3),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              )
            : FaIcon(
                icon,
                size: 14,
                color: isConnected ? activeColor : Colors.white.withOpacity(0.3),
              ),
      ),
    );
  }
}

// ============================================
// PLATFORM CONNECTIONS SECTION
// ============================================

class _PlatformConnectionsSection extends ConsumerWidget {
  const _PlatformConnectionsSection({
    required this.steamId,
    required this.steamLibraryAsync,
  });

  final String? steamId;
  final AsyncValue<List<GameLog>> steamLibraryAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: UIConstants.purpleGradient),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'PLATFORM BAĞLANTILARI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Platform cards
          _PlatformConnectionCard(
            icon: FontAwesomeIcons.steam,
            name: 'Steam',
            isConnected: steamId != null,
            activeColor: const Color(0xFF66c0f4),
            onConnect: () => showSteamLinkDialog(context),
            onSync: steamId != null
                ? () => _syncSteam(context, ref, steamId!)
                : null,
          ),
          const SizedBox(height: 12),
          _PlatformConnectionCard(
            icon: FontAwesomeIcons.playstation,
            name: 'PlayStation',
            isConnected: false,
            activeColor: const Color(0xFF003791),
            isComingSoon: true,
          ),
          const SizedBox(height: 12),
          _PlatformConnectionCard(
            icon: FontAwesomeIcons.gamepad,
            name: 'Epic Games',
            isConnected: false,
            activeColor: Colors.white,
            isComingSoon: true,
            customLabel: 'E',
          ),
        ],
      ),
    ).animate()
        .fadeIn(delay: 500.ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Future<void> _syncSteam(BuildContext context, WidgetRef ref, String steamId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: UIConstants.bgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        ),
        content: Row(
          children: [
            CircularProgressIndicator(color: UIConstants.accentSteam),
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
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.imported + result.updated} oyun senkronize edildi!'),
            backgroundColor: UIConstants.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e, stack) {
      appLogger.error('Profile: Failed to sync Steam library', e, stack);
      if (context.mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: UIConstants.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}

class _PlatformConnectionCard extends StatelessWidget {
  const _PlatformConnectionCard({
    required this.icon,
    required this.name,
    required this.isConnected,
    required this.activeColor,
    this.onConnect,
    this.onSync,
    this.isComingSoon = false,
    this.customLabel,
  });

  final IconData icon;
  final String name;
  final bool isConnected;
  final Color activeColor;
  final VoidCallback? onConnect;
  final VoidCallback? onSync;
  final bool isComingSoon;
  final String? customLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected
            ? activeColor.withOpacity(0.1)
            : UIConstants.bgSecondary,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(
          color: isConnected
              ? activeColor.withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Platform icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isConnected
                  ? activeColor.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: customLabel != null
                  ? Text(
                      customLabel!,
                      style: TextStyle(
                        color: isConnected
                            ? activeColor
                            : Colors.white.withOpacity(0.3),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : FaIcon(
                      icon,
                      size: 22,
                      color: isConnected
                          ? activeColor
                          : Colors.white.withOpacity(0.3),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Platform info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isConnected ? Colors.white : Colors.white.withOpacity(0.6),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isComingSoon
                      ? 'Yakında'
                      : isConnected
                          ? 'Bağlı'
                          : 'Bağlı değil',
                  style: TextStyle(
                    color: isComingSoon
                        ? UIConstants.accentYellow
                        : isConnected
                            ? UIConstants.accentGreen
                            : Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Action button
          if (!isComingSoon)
            GestureDetector(
              onTap: isConnected ? onSync : onConnect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isConnected
                      ? activeColor.withOpacity(0.2)
                      : activeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.sync_rounded : Icons.link_rounded,
                      size: 16,
                      color: isConnected ? activeColor : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Senkronize' : 'Bağla',
                      style: TextStyle(
                        color: isConnected ? activeColor : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: UIConstants.accentYellow.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Yakında',
                style: TextStyle(
                  color: UIConstants.accentYellow,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================
// FRIENDS SECTION
// ============================================

class _FriendsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);
    final pendingAsync = ref.watch(pendingRequestsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8b5cf6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ARKADAŞLAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8b5cf6), Color(0xFFa855f7)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Ekle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Pending requests
          pendingAsync.when(
            data: (requests) {
              if (requests.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  ...requests.map((req) => _PendingRequestCard(request: req)),
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
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12121a),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 48,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Henüz arkadaş yok',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: friends.map((f) => _FriendCard(friend: f)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF8b5cf6)),
              ),
            ),
            error: (e, _) => Center(
              child: Text(
                'Yüklenemedi: $e',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    ).animate()
        .fadeIn(delay: 600.ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }
}

class _PendingRequestCard extends ConsumerWidget {
  const _PendingRequestCard({required this.request});

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
              backgroundColor: const Color(0xFF10b981),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
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
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFf59e0b).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFf59e0b).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFf59e0b).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                color: Color(0xFFf59e0b),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: acceptRequest,
            icon: const Icon(Icons.check_rounded),
            color: const Color(0xFF10b981),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF10b981).withOpacity(0.2),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: rejectRequest,
            icon: const Icon(Icons.close_rounded),
            color: Colors.white54,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendCard extends ConsumerWidget {
  const _FriendCard({required this.friend});

  final Map<String, dynamic> friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = friend['username'] as String;
    final friendId = friend['id'] as String;

    Future<void> removeFriend() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Arkadaşlıktan Çıkar',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '$username arkadaş listenden çıkarılacak.',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Çıkar'),
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
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12121a),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8b5cf6).withOpacity(0.3),
                  const Color(0xFFa855f7).withOpacity(0.3),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                color: Color(0xFF8b5cf6),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: removeFriend,
            icon: const Icon(Icons.person_remove_rounded, size: 20),
            color: Colors.white38,
            tooltip: 'Arkadaşlıktan çıkar',
          ),
        ],
      ),
    );
  }
}

// ============================================
// LOGOUT BUTTON
// ============================================

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
      icon: const Icon(Icons.logout_rounded, size: 20),
      label: const Text('Çıkış Yap'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFef4444),
        side: BorderSide(
          color: const Color(0xFFef4444).withOpacity(0.3),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ).animate()
        .fadeIn(delay: 700.ms, duration: 400.ms);
  }
}

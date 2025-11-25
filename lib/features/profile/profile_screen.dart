import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/game_repository.dart';
import '../../data/supabase_client.dart';
import '../../models/game_log.dart';
import '../auth/auth_controller.dart';
import '../library/library_controller.dart';

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

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final email = session?.user.email ?? 'Guest';
    final collection = ref.watch(libraryControllerProvider).valueOrNull ?? [];
    final statsAsync = ref.watch(userStatsProvider);
    final badgesAsync = ref.watch(allBadgesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.charcoal,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accentGold.withOpacity(0.3),
                      AppTheme.charcoal,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(pagePadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Avatar with glow
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentGold.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 36,
                                backgroundColor: AppTheme.accentGold,
                                child: Text(
                                  email.isNotEmpty
                                      ? email.characters.first.toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session != null
                                        ? 'Gamelib Oyuncusu'
                                        : 'Misafir',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Section
                  statsAsync.when(
                    data: (stats) {
                      if (stats == null) {
                        return _buildEmptyStats(collection);
                      }
                      return _StatsSection(stats: stats, collection: collection);
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, __) => _buildEmptyStats(collection),
                  ),

                  const SizedBox(height: 24),

                  // Badge Section
                  badgesAsync.when(
                    data: (badges) {
                      if (badges.isEmpty) return const SizedBox();
                      final stats = statsAsync.valueOrNull;
                      final totalGames = stats?.totalGames ?? collection.length;
                      return _BadgeSection(
                        badges: badges,
                        totalGames: totalGames,
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  if (session != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Çıkış Yap'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: Colors.red.withOpacity(0.5),
                          ),
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStats(List<GameLog> collection) {
    // Calculate basic stats from collection
    final completed =
        collection.where((l) => l.status == PlayStatus.completed).length;
    final playing =
        collection.where((l) => l.status == PlayStatus.playing).length;
    final wishlist =
        collection.where((l) => l.status == PlayStatus.wishlist).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İstatistikler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Toplam',
                value: collection.length.toString(),
                icon: Icons.videogame_asset,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Tamamlandı',
                value: completed.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Oynuyor',
                value: playing.toString(),
                icon: Icons.play_circle,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'İstek Listesi',
                value: wishlist.toString(),
                icon: Icons.favorite,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Stats Section Widget
class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats, required this.collection});

  final dynamic stats; // UserStats
  final List<GameLog> collection;

  @override
  Widget build(BuildContext context) {
    // Calculate from collection as backup
    final completed =
        collection.where((l) => l.status == PlayStatus.completed).length;
    final playing =
        collection.where((l) => l.status == PlayStatus.playing).length;
    final wishlist =
        collection.where((l) => l.status == PlayStatus.wishlist).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İstatistikler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Toplam',
                value: collection.length.toString(),
                icon: Icons.videogame_asset,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Tamamlandı',
                value: completed.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Oynuyor',
                value: playing.toString(),
                icon: Icons.play_circle,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'İstek Listesi',
                value: wishlist.toString(),
                icon: Icons.favorite,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.15),
                AppTheme.darkGray.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Badge Section Widget
class _BadgeSection extends StatelessWidget {
  const _BadgeSection({required this.badges, required this.totalGames});

  final List<dynamic> badges; // List<Badge>
  final int totalGames;

  // Map FontAwesome icon names to emoji
  String _getEmojiForIcon(String iconName) {
    const iconMap = {
      'trophy': '🏆',
      'star': '⭐',
      'medal': '🏅',
      'crown': '👑',
      'gem': '💎',
      'fire': '🔥',
      'rocket': '🚀',
      'diamond': '💠',
    };
    return iconMap[iconName] ?? '🏆';
  }

  @override
  Widget build(BuildContext context) {
    // Find current badge - find the highest tier badge that user has unlocked
    dynamic currentBadge = badges.first;
    for (final badge in badges) {
      if (totalGames >= (badge.requiredGames as int)) {
        currentBadge = badge;
      } else {
        break;
      }
    }

    final currentTier = currentBadge.tier as int;

    // Find next badge
    final nextBadge = currentTier < badges.length - 1
        ? badges.firstWhere((b) => (b.tier as int) == currentTier + 1)
        : null;

    final progress = nextBadge != null
        ? totalGames / (nextBadge.requiredGames as int)
        : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rozet',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentGold.withOpacity(0.2),
                    AppTheme.darkGray.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.accentGold.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Current Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withOpacity(0.2),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentGold.withOpacity(0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Text(
                          _getEmojiForIcon(
                              currentBadge.iconName as String? ?? 'trophy'),
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentBadge.name as String? ?? 'Badge',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentBadge.description as String? ??
                                  'Keep playing!',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Progress to next badge
                  if (nextBadge != null) ...[
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sonraki: ${nextBadge.name}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$totalGames/${nextBadge.requiredGames}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.accentGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.grey[800],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accentGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.1, end: 0);
  }
}

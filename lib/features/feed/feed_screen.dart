import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';

import '../../core/fire_theme.dart';
import '../../core/ui_constants.dart';
import '../../data/feed_repository.dart';
import '../../data/game_repository.dart';
import '../../data/supabase_client.dart';
import '../../models/game_log.dart';
import '../discover/discover_screen.dart';
import '../search/game_detail_screen.dart';

/// Feed screen with tabs: Akış and Keşfet
/// Shows friend activities and game recommendations
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _flameController;
  late AnimationController _emberController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    timeago.setLocaleMessages('tr', timeago.TrMessages());

    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _emberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _flameController.dispose();
    _emberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.bgPrimary,
      body: Stack(
        children: [
          // Fire Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _flameController,
              builder: (context, child) {
                return CustomPaint(
                  painter: FireBackgroundPainter(
                    progress: _flameController.value,
                    intensity: 0.5,
                  ),
                );
              },
            ),
          ),

          // Ember Particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _emberController,
              builder: (context, child) {
                return CustomPaint(
                  painter: EmberParticlesPainter(
                    progress: _emberController.value,
                    particleCount: 8,
                    intensity: 0.4,
                  ),
                );
              },
            ),
          ),

          // Gradient Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      UIConstants.bgPrimary.withOpacity(0.7),
                      UIConstants.bgPrimary.withOpacity(0.95),
                    ],
                    stops: const [0.0, 0.3, 0.6],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header with tabs
                _FireFeedHeader(
                  tabController: _tabController,
                  flameController: _flameController,
                ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _FeedContent(),
                      _DiscoverContent(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// FIRE FEED HEADER WITH TABS
// ============================================

class _FireFeedHeader extends StatelessWidget {
  const _FireFeedHeader({
    required this.tabController,
    required this.flameController,
  });

  final TabController tabController;
  final AnimationController flameController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UIConstants.pagePadding,
        16,
        UIConstants.pagePadding,
        8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: flameController,
                builder: (context, child) {
                  return Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          UIConstants.fireYellow,
                          Color.lerp(
                            UIConstants.fireOrange,
                            UIConstants.fireRed,
                            flameController.value,
                          )!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: UIConstants.fireOrange.withOpacity(0.5 + flameController.value * 0.3),
                          blurRadius: 8 + flameController.value * 4,
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
                  colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                ).createShader(bounds),
                child: const Text(
                  'AKIŞ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Fire-themed Tab bar
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  UIConstants.fireOrange.withOpacity(0.1),
                  UIConstants.fireRed.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              border: Border.all(
                color: UIConstants.fireOrange.withOpacity(0.2),
              ),
            ),
            child: TabBar(
              controller: tabController,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                ),
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: UIConstants.fireOrange.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.5),
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.dynamic_feed_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Akış'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Keşfet'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// FEED CONTENT (Tab 1)
// ============================================

class _FeedContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);

    return feedAsync.when(
      loading: () => const LoadingState(message: 'Akış yükleniyor...'),
      error: (e, _) => _FireErrorState(
        message: 'Akış yüklenemedi: $e',
        onRetry: () => ref.invalidate(feedProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_rounded,
            title: 'Henüz akış boş',
            subtitle: 'Arkadaş ekle veya oyun keşfet!',
            iconColor: UIConstants.fireOrange,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(feedProvider);
          },
          color: UIConstants.fireOrange,
          backgroundColor: UIConstants.bgSecondary,
          child: ListView.builder(
            padding: const EdgeInsets.all(UIConstants.pagePadding),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.type == FeedItemType.activity) {
                return _FireActivityPostCard(item: item)
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 50 * (index % 10)),
                      duration: 400.ms,
                    )
                    .slideY(begin: 0.05, end: 0);
              } else {
                return _FireRecommendationPostCard(item: item)
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 50 * (index % 10)),
                      duration: 400.ms,
                    )
                    .slideY(begin: 0.05, end: 0);
              }
            },
          ),
        );
      },
    );
  }
}

// ============================================
// DISCOVER CONTENT (Tab 2)
// ============================================

class _DiscoverContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indieGamesAsync = ref.watch(personalizedIndieGamesProvider);
    final topGenresAsync = ref.watch(topPlayedGenresProvider);

    return Column(
      children: [
        // Fire-themed Info card
        Padding(
          padding: const EdgeInsets.fromLTRB(
            UIConstants.pagePadding,
            8,
            UIConstants.pagePadding,
            0,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  UIConstants.fireOrange.withOpacity(0.15),
                  UIConstants.fireRed.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              border: Border.all(
                color: UIConstants.fireOrange.withOpacity(0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: UIConstants.fireOrange.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: UIConstants.fireOrange.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                        ).createShader(bounds),
                        child: const Text(
                          'En Çok Oynadığın Türlerden',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bağımsız oyunları keşfet',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ref.invalidate(personalizedIndieGamesProvider);
                    ref.invalidate(topPlayedGenresProvider);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          UIConstants.fireOrange.withOpacity(0.2),
                          UIConstants.fireRed.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                      border: Border.all(
                        color: UIConstants.fireOrange.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: UIConstants.fireOrange,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Fire-themed top genres display
        topGenresAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (genres) => _FireGenreChipsRow(genres: genres),
        ),

        // Indie games grid
        Expanded(
          child: indieGamesAsync.when(
            loading: () => const LoadingState(message: 'Oyunlar yükleniyor...'),
            error: (e, _) => _FireErrorState(
              message: 'Oyunlar yüklenemedi: $e',
              onRetry: () => ref.invalidate(personalizedIndieGamesProvider),
            ),
            data: (games) {
              if (games.isEmpty) {
                return const EmptyState(
                  icon: Icons.videogame_asset_off_rounded,
                  title: 'Henüz oyun bulunamadı',
                  subtitle: 'Daha sonra tekrar dene!',
                  iconColor: UIConstants.fireOrange,
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(personalizedIndieGamesProvider);
                },
                color: UIConstants.fireOrange,
                backgroundColor: UIConstants.bgSecondary,
                child: GridView.builder(
                  padding: const EdgeInsets.all(UIConstants.pagePadding),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    return _FireIndieGameCard(game: games[index])
                        .animate()
                        .fadeIn(
                          delay: Duration(milliseconds: 50 * (index % 10)),
                          duration: 400.ms,
                        )
                        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================
// FIRE GENRE CHIPS ROW
// ============================================

class _FireGenreChipsRow extends StatelessWidget {
  const _FireGenreChipsRow({required this.genres});

  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UIConstants.pagePadding,
        8,
        UIConstants.pagePadding,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sevdiğin türler:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: genres.asMap().entries.map((entry) {
                final index = entry.key;
                final genre = entry.value;
                // Fire-themed gradients
                final gradients = [
                  [UIConstants.fireYellow, UIConstants.fireOrange],
                  [UIConstants.fireOrange, UIConstants.fireRed],
                  [UIConstants.fireGlow, UIConstants.fireYellow],
                  [UIConstants.fireRed, UIConstants.fireOrange],
                ];
                final gradient = gradients[index % gradients.length];

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          gradient[0].withOpacity(0.2),
                          gradient[1].withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: gradient[0].withOpacity(0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradient[0].withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: gradient[0],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          genre,
                          style: TextStyle(
                            color: gradient[0],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ============================================
// FIRE ERROR STATE
// ============================================

class _FireErrorState extends StatelessWidget {
  const _FireErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    UIConstants.fireRed.withOpacity(0.2),
                    UIConstants.fireOrange.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: UIConstants.fireRed.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: UIConstants.fireRed,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FireButton(
              onTap: onRetry,
              child: const Text(
                'Tekrar Dene',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// FIRE ACTIVITY POST CARD
// ============================================

class _FireActivityPostCard extends ConsumerWidget {
  const _FireActivityPostCard({required this.item});

  final FeedItem item;

  String _getActivityDescription() {
    if (item.activityType == null || item.game == null) return '';

    final gameName = item.game!.name;
    switch (item.activityType!) {
      case ActivityType.added:
        return 'Koleksiyonuma $gameName ekledi!';
      case ActivityType.completed:
        return '$gameName oyununu tamamladı!';
      case ActivityType.playing:
        return 'Şu anda $gameName oynuyor';
      case ActivityType.dropped:
        return '$gameName oyununu bıraktı';
      case ActivityType.planToPlay:
        return '$gameName oynamayı planlıyor';
      case ActivityType.rated:
        if (item.rating != null) {
          return '$gameName oyununa ${item.rating}/10 puan verdi!';
        }
        return '$gameName oyununu değerlendirdi';
    }
  }

  String _generateFakeLikes() {
    final random = Random(item.game?.id ?? 0);
    final likes = random.nextInt(10000) + 100;

    if (likes >= 1000) {
      return '${(likes / 1000).toStringAsFixed(1)}K';
    }
    return likes.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.game == null) return const SizedBox.shrink();

    final game = item.game!;
    final description = _getActivityDescription();
    final timeAgo = item.timestamp != null
        ? timeago.format(item.timestamp!, locale: 'tr')
        : '';
    final fakeLikes = _generateFakeLikes();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            UIConstants.fireOrange.withOpacity(0.1),
            UIConstants.fireRed.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(
          color: UIConstants.fireOrange.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: UIConstants.fireOrange.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: UIConstants.fireOrange.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.username ?? 'Kullanıcı',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Game cover
          if (game.coverUrl != null)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GameDetailScreen(game: game),
                  ),
                );
              },
              child: Container(
                height: 180,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: UIConstants.fireOrange.withOpacity(0.3),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  child: CachedNetworkImage(
                    imageUrl: game.coverUrl!.replaceAll('t_thumb', 't_cover_big'),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: UIConstants.bgTertiary,
                      child: const Center(child: FireLoadingIndicator(size: 24)),
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  color: UIConstants.fireRed,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  fakeLikes,
                  style: TextStyle(
                    color: UIConstants.fireRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: UIConstants.fireOrange,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '${Random(game.id).nextInt(50) + 5}',
                  style: TextStyle(
                    color: UIConstants.fireOrange,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                _FireQuickAddButton(game: game),
              ],
            ),
          ),

          // Rating stars if rated
          if (item.activityType == ActivityType.rated && item.rating != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Row(
                children: [
                  ...List.generate(10, (index) {
                    final isFilled = index < item.rating!;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isFilled
                            ? UIConstants.fireYellow
                            : Colors.white.withOpacity(0.2),
                        size: 14,
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================
// FIRE RECOMMENDATION POST CARD
// ============================================

class _FireRecommendationPostCard extends ConsumerWidget {
  const _FireRecommendationPostCard({required this.item});

  final FeedItem item;

  String _generateFakeLikes() {
    final random = Random(item.game?.id ?? 0);
    final likes = random.nextInt(15000) + 500;

    if (likes >= 1000) {
      return '${(likes / 1000).toStringAsFixed(1)}K';
    }
    return likes.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.game == null) return const SizedBox.shrink();

    final game = item.game!;
    final fakeLikes = _generateFakeLikes();
    final description = game.summary ?? 'Keşfetmeye değer harika bir indie oyun!';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            UIConstants.fireYellow.withOpacity(0.12),
            UIConstants.fireOrange.withOpacity(0.06),
          ],
        ),
        border: Border.all(
          color: UIConstants.fireYellow.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: UIConstants.fireYellow.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: GameLib recommendation badge
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: UIConstants.fireOrange.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                        ).createShader(bounds),
                        child: const Text(
                          'GameLib',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'Indie Önerisi',
                        style: TextStyle(
                          color: UIConstants.fireYellow,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Game title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              game.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 12),

          // Game cover
          if (game.coverUrl != null)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GameDetailScreen(game: game),
                  ),
                );
              },
              child: Container(
                height: 180,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: game.coverUrl!.replaceAll('t_thumb', 't_cover_big'),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: UIConstants.bgTertiary,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              UIConstants.fireOrange.withOpacity(0.2),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Genres with fire theme
          if (game.genres.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: game.genres.take(3).map((genre) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          UIConstants.fireOrange.withOpacity(0.2),
                          UIConstants.fireYellow.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: UIConstants.fireOrange.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      genre,
                      style: TextStyle(
                        color: UIConstants.fireOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 12),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  color: UIConstants.fireRed,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  fakeLikes,
                  style: TextStyle(
                    color: UIConstants.fireRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: UIConstants.fireOrange,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '${Random(game.id).nextInt(100) + 10}',
                  style: TextStyle(
                    color: UIConstants.fireOrange,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                _FireQuickAddButton(game: game),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// FIRE INDIE GAME CARD
// ============================================

class _FireIndieGameCard extends StatelessWidget {
  const _FireIndieGameCard({required this.game});

  final game;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameDetailScreen(game: game),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              UIConstants.fireOrange.withOpacity(0.1),
              UIConstants.fireRed.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: UIConstants.fireOrange.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: UIConstants.fireOrange.withOpacity(0.1),
              blurRadius: 15,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Expanded(
              child: Stack(
                children: [
                  // Game cover
                  if (game.coverUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(UIConstants.radiusLarge),
                        topRight: Radius.circular(UIConstants.radiusLarge),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: game.coverUrl!.replaceAll('t_thumb', 't_cover_big'),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: UIConstants.bgTertiary,
                          child: const Center(child: FireLoadingIndicator(size: 20)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: UIConstants.bgTertiary,
                          child: Center(
                            child: Icon(
                              Icons.videogame_asset_rounded,
                              color: UIConstants.fireOrange.withOpacity(0.3),
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: UIConstants.fireGradient),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(UIConstants.radiusLarge),
                          topRight: Radius.circular(UIConstants.radiusLarge),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.videogame_asset_rounded,
                          color: Colors.white.withOpacity(0.5),
                          size: 40,
                        ),
                      ),
                    ),

                  // Indie badge with fire glow
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: UIConstants.fireOrange.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Indie',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Game info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game name
                  Text(
                    game.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Genres
                  if (game.genres.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: game.genres.take(2).map<Widget>((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                UIConstants.fireOrange.withOpacity(0.2),
                                UIConstants.fireYellow.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: UIConstants.fireOrange.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            genre,
                            style: TextStyle(
                              color: UIConstants.fireOrange,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 8),

                  // Rating with fire colors
                  if (game.aggregatedRating != null)
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: UIConstants.fireYellow,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          game.aggregatedRating!.toStringAsFixed(0),
                          style: TextStyle(
                            color: UIConstants.fireYellow,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '/100',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10,
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
    );
  }
}

// ============================================
// FIRE QUICK ADD BUTTON
// ============================================

class _FireQuickAddButton extends ConsumerStatefulWidget {
  const _FireQuickAddButton({required this.game});

  final game;

  @override
  ConsumerState<_FireQuickAddButton> createState() => _FireQuickAddButtonState();
}

class _FireQuickAddButtonState extends ConsumerState<_FireQuickAddButton> {
  bool _isAdding = false;

  Future<void> _addToWishlist() async {
    setState(() => _isAdding = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      final repo = ref.read(gameRepositoryProvider);

      final gameLog = GameLog(
        id: const Uuid().v4(),
        game: widget.game,
        status: PlayStatus.wishlist,
        rating: null,
        notes: null,
      );

      await repo.upsertGameLog(userId, gameLog);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.game.name} istek listesine eklendi!'),
            backgroundColor: UIConstants.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: UIConstants.fireRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isAdding ? null : _addToWishlist,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              UIConstants.fireOrange.withOpacity(0.2),
              UIConstants.fireYellow.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
          border: Border.all(
            color: UIConstants.fireOrange.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isAdding)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: UIConstants.fireOrange,
                ),
              )
            else
              Icon(
                Icons.bookmark_add_rounded,
                size: 16,
                color: UIConstants.fireOrange,
              ),
            const SizedBox(width: 6),
            Text(
              'İstek Listesi',
              style: TextStyle(
                color: UIConstants.fireOrange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../data/feed_repository.dart';
import '../../data/game_repository.dart';
import '../../data/supabase_client.dart';
import '../../models/game_log.dart';
import '../search/game_detail_screen.dart';

/// Feed screen
/// Shows friend activities and game recommendations in post format
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Configure Turkish timeago messages
    timeago.setLocaleMessages('tr', timeago.TrMessages());

    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.sky.withOpacity(0.2),
                    AppTheme.mint.withOpacity(0.2),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.feed,
                    color: AppTheme.sky,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Akış',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cream,
                    ),
                  ),
                ],
              ),
            ),

            // Feed content
            Expanded(
              child: feedAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppTheme.sky),
                  ),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.withOpacity(0.7),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Akış yüklenemedi',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$e',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.lavenderGray,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 80,
                              color: AppTheme.lavenderGray.withOpacity(0.5),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Henüz akış boş',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.cream,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Arkadaş ekle veya oyun keşfet!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.lavenderGray,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(feedProvider);
                    },
                    color: AppTheme.sky,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (item.type == FeedItemType.activity) {
                          return _ActivityPostCard(item: item);
                        } else {
                          return _RecommendationPostCard(item: item);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Activity post card - Friend game action in post format
class _ActivityPostCard extends ConsumerWidget {
  const _ActivityPostCard({required this.item});

  final FeedItem item;

  String _getActivityDescription() {
    if (item.activityType == null || item.game == null) return '';

    final gameName = item.game!.name;
    switch (item.activityType!) {
      case ActivityType.added:
        return 'Koleksiyonuma $gameName ekledi!';
      case ActivityType.completed:
        return '$gameName oyununu tamamladı! Harika bir deneyimdi!';
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
    final activityText = item.getActivityText();
    final description = _getActivityDescription();
    final timeAgo = item.timestamp != null
        ? timeago.format(item.timestamp!, locale: 'tr')
        : '';
    final fakeLikes = _generateFakeLikes();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.slate,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.lavender.withOpacity(0.2),
        ),
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
                      colors: [
                        AppTheme.lavender.withOpacity(0.3),
                        AppTheme.sky.withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person,
                      color: AppTheme.lavender,
                      size: 24,
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
                          color: AppTheme.cream,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: AppTheme.lavenderGray.withOpacity(0.7),
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
              style: const TextStyle(
                color: AppTheme.cream,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Game cover
          if (game.coverUrl != null)
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GameDetailScreen(game: game),
                  ),
                );
              },
              child: Container(
                height: 200,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(
                      game.coverUrl!.replaceAll('t_thumb', 't_cover_big'),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Actions: Like, Comment, Share (fake)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.favorite_border,
                  color: AppTheme.rose,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  fakeLikes,
                  style: TextStyle(
                    color: AppTheme.rose,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(
                  Icons.chat_bubble_outline,
                  color: AppTheme.sky,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '${Random(game.id).nextInt(50) + 5}',
                  style: TextStyle(
                    color: AppTheme.sky,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                // Quick add to wishlist
                _QuickAddButton(game: game),
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
                        isFilled ? Icons.star : Icons.star_border,
                        color: isFilled
                            ? AppTheme.peach
                            : AppTheme.lavenderGray.withOpacity(0.3),
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

/// Recommendation post card - Indie game recommendation in post format
class _RecommendationPostCard extends ConsumerWidget {
  const _RecommendationPostCard({required this.item});

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
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.sky.withOpacity(0.15),
            AppTheme.mint.withOpacity(0.15),
          ],
        ),
        border: Border.all(
          color: AppTheme.sky.withOpacity(0.3),
          width: 2,
        ),
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
                      colors: [AppTheme.sky, AppTheme.mint],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
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
                      const Text(
                        'GameLib',
                        style: TextStyle(
                          color: AppTheme.cream,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Indie Önerisi',
                        style: TextStyle(
                          color: AppTheme.lavenderGray.withOpacity(0.7),
                          fontSize: 12,
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
                color: AppTheme.cream,
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
                color: AppTheme.lavenderGray,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 12),

          // Game cover
          if (game.coverUrl != null)
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GameDetailScreen(game: game),
                  ),
                );
              },
              child: Container(
                height: 200,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(
                      game.coverUrl!.replaceAll('t_thumb', 't_cover_big'),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Genres
          if (game.genres.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                children: game.genres.take(3).map((genre) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.sky.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.sky.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      genre,
                      style: TextStyle(
                        color: AppTheme.sky,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 12),

          // Actions: Like and Add to wishlist
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.favorite_border,
                  color: AppTheme.rose,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  fakeLikes,
                  style: TextStyle(
                    color: AppTheme.rose,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(
                  Icons.chat_bubble_outline,
                  color: AppTheme.sky,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '${Random(game.id).nextInt(100) + 10}',
                  style: TextStyle(
                    color: AppTheme.sky,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                // Quick add to wishlist
                _QuickAddButton(game: game),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick add to wishlist button
class _QuickAddButton extends ConsumerStatefulWidget {
  const _QuickAddButton({required this.game});

  final game;

  @override
  ConsumerState<_QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends ConsumerState<_QuickAddButton> {
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

      // Create GameLog with wishlist status
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
            backgroundColor: AppTheme.mint,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
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
    return TextButton.icon(
      onPressed: _isAdding ? null : _addToWishlist,
      icon: _isAdding
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppTheme.mint),
              ),
            )
          : const Icon(
              Icons.bookmark_add_outlined,
              size: 18,
              color: AppTheme.mint,
            ),
      label: Text(
        'İstek Listesi',
        style: TextStyle(
          color: AppTheme.mint,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        backgroundColor: AppTheme.mint.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppTheme.mint.withOpacity(0.3)),
        ),
      ),
    );
  }
}

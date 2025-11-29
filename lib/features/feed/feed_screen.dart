import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';

import '../../core/ui_constants.dart';
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
      backgroundColor: UIConstants.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _FeedHeader(),

            // Feed content
            Expanded(
              child: feedAsync.when(
                loading: () => const LoadingState(message: 'Akış yükleniyor...'),
                error: (e, _) => _ErrorState(
                  message: 'Akış yüklenemedi: $e',
                  onRetry: () => ref.invalidate(feedProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'Henüz akış boş',
                      subtitle: 'Arkadaş ekle veya oyun keşfet!',
                      iconColor: UIConstants.accentPurple,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(feedProvider);
                    },
                    color: UIConstants.accentPurple,
                    backgroundColor: UIConstants.bgSecondary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(UIConstants.pagePadding),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (item.type == FeedItemType.activity) {
                          return _ActivityPostCard(item: item)
                              .animate()
                              .fadeIn(
                                delay: Duration(milliseconds: 50 * (index % 10)),
                                duration: 400.ms,
                              )
                              .slideY(begin: 0.05, end: 0);
                        } else {
                          return _RecommendationPostCard(item: item)
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// FEED HEADER
// ============================================

class _FeedHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UIConstants.pagePadding,
        16,
        UIConstants.pagePadding,
        16,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: UIConstants.purpleGradient),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'AKIŞ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// ERROR STATE
// ============================================

class _ErrorState extends StatelessWidget {
  const _ErrorState({
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
                color: UIConstants.accentRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: UIConstants.accentRed,
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
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: UIConstants.bgSecondary,
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Tekrar Dene',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
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
// ACTIVITY POST CARD
// ============================================

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
        color: UIConstants.bgSecondary,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(
          color: UIConstants.accentPurple.withOpacity(0.15),
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
                    gradient: const LinearGradient(
                      colors: UIConstants.purpleGradient,
                    ),
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
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  child: CachedNetworkImage(
                    imageUrl: game.coverUrl!.replaceAll('t_thumb', 't_cover_big'),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: UIConstants.bgTertiary,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: UIConstants.accentPurple,
                        ),
                      ),
                    ),
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
                  Icons.favorite_border_rounded,
                  color: UIConstants.accentPink,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  fakeLikes,
                  style: TextStyle(
                    color: UIConstants.accentPink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: UIConstants.accentPurple,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '${Random(game.id).nextInt(50) + 5}',
                  style: TextStyle(
                    color: UIConstants.accentPurple,
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
                        isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isFilled
                            ? UIConstants.accentYellow
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
// RECOMMENDATION POST CARD
// ============================================

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
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        color: UIConstants.bgSecondary,
        border: Border.all(
          color: UIConstants.accentGreen.withOpacity(0.3),
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
                    gradient: const LinearGradient(
                      colors: UIConstants.greenGradient,
                    ),
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
                      const Text(
                        'GameLib',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Indie Önerisi',
                        style: TextStyle(
                          color: UIConstants.accentGreen,
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
                              Colors.black.withOpacity(0.3),
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

          // Genres
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
                      color: UIConstants.accentGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: UIConstants.accentGreen.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      genre,
                      style: TextStyle(
                        color: UIConstants.accentGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
                  Icons.favorite_border_rounded,
                  color: UIConstants.accentPink,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  fakeLikes,
                  style: TextStyle(
                    color: UIConstants.accentPink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: UIConstants.accentPurple,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '${Random(game.id).nextInt(100) + 10}',
                  style: TextStyle(
                    color: UIConstants.accentPurple,
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

// ============================================
// QUICK ADD BUTTON
// ============================================

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
            backgroundColor: UIConstants.accentRed,
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
          color: UIConstants.accentGreen.withOpacity(0.15),
          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
          border: Border.all(
            color: UIConstants.accentGreen.withOpacity(0.3),
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
                  color: UIConstants.accentGreen,
                ),
              )
            else
              Icon(
                Icons.bookmark_add_rounded,
                size: 16,
                color: UIConstants.accentGreen,
              ),
            const SizedBox(width: 6),
            Text(
              'İstek Listesi',
              style: TextStyle(
                color: UIConstants.accentGreen,
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

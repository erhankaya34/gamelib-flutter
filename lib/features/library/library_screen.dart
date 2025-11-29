import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui_constants.dart';
import '../../data/profile_repository.dart';
import '../../data/steam_library_sync_service.dart';
import '../../data/supabase_client.dart';
import '../../models/game_log.dart';
import '../library/library_controller.dart';
import '../search/game_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(libraryControllerProvider);

    return Scaffold(
      backgroundColor: UIConstants.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _LibraryHeader(),

            // Content
            Expanded(
              child: logsAsync.when(
                data: (logs) {
                  final collectionGames = logs
                      .where((log) =>
                          log.status == PlayStatus.completed ||
                          log.status == PlayStatus.playing ||
                          log.status == PlayStatus.dropped)
                      .toList();

                  collectionGames.sort((a, b) {
                    final aPlaytime = a.playtimeMinutes;
                    final bPlaytime = b.playtimeMinutes;
                    return bPlaytime.compareTo(aPlaytime);
                  });

                  return _CollectionTab(games: collectionGames, ref: ref);
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: UIConstants.accentPurple),
                ),
                error: (error, stack) => _ErrorState(
                  message: error.toString(),
                  onRetry: () => ref.read(libraryControllerProvider.notifier).refresh(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: UIConstants.accentPurple,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'KAYITLARIM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: UIConstants.accentRed,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bir hata oluştu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
              style: FilledButton.styleFrom(
                backgroundColor: UIConstants.accentPurple,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionTab extends StatelessWidget {
  const _CollectionTab({required this.games, required this.ref});

  final List<GameLog> games;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return _EmptyCollectionState();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryControllerProvider.notifier).refresh(),
      color: UIConstants.accentPurple,
      backgroundColor: UIConstants.bgSecondary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final log = games[index];
          return _GameCard(
            log: log,
            index: index,
          ).animate().fadeIn(
            delay: Duration(milliseconds: index * 50),
            duration: 400.ms,
          ).slideX(begin: 0.1, end: 0);
        },
      ),
    );
  }
}

class _EmptyCollectionState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UIConstants.accentPurple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.collections_bookmark_outlined,
              size: 56,
              color: UIConstants.accentPurple.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Koleksiyon Boş',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Oynadığın oyunları buraya ekle',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

class _WishlistTab extends StatelessWidget {
  const _WishlistTab({
    required this.games,
    required this.ref,
    this.onSyncSteamWishlist,
  });

  final List<GameLog> games;
  final WidgetRef ref;
  final VoidCallback? onSyncSteamWishlist;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return _EmptyWishlistState(onSyncSteamWishlist: onSyncSteamWishlist);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryControllerProvider.notifier).refresh(),
      color: UIConstants.accentYellow,
      backgroundColor: UIConstants.bgSecondary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final log = games[index];
          return _GameCard(
            log: log,
            index: index,
            isWishlist: true,
          ).animate().fadeIn(
            delay: Duration(milliseconds: index * 50),
            duration: 400.ms,
          ).slideX(begin: 0.1, end: 0);
        },
      ),
    );
  }
}

class _EmptyWishlistState extends StatelessWidget {
  const _EmptyWishlistState({this.onSyncSteamWishlist});

  final VoidCallback? onSyncSteamWishlist;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UIConstants.accentYellow.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: 56,
              color: UIConstants.accentYellow.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'İstek Listesi Boş',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Oynamak istediğin oyunları ekle',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onSyncSteamWishlist,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Steam İstek Listesini Çek'),
            style: FilledButton.styleFrom(
              backgroundColor: UIConstants.accentSteam,
              foregroundColor: UIConstants.bgSteam,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.log,
    required this.index,
    this.isWishlist = false,
  });

  final GameLog log;
  final int index;
  final bool isWishlist;

  Color get _statusColor {
    if (isWishlist) return UIConstants.accentYellow;
    switch (log.status) {
      case PlayStatus.completed:
        return UIConstants.accentGreen;
      case PlayStatus.playing:
        return UIConstants.accentPurple;
      case PlayStatus.dropped:
        return UIConstants.accentRed;
      default:
        return Colors.grey;
    }
  }

  String get _statusText {
    if (isWishlist) return 'İstek Listesi';
    switch (log.status) {
      case PlayStatus.completed:
        return 'Tamamlandı';
      case PlayStatus.playing:
        return 'Oynuyor';
      case PlayStatus.dropped:
        return 'Bırakıldı';
      default:
        return log.status.name;
    }
  }

  IconData get _statusIcon {
    if (isWishlist) return Icons.favorite_rounded;
    switch (log.status) {
      case PlayStatus.completed:
        return Icons.check_circle_rounded;
      case PlayStatus.playing:
        return Icons.play_circle_rounded;
      case PlayStatus.dropped:
        return Icons.cancel_rounded;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(game: log.game),
          ),
        );
      },
      child: Container(
        height: 140,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: UIConstants.bgSecondary,
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          border: Border.all(
            color: _statusColor.withOpacity(0.2),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          child: Stack(
            children: [
              // Background image
              if (log.game.coverUrlForGrid != null)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: log.game.coverUrlForGrid!,
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
                        UIConstants.bgPrimary.withOpacity(0.95),
                        UIConstants.bgPrimary.withOpacity(0.8),
                        UIConstants.bgPrimary.withOpacity(0.4),
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
                    // Game cover
                    Container(
                      width: 75,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _statusColor.withOpacity(0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: log.game.coverUrlForGrid != null
                            ? CachedNetworkImage(
                                imageUrl: log.game.coverUrlForGrid!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _GamePlaceholder(),
                              )
                            : _GamePlaceholder(),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Game info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Game name
                          Text(
                            log.game.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 8),

                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _statusColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _statusIcon,
                                  size: 14,
                                  color: _statusColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _statusText,
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Rating or playtime
                          if (log.rating != null || log.playtimeMinutes > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  if (log.rating != null) ...[
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: UIConstants.accentYellow,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${log.rating}/10',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  if (log.playtimeMinutes > 0) ...[
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 14,
                                      color: UIConstants.accentSteam,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${log.playtimeHours.toStringAsFixed(1)}s',
                                      style: TextStyle(
                                        color: UIConstants.accentSteam,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Chevron
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withOpacity(0.3),
                      size: 24,
                    ),
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

class _GamePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: UIConstants.bgTertiary,
      child: const Center(
        child: Icon(
          Icons.sports_esports_rounded,
          color: UIConstants.accentPurple,
          size: 28,
        ),
      ),
    );
  }
}

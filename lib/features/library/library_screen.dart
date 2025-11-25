/// LibraryScreen - Oyun Kütüphanesi Ekranı
///
/// 2 sekme içerir:
/// 1. Koleksiyon (Collection) - Oynadığın oyunlar (completed, playing, dropped)
/// 2. İstek Listesi (Wishlist) - Oynamak istediğin oyunlar (wishlist)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/game_log.dart';
import '../library/library_controller.dart';
import '../search/game_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(libraryControllerProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kütüphane'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.collections_bookmark),
                text: 'Koleksiyon',
              ),
              Tab(
                icon: Icon(Icons.favorite_border),
                text: 'İstek Listesi',
              ),
            ],
          ),
        ),
        body: logsAsync.when(
          // ✅ Data yüklendi - oyunları filtrele ve göster
          data: (logs) {
            // Koleksiyon: completed, playing, dropped
            final collectionGames = logs
                .where((log) =>
                    log.status == PlayStatus.completed ||
                    log.status == PlayStatus.playing ||
                    log.status == PlayStatus.dropped)
                .toList();

            // İstek Listesi: wishlist
            final wishlistGames =
                logs.where((log) => log.status == PlayStatus.wishlist).toList();

            return TabBarView(
              children: [
                // Koleksiyon Tab
                _CollectionTab(games: collectionGames, ref: ref),
                // Wishlist Tab
                _WishlistTab(games: wishlistGames, ref: ref),
              ],
            );
          },

          // ⏳ Yükleniyor
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Kütüphane yükleniyor...'),
              ],
            ),
          ),

          // ❌ Hata oluştu
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Kütüphane yüklenemedi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(libraryControllerProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// COLLECTION TAB (Koleksiyon)
// ============================================

class _CollectionTab extends StatelessWidget {
  const _CollectionTab({required this.games, required this.ref});

  final List<GameLog> games;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
              ),
              child: Icon(
                Icons.collections_bookmark_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(duration: 2.seconds, begin: const Offset(0.95, 0.95), end: const Offset(1.0, 1.0)),
            const SizedBox(height: 20),
            const Text(
              'Koleksiyonun boş',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 6),
                Text(
                  'Oynadığın oyunları ekle',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryControllerProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(pagePadding),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final log = games[index];
          return _ModernGameCard(
            log: log,
            statusColor: _getStatusColor(log.status),
            statusText: _getStatusText(log.status),
            statusIcon: _getStatusIcon(log.status),
          );
        },
      ),
    );
  }

  Color _getStatusColor(PlayStatus status) {
    switch (status) {
      case PlayStatus.completed:
        return Colors.green;
      case PlayStatus.playing:
        return Colors.blue;
      case PlayStatus.dropped:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(PlayStatus status) {
    switch (status) {
      case PlayStatus.completed:
        return 'Tamamlandı';
      case PlayStatus.playing:
        return 'Oynuyor';
      case PlayStatus.dropped:
        return 'Bırakıldı';
      default:
        return status.name;
    }
  }

  IconData _getStatusIcon(PlayStatus status) {
    switch (status) {
      case PlayStatus.completed:
        return Icons.check_circle;
      case PlayStatus.playing:
        return Icons.play_circle;
      case PlayStatus.dropped:
        return Icons.cancel;
      default:
        return Icons.circle;
    }
  }
}

// ============================================
// WISHLIST TAB (İstek Listesi)
// ============================================

class _WishlistTab extends StatelessWidget {
  const _WishlistTab({required this.games, required this.ref});

  final List<GameLog> games;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
              ),
              child: Icon(
                Icons.favorite_border,
                size: 48,
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                  duration: 2.seconds,
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.05, 1.05),
                ),
            const SizedBox(height: 20),
            const Text(
              'İstek listesi boş',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 6),
                Text(
                  'Oynamak istediğin oyunları ekle',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryControllerProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(pagePadding),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final log = games[index];
          return _ModernGameCard(
            log: log,
            statusColor: Colors.orange,
            statusText: 'İstek Listesi',
            statusIcon: Icons.favorite,
          );
        },
      ),
    );
  }
}

// ============================================
// MODERN GAME CARD WIDGET
// ============================================

class _ModernGameCard extends StatelessWidget {
  const _ModernGameCard({
    required this.log,
    required this.statusColor,
    required this.statusText,
    required this.statusIcon,
  });

  final GameLog log;
  final Color statusColor;
  final String statusText;
  final IconData statusIcon;

  // Convert cover URL to high resolution
  String? get _highResCoverUrl {
    final url = log.game.coverUrl;
    if (url == null) return null;

    // Replace thumbnail and cover_big with 1080p for better quality
    return url
        .replaceAll('/t_thumb/', '/t_1080p/')
        .replaceAll('/t_cover_big/', '/t_1080p/')
        .replaceAll('/t_cover_small/', '/t_1080p/');
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
        height: 160,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image (high resolution)
              if (_highResCoverUrl != null)
                CachedNetworkImage(
                  imageUrl: _highResCoverUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(
                      Icons.videogame_asset,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                )
              else
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(
                    Icons.videogame_asset,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.3),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Left side - Game info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Game title
                          Text(
                            log.game.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusIcon,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Rating
                          if (log.rating != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${log.rating}/10',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Notes preview
                          if (log.notes != null && log.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              log.notes!,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 12,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Right side - Chevron indicator
                    const SizedBox(width: 12),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withOpacity(0.7),
                      size: 28,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
    );
  }
}

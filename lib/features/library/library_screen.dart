/// LibraryScreen - Oyun Kütüphanesi Ekranı
///
/// 2 sekme içerir:
/// 1. Koleksiyon (Collection) - Oynadığın oyunlar (completed, playing, dropped)
/// 2. İstek Listesi (Wishlist) - Oynamak istediğin oyunlar (wishlist)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.collections_bookmark_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Koleksiyonun boş',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Oynadığın oyunları ekle',
              style: TextStyle(fontSize: 14, color: Colors.grey),
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
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GameDetailScreen(game: log.game),
                  ),
                );
              },
              contentPadding: const EdgeInsets.all(12),
              leading: log.game.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: log.game.coverUrl!,
                        width: 60,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 80,
                          color: AppTheme.darkGray,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          print('🔴 Image load error for ${log.game.name}: $error');
                          print('🔴 URL: $url');
                          return Container(
                            width: 60,
                            height: 80,
                            color: Colors.grey[800],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          );
                        },
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 80,
                      color: Colors.grey[800],
                      child: const Icon(Icons.videogame_asset, color: Colors.grey),
                    ),
              title: Text(
                log.game.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(log.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(log.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Rating (prominent!)
                  if (log.rating != null)
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${log.rating}/10',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  // Notes
                  if (log.notes != null && log.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      log.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'İstek listesi boş',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Oynamak istediğin oyunları ekle',
              style: TextStyle(fontSize: 14, color: Colors.grey),
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
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GameDetailScreen(game: log.game),
                  ),
                );
              },
              contentPadding: const EdgeInsets.all(12),
              leading: log.game.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: log.game.coverUrl!,
                        width: 60,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 80,
                          color: AppTheme.darkGray,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          print('🔴 Image load error for ${log.game.name}: $error');
                          print('🔴 URL: $url');
                          return Container(
                            width: 60,
                            height: 80,
                            color: Colors.grey[800],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          );
                        },
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 80,
                      color: Colors.grey[800],
                      child: const Icon(Icons.videogame_asset, color: Colors.grey),
                    ),
              title: Text(
                log.game.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Wishlist badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '❤️ Oynamak istiyorum',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Notes
                  if (log.notes != null && log.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      log.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

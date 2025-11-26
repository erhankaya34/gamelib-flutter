import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/igdb_client.dart';
import '../../data/supabase_client.dart';
import '../../models/game.dart';
import '../search/game_detail_screen.dart';

/// Provider for user's favorite genres
final userGenresProvider = FutureProvider<List<String>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  try {
    final results = await supabase
        .from('user_genres')
        .select('genre_name')
        .eq('user_id', userId);

    return results.map((r) => r['genre_name'] as String).toList();
  } catch (e) {
    return [];
  }
});

/// Provider for indie games
final indieGamesProvider = FutureProvider<List<Game>>((ref) async {
  final genresAsync = await ref.watch(userGenresProvider.future);
  final client = ref.read(igdbClientProvider);
  return client.fetchIndieGames(genresAsync);
});

/// Discover screen
/// Shows indie games personalized to user's favorite genres
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indieGamesAsync = ref.watch(indieGamesProvider);

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: SafeArea(
        child: Column(
          children: [
            // Header with mint gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.mint.withOpacity(0.2),
                    AppTheme.rose.withOpacity(0.2),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.explore,
                        color: AppTheme.mint,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Keşfet',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cream,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bağımsız oyunları keşfet',
                    style: TextStyle(
                      color: AppTheme.lavenderGray,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Indie games grid
            Expanded(
              child: indieGamesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppTheme.mint),
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
                          'Oyunlar yüklenemedi',
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
                data: (games) {
                  if (games.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videogame_asset_off,
                              size: 80,
                              color: AppTheme.lavenderGray.withOpacity(0.5),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Henüz oyun bulunamadı',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.cream,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Daha sonra tekrar dene!',
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
                      ref.invalidate(indieGamesProvider);
                    },
                    color: AppTheme.mint,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        return _IndieGameCard(game: games[index]);
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

/// Indie game card with beautiful design
class _IndieGameCard extends StatelessWidget {
  const _IndieGameCard({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.mint.withOpacity(0.1),
            AppTheme.rose.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: AppTheme.mint.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GameDetailScreen(game: game),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
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
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: Image.network(
                        game.coverUrl!.replaceAll('t_thumb', 't_cover_big'),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.darkSlate,
                          child: Center(
                            child: Icon(
                              Icons.videogame_asset,
                              color: AppTheme.lavenderGray,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.darkSlate,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.videogame_asset,
                          color: AppTheme.lavenderGray,
                          size: 48,
                        ),
                      ),
                    ),

                  // Indie badge
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
                          colors: [AppTheme.mint, AppTheme.rose],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Indie',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
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
                      color: AppTheme.cream,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Genres
                  if (game.genres.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: game.genres.take(2).map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.mint.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppTheme.mint.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            genre,
                            style: TextStyle(
                              color: AppTheme.mint,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 6),

                  // Rating
                  if (game.aggregatedRating != null)
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: AppTheme.peach,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          game.aggregatedRating!.toStringAsFixed(0),
                          style: TextStyle(
                            color: AppTheme.peach,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '/100',
                          style: TextStyle(
                            color: AppTheme.lavenderGray,
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

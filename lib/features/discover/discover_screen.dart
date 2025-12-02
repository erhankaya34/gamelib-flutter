import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger.dart';
import '../../core/ui_constants.dart';
import '../../data/igdb_client.dart';
import '../../models/game.dart';
import '../search/game_detail_screen.dart';
import '../steam_library/steam_library_provider.dart';

/// Provider for user's top genres based on most played games
final topPlayedGenresProvider = FutureProvider<List<String>>((ref) async {
  try {
    final steamLibrary = await ref.watch(steamLibraryProvider.future);

    if (steamLibrary.isEmpty) {
      // Fallback to popular IGDB genres if no library
      return ['Action', 'Adventure', 'Role-playing (RPG)', 'Shooter'];
    }

    // Sort by playtime and get top 10 games
    final sortedGames = [...steamLibrary]
      ..sort((a, b) => b.playtimeMinutes.compareTo(a.playtimeMinutes));

    final topGames = sortedGames.take(10).toList();

    // Count genre occurrences weighted by playtime
    final genreScores = <String, double>{};

    for (final log in topGames) {
      final playtimeWeight = log.playtimeMinutes.toDouble();
      for (final genre in log.game.genres) {
        genreScores[genre] = (genreScores[genre] ?? 0) + playtimeWeight;
      }
    }

    // Sort by score and get top genres
    final sortedGenres = genreScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topGenres = sortedGenres.take(5).map((e) => e.key).toList();

    if (topGenres.isEmpty) {
      return ['Action', 'Adventure', 'Role-playing (RPG)', 'Shooter'];
    }

    return topGenres;
  } catch (e) {
    // Fallback if Steam library fails
    return ['Action', 'Adventure', 'Role-playing (RPG)', 'Shooter'];
  }
});

/// Provider for indie games based on user's top played genres
/// Filters out games already in user's Steam library
final personalizedIndieGamesProvider = FutureProvider<List<Game>>((ref) async {
  final topGenres = await ref.watch(topPlayedGenresProvider.future);
  final client = ref.read(igdbClientProvider);

  appLogger.info('Discover: Top genres = $topGenres');

  // Try to get owned game IDs, but don't fail if Steam library is unavailable
  Set<int> ownedGameIds = {};
  try {
    final steamLibrary = await ref.watch(steamLibraryProvider.future);
    ownedGameIds = steamLibrary.map((log) => log.game.id).toSet();
    appLogger.info('Discover: Owned game IDs count = ${ownedGameIds.length}');
  } catch (e) {
    appLogger.info('Discover: Steam library unavailable, continuing without filter');
  }

  // Fetch indie games
  appLogger.info('Discover: Fetching indie games...');
  final indieGames = await client.fetchIndieGames(topGenres);
  appLogger.info('Discover: Fetched ${indieGames.length} indie games from IGDB');

  // Filter out games already in library
  final filteredGames = indieGames.where((game) {
    // Exclude games already owned
    if (ownedGameIds.contains(game.id)) return false;
    return true;
  }).toList();

  appLogger.info('Discover: After filtering = ${filteredGames.length} games');
  return filteredGames;
});

/// Discover screen
/// Shows indie games personalized based on user's most played game genres
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indieGamesAsync = ref.watch(personalizedIndieGamesProvider);
    final topGenresAsync = ref.watch(topPlayedGenresProvider);

    return Scaffold(
      backgroundColor: UIConstants.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _DiscoverHeader(
              onRefresh: () {
                ref.invalidate(personalizedIndieGamesProvider);
                ref.invalidate(topPlayedGenresProvider);
              },
            ),

            // Top genres display
            topGenresAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (genres) => _GenreChipsRow(genres: genres),
            ),

            // Indie games grid
            Expanded(
              child: indieGamesAsync.when(
                loading: () => const LoadingState(message: 'Oyunlar yükleniyor...'),
                error: (e, _) => _ErrorState(
                  message: 'Oyunlar yüklenemedi: $e',
                  onRetry: () => ref.invalidate(personalizedIndieGamesProvider),
                ),
                data: (games) {
                  if (games.isEmpty) {
                    return const EmptyState(
                      icon: Icons.videogame_asset_off_rounded,
                      title: 'Henüz oyun bulunamadı',
                      subtitle: 'Daha sonra tekrar dene!',
                      iconColor: UIConstants.accentGreen,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(personalizedIndieGamesProvider);
                    },
                    color: UIConstants.accentGreen,
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
                        return _IndieGameCard(game: games[index])
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
        ),
      ),
    );
  }
}

// ============================================
// DISCOVER HEADER
// ============================================

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({required this.onRefresh});

  final VoidCallback onRefresh;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: UIConstants.greenGradient),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'KEŞFET',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onRefresh,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: UIConstants.accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                    border: Border.all(
                      color: UIConstants.accentGreen.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: UIConstants.accentGreen,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UIConstants.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              border: Border.all(
                color: UIConstants.accentGreen.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: UIConstants.greenGradient),
                    borderRadius: BorderRadius.circular(10),
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
                      const Text(
                        'En Çok Oynadığın Türlerden',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// GENRE CHIPS ROW
// ============================================

class _GenreChipsRow extends StatelessWidget {
  const _GenreChipsRow({required this.genres});

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
                final gradients = [
                  UIConstants.greenGradient,
                  UIConstants.purpleGradient,
                  UIConstants.violetGradient,
                  UIConstants.yellowGradient,
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
// INDIE GAME CARD
// ============================================

class _IndieGameCard extends StatelessWidget {
  const _IndieGameCard({required this.game});

  final Game game;

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
          color: UIConstants.bgSecondary,
          border: Border.all(
            color: UIConstants.accentGreen.withOpacity(0.2),
            width: 1,
          ),
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
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: UIConstants.accentGreen,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: UIConstants.bgTertiary,
                          child: Center(
                            child: Icon(
                              Icons.videogame_asset_rounded,
                              color: Colors.white.withOpacity(0.3),
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: UIConstants.bgTertiary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(UIConstants.radiusLarge),
                          topRight: Radius.circular(UIConstants.radiusLarge),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.videogame_asset_rounded,
                          color: Colors.white.withOpacity(0.3),
                          size: 40,
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
                        gradient: const LinearGradient(
                          colors: UIConstants.greenGradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: UIConstants.accentGreen.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
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
                      children: game.genres.take(2).map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: UIConstants.accentGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: UIConstants.accentGreen.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            genre,
                            style: TextStyle(
                              color: UIConstants.accentGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 8),

                  // Rating
                  if (game.aggregatedRating != null)
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: UIConstants.accentYellow,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          game.aggregatedRating!.toStringAsFixed(0),
                          style: TextStyle(
                            color: UIConstants.accentYellow,
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

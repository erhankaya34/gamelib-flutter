import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/logger.dart';
import '../models/game.dart';
import '../models/game_log.dart';
import 'game_repository.dart';
import 'igdb_steam_matcher.dart';
import 'steam_service.dart';

/// Result of a Steam library sync operation
class SyncResult {
  const SyncResult({
    required this.totalGames,
    required this.matched,
    required this.unmatched,
    required this.imported,
    required this.updated,
    required this.failed,
  });

  final int totalGames;
  final int matched;
  final int unmatched;
  final int imported;
  final int updated;
  final int failed;

  @override
  String toString() {
    return 'SyncResult(total: $totalGames, matched: $matched, '
        'unmatched: $unmatched, imported: $imported, updated: $updated, failed: $failed)';
  }
}

/// Service for syncing Steam library to GameLib
/// Orchestrates Steam API calls, IGDB matching, and database operations
class SteamLibrarySyncService {
  SteamLibrarySyncService({
    required this.steamService,
    required this.matcher,
    required this.gameRepository,
  });

  final SteamService steamService;
  final IgdbSteamMatcher matcher;
  final GameRepository gameRepository;

  static const _uuid = Uuid();

  /// Perform full library sync
  /// Fetches all Steam games, matches with IGDB, and imports to database
  Future<SyncResult> syncFullLibrary(String userId, String steamId) async {
    appLogger.info('Steam Sync: Starting full library sync for user $userId');

    try {
      // Step 1: Fetch all Steam games
      appLogger.info('Steam Sync: Step 1/3 - Fetching Steam games');
      final steamGames = await steamService.fetchOwnedGamesDetailed(steamId);
      appLogger.info('Steam Sync: Fetched ${steamGames.length} Steam games');

      if (steamGames.isEmpty) {
        appLogger.info('Steam Sync: No games found, sync complete');
        return SyncResult(
          totalGames: 0,
          matched: 0,
          unmatched: 0,
          imported: 0,
          updated: 0,
          failed: 0,
        );
      }

      // Step 2: Match with IGDB
      appLogger.info('Steam Sync: Step 2/3 - Matching with IGDB');
      final matches = await matcher.matchMultipleSteamGames(steamGames);
      final matchedCount = matches.values.where((g) => g != null).length;
      final unmatchedCount = steamGames.length - matchedCount;
      appLogger.info('Steam Sync: Matched $matchedCount, unmatched $unmatchedCount');

      // Step 3: Import to database (with aggressive parallel processing)
      appLogger.info('Steam Sync: Step 3/3 - Importing to database');
      var importedCount = 0;
      var updatedCount = 0;
      var failedCount = 0;

      // First, get all existing games in one query for faster lookups
      final existingGames = await _getExistingGames(userId);

      // Process games in large parallel batches for maximum speed
      const batchSize = 20;
      for (var i = 0; i < steamGames.length; i += batchSize) {
        final batch = steamGames.skip(i).take(batchSize).toList();

        // Process entire batch in parallel
        final results = await Future.wait(
          batch.map((steamGame) async {
            try {
              final igdbGame = matches[steamGame.appId];

              // Lookup existing ID from pre-fetched maps (no DB query needed!)
              String? existingId = existingGames.bySteamAppId[steamGame.appId];
              if (existingId == null && igdbGame != null) {
                existingId = existingGames.byGameId[igdbGame.id];
              }

              final success = await _importSteamGameFast(
                userId: userId,
                steamGame: steamGame,
                igdbGame: igdbGame,
                existingId: existingId,
              );

              return {
                'success': success,
                'exists': existingId != null,
                'name': steamGame.name,
              };
            } catch (e, stack) {
              appLogger.error(
                'Steam Sync: Failed to import ${steamGame.name}',
                e,
                stack,
              );
              return {
                'success': false,
                'exists': false,
                'name': steamGame.name,
              };
            }
          }),
        );

        // Count results
        for (final result in results) {
          if (result['success'] as bool) {
            if (result['exists'] as bool) {
              updatedCount++;
            } else {
              importedCount++;
            }
          } else {
            failedCount++;
          }
        }

        // Log progress
        final processed = i + batch.length;
        appLogger.info('Steam Sync: Processed $processed/${steamGames.length} games');
      }

      final result = SyncResult(
        totalGames: steamGames.length,
        matched: matchedCount,
        unmatched: unmatchedCount,
        imported: importedCount,
        updated: updatedCount,
        failed: failedCount,
      );

      appLogger.info('Steam Sync: Complete - $result');
      return result;
    } catch (e, stack) {
      appLogger.error('Steam Sync: Failed to sync library', e, stack);
      rethrow;
    }
  }

  /// Fast import - existing ID is pre-fetched, no DB query needed
  /// Returns true if successful, false otherwise
  Future<bool> _importSteamGameFast({
    required String userId,
    required SteamGame steamGame,
    required Game? igdbGame,
    required String? existingId,
  }) async {
    try {
      // Create Game object from IGDB or Steam data
      final game = igdbGame ?? _createGameFromSteam(steamGame);

      if (existingId != null) {
        // Game exists - only update Steam-specific fields to preserve user data
        final updateData = <String, dynamic>{
          'steam_app_id': steamGame.appId,
          'playtime_minutes': steamGame.playtimeMinutes,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        // If IGDB match found, update game metadata
        if (igdbGame != null) {
          updateData['game_name'] = game.name;
          updateData['game_cover_url'] = game.coverUrl;
          updateData['game_data'] = game.toMap();
        }

        await gameRepository.supabase
            .from('game_logs')
            .update(updateData)
            .eq('id', existingId);
      } else {
        // New game - do full insert
        final gameLog = GameLog(
          id: _uuid.v4(),
          game: game,
          status: PlayStatus.playing,
          source: 'steam',
          steamAppId: steamGame.appId,
          playtimeMinutes: steamGame.playtimeMinutes,
          lastSyncedAt: DateTime.now(),
        );

        await gameRepository.upsertGameLog(userId, gameLog);
      }

      return true;
    } catch (e, stack) {
      appLogger.error(
        'Steam Sync: Failed to import ${steamGame.name}',
        e,
        stack,
      );
      return false;
    }
  }

  /// Create a Game object from Steam data (when IGDB match not found)
  /// Uses high-resolution Steam images for covers and screenshots
  Game _createGameFromSteam(SteamGame steamGame) {
    // Use header.jpg as primary - it exists for all Steam games
    // library_600x900.jpg is better quality but doesn't exist for all games
    const cdnBase = 'https://steamcdn-a.akamaihd.net/steam/apps';
    final coverUrl = '$cdnBase/${steamGame.appId}/header.jpg';

    return Game(
      id: steamGame.appId,
      name: steamGame.name,
      coverUrl: coverUrl,
      // Generate Steam screenshot URLs
      screenshotUrls: _generateSteamScreenshots(steamGame.appId),
      summary: null,
      platforms: const ['PC (Microsoft Windows)'],
      genres: const [],
      aggregatedRating: null,
      userRating: null,
      ratingCount: null,
      metacriticScore: null,
      releaseDate: null,
    );
  }

  /// Generate Steam screenshot URLs for a game
  /// Steam stores screenshots with predictable naming patterns
  List<String> _generateSteamScreenshots(int appId) {
    const cdnBase = 'https://steamcdn-a.akamaihd.net/steam/apps';
    // Generate multiple screenshot URLs - Steam typically has 4-10 screenshots
    return [
      '$cdnBase/$appId/ss_1.1920x1080.jpg',
      '$cdnBase/$appId/ss_2.1920x1080.jpg',
      '$cdnBase/$appId/ss_3.1920x1080.jpg',
      '$cdnBase/$appId/ss_4.1920x1080.jpg',
    ];
  }

  /// Check if a Steam game already exists in the database
  /// Checks both by steam_app_id AND by game_id (IGDB ID) to handle all cases
  Future<String?> _getExistingGameLogId(String userId, int steamAppId, {int? gameId}) async {
    try {
      // First try to find by steam_app_id
      var response = await gameRepository.supabase
          .from('game_logs')
          .select('id')
          .eq('user_id', userId)
          .eq('steam_app_id', steamAppId)
          .maybeSingle();

      if (response != null) {
        return response['id'] as String?;
      }

      // If not found and we have a game_id, try to find by game_id
      // This handles cases where the same game exists from manual entry
      if (gameId != null) {
        response = await gameRepository.supabase
            .from('game_logs')
            .select('id')
            .eq('user_id', userId)
            .eq('game_id', gameId)
            .maybeSingle();

        return response?['id'] as String?;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get all existing games for a user in one query
  /// Returns maps of Steam App ID -> Game Log ID and Game ID -> Game Log ID
  Future<({Map<int, String> bySteamAppId, Map<int, String> byGameId})> _getExistingGames(String userId) async {
    try {
      final response = await gameRepository.supabase
          .from('game_logs')
          .select('id, steam_app_id, game_id')
          .eq('user_id', userId);

      final bySteamAppId = <int, String>{};
      final byGameId = <int, String>{};

      for (final row in response as List) {
        final id = row['id'] as String;
        final steamAppId = row['steam_app_id'] as int?;
        final gameId = row['game_id'] as int?;

        if (steamAppId != null) {
          bySteamAppId[steamAppId] = id;
        }
        if (gameId != null) {
          byGameId[gameId] = id;
        }
      }

      appLogger.info('Steam Sync: Found ${bySteamAppId.length} by Steam ID, ${byGameId.length} by game ID');
      return (bySteamAppId: bySteamAppId, byGameId: byGameId);
    } catch (e) {
      appLogger.warning('Steam Sync: Failed to fetch existing games: $e');
      return (bySteamAppId: <int, String>{}, byGameId: <int, String>{});
    }
  }

  /// Sync Steam wishlist to collection wishlist
  /// Fetches Steam wishlist and imports games with 'wishlist' status
  Future<SyncResult> syncWishlist(String userId, String steamId) async {
    appLogger.info('Steam Sync: Starting wishlist sync for user $userId');

    try {
      // Step 1: Fetch Steam wishlist
      appLogger.info('Steam Sync: Fetching Steam wishlist');
      final wishlistItems = await steamService.fetchWishlist(steamId);
      appLogger.info('Steam Sync: Fetched ${wishlistItems.length} wishlist items');

      if (wishlistItems.isEmpty) {
        return const SyncResult(
          totalGames: 0,
          matched: 0,
          unmatched: 0,
          imported: 0,
          updated: 0,
          failed: 0,
        );
      }

      // Step 2: Convert to SteamGame format for IGDB matching
      final steamGames = wishlistItems.map((item) => SteamGame(
        appId: item.appId,
        name: item.name,
        playtimeMinutes: 0,
        headerUrl: item.headerUrl,
        libraryCapsuleUrl: 'https://steamcdn-a.akamaihd.net/steam/apps/${item.appId}/library_600x900.jpg',
        libraryHeroUrl: 'https://steamcdn-a.akamaihd.net/steam/apps/${item.appId}/library_hero.jpg',
        capsuleLargeUrl: 'https://steamcdn-a.akamaihd.net/steam/apps/${item.appId}/capsule_616x353.jpg',
      )).toList();

      // Step 3: Match with IGDB (fast batch lookup)
      appLogger.info('Steam Sync: Matching wishlist with IGDB');
      final matches = await matcher.matchMultipleSteamGames(
        steamGames,
        useFuzzyFallback: false, // Skip slow fuzzy for wishlist
      );
      final matchedCount = matches.values.where((g) => g != null).length;

      // Step 4: Import to database with wishlist status
      appLogger.info('Steam Sync: Importing wishlist to database');
      var importedCount = 0;
      var updatedCount = 0;
      var failedCount = 0;

      for (final item in wishlistItems) {
        try {
          final igdbGame = matches[item.appId];

          // Create Game object with Steam screenshots
          // Use header.jpg - it exists for all Steam games
          final game = igdbGame ?? Game(
            id: item.appId,
            name: item.name,
            coverUrl: 'https://steamcdn-a.akamaihd.net/steam/apps/${item.appId}/header.jpg',
            screenshotUrls: _generateSteamScreenshots(item.appId),
            summary: null,
            platforms: const ['PC (Microsoft Windows)'],
            genres: const [],
            aggregatedRating: null,
            userRating: null,
            ratingCount: null,
            metacriticScore: null,
            releaseDate: null,
          );

          // Check if game already exists (any status)
          final existingId = await _getExistingGameLogId(
            userId,
            item.appId,
            gameId: game.id,
          );

          if (existingId != null) {
            // Game already exists - skip (don't overwrite user's status)
            updatedCount++;
            continue;
          }

          // New game - insert with wishlist status
          final gameLog = GameLog(
            id: _uuid.v4(),
            game: game,
            status: PlayStatus.wishlist,
            source: 'steam_wishlist',
            steamAppId: item.appId,
            playtimeMinutes: 0,
            lastSyncedAt: DateTime.now(),
          );

          await gameRepository.upsertGameLog(userId, gameLog);
          importedCount++;

          appLogger.info('Steam Sync: Imported wishlist item ${item.name}');
        } catch (e) {
          appLogger.warning('Steam Sync: Failed to import wishlist item ${item.name}: $e');
          failedCount++;
        }
      }

      final result = SyncResult(
        totalGames: wishlistItems.length,
        matched: matchedCount,
        unmatched: wishlistItems.length - matchedCount,
        imported: importedCount,
        updated: updatedCount,
        failed: failedCount,
      );

      appLogger.info('Steam Sync: Wishlist sync complete - $result');
      return result;
    } catch (e, stack) {
      appLogger.error('Steam Sync: Failed to sync wishlist', e, stack);
      rethrow;
    }
  }

  /// Sync only playtimes (incremental update)
  /// Faster than full sync, only updates playtime data
  Future<SyncResult> syncPlaytimes(String userId, String steamId) async {
    appLogger.info('Steam Sync: Starting playtime sync for user $userId');

    try {
      // Fetch Steam games
      final steamGames = await steamService.fetchOwnedGamesDetailed(steamId);

      // Pre-fetch all existing games with steam_app_id in one query
      final existingGames = await _getExistingGames(userId);

      var updatedCount = 0;
      var failedCount = 0;
      final now = DateTime.now().toIso8601String();

      // Process in parallel batches
      const batchSize = 20;
      for (var i = 0; i < steamGames.length; i += batchSize) {
        final batch = steamGames.skip(i).take(batchSize).toList();

        final results = await Future.wait(
          batch.map((steamGame) async {
            try {
              final existingId = existingGames.bySteamAppId[steamGame.appId];

              if (existingId != null) {
                await gameRepository.supabase.from('game_logs').update({
                  'playtime_minutes': steamGame.playtimeMinutes,
                  'last_synced_at': now,
                }).eq('id', existingId);
                return true;
              }
              return false;
            } catch (e) {
              return false;
            }
          }),
        );

        updatedCount += results.where((r) => r).length;
        failedCount += results.where((r) => !r).length;
      }

      final result = SyncResult(
        totalGames: steamGames.length,
        matched: 0,
        unmatched: 0,
        imported: 0,
        updated: updatedCount,
        failed: failedCount,
      );

      appLogger.info('Steam Sync: Playtime sync complete - $result');
      return result;
    } catch (e, stack) {
      appLogger.error('Steam Sync: Failed to sync playtimes', e, stack);
      rethrow;
    }
  }
}

/// Provider for SteamLibrarySyncService
final steamLibrarySyncServiceProvider = Provider<SteamLibrarySyncService>((ref) {
  return SteamLibrarySyncService(
    steamService: ref.watch(steamServiceProvider),
    matcher: ref.watch(igdbSteamMatcherProvider),
    gameRepository: ref.watch(gameRepositoryProvider),
  );
});

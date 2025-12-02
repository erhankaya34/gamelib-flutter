import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/logger.dart';
import '../models/game.dart';
import '../models/game_log.dart';
import 'game_repository.dart';
import 'igdb_client.dart';
import 'playstation_auth_service.dart';
import 'playstation_service.dart';
import 'profile_repository.dart';

/// Result of a PlayStation library sync operation
class PSNSyncResult {
  const PSNSyncResult({
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
    return 'PSNSyncResult(total: $totalGames, matched: $matched, '
        'unmatched: $unmatched, imported: $imported, updated: $updated, failed: $failed)';
  }
}

/// Service for syncing PlayStation library to GameLib
class PlayStationLibrarySyncService {
  PlayStationLibrarySyncService({
    required this.playstationService,
    required this.playstationAuthService,
    required this.igdbClient,
    required this.gameRepository,
    required this.profileRepository,
  });

  final PlayStationService playstationService;
  final PlayStationAuthService playstationAuthService;
  final IgdbClient igdbClient;
  final GameRepository gameRepository;
  final ProfileRepository profileRepository;

  static const _uuid = Uuid();

  /// Perform full library sync
  /// Fetches all PlayStation trophy titles, matches with IGDB, and imports to database
  Future<PSNSyncResult> syncFullLibrary(
    String userId,
    String accessToken,
    String refreshToken,
  ) async {
    appLogger.info('PSN Sync: Starting full library sync for user $userId');

    // Working token that may be refreshed
    var currentAccessToken = accessToken;
    var currentRefreshToken = refreshToken;

    try {
      // Step 0: Try to refresh token first (PSN tokens expire after 1 hour)
      appLogger.info('PSN Sync: Step 0 - Attempting token refresh');
      final newTokens = await playstationAuthService.refreshTokens(refreshToken);
      if (newTokens != null) {
        appLogger.info('PSN Sync: Token refreshed successfully');
        currentAccessToken = newTokens.accessToken;
        currentRefreshToken = newTokens.refreshToken;
      } else {
        appLogger.warning('PSN Sync: Token refresh failed, using existing token');
      }

      // Save tokens to profile (new or existing)
      await _savePsnTokens(userId, currentAccessToken, currentRefreshToken);

      // Step 1: Get PSN profile info
      appLogger.info('PSN Sync: Step 1/5 - Getting profile');
      final profile = await playstationService.getUserProfile(currentAccessToken);
      if (profile != null) {
        await _savePsnProfile(userId, profile);
      }

      // Step 2: Fetch all trophy titles
      appLogger.info('PSN Sync: Step 2/5 - Fetching trophy titles');
      var psnGames = await playstationService.getAllUserTitles(currentAccessToken);
      appLogger.info('PSN Sync: Fetched ${psnGames.length} PSN games');

      if (psnGames.isEmpty) {
        appLogger.info('PSN Sync: No games found, sync complete');
        return const PSNSyncResult(
          totalGames: 0,
          matched: 0,
          unmatched: 0,
          imported: 0,
          updated: 0,
          failed: 0,
        );
      }

      // Step 2.5: Fetch playtime data (keyed by normalized game name)
      appLogger.info('PSN Sync: Step 2.5/5 - Fetching playtime data');
      final playtimeByName = await playstationService.getPlaytimeData(currentAccessToken);
      appLogger.info('PSN Sync: Got playtime for ${playtimeByName.length} games');

      // Step 3: Match with IGDB
      appLogger.info('PSN Sync: Step 3/4 - Matching with IGDB');
      final matches = await _matchWithIgdb(psnGames);
      final matchedCount = matches.values.where((g) => g != null).length;
      final unmatchedCount = psnGames.length - matchedCount;
      appLogger.info('PSN Sync: Matched $matchedCount, unmatched $unmatchedCount');

      // Step 4: Import to database
      appLogger.info('PSN Sync: Step 4/5 - Importing to database');
      var importedCount = 0;
      var updatedCount = 0;
      var failedCount = 0;

      // Get existing PSN games
      final existingGamesMap = await _getExistingPsnGames(userId);

      // Process games in batches
      const batchSize = 10;
      for (var i = 0; i < psnGames.length; i += batchSize) {
        final batch = psnGames.skip(i).take(batchSize).toList();

        final results = await Future.wait(
          batch.map((psnGame) async {
            try {
              final igdbGame = matches[psnGame.titleId];
              final exists = existingGamesMap.containsKey(psnGame.titleId);

              // Get playtime for this game (by normalized name)
              final normalizedName = _normalizeGameName(psnGame.name);
              final playtime = playtimeByName[normalizedName] ?? 0;

              final success = await _importPsnGame(
                userId: userId,
                psnGame: psnGame,
                igdbGame: igdbGame,
                playtimeMinutes: playtime,
              );

              return {
                'success': success,
                'exists': exists,
                'name': psnGame.name,
              };
            } catch (e, stack) {
              appLogger.error(
                'PSN Sync: Failed to import ${psnGame.name}',
                e,
                stack,
              );
              return {
                'success': false,
                'exists': false,
                'name': psnGame.name,
              };
            }
          }),
        );

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

        final processed = i + batch.length;
        appLogger.info('PSN Sync: Processed $processed/${psnGames.length} games');
      }

      final result = PSNSyncResult(
        totalGames: psnGames.length,
        matched: matchedCount,
        unmatched: unmatchedCount,
        imported: importedCount,
        updated: updatedCount,
        failed: failedCount,
      );

      appLogger.info('PSN Sync: Complete - $result');
      return result;
    } catch (e, stack) {
      appLogger.error('PSN Sync: Failed to sync library', e, stack);
      rethrow;
    }
  }

  /// Match PSN games with IGDB (parallel batch processing)
  Future<Map<String, Game?>> _matchWithIgdb(List<PSNGame> psnGames) async {
    final matches = <String, Game?>{};

    // Process 4 games in parallel (IGDB rate limit: 4 req/sec)
    const batchSize = 4;
    for (var i = 0; i < psnGames.length; i += batchSize) {
      final batch = psnGames.skip(i).take(batchSize).toList();

      final batchResults = await Future.wait(
        batch.map((psnGame) async {
          try {
            // Clean game name for IGDB search (remove "Trophies" suffix etc.)
            final cleanedName = _cleanGameNameForSearch(psnGame.name);

            // Search IGDB by cleaned name
            final results = await igdbClient.searchGames(cleanedName);

            if (results.isNotEmpty) {
              // Find best match by comparing names (take first 3)
              final topResults = results.take(3).toList();
              Game? bestMatch;
              final cleanedNameLower = cleanedName.toLowerCase();

              for (final game in topResults) {
                final nameLower = game.name.toLowerCase();

                if (nameLower == cleanedNameLower) {
                  bestMatch = game;
                  break;
                } else if (nameLower.contains(cleanedNameLower) ||
                    cleanedNameLower.contains(nameLower)) {
                  bestMatch ??= game;
                }
              }
              final matched = bestMatch ?? topResults.first;
              appLogger.info('PSN Sync: Matched "$cleanedName" -> "${matched.name}"');
              return MapEntry(psnGame.titleId, matched);
            } else {
              return MapEntry<String, Game?>(psnGame.titleId, null);
            }
          } catch (e) {
            appLogger.warning('PSN Sync: Failed to match ${psnGame.name}: $e');
            return MapEntry<String, Game?>(psnGame.titleId, null);
          }
        }),
      );

      // Add results to matches map
      for (final entry in batchResults) {
        matches[entry.key] = entry.value;
      }

      // Log progress
      final processed = i + batch.length;
      if (processed % 20 == 0 || processed == psnGames.length) {
        appLogger.info('PSN Sync: IGDB matching progress $processed/${psnGames.length}');
      }

      // Rate limiting between batches (260ms for 4 requests = 15 req/sec safe margin)
      if (i + batchSize < psnGames.length) {
        await Future.delayed(const Duration(milliseconds: 260));
      }
    }

    return matches;
  }

  /// Import a single PSN game to the database
  Future<bool> _importPsnGame({
    required String userId,
    required PSNGame psnGame,
    required Game? igdbGame,
    int playtimeMinutes = 0,
  }) async {
    try {
      final game = igdbGame ?? _createGameFromPsn(psnGame);

      // Check if game already exists by PSN title ID
      var existingId = await _getExistingGameLogId(userId, psnGame.titleId);

      // If not found by PSN ID and we have IGDB match, check by game_id
      // (game might exist from Steam import)
      if (existingId == null && igdbGame != null) {
        existingId = await _getExistingGameLogByGameId(userId, igdbGame.id);
      }

      if (existingId != null) {
        // Update existing game - add PSN data to existing record
        final updateData = <String, dynamic>{
          'psn_title_id': psnGame.titleId,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (igdbGame != null) {
          updateData['game_name'] = game.name;
          updateData['game_cover_url'] = game.coverUrl;
          updateData['game_data'] = game.toMap();
        }

        // Update playtime if we have data (add to existing if from different source)
        if (playtimeMinutes > 0) {
          updateData['playtime_minutes'] = playtimeMinutes;
        }

        await gameRepository.supabase
            .from('game_logs')
            .update(updateData)
            .eq('id', existingId);

        appLogger.info('PSN Sync: Updated ${psnGame.name} (${(playtimeMinutes / 60).toStringAsFixed(1)}h)');
      } else {
        // New game
        final gameLog = GameLog(
          id: _uuid.v4(),
          game: game,
          status: _getStatusFromProgress(psnGame),
          source: 'playstation',
          psnTitleId: psnGame.titleId,
          playtimeMinutes: playtimeMinutes,
          lastSyncedAt: DateTime.now(),
        );

        await gameRepository.upsertGameLog(userId, gameLog);
        appLogger.info('PSN Sync: Imported ${psnGame.name} (${(playtimeMinutes / 60).toStringAsFixed(1)}h)');
      }

      return true;
    } catch (e, stack) {
      appLogger.error('PSN Sync: Failed to import ${psnGame.name}', e, stack);
      return false;
    }
  }

  /// Get existing game log ID by IGDB game_id
  Future<String?> _getExistingGameLogByGameId(String userId, int gameId) async {
    try {
      final response = await gameRepository.supabase
          .from('game_logs')
          .select('id')
          .eq('user_id', userId)
          .eq('game_id', gameId)
          .maybeSingle();

      return response?['id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Get play status from trophy progress
  PlayStatus _getStatusFromProgress(PSNGame psnGame) {
    if (psnGame.progress == 100) {
      return PlayStatus.completed;
    } else if (psnGame.progress != null && psnGame.progress! > 0) {
      return PlayStatus.playing;
    } else if (psnGame.earnedTrophies > 0) {
      return PlayStatus.playing;
    }
    // PlayStation kütüphanesindeki oyunlar koleksiyonda olmalı, wishlist değil
    // Database constraint doesn't allow 'backlog', use 'playing' as default
    return PlayStatus.playing;
  }

  /// Create a Game object from PSN data
  Game _createGameFromPsn(PSNGame psnGame) {
    return Game(
      id: psnGame.titleId.hashCode, // Use hash as ID
      name: psnGame.name,
      coverUrl: psnGame.iconUrl,
      screenshotUrls: const [],
      summary: null,
      platforms: [psnGame.platform],
      genres: const [],
      aggregatedRating: null,
      userRating: null,
      ratingCount: null,
      metacriticScore: null,
      releaseDate: null,
    );
  }

  /// Get existing PSN games for a user
  Future<Map<String, String>> _getExistingPsnGames(String userId) async {
    try {
      final response = await gameRepository.supabase
          .from('game_logs')
          .select('id, psn_title_id')
          .eq('user_id', userId)
          .eq('source', 'playstation');

      final map = <String, String>{};
      for (final row in response as List) {
        final titleId = row['psn_title_id'] as String?;
        final id = row['id'] as String;
        if (titleId != null) {
          map[titleId] = id;
        }
      }

      appLogger.info('PSN Sync: Found ${map.length} existing PSN games');
      return map;
    } catch (e) {
      appLogger.warning('PSN Sync: Failed to fetch existing games: $e');
      return {};
    }
  }

  /// Get existing game log ID by PSN title ID
  Future<String?> _getExistingGameLogId(String userId, String titleId) async {
    try {
      final response = await gameRepository.supabase
          .from('game_logs')
          .select('id')
          .eq('user_id', userId)
          .eq('psn_title_id', titleId)
          .maybeSingle();

      return response?['id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Save PSN tokens to profile
  Future<void> _savePsnTokens(
    String userId,
    String accessToken,
    String refreshToken,
  ) async {
    try {
      await profileRepository.supabase.from('profiles').update({
        'psn_access_token': accessToken,
        'psn_refresh_token': refreshToken,
        'psn_linked_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      appLogger.info('PSN Sync: Saved tokens to profile');
    } catch (e) {
      appLogger.warning('PSN Sync: Failed to save tokens: $e');
    }
  }

  /// Save PSN profile info
  Future<void> _savePsnProfile(String userId, PSNProfile profile) async {
    try {
      await profileRepository.supabase.from('profiles').update({
        'psn_id': profile.onlineId,
        'psn_account_id': profile.accountId,
        'psn_avatar_url': profile.avatarUrl,
      }).eq('id', userId);

      appLogger.info('PSN Sync: Saved profile info (${profile.onlineId})');
    } catch (e) {
      appLogger.warning('PSN Sync: Failed to save profile: $e');
    }
  }

  /// Normalize game name for matching between APIs (playtime matching)
  /// Removes "Trophies" suffix, special characters, and normalizes whitespace
  /// Also handles brand name changes (FIFA -> EA SPORTS FC)
  String _normalizeGameName(String name) {
    var normalized = name.toLowerCase();

    // Remove common suffixes that differ between trophy and gamelist APIs
    normalized = normalized
        .replaceAll(' trophies', '')
        .replaceAll(' trophy', '')
        .replaceAll(' ps4 ve ps5', '')  // Turkish localization
        .replaceAll(' ps4 & ps5', '')
        .replaceAll(' ps4™ ve ps5™', '')
        .replaceAll(' ps4™ & ps5™', '');

    // Remove special characters and normalize whitespace
    normalized = normalized
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Handle FIFA -> EA SPORTS FC brand change
    // FIFA 24 and later became EA SPORTS FC
    // Create a canonical form for matching
    normalized = _normalizeFifaName(normalized);

    return normalized;
  }

  /// Normalize FIFA/EA SPORTS FC names for matching
  /// Both "fifa 24" and "ea sports fc 24" should match the same game
  String _normalizeFifaName(String name) {
    // EA SPORTS FC pattern (new branding)
    final eaSportsFcMatch = RegExp(r'ea sports fc\s*(\d+)').firstMatch(name);
    if (eaSportsFcMatch != null) {
      final year = eaSportsFcMatch.group(1);
      return 'fifa fc $year';
    }

    // FIFA pattern (old branding) - FIFA 24+
    final fifaMatch = RegExp(r'fifa\s*(\d+)').firstMatch(name);
    if (fifaMatch != null) {
      final year = int.tryParse(fifaMatch.group(1) ?? '');
      if (year != null && year >= 24) {
        // FIFA 24 and later became EA SPORTS FC
        return 'fifa fc $year';
      }
    }

    return name;
  }

  /// Clean game name for IGDB search
  /// Removes "Trophies" suffix and platform markers but keeps original formatting
  /// for better IGDB matching (e.g., "EA SPORTS FC™ 24 Trophies" -> "EA SPORTS FC 24")
  String _cleanGameNameForSearch(String name) {
    var cleaned = name;

    // Remove "Trophies" suffix (case insensitive, at the end)
    cleaned = cleaned.replaceAll(RegExp(r'\s+Trophies$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+Trophy$', caseSensitive: false), '');

    // Remove platform markers
    cleaned = cleaned
        .replaceAll(' PS4 ve PS5', '')  // Turkish
        .replaceAll(' PS4 & PS5', '')
        .replaceAll(' PS4™ ve PS5™', '')
        .replaceAll(' PS4™ & PS5™', '')
        .replaceAll(' PS5™', '')
        .replaceAll(' PS4™', '')
        .replaceAll(' PS5', '')
        .replaceAll(' PS4', '');

    // Remove trademark symbols for cleaner search
    cleaned = cleaned
        .replaceAll('™', '')
        .replaceAll('®', '');

    // Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }
}

/// Provider for PlayStationLibrarySyncService
final playstationLibrarySyncServiceProvider =
    Provider<PlayStationLibrarySyncService>((ref) {
  return PlayStationLibrarySyncService(
    playstationService: ref.watch(playstationServiceProvider),
    playstationAuthService: ref.watch(playstationAuthServiceProvider),
    igdbClient: ref.watch(igdbClientProvider),
    gameRepository: ref.watch(gameRepositoryProvider),
    profileRepository: ref.watch(profileRepositoryProvider),
  );
});

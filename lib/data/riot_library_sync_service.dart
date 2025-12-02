import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/logger.dart';
import '../models/game.dart';
import '../models/game_log.dart';
import 'game_repository.dart';
import 'profile_repository.dart';
import 'riot_service.dart';

/// Result of a Riot Games library sync operation
class RiotSyncResult {
  const RiotSyncResult({
    required this.gamesImported,
    required this.gamesUpdated,
    required this.gamesFailed,
    this.lolRank,
    this.tftRank,
    this.valorantMatches,
  });

  final int gamesImported;
  final int gamesUpdated;
  final int gamesFailed;
  final String? lolRank;
  final String? tftRank;
  final int? valorantMatches;

  int get totalGames => gamesImported + gamesUpdated;

  @override
  String toString() {
    return 'RiotSyncResult(imported: $gamesImported, updated: $gamesUpdated, '
        'failed: $gamesFailed, lol: $lolRank, tft: $tftRank, val: $valorantMatches)';
  }
}

/// Service for syncing Riot Games library to GameLib
/// Handles LoL, Valorant, and TFT game data
class RiotLibrarySyncService {
  RiotLibrarySyncService({
    required this.riotService,
    required this.gameRepository,
    required this.profileRepository,
  });

  final RiotService riotService;
  final GameRepository gameRepository;
  final ProfileRepository profileRepository;

  static const _uuid = Uuid();

  // Fixed IGDB IDs for Riot games (these don't change)
  static const _lolIgdbId = 115; // League of Legends
  static const _valorantIgdbId = 126459; // Valorant
  static const _tftIgdbId = 119255; // Teamfight Tactics

  // Fixed game metadata
  static const _lolGame = Game(
    id: _lolIgdbId,
    name: 'League of Legends',
    coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co49wj.jpg',
    screenshotUrls: [],
    summary: 'A fast-paced, competitive online game that blends the speed and intensity of an RTS with RPG elements.',
    platforms: ['PC (Microsoft Windows)', 'Mac'],
    genres: ['MOBA', 'Strategy'],
  );

  static const _valorantGame = Game(
    id: _valorantIgdbId,
    name: 'Valorant',
    coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co2mvt.jpg',
    screenshotUrls: [],
    summary: 'A 5v5 character-based tactical FPS where precise gunplay meets unique agent abilities.',
    platforms: ['PC (Microsoft Windows)'],
    genres: ['Shooter', 'Tactical'],
  );

  static const _tftGame = Game(
    id: _tftIgdbId,
    name: 'Teamfight Tactics',
    coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1wyy.jpg',
    screenshotUrls: [],
    summary: 'An auto-battler game set in the League of Legends universe.',
    platforms: ['PC (Microsoft Windows)', 'Android', 'iOS'],
    genres: ['Strategy', 'Auto Battler'],
  );

  /// Perform full Riot Games library sync
  /// Syncs LoL, TFT, and Valorant data
  Future<RiotSyncResult> syncFullLibrary({
    required String userId,
    required String puuid,
    required String platform,
    required String apiKey,
  }) async {
    appLogger.info('Riot Sync: Starting full library sync for user $userId');

    try {
      // Fetch all game data from Riot API
      appLogger.info('Riot Sync: Fetching game data from Riot API');
      final gameData = await riotService.fetchAllGameData(
        puuid: puuid,
        platform: platform,
        apiKey: apiKey,
      );

      var importedCount = 0;
      var updatedCount = 0;
      var failedCount = 0;

      String? lolRank;
      String? tftRank;
      int? valorantMatchCount;

      // Process League of Legends
      if (gameData.hasLoL) {
        appLogger.info('Riot Sync: Processing League of Legends data');
        final success = await _syncRiotGame(
          userId: userId,
          game: _lolGame,
          source: 'lol',
          riotGameId: 'lol',
          rankedData: gameData.lolRankedEntries,
          summonerLevel: gameData.lolSummoner!.summonerLevel,
        );

        if (success) {
          final existingId = await _getExistingGameLogId(userId, 'lol');
          if (existingId != null) {
            updatedCount++;
          } else {
            importedCount++;
          }
        } else {
          failedCount++;
        }

        // Get ranked display string
        if (gameData.lolRankedEntries != null && gameData.lolRankedEntries!.isNotEmpty) {
          final soloQueue = gameData.lolRankedEntries!.firstWhere(
            (e) => e.queueType == 'RANKED_SOLO_5x5',
            orElse: () => gameData.lolRankedEntries!.first,
          );
          lolRank = soloQueue.displayRank;
        }
      }

      // Process Teamfight Tactics
      if (gameData.hasTFT) {
        appLogger.info('Riot Sync: Processing TFT data');
        final success = await _syncRiotGame(
          userId: userId,
          game: _tftGame,
          source: 'tft',
          riotGameId: 'tft',
          rankedData: gameData.tftRankedEntries,
          summonerLevel: gameData.tftSummoner!.summonerLevel,
        );

        if (success) {
          final existingId = await _getExistingGameLogId(userId, 'tft');
          if (existingId != null) {
            updatedCount++;
          } else {
            importedCount++;
          }
        } else {
          failedCount++;
        }

        // Get ranked display string
        if (gameData.tftRankedEntries != null && gameData.tftRankedEntries!.isNotEmpty) {
          final ranked = gameData.tftRankedEntries!.first;
          tftRank = ranked.displayRank;
        }
      }

      // Process Valorant
      if (gameData.hasValorant) {
        appLogger.info('Riot Sync: Processing Valorant data');
        valorantMatchCount = gameData.valorantMatches?.length ?? 0;

        final success = await _syncRiotGame(
          userId: userId,
          game: _valorantGame,
          source: 'valorant',
          riotGameId: 'valorant',
          matchCount: valorantMatchCount,
        );

        if (success) {
          final existingId = await _getExistingGameLogId(userId, 'valorant');
          if (existingId != null) {
            updatedCount++;
          } else {
            importedCount++;
          }
        } else {
          failedCount++;
        }
      }

      // Update profile with Riot data summary
      await profileRepository.linkRiotAccount(
        puuid: puuid,
        gameName: '', // Already set during OAuth
        tagLine: '', // Already set during OAuth
        accessToken: '', // Already set during OAuth
        refreshToken: '', // Already set during OAuth
        region: platform,
        riotData: gameData.toJson(),
      );

      final result = RiotSyncResult(
        gamesImported: importedCount,
        gamesUpdated: updatedCount,
        gamesFailed: failedCount,
        lolRank: lolRank,
        tftRank: tftRank,
        valorantMatches: valorantMatchCount,
      );

      appLogger.info('Riot Sync: Complete - $result');
      return result;
    } catch (e, stack) {
      appLogger.error('Riot Sync: Failed to sync library', e, stack);
      rethrow;
    }
  }

  /// Sync a single Riot game to the database
  Future<bool> _syncRiotGame({
    required String userId,
    required Game game,
    required String source,
    required String riotGameId,
    List<dynamic>? rankedData,
    int? summonerLevel,
    int? matchCount,
  }) async {
    try {
      // Check if game already exists
      final existingId = await _getExistingGameLogId(userId, riotGameId);

      // Build ranked data JSON
      Map<String, dynamic>? rankedJson;
      if (rankedData != null && rankedData.isNotEmpty) {
        rankedJson = {
          'entries': rankedData.map((e) {
            if (e is LeagueEntry) return e.toJson();
            if (e is TFTLeagueEntry) return e.toJson();
            return null;
          }).where((e) => e != null).toList(),
          'summoner_level': summonerLevel,
        };
      }
      if (matchCount != null) {
        rankedJson ??= {};
        rankedJson['match_count'] = matchCount;
      }

      if (existingId != null) {
        // Update existing game
        final updateData = <String, dynamic>{
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (rankedJson != null) {
          updateData['riot_ranked_data'] = rankedJson;
        }

        await gameRepository.supabase
            .from('game_logs')
            .update(updateData)
            .eq('id', existingId);

        appLogger.info('Riot Sync: Updated ${game.name}');
      } else {
        // Create new game log
        final gameLog = GameLog(
          id: _uuid.v4(),
          game: game,
          status: PlayStatus.playing,
          source: source,
          riotGameId: riotGameId,
          riotRankedData: rankedJson,
          lastSyncedAt: DateTime.now(),
        );

        await gameRepository.upsertGameLog(userId, gameLog);
        appLogger.info('Riot Sync: Imported ${game.name}');
      }

      return true;
    } catch (e, stack) {
      appLogger.error('Riot Sync: Failed to sync ${game.name}', e, stack);
      return false;
    }
  }

  /// Get existing game log ID by riot_game_id
  Future<String?> _getExistingGameLogId(String userId, String riotGameId) async {
    try {
      final response = await gameRepository.supabase
          .from('game_logs')
          .select('id')
          .eq('user_id', userId)
          .eq('riot_game_id', riotGameId)
          .maybeSingle();

      return response?['id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Quick sync - only update ranked stats without full import
  Future<RiotSyncResult> syncRankedStats({
    required String userId,
    required String puuid,
    required String platform,
    required String apiKey,
  }) async {
    appLogger.info('Riot Sync: Starting ranked stats sync');

    try {
      final gameData = await riotService.fetchAllGameData(
        puuid: puuid,
        platform: platform,
        apiKey: apiKey,
      );

      var updatedCount = 0;
      String? lolRank;
      String? tftRank;

      // Update LoL ranked
      if (gameData.lolRankedEntries != null) {
        final existingId = await _getExistingGameLogId(userId, 'lol');
        if (existingId != null) {
          await gameRepository.supabase.from('game_logs').update({
            'riot_ranked_data': {
              'entries': gameData.lolRankedEntries!.map((e) => e.toJson()).toList(),
              'summoner_level': gameData.lolSummoner?.summonerLevel,
            },
            'last_synced_at': DateTime.now().toIso8601String(),
          }).eq('id', existingId);

          updatedCount++;

          final soloQueue = gameData.lolRankedEntries!.firstWhere(
            (e) => e.queueType == 'RANKED_SOLO_5x5',
            orElse: () => gameData.lolRankedEntries!.first,
          );
          lolRank = soloQueue.displayRank;
        }
      }

      // Update TFT ranked
      if (gameData.tftRankedEntries != null) {
        final existingId = await _getExistingGameLogId(userId, 'tft');
        if (existingId != null) {
          await gameRepository.supabase.from('game_logs').update({
            'riot_ranked_data': {
              'entries': gameData.tftRankedEntries!.map((e) => e.toJson()).toList(),
              'summoner_level': gameData.tftSummoner?.summonerLevel,
            },
            'last_synced_at': DateTime.now().toIso8601String(),
          }).eq('id', existingId);

          updatedCount++;

          if (gameData.tftRankedEntries!.isNotEmpty) {
            tftRank = gameData.tftRankedEntries!.first.displayRank;
          }
        }
      }

      return RiotSyncResult(
        gamesImported: 0,
        gamesUpdated: updatedCount,
        gamesFailed: 0,
        lolRank: lolRank,
        tftRank: tftRank,
      );
    } catch (e, stack) {
      appLogger.error('Riot Sync: Failed to sync ranked stats', e, stack);
      rethrow;
    }
  }
}

/// Provider for RiotLibrarySyncService
final riotLibrarySyncServiceProvider = Provider<RiotLibrarySyncService>((ref) {
  return RiotLibrarySyncService(
    riotService: ref.watch(riotServiceProvider),
    gameRepository: ref.watch(gameRepositoryProvider),
    profileRepository: ref.watch(profileRepositoryProvider),
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform_icons.dart';
import '../../data/game_repository.dart';
import '../../data/profile_repository.dart';
import '../../data/steam_library_sync_service.dart';
import '../../data/supabase_client.dart';
import '../../data/valorant_service.dart';
import '../../models/game_log.dart';

/// Provider for Steam library games
/// Fetches all Steam-sourced games sorted by playtime
final steamLibraryProvider = FutureProvider<List<GameLog>>((ref) async {
  final userId = ref.watch(supabaseProvider).auth.currentUser?.id;
  if (userId == null) return [];

  final repo = ref.read(gameRepositoryProvider);
  return repo.fetchSteamLibrary(userId);
});

/// Provider for Steam library sync
/// Triggers a full library sync when called
final steamLibrarySyncProvider =
    FutureProvider.family<SyncResult, String>((ref, steamId) async {
  final userId = ref.watch(supabaseProvider).auth.currentUser?.id;
  if (userId == null) {
    throw Exception('User not authenticated');
  }

  final syncService = ref.read(steamLibrarySyncServiceProvider);
  return syncService.syncFullLibrary(userId, steamId);
});

// Steam wishlist sync removed - wishlist is now app-only

/// Provider for PlayStation library games
/// Fetches all PlayStation-sourced games sorted by playtime
final playstationLibraryProvider = FutureProvider<List<GameLog>>((ref) async {
  final userId = ref.watch(supabaseProvider).auth.currentUser?.id;
  if (userId == null) return [];

  final repo = ref.read(gameRepositoryProvider);
  return repo.fetchPlayStationLibrary(userId);
});

/// Provider for Riot Games library (LoL, Valorant, TFT)
/// Fetches all Riot-sourced games
final riotLibraryProvider = FutureProvider<List<GameLog>>((ref) async {
  final userId = ref.watch(supabaseProvider).auth.currentUser?.id;
  if (userId == null) return [];

  final repo = ref.read(gameRepositoryProvider);
  return repo.fetchRiotLibrary(userId);
});

/// Combined game entry with platforms info
class CombinedGameEntry {
  final GameLog log;
  final Set<GamePlatform> platforms;

  CombinedGameEntry({required this.log, required this.platforms});
}

/// Provider for combined library (Steam + PlayStation + Riot)
/// Deduplicates games and tracks which platforms each game is on
/// This is the SINGLE SOURCE OF TRUTH for game counts
final combinedLibraryProvider = FutureProvider<List<CombinedGameEntry>>((ref) async {
  final steamGames = await ref.watch(steamLibraryProvider.future);
  final psnGames = await ref.watch(playstationLibraryProvider.future);
  final riotGames = await ref.watch(riotLibraryProvider.future);

  // Create a map to track games by game_id (IGDB ID) for deduplication
  final gameMap = <int, CombinedGameEntry>{};

  // Add Steam games - check if they also have PSN data
  for (final game in steamGames) {
    final id = game.game.id;
    final platforms = <GamePlatform>{GamePlatform.steam};

    // If this Steam game also has PSN title ID, it's on both platforms
    if (game.psnTitleId != null && game.psnTitleId!.isNotEmpty) {
      platforms.add(GamePlatform.playstation);
    }

    if (gameMap.containsKey(id)) {
      final existing = gameMap[id]!;
      existing.platforms.addAll(platforms);
      if (game.playtimeMinutes > existing.log.playtimeMinutes) {
        gameMap[id] = CombinedGameEntry(log: game, platforms: existing.platforms);
      }
    } else {
      gameMap[id] = CombinedGameEntry(log: game, platforms: platforms);
    }
  }

  // Add PlayStation-only games
  for (final game in psnGames) {
    final id = game.game.id;
    final platforms = <GamePlatform>{GamePlatform.playstation};

    // If this PSN game also has Steam app ID, it's on both platforms
    if (game.steamAppId != null) {
      platforms.add(GamePlatform.steam);
    }

    if (gameMap.containsKey(id)) {
      final existing = gameMap[id]!;
      existing.platforms.addAll(platforms);
      if (game.playtimeMinutes > existing.log.playtimeMinutes) {
        gameMap[id] = CombinedGameEntry(log: game, platforms: existing.platforms);
      }
    } else {
      gameMap[id] = CombinedGameEntry(log: game, platforms: platforms);
    }
  }

  // Add Riot Games (LoL, Valorant, TFT)
  // All Riot games are grouped under valorant platform for filtering
  // Check both riotGameId and source for legacy entries
  for (final game in riotGames) {
    final id = game.game.id;
    final isRiotGame = game.riotGameId != null ||
        game.source == 'lol' ||
        game.source == 'valorant' ||
        game.source == 'tft';

    if (!isRiotGame) continue;

    final platforms = <GamePlatform>{GamePlatform.valorant};

    if (gameMap.containsKey(id)) {
      final existing = gameMap[id]!;
      existing.platforms.addAll(platforms);
      // Riot games don't have playtime from API, keep existing if available
      if (game.playtimeMinutes > existing.log.playtimeMinutes) {
        gameMap[id] = CombinedGameEntry(log: game, platforms: existing.platforms);
      }
    } else {
      gameMap[id] = CombinedGameEntry(log: game, platforms: platforms);
    }
  }

  // Convert to list and sort by playtime
  final combinedGames = gameMap.values.toList()
    ..sort((a, b) => b.log.playtimeMinutes.compareTo(a.log.playtimeMinutes));

  return combinedGames;
});

/// Provider for library stats (game count, total hours)
/// Used by both profile and library screens for consistent counts
final libraryStatsProvider = Provider<({int gameCount, double totalHours})>((ref) {
  final combinedAsync = ref.watch(combinedLibraryProvider);
  final games = combinedAsync.valueOrNull ?? [];

  final totalMinutes = games.fold<int>(0, (sum, e) => sum + e.log.playtimeMinutes);

  return (gameCount: games.length, totalHours: totalMinutes / 60);
});

/// Provider to check if a game can be rated
/// Game must be in library with 2+ hours playtime
/// Returns (canRate: bool, playtimeHours: double, reason: String?)
final canRateGameProvider = Provider.family<({bool canRate, double playtimeHours, String? reason}), int>((ref, gameId) {
  final combinedAsync = ref.watch(combinedLibraryProvider);
  final games = combinedAsync.valueOrNull ?? [];

  // Find game in combined library
  final entry = games.where((e) => e.log.game.id == gameId).firstOrNull;

  if (entry == null) {
    return (canRate: false, playtimeHours: 0, reason: 'Bu oyunu değerlendirmek için kütüphanenizde olması gerekiyor');
  }

  final playtimeHours = entry.log.playtimeHours;

  if (playtimeHours < 2) {
    return (
      canRate: false,
      playtimeHours: playtimeHours,
      reason: 'Bu oyunu değerlendirmek için en az 2 saat oynamış olmalısınız (${playtimeHours.toStringAsFixed(1)} saat)'
    );
  }

  return (canRate: true, playtimeHours: playtimeHours, reason: null);
});

/// Provider for Valorant profile data from user's riot_data
/// Returns parsed ValorantProfile if available
final valorantProfileProvider = FutureProvider<ValorantProfile?>((ref) async {
  final profileAsync = await ref.watch(currentProfileProvider.future);
  if (profileAsync == null) return null;

  final riotData = profileAsync['riot_data'];
  if (riotData == null) return null;

  try {
    final data = riotData is String ? {} : riotData as Map<String, dynamic>;

    // Parse account
    final accountData = data['account'] as Map<String, dynamic>?;
    if (accountData == null) return null;

    final account = ValorantAccount(
      puuid: accountData['puuid'] as String? ?? '',
      name: accountData['name'] as String? ?? '',
      tag: accountData['tag'] as String? ?? '',
      region: accountData['region'] as String? ?? 'eu',
      accountLevel: accountData['account_level'] as int?,
      cardId: accountData['card_id'] as String?,
    );

    // Parse MMR
    ValorantMMR? mmr;
    final mmrData = data['mmr'] as Map<String, dynamic>?;
    if (mmrData != null) {
      mmr = ValorantMMR(
        currentTier: mmrData['current_tier'] as int? ?? 0,
        currentTierPatched: mmrData['current_tier_patched'] as String? ?? 'Unranked',
        rankingInTier: mmrData['ranking_in_tier'] as int? ?? 0,
        mmrChangeToLastGame: mmrData['mmr_change'] as int?,
        elo: mmrData['elo'] as int?,
        peakTier: mmrData['peak_tier'] as int?,
        peakTierPatched: mmrData['peak_tier_patched'] as String?,
        peakSeason: mmrData['peak_season'] as String?,
      );
    }

    // Parse stats
    ValorantPlayerStats? stats;
    final statsData = data['stats'] as Map<String, dynamic>?;
    if (statsData != null) {
      stats = ValorantPlayerStats(
        totalMatches: statsData['total_matches'] as int? ?? 0,
        wins: statsData['wins'] as int? ?? 0,
        losses: statsData['losses'] as int? ?? 0,
        totalKills: statsData['total_kills'] as int? ?? 0,
        totalDeaths: statsData['total_deaths'] as int? ?? 0,
        totalAssists: statsData['total_assists'] as int? ?? 0,
        totalPlaytimeMinutes: statsData['total_playtime_minutes'] as int? ?? 0,
        avgKda: (statsData['avg_kda'] as num?)?.toDouble() ?? 0,
        avgHeadshotPercent: (statsData['avg_hs_percent'] as num?)?.toDouble() ?? 0,
        mostPlayedAgent: statsData['most_played_agent'] as String?,
        mostPlayedMap: statsData['most_played_map'] as String?,
      );
    }

    return ValorantProfile(
      account: account,
      mmr: mmr,
      stats: stats,
    );
  } catch (e) {
    return null;
  }
});

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/logger.dart';

/// Provider for ValorantService
final valorantServiceProvider = Provider<ValorantService>((ref) {
  return ValorantService();
});

/// Valorant account info
class ValorantAccount {
  const ValorantAccount({
    required this.puuid,
    required this.name,
    required this.tag,
    required this.region,
    this.accountLevel,
    this.cardId,
    this.lastUpdate,
  });

  final String puuid;
  final String name;
  final String tag;
  final String region;
  final int? accountLevel;
  final String? cardId;
  final DateTime? lastUpdate;

  String get riotId => '$name#$tag';

  String? get cardUrl => cardId != null
      ? 'https://media.valorant-api.com/playercards/$cardId/smallart.png'
      : null;

  factory ValorantAccount.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return ValorantAccount(
      puuid: data['puuid'] as String? ?? '',
      name: data['name'] as String? ?? '',
      tag: data['tag'] as String? ?? '',
      region: data['region'] as String? ?? 'eu',
      accountLevel: data['account_level'] as int?,
      cardId: data['card']?['id'] as String?,
      lastUpdate: data['last_update_raw'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['last_update_raw'] * 1000)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'puuid': puuid,
    'name': name,
    'tag': tag,
    'region': region,
    'account_level': accountLevel,
    'card_id': cardId,
  };
}

/// Valorant MMR/Rank info
class ValorantMMR {
  const ValorantMMR({
    required this.currentTier,
    required this.currentTierPatched,
    required this.rankingInTier,
    this.mmrChangeToLastGame,
    this.elo,
    this.gamesNeededForRating,
    this.peakTier,
    this.peakTierPatched,
    this.peakSeason,
  });

  final int currentTier;
  final String currentTierPatched; // e.g., "Diamond 2"
  final int rankingInTier; // RR points (0-100)
  final int? mmrChangeToLastGame;
  final int? elo;
  final int? gamesNeededForRating;
  final int? peakTier;
  final String? peakTierPatched;
  final String? peakSeason;

  String get rankIconUrl =>
      'https://media.valorant-api.com/competitivetiers/03621f52-342b-cf4e-4f86-9350a49c6d04/$currentTier/smallicon.png';

  factory ValorantMMR.fromJson(Map<String, dynamic> json) {
    final data = json['data']?['current_data'] ?? json['current_data'] ?? json;
    return ValorantMMR(
      currentTier: data['currenttier'] as int? ?? 0,
      currentTierPatched: data['currenttierpatched'] as String? ?? 'Unranked',
      rankingInTier: data['ranking_in_tier'] as int? ?? 0,
      mmrChangeToLastGame: data['mmr_change_to_last_game'] as int?,
      elo: data['elo'] as int?,
      gamesNeededForRating: data['games_needed_for_rating'] as int?,
      peakTier: json['data']?['highest_rank']?['tier'] as int?,
      peakTierPatched: json['data']?['highest_rank']?['patched_tier'] as String?,
      peakSeason: json['data']?['highest_rank']?['season'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'current_tier': currentTier,
    'current_tier_patched': currentTierPatched,
    'ranking_in_tier': rankingInTier,
    'mmr_change': mmrChangeToLastGame,
    'elo': elo,
    'peak_tier': peakTier,
    'peak_tier_patched': peakTierPatched,
    'peak_season': peakSeason,
  };
}

/// Valorant match info
class ValorantMatch {
  const ValorantMatch({
    required this.matchId,
    required this.map,
    required this.mode,
    required this.startedAt,
    required this.durationMs,
    required this.isWin,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.score,
    required this.agent,
    this.headshots,
    this.bodyshots,
    this.legshots,
    this.damageDealt,
    this.damageReceived,
  });

  final String matchId;
  final String map;
  final String mode;
  final DateTime startedAt;
  final int durationMs;
  final bool isWin;
  final int kills;
  final int deaths;
  final int assists;
  final int score;
  final String agent;
  final int? headshots;
  final int? bodyshots;
  final int? legshots;
  final int? damageDealt;
  final int? damageReceived;

  double get kda => deaths > 0 ? (kills + assists) / deaths : (kills + assists).toDouble();
  int get durationMinutes => durationMs ~/ 60000;

  double get headshotPercent {
    final total = (headshots ?? 0) + (bodyshots ?? 0) + (legshots ?? 0);
    if (total == 0) return 0;
    return ((headshots ?? 0) / total) * 100;
  }

  String get agentIconUrl =>
      'https://media.valorant-api.com/agents/${agent.toLowerCase()}/displayicon.png';

  factory ValorantMatch.fromJson(Map<String, dynamic> json, String puuid) {
    final metadata = json['metadata'] ?? {};
    final players = json['players']?['all_players'] as List? ?? [];

    // Find the player's stats
    Map<String, dynamic>? playerStats;
    for (final player in players) {
      if (player['puuid'] == puuid) {
        playerStats = player;
        break;
      }
    }

    final stats = playerStats?['stats'] ?? {};
    final teams = json['teams'] ?? {};

    // Determine if win
    final playerTeam = playerStats?['team']?.toString().toLowerCase() ?? '';
    bool isWin = false;
    if (playerTeam.isNotEmpty && teams[playerTeam] != null) {
      isWin = teams[playerTeam]['has_won'] == true;
    }

    return ValorantMatch(
      matchId: metadata['matchid'] as String? ?? '',
      map: metadata['map'] as String? ?? 'Unknown',
      mode: metadata['mode'] as String? ?? 'Unknown',
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (metadata['game_start'] as int? ?? 0) * 1000,
      ),
      durationMs: (metadata['game_length'] as int? ?? 0) * 1000,
      isWin: isWin,
      kills: stats['kills'] as int? ?? 0,
      deaths: stats['deaths'] as int? ?? 0,
      assists: stats['assists'] as int? ?? 0,
      score: stats['score'] as int? ?? 0,
      agent: playerStats?['character'] as String? ?? 'Unknown',
      headshots: stats['headshots'] as int?,
      bodyshots: stats['bodyshots'] as int?,
      legshots: stats['legshots'] as int?,
      damageDealt: playerStats?['damage_made'] as int?,
      damageReceived: playerStats?['damage_received'] as int?,
    );
  }
}

/// Aggregated player stats
class ValorantPlayerStats {
  const ValorantPlayerStats({
    required this.totalMatches,
    required this.wins,
    required this.losses,
    required this.totalKills,
    required this.totalDeaths,
    required this.totalAssists,
    required this.totalPlaytimeMinutes,
    required this.avgKda,
    required this.avgHeadshotPercent,
    this.mostPlayedAgent,
    this.mostPlayedMap,
  });

  final int totalMatches;
  final int wins;
  final int losses;
  final int totalKills;
  final int totalDeaths;
  final int totalAssists;
  final int totalPlaytimeMinutes;
  final double avgKda;
  final double avgHeadshotPercent;
  final String? mostPlayedAgent;
  final String? mostPlayedMap;

  double get winRate => totalMatches > 0 ? (wins / totalMatches) * 100 : 0;
  double get playtimeHours => totalPlaytimeMinutes / 60.0;

  factory ValorantPlayerStats.fromMatches(List<ValorantMatch> matches) {
    if (matches.isEmpty) {
      return const ValorantPlayerStats(
        totalMatches: 0,
        wins: 0,
        losses: 0,
        totalKills: 0,
        totalDeaths: 0,
        totalAssists: 0,
        totalPlaytimeMinutes: 0,
        avgKda: 0,
        avgHeadshotPercent: 0,
      );
    }

    int wins = 0;
    int totalKills = 0;
    int totalDeaths = 0;
    int totalAssists = 0;
    int totalPlaytime = 0;
    double totalKda = 0;
    double totalHsPercent = 0;

    final agentCounts = <String, int>{};
    final mapCounts = <String, int>{};

    for (final match in matches) {
      if (match.isWin) wins++;
      totalKills += match.kills;
      totalDeaths += match.deaths;
      totalAssists += match.assists;
      totalPlaytime += match.durationMinutes;
      totalKda += match.kda;
      totalHsPercent += match.headshotPercent;

      agentCounts[match.agent] = (agentCounts[match.agent] ?? 0) + 1;
      mapCounts[match.map] = (mapCounts[match.map] ?? 0) + 1;
    }

    String? mostPlayedAgent;
    int maxAgentCount = 0;
    agentCounts.forEach((agent, count) {
      if (count > maxAgentCount) {
        maxAgentCount = count;
        mostPlayedAgent = agent;
      }
    });

    String? mostPlayedMap;
    int maxMapCount = 0;
    mapCounts.forEach((map, count) {
      if (count > maxMapCount) {
        maxMapCount = count;
        mostPlayedMap = map;
      }
    });

    return ValorantPlayerStats(
      totalMatches: matches.length,
      wins: wins,
      losses: matches.length - wins,
      totalKills: totalKills,
      totalDeaths: totalDeaths,
      totalAssists: totalAssists,
      totalPlaytimeMinutes: totalPlaytime,
      avgKda: totalKda / matches.length,
      avgHeadshotPercent: totalHsPercent / matches.length,
      mostPlayedAgent: mostPlayedAgent,
      mostPlayedMap: mostPlayedMap,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_matches': totalMatches,
    'wins': wins,
    'losses': losses,
    'total_kills': totalKills,
    'total_deaths': totalDeaths,
    'total_assists': totalAssists,
    'total_playtime_minutes': totalPlaytimeMinutes,
    'avg_kda': avgKda,
    'avg_hs_percent': avgHeadshotPercent,
    'most_played_agent': mostPlayedAgent,
    'most_played_map': mostPlayedMap,
    'win_rate': winRate,
  };
}

/// Stored match from Henrik's database (lightweight version)
class StoredMatch {
  const StoredMatch({
    required this.matchId,
    required this.map,
    required this.mode,
    required this.startedAt,
    required this.matchLengthSeconds,
    required this.tier,
    required this.tierPatched,
  });

  final String matchId;
  final String map;
  final String mode;
  final DateTime startedAt;
  final int matchLengthSeconds;
  final int tier;
  final String tierPatched;

  int get matchLengthMinutes => matchLengthSeconds ~/ 60;

  factory StoredMatch.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] ?? json;
    return StoredMatch(
      matchId: meta['id'] as String? ?? json['match_id'] as String? ?? '',
      map: (meta['map']?['name'] as String?) ?? json['map'] as String? ?? 'Unknown',
      mode: (meta['mode'] as String?) ?? json['mode'] as String? ?? 'Unknown',
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        ((meta['started_at'] as int?) ?? (json['game_start'] as int?) ?? 0) * 1000,
      ),
      matchLengthSeconds: (meta['season']?['short'] != null)
          ? (json['game_length'] as int? ?? 2400) // Default ~40 min if not available
          : (json['game_length'] as int? ?? 2400),
      tier: json['stats']?['tier'] as int? ?? 0,
      tierPatched: json['stats']?['tier_patched'] as String? ?? 'Unranked',
    );
  }
}

/// Full Valorant profile with all data
class ValorantProfile {
  const ValorantProfile({
    required this.account,
    this.mmr,
    this.stats,
    this.recentMatches,
  });

  final ValorantAccount account;
  final ValorantMMR? mmr;
  final ValorantPlayerStats? stats;
  final List<ValorantMatch>? recentMatches;

  Map<String, dynamic> toJson() => {
    'account': account.toJson(),
    'mmr': mmr?.toJson(),
    'stats': stats?.toJson(),
  };
}

/// Service for Valorant API calls using Henrik's API
/// https://docs.henrikdev.xyz/valorant.html
class ValorantService {
  static const _baseUrl = 'https://api.henrikdev.xyz/valorant';

  /// Get API key from environment
  String? get _apiKey => dotenv.env['HENRIK_API_KEY'];

  /// Build headers with API key
  Map<String, String> get _headers {
    final headers = {'Accept': 'application/json'};
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      headers['Authorization'] = _apiKey!;
    }
    return headers;
  }

  /// Get account info by Riot ID
  Future<ValorantAccount?> getAccount(String name, String tag) async {
    try {
      appLogger.info('Valorant Service: Fetching account $name#$tag');

      final response = await http.get(
        Uri.parse('$_baseUrl/v1/account/$name/$tag'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 200) {
          return ValorantAccount.fromJson(json);
        }
      }

      appLogger.warning('Valorant Service: Account not found or error: ${response.statusCode}');
      return null;
    } catch (e, stack) {
      appLogger.error('Valorant Service: Error fetching account', e, stack);
      return null;
    }
  }

  /// Get MMR/Rank info by Riot ID
  Future<ValorantMMR?> getMMR(String name, String tag, {String region = 'eu'}) async {
    try {
      appLogger.info('Valorant Service: Fetching MMR for $name#$tag');

      final response = await http.get(
        Uri.parse('$_baseUrl/v2/mmr/$region/$name/$tag'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 200) {
          return ValorantMMR.fromJson(json);
        }
      }

      appLogger.warning('Valorant Service: MMR not found: ${response.statusCode}');
      return null;
    } catch (e, stack) {
      appLogger.error('Valorant Service: Error fetching MMR', e, stack);
      return null;
    }
  }

  /// Get match history by PUUID
  Future<List<ValorantMatch>> getMatchHistory(
    String region,
    String name,
    String tag, {
    int size = 10,
    String? mode, // competitive, unrated, deathmatch, etc.
  }) async {
    try {
      appLogger.info('Valorant Service: Fetching match history for $name#$tag');

      var url = '$_baseUrl/v3/matches/$region/$name/$tag?size=$size';
      if (mode != null) {
        url += '&filter=$mode';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 200 && json['data'] != null) {
          // First get account to get PUUID
          final account = await getAccount(name, tag);
          if (account == null) return [];

          final matches = <ValorantMatch>[];
          for (final matchJson in json['data']) {
            try {
              matches.add(ValorantMatch.fromJson(matchJson, account.puuid));
            } catch (e) {
              appLogger.warning('Valorant Service: Failed to parse match: $e');
            }
          }
          return matches;
        }
      }

      appLogger.warning('Valorant Service: Match history not found: ${response.statusCode}');
      return [];
    } catch (e, stack) {
      appLogger.error('Valorant Service: Error fetching match history', e, stack);
      return [];
    }
  }

  /// Get match count from ALL stored matches in Henrik's database
  Future<int> getStoredMatchCount(String region, String name, String tag) async {
    try {
      appLogger.info('Valorant Service: Fetching stored match count for $name#$tag');

      final url = '$_baseUrl/v1/stored-matches/$region/$name/$tag';

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 200 && json['data'] != null) {
          final matchCount = (json['data'] as List).length;
          appLogger.info('Valorant Service: Found $matchCount stored matches');
          return matchCount;
        }
      }

      appLogger.warning('Valorant Service: Stored matches not found: ${response.statusCode}');
      return 0;
    } catch (e, stack) {
      appLogger.error('Valorant Service: Error fetching stored matches', e, stack);
      return 0;
    }
  }

  /// Calculate total playtime from account level
  /// Each level requires ~1.75 matches on average
  /// Average match is ~35 minutes
  /// Multiply by 1.3 for queue time, agent select, etc.
  int calculatePlaytimeFromLevel(int accountLevel) {
    if (accountLevel <= 0) return 0;

    // Each level requires roughly 1.75 matches on average
    const matchesPerLevel = 1.75;
    // Average Valorant match is ~35 minutes
    const avgMatchMinutes = 35;
    // Multiply by 1.3 to account for queue time, agent select, loading, etc.
    const multiplier = 1.3;

    final estimatedMatches = (accountLevel * matchesPerLevel).round();
    final totalMinutes = (estimatedMatches * avgMatchMinutes * multiplier).round();

    appLogger.info('Valorant Service: Level $accountLevel → ~$estimatedMatches matches × $avgMatchMinutes min × $multiplier = $totalMinutes minutes (${(totalMinutes / 60).toStringAsFixed(1)} hours)');
    return totalMinutes;
  }

  /// Get full profile with all data
  Future<ValorantProfile?> getFullProfile(String name, String tag, {String region = 'eu'}) async {
    appLogger.info('Valorant Service: Fetching full profile for $name#$tag');

    // Get account first
    final account = await getAccount(name, tag);
    if (account == null) {
      appLogger.warning('Valorant Service: Account not found');
      return null;
    }

    // Fetch MMR and matches in parallel
    final results = await Future.wait([
      getMMR(name, tag, region: region),
      getMatchHistory(region, name, tag, size: 20),
    ]);

    final mmr = results[0] as ValorantMMR?;
    final matches = results[1] as List<ValorantMatch>;

    // Calculate stats from matches
    final stats = ValorantPlayerStats.fromMatches(matches);

    return ValorantProfile(
      account: account,
      mmr: mmr,
      stats: stats,
      recentMatches: matches,
    );
  }

  /// Map region code to API region
  static String mapRegion(String region) {
    switch (region.toLowerCase()) {
      case 'tr1':
      case 'euw1':
      case 'eun1':
      case 'ru':
        return 'eu';
      case 'na1':
      case 'br1':
      case 'la1':
      case 'la2':
        return 'na';
      case 'kr':
        return 'kr';
      case 'jp1':
        return 'ap';
      default:
        return 'eu';
    }
  }
}

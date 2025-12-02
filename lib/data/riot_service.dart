import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/logger.dart';
import '../core/utils.dart';

/// Provider for RiotService
final riotServiceProvider = Provider<RiotService>((ref) {
  return RiotService();
});

/// Regional routing for Riot API
class RiotRegion {
  static const Map<String, String> platformToCluster = {
    'tr1': 'europe',
    'euw1': 'europe',
    'eun1': 'europe',
    'ru': 'europe',
    'na1': 'americas',
    'br1': 'americas',
    'la1': 'americas',
    'la2': 'americas',
    'kr': 'asia',
    'jp1': 'asia',
    'oc1': 'sea',
    'ph2': 'sea',
    'sg2': 'sea',
    'th2': 'sea',
    'tw2': 'sea',
    'vn2': 'sea',
  };

  static String getCluster(String platform) {
    return platformToCluster[platform.toLowerCase()] ?? 'europe';
  }
}

/// League of Legends Summoner info
class LoLSummoner {
  const LoLSummoner({
    required this.id,
    required this.accountId,
    required this.puuid,
    required this.profileIconId,
    required this.summonerLevel,
    this.name,
  });

  final String id;
  final String accountId;
  final String puuid;
  final int profileIconId;
  final int summonerLevel;
  final String? name;

  factory LoLSummoner.fromJson(Map<String, dynamic> json) {
    return LoLSummoner(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      puuid: json['puuid'] as String,
      profileIconId: json['profileIconId'] as int,
      summonerLevel: json['summonerLevel'] as int,
      name: json['name'] as String?,
    );
  }
}

/// League Entry (Ranked stats)
class LeagueEntry {
  const LeagueEntry({
    required this.queueType,
    required this.tier,
    required this.rank,
    required this.leaguePoints,
    required this.wins,
    required this.losses,
  });

  final String queueType;
  final String tier;
  final String rank;
  final int leaguePoints;
  final int wins;
  final int losses;

  int get totalGames => wins + losses;
  double get winRate => totalGames > 0 ? (wins / totalGames) * 100 : 0;

  String get displayRank => '$tier $rank';

  factory LeagueEntry.fromJson(Map<String, dynamic> json) {
    return LeagueEntry(
      queueType: json['queueType'] as String,
      tier: json['tier'] as String,
      rank: json['rank'] as String,
      leaguePoints: json['leaguePoints'] as int,
      wins: json['wins'] as int,
      losses: json['losses'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'queueType': queueType,
    'tier': tier,
    'rank': rank,
    'leaguePoints': leaguePoints,
    'wins': wins,
    'losses': losses,
  };
}

/// TFT Summoner info
class TFTSummoner {
  const TFTSummoner({
    required this.id,
    required this.accountId,
    required this.puuid,
    required this.profileIconId,
    required this.summonerLevel,
    this.name,
  });

  final String id;
  final String accountId;
  final String puuid;
  final int profileIconId;
  final int summonerLevel;
  final String? name;

  factory TFTSummoner.fromJson(Map<String, dynamic> json) {
    return TFTSummoner(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      puuid: json['puuid'] as String,
      profileIconId: json['profileIconId'] as int,
      summonerLevel: json['summonerLevel'] as int,
      name: json['name'] as String?,
    );
  }
}

/// TFT League Entry
class TFTLeagueEntry {
  const TFTLeagueEntry({
    required this.queueType,
    required this.tier,
    required this.rank,
    required this.leaguePoints,
    required this.wins,
    required this.losses,
  });

  final String queueType;
  final String tier;
  final String rank;
  final int leaguePoints;
  final int wins;
  final int losses;

  int get totalGames => wins + losses;
  double get winRate => totalGames > 0 ? (wins / totalGames) * 100 : 0;

  String get displayRank => '$tier $rank';

  factory TFTLeagueEntry.fromJson(Map<String, dynamic> json) {
    return TFTLeagueEntry(
      queueType: json['queueType'] as String,
      tier: json['tier'] as String,
      rank: json['rank'] as String,
      leaguePoints: json['leaguePoints'] as int,
      wins: json['wins'] as int,
      losses: json['losses'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'queueType': queueType,
    'tier': tier,
    'rank': rank,
    'leaguePoints': leaguePoints,
    'wins': wins,
    'losses': losses,
  };
}

/// Valorant player info
class ValorantPlayer {
  const ValorantPlayer({
    required this.puuid,
    required this.gameName,
    required this.tagLine,
  });

  final String puuid;
  final String gameName;
  final String tagLine;

  String get riotId => '$gameName#$tagLine';

  factory ValorantPlayer.fromJson(Map<String, dynamic> json) {
    return ValorantPlayer(
      puuid: json['puuid'] as String,
      gameName: json['gameName'] as String,
      tagLine: json['tagLine'] as String,
    );
  }
}

/// Valorant Match info
class ValorantMatch {
  const ValorantMatch({
    required this.matchId,
    required this.gameStartTime,
    required this.queueId,
  });

  final String matchId;
  final int gameStartTime;
  final String queueId;

  factory ValorantMatch.fromJson(Map<String, dynamic> json) {
    return ValorantMatch(
      matchId: json['matchId'] as String,
      gameStartTime: json['gameStartTimeMillis'] as int,
      queueId: json['queueId'] as String,
    );
  }
}

/// Combined Riot Games data for all games
class RiotGamesData {
  const RiotGamesData({
    this.lolSummoner,
    this.lolRankedEntries,
    this.tftSummoner,
    this.tftRankedEntries,
    this.valorantPlayer,
    this.valorantMatches,
  });

  final LoLSummoner? lolSummoner;
  final List<LeagueEntry>? lolRankedEntries;
  final TFTSummoner? tftSummoner;
  final List<TFTLeagueEntry>? tftRankedEntries;
  final ValorantPlayer? valorantPlayer;
  final List<ValorantMatch>? valorantMatches;

  bool get hasLoL => lolSummoner != null;
  bool get hasTFT => tftSummoner != null;
  bool get hasValorant => valorantPlayer != null;

  Map<String, dynamic> toJson() => {
    if (lolSummoner != null) 'lol_summoner_level': lolSummoner!.summonerLevel,
    if (lolSummoner != null) 'lol_profile_icon': lolSummoner!.profileIconId,
    if (lolRankedEntries != null && lolRankedEntries!.isNotEmpty)
      'lol_ranked': lolRankedEntries!.map((e) => e.toJson()).toList(),
    if (tftSummoner != null) 'tft_summoner_level': tftSummoner!.summonerLevel,
    if (tftRankedEntries != null && tftRankedEntries!.isNotEmpty)
      'tft_ranked': tftRankedEntries!.map((e) => e.toJson()).toList(),
    if (valorantMatches != null) 'valorant_match_count': valorantMatches!.length,
  };
}

/// Service for Riot Games API calls
/// Supports League of Legends, Valorant, and TFT
class RiotService {
  // Riot API base URLs
  static const _accountApiBase = 'https://americas.api.riotgames.com';

  // Platform-specific API base URLs
  static String _lolApiBase(String platform) => 'https://$platform.api.riotgames.com';
  static String _tftApiBase(String platform) => 'https://$platform.api.riotgames.com';
  static String _valorantApiBase(String cluster) => 'https://$cluster.api.riotgames.com';

  // API headers
  Map<String, String> _getHeaders(String accessToken) => {
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
  };

  // API key headers (for production API key)
  Map<String, String> _getApiKeyHeaders(String apiKey) => {
    'X-Riot-Token': apiKey,
    'Accept': 'application/json',
  };

  /// Fetch League of Legends summoner by PUUID
  Future<LoLSummoner?> getLoLSummoner(String puuid, String platform, String apiKey) async {
    try {
      appLogger.info('Riot Service: Fetching LoL summoner for PUUID: ${puuid.substring(0, 8)}...');

      final response = await http.get(
        Uri.parse('${_lolApiBase(platform)}/lol/summoner/v4/summoners/by-puuid/$puuid'),
        headers: _getApiKeyHeaders(apiKey),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LoLSummoner.fromJson(data);
      } else if (response.statusCode == 404) {
        appLogger.info('Riot Service: LoL summoner not found (user may not play LoL)');
        return null;
      } else {
        appLogger.error('Riot Service: Failed to fetch LoL summoner: ${response.statusCode}');
        return null;
      }
    } catch (e, stack) {
      appLogger.error('Riot Service: Error fetching LoL summoner', e, stack);
      return null;
    }
  }

  /// Fetch League of Legends ranked entries by summoner ID
  Future<List<LeagueEntry>> getLoLRankedEntries(String summonerId, String platform, String apiKey) async {
    try {
      appLogger.info('Riot Service: Fetching LoL ranked entries');

      final response = await http.get(
        Uri.parse('${_lolApiBase(platform)}/lol/league/v4/entries/by-summoner/$summonerId'),
        headers: _getApiKeyHeaders(apiKey),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => LeagueEntry.fromJson(e)).toList();
      } else {
        appLogger.error('Riot Service: Failed to fetch LoL ranked: ${response.statusCode}');
        return [];
      }
    } catch (e, stack) {
      appLogger.error('Riot Service: Error fetching LoL ranked', e, stack);
      return [];
    }
  }

  /// Fetch LoL match IDs by PUUID
  Future<List<String>> getLoLMatchIds(String puuid, String cluster, String apiKey, {int count = 20}) async {
    try {
      appLogger.info('Riot Service: Fetching LoL match IDs');

      final response = await http.get(
        Uri.parse('${_valorantApiBase(cluster)}/lol/match/v5/matches/by-puuid/$puuid/ids?count=$count'),
        headers: _getApiKeyHeaders(apiKey),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<String>();
      } else {
        appLogger.error('Riot Service: Failed to fetch LoL matches: ${response.statusCode}');
        return [];
      }
    } catch (e, stack) {
      appLogger.error('Riot Service: Error fetching LoL matches', e, stack);
      return [];
    }
  }

  /// Fetch TFT summoner by PUUID
  Future<TFTSummoner?> getTFTSummoner(String puuid, String platform, String apiKey) async {
    try {
      appLogger.info('Riot Service: Fetching TFT summoner for PUUID: ${puuid.substring(0, 8)}...');

      final response = await http.get(
        Uri.parse('${_tftApiBase(platform)}/tft/summoner/v1/summoners/by-puuid/$puuid'),
        headers: _getApiKeyHeaders(apiKey),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TFTSummoner.fromJson(data);
      } else if (response.statusCode == 404) {
        appLogger.info('Riot Service: TFT summoner not found (user may not play TFT)');
        return null;
      } else {
        appLogger.error('Riot Service: Failed to fetch TFT summoner: ${response.statusCode}');
        return null;
      }
    } catch (e, stack) {
      appLogger.error('Riot Service: Error fetching TFT summoner', e, stack);
      return null;
    }
  }

  /// Fetch TFT ranked entries by summoner ID
  Future<List<TFTLeagueEntry>> getTFTRankedEntries(String summonerId, String platform, String apiKey) async {
    try {
      appLogger.info('Riot Service: Fetching TFT ranked entries');

      final response = await http.get(
        Uri.parse('${_tftApiBase(platform)}/tft/league/v1/entries/by-summoner/$summonerId'),
        headers: _getApiKeyHeaders(apiKey),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => TFTLeagueEntry.fromJson(e)).toList();
      } else {
        appLogger.error('Riot Service: Failed to fetch TFT ranked: ${response.statusCode}');
        return [];
      }
    } catch (e, stack) {
      appLogger.error('Riot Service: Error fetching TFT ranked', e, stack);
      return [];
    }
  }

  /// Fetch TFT match IDs by PUUID
  Future<List<String>> getTFTMatchIds(String puuid, String cluster, String apiKey, {int count = 20}) async {
    try {
      appLogger.info('Riot Service: Fetching TFT match IDs');

      final response = await http.get(
        Uri.parse('${_valorantApiBase(cluster)}/tft/match/v1/matches/by-puuid/$puuid/ids?count=$count'),
        headers: _getApiKeyHeaders(apiKey),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<String>();
      } else {
        appLogger.error('Riot Service: Failed to fetch TFT matches: ${response.statusCode}');
        return [];
      }
    } catch (e, stack) {
      appLogger.error('Riot Service: Error fetching TFT matches', e, stack);
      return [];
    }
  }

  /// Fetch Valorant match list by PUUID
  /// Note: Requires separate Valorant API approval from Riot
  Future<List<ValorantMatch>> getValorantMatches(String puuid, String cluster, String apiKey) async {
    try {
      appLogger.info('Riot Service: Fetching Valorant matches');

      final response = await http.get(
        Uri.parse('${_valorantApiBase(cluster)}/val/match/v1/matchlists/by-puuid/$puuid'),
        headers: _getApiKeyHeaders(apiKey),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> history = data['history'] ?? [];
        return history.map((e) => ValorantMatch.fromJson(e)).toList();
      } else if (response.statusCode == 403) {
        appLogger.warning('Riot Service: Valorant API access not approved');
        return [];
      } else {
        appLogger.error('Riot Service: Failed to fetch Valorant matches: ${response.statusCode}');
        return [];
      }
    } catch (e, stack) {
      appLogger.error('Riot Service: Error fetching Valorant matches', e, stack);
      return [];
    }
  }

  /// Fetch all available data for a Riot account
  Future<RiotGamesData> fetchAllGameData({
    required String puuid,
    required String platform,
    required String apiKey,
  }) async {
    final cluster = RiotRegion.getCluster(platform);
    appLogger.info('Riot Service: Fetching all game data for platform: $platform, cluster: $cluster');

    // Fetch LoL and TFT summoner data in parallel
    final results = await Future.wait([
      getLoLSummoner(puuid, platform, apiKey),
      getTFTSummoner(puuid, platform, apiKey),
    ]);

    final lolSummoner = results[0] as LoLSummoner?;
    final tftSummoner = results[1] as TFTSummoner?;

    // Fetch ranked data for summoners that exist
    List<LeagueEntry>? lolRanked;
    List<TFTLeagueEntry>? tftRanked;

    if (lolSummoner != null) {
      lolRanked = await getLoLRankedEntries(lolSummoner.id, platform, apiKey);
    }

    if (tftSummoner != null) {
      tftRanked = await getTFTRankedEntries(tftSummoner.id, platform, apiKey);
    }

    // Try to fetch Valorant data (may fail if not approved)
    final valorantMatches = await getValorantMatches(puuid, cluster, apiKey);

    return RiotGamesData(
      lolSummoner: lolSummoner,
      lolRankedEntries: lolRanked,
      tftSummoner: tftSummoner,
      tftRankedEntries: tftRanked,
      valorantMatches: valorantMatches.isNotEmpty ? valorantMatches : null,
    );
  }

  /// Refresh RSO access token using refresh token
  Future<Map<String, String>?> refreshAccessToken(String refreshToken) async {
    try {
      appLogger.info('Riot Service: Refreshing access token');

      // This should go through our Edge Function for security
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/riot-refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'access_token': data['access_token'],
          'refresh_token': data['refresh_token'],
        };
      } else {
        appLogger.error('Riot Service: Token refresh failed: ${response.statusCode}');
        return null;
      }
    } catch (e, stack) {
      appLogger.error('Riot Service: Error refreshing token', e, stack);
      return null;
    }
  }
}

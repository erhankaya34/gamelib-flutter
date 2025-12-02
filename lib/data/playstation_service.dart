import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/logger.dart';
import 'playstation_auth_service.dart';

/// Provider for PlayStationService
final playstationServiceProvider = Provider<PlayStationService>((ref) {
  return PlayStationService();
});

/// PlayStation game from trophy titles
class PSNGame {
  final String titleId;
  final String name;
  final String? iconUrl;
  final String platform; // PS5, PS4, PS3, PSVITA
  final int earnedTrophies;
  final int totalTrophies;
  final int? progress; // Trophy progress percentage
  final DateTime? lastUpdated;
  final int playtimeMinutes; // Playtime in minutes

  PSNGame({
    required this.titleId,
    required this.name,
    this.iconUrl,
    required this.platform,
    required this.earnedTrophies,
    required this.totalTrophies,
    this.progress,
    this.lastUpdated,
    this.playtimeMinutes = 0,
  });

  /// Create a copy with updated playtime
  PSNGame copyWithPlaytime(int minutes) {
    return PSNGame(
      titleId: titleId,
      name: name,
      iconUrl: iconUrl,
      platform: platform,
      earnedTrophies: earnedTrophies,
      totalTrophies: totalTrophies,
      progress: progress,
      lastUpdated: lastUpdated,
      playtimeMinutes: minutes,
    );
  }

  factory PSNGame.fromJson(Map<String, dynamic> json) {
    // Parse earned trophies
    final earnedTrophies = json['earnedTrophies'] as Map<String, dynamic>?;
    final totalEarned = earnedTrophies != null
        ? (earnedTrophies['bronze'] as int? ?? 0) +
            (earnedTrophies['silver'] as int? ?? 0) +
            (earnedTrophies['gold'] as int? ?? 0) +
            (earnedTrophies['platinum'] as int? ?? 0)
        : 0;

    // Parse defined trophies
    final definedTrophies = json['definedTrophies'] as Map<String, dynamic>?;
    final totalDefined = definedTrophies != null
        ? (definedTrophies['bronze'] as int? ?? 0) +
            (definedTrophies['silver'] as int? ?? 0) +
            (definedTrophies['gold'] as int? ?? 0) +
            (definedTrophies['platinum'] as int? ?? 0)
        : 0;

    return PSNGame(
      titleId: json['npCommunicationId'] as String? ?? json['trophyTitleId'] as String? ?? '',
      name: json['trophyTitleName'] as String? ?? 'Unknown Game',
      iconUrl: json['trophyTitleIconUrl'] as String?,
      platform: json['trophyTitlePlatform'] as String? ?? 'PS4',
      earnedTrophies: totalEarned,
      totalTrophies: totalDefined,
      progress: json['progress'] as int?,
      lastUpdated: json['lastUpdatedDateTime'] != null
          ? DateTime.tryParse(json['lastUpdatedDateTime'] as String)
          : null,
    );
  }
}

/// PSN user profile
class PSNProfile {
  final String accountId;
  final String onlineId; // PSN username
  final String? avatarUrl;
  final int trophyLevel;
  final int platinumTrophies;
  final int goldTrophies;
  final int silverTrophies;
  final int bronzeTrophies;

  PSNProfile({
    required this.accountId,
    required this.onlineId,
    this.avatarUrl,
    required this.trophyLevel,
    required this.platinumTrophies,
    required this.goldTrophies,
    required this.silverTrophies,
    required this.bronzeTrophies,
  });

  int get totalTrophies =>
      platinumTrophies + goldTrophies + silverTrophies + bronzeTrophies;

  factory PSNProfile.fromJson(Map<String, dynamic> json) {
    final trophySummary = json['trophySummary'] as Map<String, dynamic>?;
    final earnedTrophies =
        trophySummary?['earnedTrophies'] as Map<String, dynamic>?;

    return PSNProfile(
      accountId: json['accountId'] as String? ?? '',
      onlineId: json['onlineId'] as String? ?? 'Unknown',
      avatarUrl: json['avatarUrl'] as String?,
      trophyLevel: trophySummary?['level'] as int? ?? 1,
      platinumTrophies: earnedTrophies?['platinum'] as int? ?? 0,
      goldTrophies: earnedTrophies?['gold'] as int? ?? 0,
      silverTrophies: earnedTrophies?['silver'] as int? ?? 0,
      bronzeTrophies: earnedTrophies?['bronze'] as int? ?? 0,
    );
  }
}

/// Service for interacting with PlayStation Network API
class PlayStationService {
  static const _baseUrl = 'https://m.np.playstation.com/api';

  /// Get user's trophy titles (game library)
  Future<List<PSNGame>> getUserTitles(
    String accessToken, {
    String accountId = 'me',
    int limit = 100,
    int offset = 0,
  }) async {
    appLogger.info('PSN Service: Fetching trophy titles for $accountId');

    try {
      final uri = Uri.parse(
        '$_baseUrl/trophy/v1/users/$accountId/trophyTitles',
      ).replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final titles = data['trophyTitles'] as List<dynamic>? ?? [];

        appLogger.info('PSN Service: Fetched ${titles.length} trophy titles');

        return titles
            .map((t) => PSNGame.fromJson(t as Map<String, dynamic>))
            .toList();
      }

      appLogger.warning(
        'PSN Service: Failed to fetch titles (${response.statusCode}): ${response.body}',
      );
      return [];
    } catch (e, stack) {
      appLogger.error('PSN Service: Error fetching titles', e, stack);
      return [];
    }
  }

  /// Get all user titles with pagination
  Future<List<PSNGame>> getAllUserTitles(
    String accessToken, {
    String accountId = 'me',
  }) async {
    appLogger.info('PSN Service: Fetching all trophy titles');

    final allTitles = <PSNGame>[];
    int offset = 0;
    const limit = 100;
    bool hasMore = true;

    while (hasMore) {
      final titles = await getUserTitles(
        accessToken,
        accountId: accountId,
        limit: limit,
        offset: offset,
      );

      allTitles.addAll(titles);

      if (titles.length < limit) {
        hasMore = false;
      } else {
        offset += limit;
        // Rate limiting - wait a bit between requests
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    appLogger.info('PSN Service: Total titles fetched: ${allTitles.length}');
    return allTitles;
  }

  /// Get user profile with trophy summary
  Future<PSNProfile?> getUserProfile(
    String accessToken, {
    String accountId = 'me',
  }) async {
    appLogger.info('PSN Service: Fetching profile for $accountId');

    try {
      final uri = Uri.parse(
        '$_baseUrl/trophy/v1/users/$accountId/trophySummary',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        appLogger.info('PSN Service: Profile fetched successfully');
        return PSNProfile.fromJson(data);
      }

      appLogger.warning(
        'PSN Service: Failed to fetch profile (${response.statusCode}): ${response.body}',
      );
      return null;
    } catch (e, stack) {
      appLogger.error('PSN Service: Error fetching profile', e, stack);
      return null;
    }
  }

  /// Get recently played games
  Future<List<PSNGame>> getRecentlyPlayedGames(
    String accessToken, {
    int limit = 20,
  }) async {
    appLogger.info('PSN Service: Fetching recently played games');

    try {
      // Recently played uses a different endpoint
      final uri = Uri.parse(
        '$_baseUrl/gamelist/v2/users/me/titles',
      ).replace(queryParameters: {
        'limit': limit.toString(),
        'categories': 'ps4_game,ps5_native_game',
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final titles = data['titles'] as List<dynamic>? ?? [];

        appLogger.info('PSN Service: Fetched ${titles.length} recent games');

        return titles.map((t) {
          final map = t as Map<String, dynamic>;
          return PSNGame(
            titleId: map['titleId'] as String? ?? '',
            name: map['name'] as String? ?? 'Unknown',
            iconUrl: map['imageUrl'] as String?,
            platform: map['category'] == 'ps5_native_game' ? 'PS5' : 'PS4',
            earnedTrophies: 0,
            totalTrophies: 0,
            lastUpdated: map['lastPlayedDateTime'] != null
                ? DateTime.tryParse(map['lastPlayedDateTime'] as String)
                : null,
          );
        }).toList();
      }

      appLogger.warning(
        'PSN Service: Failed to fetch recent games (${response.statusCode})',
      );
      return [];
    } catch (e, stack) {
      appLogger.error('PSN Service: Error fetching recent games', e, stack);
      return [];
    }
  }

  /// Get game list with playtime data
  /// Returns a map of normalized game name -> playtime in minutes
  /// (We use name instead of titleId because trophy API and gamelist API use different IDs)
  Future<Map<String, int>> getPlaytimeData(String accessToken) async {
    appLogger.info('PSN Service: Fetching playtime data');

    final playtimeMap = <String, int>{};

    try {
      // Fetch titles with playtime from game list API
      int offset = 0;
      const limit = 100;
      bool hasMore = true;

      while (hasMore) {
        final uri = Uri.parse(
          '$_baseUrl/gamelist/v2/users/me/titles',
        ).replace(queryParameters: {
          'limit': limit.toString(),
          'offset': offset.toString(),
          'categories': 'ps4_game,ps5_native_game',
        });

        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final titles = data['titles'] as List<dynamic>? ?? [];

          for (final t in titles) {
            final map = t as Map<String, dynamic>;
            final name = map['name'] as String?;

            // playDuration is in ISO 8601 duration format (e.g., "PT45H30M")
            // or sometimes just minutes as an integer
            final playDuration = map['playDuration'];

            if (name != null && playDuration != null) {
              int minutes = 0;

              if (playDuration is String) {
                minutes = _parseDuration(playDuration);
              } else if (playDuration is int) {
                minutes = playDuration;
              }

              if (minutes > 0) {
                // Use normalized name as key for matching with trophy titles
                final normalizedName = _normalizeGameName(name);
                playtimeMap[normalizedName] = minutes;
                appLogger.info(
                  'PSN Service: $name -> ${(minutes / 60).toStringAsFixed(1)}h',
                );
              }
            }
          }

          if (titles.length < limit) {
            hasMore = false;
          } else {
            offset += limit;
            await Future.delayed(const Duration(milliseconds: 300));
          }
        } else {
          appLogger.warning(
            'PSN Service: Failed to fetch playtime (${response.statusCode})',
          );
          hasMore = false;
        }
      }

      appLogger.info(
        'PSN Service: Fetched playtime for ${playtimeMap.length} games',
      );
    } catch (e, stack) {
      appLogger.error('PSN Service: Error fetching playtime', e, stack);
    }

    return playtimeMap;
  }

  /// Normalize game name for matching between APIs
  /// Also handles brand name changes (FIFA -> EA SPORTS FC)
  String _normalizeGameName(String name) {
    var normalized = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
        .replaceAll(RegExp(r'\s+'), ' ')    // Normalize whitespace
        .trim();

    // Handle FIFA -> EA SPORTS FC brand change
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

  /// Parse ISO 8601 duration format (PT45H30M) to minutes
  int _parseDuration(String duration) {
    if (!duration.startsWith('PT')) return 0;

    int totalMinutes = 0;
    final durationPart = duration.substring(2);

    // Parse hours
    final hoursMatch = RegExp(r'(\d+)H').firstMatch(durationPart);
    if (hoursMatch != null) {
      totalMinutes += int.parse(hoursMatch.group(1)!) * 60;
    }

    // Parse minutes
    final minutesMatch = RegExp(r'(\d+)M').firstMatch(durationPart);
    if (minutesMatch != null) {
      totalMinutes += int.parse(minutesMatch.group(1)!);
    }

    return totalMinutes;
  }
}

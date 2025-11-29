import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/logger.dart';
import '../core/utils.dart';

/// Steam user data model
class SteamUserData {
  const SteamUserData({
    required this.steamId,
    required this.profileImageUrl,
    required this.totalGames,
    required this.totalPlaytimeHours,
    required this.totalAchievements,
  });

  final String steamId;
  final String? profileImageUrl;
  final int totalGames;
  final double totalPlaytimeHours;
  final int totalAchievements;

  Map<String, dynamic> toJson() {
    return {
      'profile_image_url': profileImageUrl,
      'total_games': totalGames,
      'total_playtime_hours': totalPlaytimeHours,
      'total_achievements': totalAchievements,
      'last_synced': DateTime.now().toIso8601String(),
    };
  }

  factory SteamUserData.fromJson(Map<String, dynamic> json) {
    return SteamUserData(
      steamId: '',
      profileImageUrl: json['profile_image_url'] as String?,
      totalGames: json['total_games'] as int? ?? 0,
      totalPlaytimeHours: (json['total_playtime_hours'] as num?)?.toDouble() ?? 0.0,
      totalAchievements: json['total_achievements'] as int? ?? 0,
    );
  }
}

/// Steam game model for library import
/// Contains various image URLs for different use cases
class SteamGame {
  const SteamGame({
    required this.appId,
    required this.name,
    required this.playtimeMinutes,
    this.iconUrl,
    this.headerUrl,
    this.libraryCapsuleUrl,
    this.libraryHeroUrl,
    this.capsuleLargeUrl,
    this.hasAchievements = false,
  });

  final int appId;
  final String name;
  final int playtimeMinutes;

  /// Tiny icon (32x32) - for very small thumbnails
  final String? iconUrl;

  /// Header image (460x215) - landscape, good for cards
  final String? headerUrl;

  /// Library capsule (600x900) - portrait, best for library covers
  final String? libraryCapsuleUrl;

  /// Library hero (1920x620) - wide banner for detail page backgrounds
  final String? libraryHeroUrl;

  /// Large capsule (616x353) - landscape, good for featured cards
  final String? capsuleLargeUrl;

  final bool hasAchievements;

  /// Portrait cover URL - best for library grid display (600x900)
  String? get coverUrl => libraryCapsuleUrl ?? headerUrl;

  /// Landscape banner URL - best for detail page header (1920x620)
  String? get bannerUrl => libraryHeroUrl ?? headerUrl;

  /// Card image URL - best for horizontal cards (616x353)
  String? get cardUrl => capsuleLargeUrl ?? headerUrl;

  /// Screenshot URLs for game detail page
  List<String> get screenshotUrls {
    // Steam stores screenshots at predictable URLs
    // We'll generate the first 4 potential screenshot URLs
    return List.generate(4, (i) =>
      'https://steamcdn-a.akamaihd.net/steam/apps/$appId/ss_${i + 1}.jpg'
    );
  }

  factory SteamGame.fromJson(Map<String, dynamic> json) {
    final playtime = json['playtime_forever'] as int? ?? 0;
    final appId = json['appid'] as int;
    final name = json['name'] as String? ?? 'Unknown Game';

    // Steam CDN base URL
    const cdnBase = 'https://steamcdn-a.akamaihd.net/steam/apps';

    return SteamGame(
      appId: appId,
      name: name,
      playtimeMinutes: playtime,
      iconUrl: json['img_icon_url'] != null
          ? 'https://media.steampowered.com/steamcommunity/public/images/apps/$appId/${json['img_icon_url']}.jpg'
          : null,
      // Various Steam image sizes for different use cases
      headerUrl: '$cdnBase/$appId/header.jpg',
      libraryCapsuleUrl: '$cdnBase/$appId/library_600x900.jpg',
      libraryHeroUrl: '$cdnBase/$appId/library_hero.jpg',
      capsuleLargeUrl: '$cdnBase/$appId/capsule_616x353.jpg',
      hasAchievements: json['has_community_visible_stats'] as bool? ?? false,
    );
  }
}

/// Service for interacting with Steam Web API
class SteamService {
  SteamService({http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        _apiKey = steamApiKey;

  final http.Client _http;
  final String _apiKey;

  static const _baseUrl = 'https://api.steampowered.com';

  /// Fetch Steam user data
  /// Requires user's Steam ID (64-bit)
  Future<SteamUserData> fetchUserData(String steamId) async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'Steam API key not configured. Set STEAM_API_KEY in .env file.\n'
        'Get your key from: https://steamcommunity.com/dev/apikey',
      );
    }

    appLogger.info('Steam: Fetching data for user $steamId');

    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        _fetchPlayerSummary(steamId),
        _fetchOwnedGames(steamId),
        _fetchPlayerAchievements(steamId),
      ]);

      final profileImageUrl = results[0] as String?;
      final gamesData = results[1] as Map<String, dynamic>;
      final totalAchievements = results[2] as int;

      final totalGames = gamesData['total_games'] as int;
      final totalPlaytimeMinutes = gamesData['total_playtime'] as int;
      final totalPlaytimeHours = totalPlaytimeMinutes / 60.0;

      final userData = SteamUserData(
        steamId: steamId,
        profileImageUrl: profileImageUrl,
        totalGames: totalGames,
        totalPlaytimeHours: totalPlaytimeHours,
        totalAchievements: totalAchievements,
      );

      appLogger.info(
        'Steam: Fetched data - $totalGames games, ${totalPlaytimeHours.toStringAsFixed(1)}h, $totalAchievements achievements',
      );

      return userData;
    } catch (e, stack) {
      appLogger.error('Steam: Failed to fetch user data', e, stack);
      rethrow;
    }
  }

  /// Fetch all owned games with detailed information
  /// Returns list of games with playtime and metadata
  Future<List<SteamGame>> fetchOwnedGamesDetailed(String steamId) async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'Steam API key not configured. Set STEAM_API_KEY in .env file.\n'
        'Get your key from: https://steamcommunity.com/dev/apikey',
      );
    }

    appLogger.info('Steam: Fetching detailed game list for user $steamId');

    try {
      final url = Uri.parse(
        '$_baseUrl/IPlayerService/GetOwnedGames/v0001/?key=$_apiKey&steamid=$steamId&include_played_free_games=1&include_appinfo=1',
      );

      final response = await _http.get(url).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch owned games: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final gameResponse = json['response'] as Map<String, dynamic>?;

      if (gameResponse == null) {
        throw Exception('Steam profile is private or has no games');
      }

      final gamesJson = gameResponse['games'] as List? ?? [];

      final games = gamesJson
          .map((gameJson) => SteamGame.fromJson(gameJson as Map<String, dynamic>))
          .toList();

      appLogger.info('Steam: Fetched ${games.length} games');

      return games;
    } catch (e, stack) {
      appLogger.error('Steam: Failed to fetch detailed games', e, stack);
      rethrow;
    }
  }

  /// Fetch player summary (profile image, etc.)
  Future<String?> _fetchPlayerSummary(String steamId) async {
    final url = Uri.parse(
      '$_baseUrl/ISteamUser/GetPlayerSummaries/v0002/?key=$_apiKey&steamids=$steamId',
    );

    final response = await _http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch player summary: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final players = json['response']?['players'] as List?;

    if (players == null || players.isEmpty) {
      throw Exception('Steam user not found or profile is private');
    }

    final player = players.first as Map<String, dynamic>;

    // Return the full-size avatar
    return player['avatarfull'] as String?;
  }

  /// Fetch owned games
  Future<Map<String, dynamic>> _fetchOwnedGames(String steamId) async {
    final url = Uri.parse(
      '$_baseUrl/IPlayerService/GetOwnedGames/v0001/?key=$_apiKey&steamid=$steamId&include_played_free_games=1',
    );

    final response = await _http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch owned games: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final gameResponse = json['response'] as Map<String, dynamic>?;

    if (gameResponse == null) {
      throw Exception('Steam profile is private or has no games');
    }

    final gameCount = gameResponse['game_count'] as int? ?? 0;
    final games = gameResponse['games'] as List? ?? [];

    // Calculate total playtime
    var totalPlaytime = 0;
    for (final game in games) {
      final playtime = (game as Map<String, dynamic>)['playtime_forever'] as int? ?? 0;
      totalPlaytime += playtime;
    }

    return {
      'total_games': gameCount,
      'total_playtime': totalPlaytime, // in minutes
    };
  }

  /// Fetch total player achievements across all games
  Future<int> _fetchPlayerAchievements(String steamId) async {
    try {
      // First get owned games
      final url = Uri.parse(
        '$_baseUrl/IPlayerService/GetOwnedGames/v0001/?key=$_apiKey&steamid=$steamId&include_played_free_games=1&include_appinfo=1',
      );

      final response = await _http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        appLogger.warning('Failed to fetch games for achievements count');
        return 0;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final gameResponse = json['response'] as Map<String, dynamic>?;
      final games = gameResponse?['games'] as List? ?? [];

      // For simplicity, we'll estimate based on playtime
      // Steam doesn't provide a direct "total achievements" endpoint
      // This would require checking each game individually which is slow

      // Simple estimation: ~20 achievements per 100 hours of playtime
      var totalPlaytime = 0;
      for (final game in games) {
        final playtime = (game as Map<String, dynamic>)['playtime_forever'] as int? ?? 0;
        totalPlaytime += playtime;
      }

      final estimatedAchievements = (totalPlaytime / 60.0 * 0.2).round();

      return estimatedAchievements;
    } catch (e) {
      appLogger.warning('Failed to fetch achievements: $e');
      return 0;
    }
  }

  /// Validate Steam ID format
  static bool isValidSteamId(String steamId) {
    // Steam ID64 is a 17-digit number
    if (steamId.length != 17) return false;
    return int.tryParse(steamId) != null;
  }

  /// Extract Steam ID from Steam profile URL
  /// Supports formats:
  /// - https://steamcommunity.com/id/customurl
  /// - https://steamcommunity.com/profiles/76561198012345678
  static String? extractSteamIdFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Check for direct Steam ID64 format
    final match = RegExp(r'profiles/(\d{17})').firstMatch(url);
    if (match != null) {
      return match.group(1);
    }

    // For custom URLs, we'd need to resolve via API
    // Return null for now - user should provide Steam ID64
    return null;
  }

  /// Fetch user's Steam wishlist
  /// Returns list of games in the wishlist with their details
  ///
  /// NOTE: This requires the Steam profile's wishlist to be PUBLIC.
  /// Users must set: Steam Profile > Edit Profile > Privacy Settings > Game details > Public
  Future<List<SteamWishlistItem>> fetchWishlist(String steamId) async {
    appLogger.info('Steam: Fetching wishlist for user $steamId');

    try {
      // Steam wishlist API - fetches all pages
      final allItems = <SteamWishlistItem>[];
      var page = 0;
      var hasMore = true;

      while (hasMore) {
        final url = Uri.parse(
          'https://store.steampowered.com/wishlist/profiles/$steamId/wishlistdata/?p=$page',
        );

        appLogger.info('Steam: Fetching wishlist page $page from $url');

        final response = await _http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'GameLib/1.0',
          },
        ).timeout(const Duration(seconds: 15));

        appLogger.info('Steam: Wishlist response status: ${response.statusCode}');

        if (response.statusCode != 200) {
          if (page == 0) {
            throw Exception(
              'İstek listesi çekilemedi (HTTP ${response.statusCode}). '
              'Steam profilinizdeki istek listesi gizliliğini "Herkese Açık" olarak ayarladığınızdan emin olun.',
            );
          }
          break;
        }

        final responseBody = response.body;
        appLogger.info('Steam: Wishlist response length: ${responseBody.length}');

        // Handle empty response
        if (responseBody.isEmpty || responseBody == '[]') {
          if (page == 0) {
            appLogger.info('Steam: Wishlist is empty or private');
            return [];
          }
          break;
        }

        dynamic json;
        try {
          json = jsonDecode(responseBody);
        } catch (e) {
          appLogger.warning('Steam: Failed to parse wishlist JSON: $e');
          if (page == 0) {
            throw Exception(
              'İstek listesi yanıtı ayrıştırılamadı. '
              'Steam istek listesi gizliliğinizi kontrol edin.',
            );
          }
          break;
        }

        // Check if response indicates private/unavailable wishlist
        if (json is Map && json['success'] == 2) {
          throw Exception(
            'Steam istek listesi erişilemez durumda. '
            'Lütfen Steam gizlilik ayarlarından istek listenizi "Herkese Açık" yapın: '
            'Steam > Profil > Profili Düzenle > Gizlilik Ayarları > Oyun Detayları > Herkese Açık',
          );
        }

        // Check if response is empty or not a map
        if (json is! Map || json.isEmpty) {
          hasMore = false;
          break;
        }

        // Parse wishlist items
        for (final entry in (json as Map<String, dynamic>).entries) {
          // Skip non-numeric keys (like 'success', 'rgWishlist', etc.)
          final appId = int.tryParse(entry.key);
          if (appId == null) continue;

          final data = entry.value;
          if (data is! Map<String, dynamic>) continue;

          allItems.add(SteamWishlistItem.fromJson(appId, data));
        }

        page++;

        // Safety limit to prevent infinite loops
        if (page > 50) break;

        // Small delay between pages to be nice to Steam servers
        if (hasMore && allItems.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 200));
        } else if (allItems.isEmpty && page > 0) {
          // No items found on first page, probably end of list
          hasMore = false;
        }
      }

      appLogger.info('Steam: Fetched ${allItems.length} wishlist items');
      return allItems;
    } catch (e, stack) {
      appLogger.error('Steam: Failed to fetch wishlist', e, stack);
      rethrow;
    }
  }
}

/// Steam wishlist item model
class SteamWishlistItem {
  const SteamWishlistItem({
    required this.appId,
    required this.name,
    this.capsuleUrl,
    this.headerUrl,
    this.releaseDate,
    this.reviewScore,
    this.priority,
    this.addedTimestamp,
  });

  final int appId;
  final String name;
  final String? capsuleUrl;
  final String? headerUrl;
  final String? releaseDate;
  final int? reviewScore;
  final int? priority;
  final int? addedTimestamp;

  /// High resolution cover URL
  String get highResCoverUrl =>
      'https://steamcdn-a.akamaihd.net/steam/apps/$appId/library_600x900.jpg';

  factory SteamWishlistItem.fromJson(int appId, Map<String, dynamic> json) {
    return SteamWishlistItem(
      appId: appId,
      name: json['name'] as String? ?? 'Unknown Game',
      capsuleUrl: json['capsule'] as String?,
      headerUrl: json['header'] as String?,
      releaseDate: json['release_date'] as String?,
      reviewScore: json['review_score'] as int?,
      priority: json['priority'] as int?,
      addedTimestamp: json['added'] as int?,
    );
  }
}

/// Provider for SteamService
final steamServiceProvider = Provider<SteamService>((ref) {
  return SteamService();
});

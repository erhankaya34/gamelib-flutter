import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger.dart';
import '../models/game.dart';
import 'igdb_client.dart';
import 'steam_service.dart';

/// Service for matching Steam games with IGDB games
/// Uses Steam App ID batch lookup (fast) then fuzzy name matching (fallback)
class IgdbSteamMatcher {
  IgdbSteamMatcher(this.igdbClient);

  final IgdbClient igdbClient;

  /// Match multiple Steam games using fast batch lookup
  /// Returns a map of Steam App ID → IGDB Game (or null if no match)
  ///
  /// Strategy:
  /// 1. First: Use IGDB external_games to batch lookup by Steam App ID (FAST)
  /// 2. Fallback: For unmatched games, use fuzzy name search (SLOW)
  Future<Map<int, Game?>> matchMultipleSteamGames(
    List<SteamGame> steamGames, {
    bool useFuzzyFallback = true,
  }) async {
    appLogger.info('IGDB Matcher: Matching ${steamGames.length} games');

    final matches = <int, Game?>{};

    // Step 1: Fast batch lookup using Steam App IDs
    appLogger.info('IGDB Matcher: Step 1 - Fast batch lookup by Steam App ID');
    final steamAppIds = steamGames.map((g) => g.appId).toList();

    try {
      final batchResults = await igdbClient.fetchGamesBySteamAppIds(steamAppIds);

      for (final steamGame in steamGames) {
        matches[steamGame.appId] = batchResults[steamGame.appId];
      }

      final matchedCount = batchResults.length;
      appLogger.info('IGDB Matcher: Fast lookup matched $matchedCount/${steamGames.length} games');
    } catch (e) {
      appLogger.warning('IGDB Matcher: Batch lookup failed, will use fuzzy fallback: $e');
    }

    // Step 2: Fuzzy fallback for unmatched games (optional, slower)
    if (useFuzzyFallback) {
      final unmatchedGames = steamGames.where((g) => matches[g.appId] == null).toList();

      if (unmatchedGames.isNotEmpty) {
        appLogger.info('IGDB Matcher: Step 2 - Fuzzy search for ${unmatchedGames.length} unmatched games');

        // Process 4 games in parallel (IGDB rate limit: 4 req/sec)
        const batchSize = 4;
        for (var i = 0; i < unmatchedGames.length; i += batchSize) {
          final batch = unmatchedGames.skip(i).take(batchSize).toList();

          final batchResults = await Future.wait(
            batch.map((game) async {
              try {
                final match = await _fuzzyMatchSteamGame(game);
                return MapEntry(game.appId, match);
              } catch (e) {
                appLogger.warning('IGDB Matcher: Fuzzy failed for ${game.name}: $e');
                return MapEntry<int, Game?>(game.appId, null);
              }
            }),
          );

          for (final entry in batchResults) {
            if (entry.value != null) {
              matches[entry.key] = entry.value;
            }
          }

          // Log progress
          final processed = i + batch.length;
          if (processed % 20 == 0 || processed == unmatchedGames.length) {
            appLogger.info('IGDB Matcher: Fuzzy progress $processed/${unmatchedGames.length}');
          }

          if (i + batchSize < unmatchedGames.length) {
            await Future.delayed(const Duration(milliseconds: 260));
          }
        }
      }
    }

    final matchedCount = matches.values.where((g) => g != null).length;
    final unmatchedCount = steamGames.length - matchedCount;
    appLogger.info(
      'IGDB Matcher: Complete - $matchedCount matched, $unmatchedCount unmatched',
    );

    return matches;
  }

  /// Fuzzy match a single Steam game with IGDB (slower fallback)
  /// Uses name similarity with lower threshold for better coverage
  Future<Game?> _fuzzyMatchSteamGame(SteamGame steamGame) async {
    try {
      // Search IGDB for games with similar names
      final results = await igdbClient.searchGames(steamGame.name);

      if (results.isEmpty) {
        return null;
      }

      // Find best match using name similarity
      Game? bestMatch;
      double bestSimilarity = 0.0;

      for (final game in results) {
        final similarity = _calculateSimilarity(
          _normalizeName(steamGame.name),
          _normalizeName(game.name),
        );

        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestMatch = game;
        }
      }

      // Lower threshold (60%) for better coverage of games with slightly different names
      if (bestSimilarity > 0.6 && bestMatch != null) {
        appLogger.info(
          'IGDB Matcher: Fuzzy matched "${steamGame.name}" → "${bestMatch.name}" (${(bestSimilarity * 100).toStringAsFixed(0)}%)',
        );
        return bestMatch;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Normalize game name for better matching
  /// Removes common suffixes, special characters, etc.
  String _normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[™®©]'), '')
        .replaceAll(RegExp(r'\s*[-:]\s*(definitive|complete|enhanced|remastered|goty|game of the year|gold|special|deluxe|ultimate|anniversary)\s*edition\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Calculate similarity between two strings
  /// Returns a value between 0.0 (no match) and 1.0 (exact match)
  /// Uses Levenshtein distance for fuzzy matching
  double _calculateSimilarity(String s1, String s2) {
    // Exact match
    if (s1 == s2) return 1.0;

    // Check if one contains the other
    if (s1.contains(s2) || s2.contains(s1)) {
      final shorter = s1.length < s2.length ? s1.length : s2.length;
      final longer = s1.length > s2.length ? s1.length : s2.length;
      return shorter / longer;
    }

    // Calculate Levenshtein distance
    final distance = _levenshteinDistance(s1, s2);
    final maxLength = s1.length > s2.length ? s1.length : s2.length;

    // Convert distance to similarity (0.0 - 1.0)
    return 1.0 - (distance / maxLength);
  }

  /// Calculate Levenshtein distance between two strings
  /// Returns the minimum number of edits needed to transform s1 into s2
  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    // Create matrix
    final matrix = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );

    // Initialize first row and column
    for (var i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    // Fill matrix
    for (var i = 1; i <= len1; i++) {
      for (var j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = _min3(
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        );
      }
    }

    return matrix[len1][len2];
  }

  /// Helper to find minimum of three integers
  int _min3(int a, int b, int c) {
    var min = a;
    if (b < min) min = b;
    if (c < min) min = c;
    return min;
  }
}

/// Provider for IgdbSteamMatcher
final igdbSteamMatcherProvider = Provider<IgdbSteamMatcher>((ref) {
  final igdbClient = ref.watch(igdbClientProvider);
  return IgdbSteamMatcher(igdbClient);
});

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/logger.dart';
import '../core/utils.dart';
import '../models/game.dart';

class IgdbClient {
  IgdbClient({
    http.Client? httpClient,
    String? clientId,
    String? accessToken,
  })  : _http = httpClient ?? http.Client(),
        clientId = (clientId ?? igdbClientId).trim(),
        accessToken = (accessToken ?? igdbAccessToken).trim();

  // ignore: unused_field
  final http.Client _http;
  final String clientId;
  final String accessToken;
  static const _baseUrl = 'https://api.igdb.com/v4';

  Future<List<Game>> searchGames(String query) async {
    final sanitizedQuery = query.trim();
    if (sanitizedQuery.isEmpty) {
      return [];
    }

    if (clientId.isEmpty || accessToken.isEmpty) {
      throw StateError(
        'Missing IGDB credentials. Set IGDB_CLIENT_ID and IGDB_ACCESS_TOKEN in .env.',
      );
    }

    final uri = Uri.parse('$_baseUrl/games');
    final body = '''
search "$sanitizedQuery";
fields id,name,summary,cover.url,screenshots.url,platforms.name,genres.name,aggregated_rating,aggregated_rating_count,rating,rating_count,first_release_date;
limit 20;
''';

    appLogger.info('IGDB: searching "$sanitizedQuery"');

    final request = http.Request('POST', uri)
      ..headers.addAll(<String, String>{
        'Client-ID': clientId,
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      })
      ..body = body;

    final streamed = await _http.send(request).timeout(const Duration(seconds: 12));
    final responseBody = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      if (streamed.statusCode == 401 || streamed.statusCode == 403) {
        throw StateError(
          'IGDB erişim yetkisi reddedildi (401/403). Client ID ve App Access Token doğru ve geçerli mi? Token süresi dolduysa yeniden üretin.',
        );
      }
      appLogger.error(
        'IGDB: search failed (${streamed.statusCode}) for "$sanitizedQuery"',
        responseBody,
      );
      throw StateError('IGDB search failed (${streamed.statusCode}). See logs.');
    }

    final decoded = jsonDecode(responseBody) as List<dynamic>;
    final results = decoded.map((item) {
      final map = item as Map<String, dynamic>;
      return Game.fromMap(map);
    }).toList();

    appLogger.info('IGDB: ${results.length} result(s) for "$sanitizedQuery"');
    return results;
  }

  Future<List<Game>> fetchTrendingGames() async {
    if (clientId.isEmpty || accessToken.isEmpty) {
      throw StateError(
        'Missing IGDB credentials. Set IGDB_CLIENT_ID and IGDB_ACCESS_TOKEN in .env.',
      );
    }

    final uri = Uri.parse('$_baseUrl/games');
    // Fetch trending games: highly rated, popular games from recent years
    // Use aggregated_rating for critical acclaim and rating_count for popularity
    final currentYear = DateTime.now().year;
    final body = '''
where aggregated_rating > 75 & rating_count > 100 & first_release_date > ${DateTime(currentYear - 5).millisecondsSinceEpoch ~/ 1000};
fields id,name,summary,cover.url,screenshots.url,platforms.name,genres.name,aggregated_rating,aggregated_rating_count,rating,rating_count,first_release_date;
sort aggregated_rating desc;
limit 20;
''';

    appLogger.info('IGDB: fetching trending games');

    final request = http.Request('POST', uri)
      ..headers.addAll(<String, String>{
        'Client-ID': clientId,
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      })
      ..body = body;

    final streamed = await _http.send(request).timeout(const Duration(seconds: 12));
    final responseBody = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      if (streamed.statusCode == 401 || streamed.statusCode == 403) {
        throw StateError(
          'IGDB erişim yetkisi reddedildi (401/403). Client ID ve App Access Token doğru ve geçerli mi? Token süresi dolduysa yeniden üretin.',
        );
      }
      appLogger.error(
        'IGDB: trending games failed (${streamed.statusCode})',
        responseBody,
      );
      throw StateError('IGDB trending games failed (${streamed.statusCode}). See logs.');
    }

    final decoded = jsonDecode(responseBody) as List<dynamic>;
    final results = decoded.map((item) {
      final map = item as Map<String, dynamic>;
      return Game.fromMap(map);
    }).toList();

    appLogger.info('IGDB: ${results.length} trending game(s)');
    return results;
  }

  Future<Game?> fetchGameById(int id) async {
    if (clientId.isEmpty || accessToken.isEmpty) {
      throw StateError(
        'Missing IGDB credentials. Set IGDB_CLIENT_ID and IGDB_ACCESS_TOKEN in .env.',
      );
    }
    final uri = Uri.parse('$_baseUrl/games');
    final body = '''
where id = $id;
fields id,name,summary,cover.url,screenshots.url,platforms.name,genres.name,aggregated_rating,aggregated_rating_count,rating,rating_count,first_release_date;
limit 1;
''';

    final request = http.Request('POST', uri)
      ..headers.addAll(<String, String>{
        'Client-ID': clientId,
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      })
      ..body = body;

    final streamed = await _http.send(request).timeout(const Duration(seconds: 12));
    final responseBody = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      if (streamed.statusCode == 401 || streamed.statusCode == 403) {
        throw StateError(
          'IGDB erişim yetkisi reddedildi (401/403). Client ID ve App Access Token doğru ve geçerli mi? Token süresi dolduysa yeniden üretin.',
        );
      }
      appLogger.error(
        'IGDB: detail failed (${streamed.statusCode}) for "$id"',
        responseBody,
      );
      throw StateError('IGDB detail failed (${streamed.statusCode}). See logs.');
    }

    final decoded = jsonDecode(responseBody) as List<dynamic>;
    if (decoded.isEmpty) return null;
    return Game.fromMap(decoded.first as Map<String, dynamic>);
  }

  /// Fetch all available genres from IGDB
  /// Used for genre onboarding screen
  Future<List<String>> fetchGenres() async {
    if (clientId.isEmpty || accessToken.isEmpty) {
      throw StateError(
        'Missing IGDB credentials. Set IGDB_CLIENT_ID and IGDB_ACCESS_TOKEN in .env.',
      );
    }

    final uri = Uri.parse('$_baseUrl/genres');
    final body = '''
fields name;
limit 50;
sort name asc;
''';

    appLogger.info('IGDB: fetching genres');

    final request = http.Request('POST', uri)
      ..headers.addAll(<String, String>{
        'Client-ID': clientId,
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      })
      ..body = body;

    final streamed = await _http.send(request).timeout(const Duration(seconds: 12));
    final responseBody = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      appLogger.error(
        'IGDB: genres failed (${streamed.statusCode})',
        responseBody,
      );
      throw StateError('Failed to fetch genres (${streamed.statusCode}). See logs.');
    }

    final decoded = jsonDecode(responseBody) as List<dynamic>;
    final genres = decoded
        .map((item) => item['name'] as String)
        .toList();

    appLogger.info('IGDB: ${genres.length} genre(s) fetched');
    return genres;
  }

  /// Fetch game recommendations based on user's favorite genres
  /// Used for feed screen when user has <3 friends
  Future<List<Game>> fetchRecommendationsByGenres(
    List<String> genreNames, {
    int limit = 6,
  }) async {
    if (clientId.isEmpty || accessToken.isEmpty) {
      throw StateError(
        'Missing IGDB credentials. Set IGDB_CLIENT_ID and IGDB_ACCESS_TOKEN in .env.',
      );
    }

    if (genreNames.isEmpty) {
      // Fallback to trending games if no genres specified
      return fetchTrendingGames();
    }

    // First, get genre IDs from genre names
    final genreUri = Uri.parse('$_baseUrl/genres');
    final genreQuery = genreNames.map((g) => '"$g"').join(',');
    final genreBody = '''
where name = ($genreQuery);
fields id,name;
limit 50;
''';

    final genreRequest = http.Request('POST', genreUri)
      ..headers.addAll(<String, String>{
        'Client-ID': clientId,
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      })
      ..body = genreBody;

    final genreStreamed = await _http.send(genreRequest).timeout(const Duration(seconds: 12));
    final genreResponseBody = await genreStreamed.stream.bytesToString();

    if (genreStreamed.statusCode != 200) {
      appLogger.error(
        'IGDB: genre lookup failed (${genreStreamed.statusCode})',
        genreResponseBody,
      );
      // Fallback to trending
      return fetchTrendingGames();
    }

    final genreDecoded = jsonDecode(genreResponseBody) as List<dynamic>;
    final genreIds = genreDecoded
        .map((item) => item['id'] as int)
        .toList();

    if (genreIds.isEmpty) {
      // Fallback to trending if no matching genres
      return fetchTrendingGames();
    }

    // Now fetch highly rated games in these genres
    final uri = Uri.parse('$_baseUrl/games');
    final currentYear = DateTime.now().year;
    final genreIdList = genreIds.join(',');
    final body = '''
where genres = ($genreIdList) & aggregated_rating > 70 & rating_count > 50 & first_release_date > ${DateTime(currentYear - 7).millisecondsSinceEpoch ~/ 1000};
fields id,name,summary,cover.url,screenshots.url,platforms.name,genres.name,aggregated_rating,aggregated_rating_count,rating,rating_count,first_release_date;
sort aggregated_rating desc;
limit $limit;
''';

    appLogger.info('IGDB: fetching recommendations for genres: $genreNames');

    final request = http.Request('POST', uri)
      ..headers.addAll(<String, String>{
        'Client-ID': clientId,
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      })
      ..body = body;

    final streamed = await _http.send(request).timeout(const Duration(seconds: 12));
    final responseBody = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      appLogger.error(
        'IGDB: recommendations failed (${streamed.statusCode})',
        responseBody,
      );
      throw StateError('Failed to fetch recommendations (${streamed.statusCode}). See logs.');
    }

    final decoded = jsonDecode(responseBody) as List<dynamic>;
    final results = decoded.map((item) {
      final map = item as Map<String, dynamic>;
      return Game.fromMap(map);
    }).toList();

    appLogger.info('IGDB: ${results.length} recommendation(s) for genres: $genreNames');
    return results;
  }

  /// Fetch indie games personalized to user's favorite genres
  /// Used for discover screen
  Future<List<Game>> fetchIndieGames(List<String> genreNames) async {
    if (clientId.isEmpty || accessToken.isEmpty) {
      throw StateError(
        'Missing IGDB credentials. Set IGDB_CLIENT_ID and IGDB_ACCESS_TOKEN in .env.',
      );
    }

    // Get genre IDs if genres specified
    List<int> genreIds = [];
    if (genreNames.isNotEmpty) {
      final genreUri = Uri.parse('$_baseUrl/genres');
      final genreQuery = genreNames.map((g) => '"$g"').join(',');
      final genreBody = '''
where name = ($genreQuery);
fields id,name;
limit 50;
''';

      final genreRequest = http.Request('POST', genreUri)
        ..headers.addAll(<String, String>{
          'Client-ID': clientId,
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        })
        ..body = genreBody;

      final genreStreamed = await _http.send(genreRequest).timeout(const Duration(seconds: 12));
      final genreResponseBody = await genreStreamed.stream.bytesToString();

      if (genreStreamed.statusCode == 200) {
        final genreDecoded = jsonDecode(genreResponseBody) as List<dynamic>;
        genreIds = genreDecoded.map((item) => item['id'] as int).toList();
      }
    }

    // Build query for indie games
    final uri = Uri.parse('$_baseUrl/games');
    final currentYear = DateTime.now().year;

    // IGDB doesn't have a direct "indie" flag, so we filter by:
    // - Category 0 (main game)
    // - Good ratings but not too mainstream (rating_count between 10-500)
    // - Recent years (last 10 years)
    // - Match user's genres if available
    String whereClause = '''
category = 0 &
rating_count > 10 & rating_count < 500 &
aggregated_rating > 65 &
first_release_date > ${DateTime(currentYear - 10).millisecondsSinceEpoch ~/ 1000}
''';

    if (genreIds.isNotEmpty) {
      final genreIdList = genreIds.join(',');
      whereClause += ' & genres = ($genreIdList)';
    }

    final body = '''
where $whereClause;
fields id,name,summary,cover.url,screenshots.url,platforms.name,genres.name,aggregated_rating,aggregated_rating_count,rating,rating_count,first_release_date;
sort aggregated_rating desc;
limit 30;
''';

    appLogger.info('IGDB: fetching indie games');

    final request = http.Request('POST', uri)
      ..headers.addAll(<String, String>{
        'Client-ID': clientId,
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      })
      ..body = body;

    final streamed = await _http.send(request).timeout(const Duration(seconds: 12));
    final responseBody = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      appLogger.error(
        'IGDB: indie games failed (${streamed.statusCode})',
        responseBody,
      );
      throw StateError('Failed to fetch indie games (${streamed.statusCode}). See logs.');
    }

    final decoded = jsonDecode(responseBody) as List<dynamic>;
    final results = decoded.map((item) {
      final map = item as Map<String, dynamic>;
      return Game.fromMap(map);
    }).toList();

    appLogger.info('IGDB: ${results.length} indie game(s)');
    return results;
  }
}

final igdbClientProvider = Provider<IgdbClient>((ref) {
  return IgdbClient();
});

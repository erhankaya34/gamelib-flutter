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
}

final igdbClientProvider = Provider<IgdbClient>((ref) {
  return IgdbClient();
});

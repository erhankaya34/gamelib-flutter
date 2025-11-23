import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/utils.dart';
import '../models/game.dart';

class IgdbClient {
  IgdbClient({
    http.Client? httpClient,
    String? clientId,
    String? accessToken,
  })  : _http = httpClient ?? http.Client(),
        clientId = clientId ?? igdbClientId,
        accessToken = accessToken ?? igdbAccessToken;

  // ignore: unused_field
  final http.Client _http;
  final String clientId;
  final String accessToken;

  Future<List<Game>> searchGames(String query) async {
    if (query.isEmpty) return [];
    // IGDB integration will be added later.
    return [];
  }

  Future<Game?> fetchGameById(int id) async {
    // Placeholder for future detailed fetch.
    return null;
  }
}

final igdbClientProvider = Provider<IgdbClient>((ref) {
  return IgdbClient();
});

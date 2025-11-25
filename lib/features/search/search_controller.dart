import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/igdb_client.dart';
import '../../models/game.dart';

final searchControllerProvider =
    StateNotifierProvider<SearchController, AsyncValue<List<Game>>>((ref) {
  return SearchController(ref);
});

// Provider for trending games (cached)
final trendingGamesProvider = FutureProvider<List<Game>>((ref) async {
  final client = ref.read(igdbClientProvider);
  return client.fetchTrendingGames();
});

class SearchController extends StateNotifier<AsyncValue<List<Game>>> {
  SearchController(this.ref) : super(const AsyncData(<Game>[]));

  final Ref ref;

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const AsyncData(<Game>[]);
      return;
    }

    state = const AsyncLoading();
    try {
      final results = await ref.read(igdbClientProvider).searchGames(trimmed);
      state = AsyncData(results);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/igdb_client.dart';
import '../../models/game.dart';

final searchControllerProvider =
    StateNotifierProvider<SearchController, AsyncValue<List<Game>>>((ref) {
  return SearchController(ref);
});

class SearchController extends StateNotifier<AsyncValue<List<Game>>> {
  SearchController(this.ref) : super(const AsyncData(<Game>[]));

  final Ref ref;

  Future<void> search(String query) async {
    state = const AsyncLoading();
    try {
      final results = await ref.read(igdbClientProvider).searchGames(query);
      state = AsyncData(results);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

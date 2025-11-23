import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/game_log.dart';

final libraryControllerProvider =
    StateNotifierProvider<LibraryController, List<GameLog>>((ref) {
  return LibraryController();
});

class LibraryController extends StateNotifier<List<GameLog>> {
  LibraryController() : super(const []);

  void upsertLog(GameLog log) {
    state = [
      for (final existing in state)
        if (existing.id == log.id) log else existing,
    ];
    if (!state.any((item) => item.id == log.id)) {
      state = [...state, log];
    }
  }
}

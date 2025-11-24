import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/game_log.dart';

final libraryControllerProvider =
    StateNotifierProvider<LibraryController, List<GameLog>>((ref) {
  return LibraryController();
});

class LibraryController extends StateNotifier<List<GameLog>> {
  LibraryController() : super(const []);

  void upsertLog(GameLog log) {
    final existingIndex = state.indexWhere((item) => item.id == log.id);
    if (existingIndex == -1) {
      state = [...state, log];
    } else {
      final updated = [...state];
      updated[existingIndex] = log;
      state = updated;
    }
  }

  bool isInLibrary(int gameId) {
    return state.any((log) => log.game.id == gameId);
  }

  GameLog? getLogFor(int gameId) {
    for (final log in state) {
      if (log.game.id == gameId) return log;
    }
    return null;
  }
}

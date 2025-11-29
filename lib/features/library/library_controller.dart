/// LibraryController - Oyun Koleksiyonu Yönetimi
///
/// Bu controller kullanıcının oyun koleksiyonunu (library) yönetir.
/// Supabase ile senkronize çalışır: Her değişiklik hem local state'e
/// hem de Supabase database'ine kaydedilir.
///
/// Kullanım:
/// ```dart
/// final library = ref.watch(libraryControllerProvider);
/// library.when(
///   data: (games) => ListView.builder(...),
///   loading: () => CircularProgressIndicator(),
///   error: (e, st) => Text('Hata: $e'),
/// );
/// ```

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger.dart';
import '../../data/game_repository.dart';
import '../../data/supabase_client.dart';
import '../../models/game_log.dart';

/// Provider: Kullanıcının oyun koleksiyonunu sağlar (Supabase'den)
///
/// AsyncNotifier kullanıyoruz çünkü:
/// - Veri Supabase'den asenkron yüklenir
/// - Loading/error durumlarını otomatik yönetir
/// - Auto-refresh desteği var
final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, List<GameLog>>(
  LibraryController.new,
);

class LibraryController extends AsyncNotifier<List<GameLog>> {
  /// İlk yükleme: Supabase'den kullanıcının oyunlarını getir
  ///
  /// Bu method AsyncNotifier tarafından otomatik çağrılır.
  /// Dönen değer widget'lara AsyncValue<List<GameLog>> olarak gider.
  @override
  Future<List<GameLog>> build() async {
    // Kullanıcı ID'sini al
    final userId = _getCurrentUserId();
    if (userId == null) {
      appLogger.warning('LibraryController: No user logged in');
      return []; // Giriş yapılmamışsa boş liste dön
    }

    try {
      appLogger.info('LibraryController: Loading collection for user $userId');

      // Supabase'den koleksiyon ve wishlist oyunlarını fetch et
      // Manuel eklenen + Steam wishlist'ten gelen oyunlar
      // (Steam kütüphanesi ayrı ekranda, status='playing' olarak kaydediliyor)
      final repository = ref.read(gameRepositoryProvider);
      final games = await repository.fetchCollectionAndWishlist(userId);

      appLogger.info('LibraryController: Loaded ${games.length} games');
      return games;
    } catch (e, stack) {
      appLogger.error('LibraryController: Failed to load games', e, stack);
      rethrow; // Hata UI'a gider (AsyncValue.error olarak)
    }
  }

  /// Oyun ekle veya güncelle (Upsert = Update + Insert)
  ///
  /// [log] - Eklenecek/güncellenecek oyun logu
  ///
  /// Bu method:
  /// 1. Önce Supabase'e kaydeder
  /// 2. Başarılıysa local state'i günceller
  /// 3. Hata varsa kullanıcıya gösterir
  ///
  /// Örnek:
  /// ```dart
  /// await ref.read(libraryControllerProvider.notifier).upsertLog(
  ///   GameLog(
  ///     id: 'game-123',
  ///     game: myGame,
  ///     status: PlayStatus.completed,
  ///     rating: 9,
  ///   ),
  /// );
  /// ```
  Future<void> upsertLog(GameLog log) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('Kullanıcı girişi yapılmamış');
    }

    try {
      appLogger.info('LibraryController: Upserting game ${log.game.name}');

      // 1. Supabase'e kaydet
      final repository = ref.read(gameRepositoryProvider);
      await repository.upsertGameLog(userId, log);

      // 2. Local state'i güncelle
      // (Optimistic update: Supabase'den tekrar fetch etmeden güncelle)
      final currentGames = state.valueOrNull ?? [];
      final existingIndex = currentGames.indexWhere((g) => g.id == log.id);

      if (existingIndex == -1) {
        // Yeni oyun ekle
        state = AsyncData([...currentGames, log]);
      } else {
        // Mevcut oyunu güncelle
        final updated = [...currentGames];
        updated[existingIndex] = log;
        state = AsyncData(updated);
      }

      appLogger.info('LibraryController: Successfully upserted ${log.game.name}');
    } catch (e, stack) {
      appLogger.error('LibraryController: Failed to upsert game', e, stack);
      rethrow; // Hatayı UI'a fırlat
    }
  }

  /// Oyun sil
  ///
  /// [logId] - Silinecek oyun log'unun ID'si
  ///
  /// Bu method:
  /// 1. Supabase'den siler
  /// 2. Başarılıysa local state'den kaldırır
  ///
  /// Örnek:
  /// ```dart
  /// await ref.read(libraryControllerProvider.notifier).deleteLog('game-123');
  /// ```
  Future<void> deleteLog(String logId) async {
    try {
      appLogger.info('LibraryController: Deleting game $logId');

      // 1. Supabase'den sil
      final repository = ref.read(gameRepositoryProvider);
      await repository.deleteGameLog(logId);

      // 2. Local state'den kaldır
      final currentGames = state.valueOrNull ?? [];
      state = AsyncData(currentGames.where((g) => g.id != logId).toList());

      appLogger.info('LibraryController: Successfully deleted game $logId');
    } catch (e, stack) {
      appLogger.error('LibraryController: Failed to delete game', e, stack);
      rethrow;
    }
  }

  /// Oyunun kütüphanede olup olmadığını kontrol et
  ///
  /// [gameId] - IGDB game ID
  /// Returns: true ise oyun var, false ise yok
  bool isInLibrary(int gameId) {
    final games = state.valueOrNull ?? [];
    return games.any((log) => log.game.id == gameId);
  }

  /// Belirli bir oyunun logunu getir
  ///
  /// [gameId] - IGDB game ID
  /// Returns: GameLog veya null (oyun yoksa)
  GameLog? getLogFor(int gameId) {
    final games = state.valueOrNull ?? [];
    for (final log in games) {
      if (log.game.id == gameId) return log;
    }
    return null;
  }

  /// Koleksiyonu yeniden yükle (refresh)
  ///
  /// Örneğin pull-to-refresh yaparken kullanılabilir
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  /// Mevcut kullanıcının ID'sini al (Supabase auth'dan)
  String? _getCurrentUserId() {
    return ref.read(supabaseProvider).auth.currentUser?.id;
  }
}

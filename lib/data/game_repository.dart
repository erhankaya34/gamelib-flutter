/// GameRepository - Supabase Database İşlemleri
///
/// Bu sınıf Flutter ile Supabase database arasındaki tüm iletişimi yönetir.
/// CRUD (Create, Read, Update, Delete) operasyonlarını içerir.
///
/// Kullanım:
/// ```dart
/// final repo = ref.read(gameRepositoryProvider);
/// final games = await repo.fetchUserGameLogs(userId);
/// ```

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logger.dart';
import '../models/badge.dart';
import '../models/game.dart';
import '../models/game_log.dart';
import '../models/user_stats.dart';
import 'supabase_client.dart';

class GameRepository {
  GameRepository(this.supabase);

  /// Supabase client instance (tüm database işlemleri için)
  final SupabaseClient supabase;

  // ============================================
  // GAME LOGS İŞLEMLERİ (Koleksiyon & İstek Listesi)
  // ============================================

  /// Kullanıcının tüm oyunlarını getir
  ///
  /// [userId] - Kullanıcı ID'si (Supabase auth.users.id)
  /// Returns: Kullanıcının oyun listesi (tarih sırasına göre yeni → eski)
  ///
  /// Örnek:
  /// ```dart
  /// final games = await repo.fetchUserGameLogs('user-123');
  /// print('Toplam ${games.length} oyun');
  /// ```
  Future<List<GameLog>> fetchUserGameLogs(String userId) async {
    try {
      appLogger.info('Fetching game logs for user: $userId');

      // Supabase'den kullanıcının oyunlarını çek
      final response = await supabase
          .from('game_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      appLogger.info('Fetched ${(response as List).length} game logs');

      // JSON'u GameLog nesnesine çevir
      return (response).map((json) {
        final gameData = json['game_data'] as Map<String, dynamic>;
        final coverUrl = json['game_cover_url'] as String?;

        // Debug: Log actual cover URLs
        final gameDataCoverUrl = gameData['coverUrl'] as String?;
        appLogger.info(
          'Fetched game ${json['game_name']}: '
          'game_cover_url="$coverUrl", '
          'game_data.coverUrl="$gameDataCoverUrl"',
        );

        return GameLog.fromMap({
          'id': json['id'],
          'game': {
            // Önce game_data'yı spread et
            ...gameData,
            // Sonra kolonları override et (öncelik bunlarda)
            'id': json['game_id'],
            'name': json['game_name'],
            // Only override if game_cover_url is not null AND not empty
            if (coverUrl != null && coverUrl.isNotEmpty)
              'coverUrl': coverUrl,
          },
          'status': json['status'],
          'rating': json['rating'],
          'notes': json['notes'],
        });
      }).toList();
    } catch (e, stack) {
      appLogger.error('Failed to fetch game logs for user $userId', e, stack);
      rethrow; // Hatayı yukarı fırlat, UI'da yakalanacak
    }
  }

  /// Oyun ekle veya güncelle (Upsert = Update + Insert)
  ///
  /// [userId] - Kullanıcı ID'si
  /// [log] - Eklenecek/güncellenecek oyun logu
  ///
  /// Eğer oyun zaten varsa → Güncelle
  /// Eğer oyun yoksa → Yeni ekle
  ///
  /// Örnek:
  /// ```dart
  /// final log = GameLog(
  ///   id: 'game-123',
  ///   game: myGame,
  ///   status: PlayStatus.completed,
  ///   rating: 9,
  ///   notes: 'Muhteşem bir oyun!',
  /// );
  /// await repo.upsertGameLog(userId, log);
  /// ```
  Future<void> upsertGameLog(String userId, GameLog log) async {
    try {
      appLogger.info('Upserting game log: ${log.game.name} for user $userId');

      // GameLog'u Supabase formatına çevir
      final gameMap = log.game.toMap();
      final data = {
        'id': log.id,
        'user_id': userId,
        'game_id': log.game.id,
        'game_name': log.game.name,
        // Ensure coverUrl is always saved (from game or game_data)
        'game_cover_url': log.game.coverUrl ?? gameMap['coverUrl'],
        'game_data': gameMap, // Tüm game bilgisini JSON olarak sakla
        'status': log.status.name, // enum → string ('completed', 'wishlist', etc.)
        'rating': log.rating,
        'notes': log.notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Debug log
      appLogger.info('Saving coverUrl: ${data['game_cover_url']}');

      // Supabase'e kaydet (eğer id varsa güncelle, yoksa ekle)
      await supabase.from('game_logs').upsert(data);

      appLogger.info('Successfully upserted game: ${log.game.name}');
    } catch (e, stack) {
      appLogger.error('Failed to upsert game log: ${log.game.name}', e, stack);
      rethrow;
    }
  }

  /// Oyun sil
  ///
  /// [logId] - Silinecek oyun log'unun ID'si
  ///
  /// Örnek:
  /// ```dart
  /// await repo.deleteGameLog('game-123');
  /// ```
  Future<void> deleteGameLog(String logId) async {
    try {
      appLogger.info('Deleting game log: $logId');

      await supabase.from('game_logs').delete().eq('id', logId);

      appLogger.info('Successfully deleted game log: $logId');
    } catch (e, stack) {
      appLogger.error('Failed to delete game log: $logId', e, stack);
      rethrow;
    }
  }

  // ============================================
  // USER STATS İŞLEMLERİ (İstatistikler)
  // ============================================

  /// Kullanıcının istatistiklerini getir
  ///
  /// [userId] - Kullanıcı ID'si
  /// Returns: Kullanıcı istatistikleri (otomatik hesaplanan)
  ///
  /// NOT: Bu veriler Supabase trigger tarafından otomatik güncellenir.
  /// Yani oyun eklenince/silinince stats tablosu kendini güncelliyor.
  ///
  /// Örnek:
  /// ```dart
  /// final stats = await repo.fetchUserStats('user-123');
  /// print('Tamamlanan oyun: ${stats?.completedGames}');
  /// print('Favori tür: ${stats?.favoriteGenre}');
  /// ```
  Future<UserStats?> fetchUserStats(String userId) async {
    try {
      appLogger.info('Fetching user stats for: $userId');

      final response = await supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle(); // Tek kayıt döner (veya null)

      if (response == null) {
        appLogger.info('No stats found for user $userId (probably new user)');
        return null;
      }

      final stats = UserStats.fromMap(response);
      appLogger.info(
        'Fetched stats: ${stats.totalGames} games, tier ${stats.currentBadgeTier}',
      );
      return stats;
    } catch (e, stack) {
      appLogger.error('Failed to fetch user stats for $userId', e, stack);
      rethrow;
    }
  }

  // ============================================
  // BADGES İŞLEMLERİ (Rozetler)
  // ============================================

  /// Tüm rozet tanımlarını getir
  ///
  /// Returns: Tüm rozetler (6 adet, tier 0-5)
  ///
  /// Bu method genellikle uygulama başlangıcında bir kez çağrılır
  /// ve sonuç cache'lenir.
  ///
  /// Örnek:
  /// ```dart
  /// final badges = await repo.fetchAllBadges();
  /// for (final badge in badges) {
  ///   print('${badge.name}: ${badge.requiredGames} oyun gerekli');
  /// }
  /// ```
  Future<List<Badge>> fetchAllBadges() async {
    try {
      appLogger.info('Fetching all badges');

      final response = await supabase
          .from('badges')
          .select()
          .order('tier', ascending: true);

      final badges = (response as List).map((json) {
        return Badge.fromMap(json);
      }).toList();

      appLogger.info('Fetched ${badges.length} badges');
      return badges;
    } catch (e, stack) {
      appLogger.error('Failed to fetch badges', e, stack);
      rethrow;
    }
  }

  // ============================================
  // HELPER METHODLAR
  // ============================================

  /// Kullanıcının belirli bir oyunu olup olmadığını kontrol et
  ///
  /// [userId] - Kullanıcı ID'si
  /// [gameId] - IGDB game ID
  /// Returns: true ise oyun var, false ise yok
  Future<bool> hasGame(String userId, int gameId) async {
    try {
      final response = await supabase
          .from('game_logs')
          .select('id')
          .eq('user_id', userId)
          .eq('game_id', gameId)
          .maybeSingle();

      return response != null;
    } catch (e, stack) {
      appLogger.error('Failed to check if user has game', e, stack);
      return false;
    }
  }

  /// Belirli status'taki oyunları getir
  ///
  /// [userId] - Kullanıcı ID'si
  /// [status] - Oyun durumu ('wishlist', 'completed', etc.)
  /// Returns: O status'taki oyunlar
  ///
  /// Örnek:
  /// ```dart
  /// final wishlist = await repo.fetchGamesByStatus(userId, 'wishlist');
  /// final completed = await repo.fetchGamesByStatus(userId, 'completed');
  /// ```
  Future<List<GameLog>> fetchGamesByStatus(String userId, String status) async {
    try {
      final response = await supabase
          .from('game_logs')
          .select()
          .eq('user_id', userId)
          .eq('status', status)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final gameData = json['game_data'] as Map<String, dynamic>;
        final coverUrl = json['game_cover_url'] as String?;

        return GameLog.fromMap({
          'id': json['id'],
          'game': {
            // Önce game_data'yı spread et
            ...gameData,
            // Sonra kolonları override et (öncelik bunlarda)
            'id': json['game_id'],
            'name': json['game_name'],
            // Only override if game_cover_url is not null AND not empty
            if (coverUrl != null && coverUrl.isNotEmpty)
              'coverUrl': coverUrl,
          },
          'status': json['status'],
          'rating': json['rating'],
          'notes': json['notes'],
        });
      }).toList();
    } catch (e, stack) {
      appLogger.error('Failed to fetch games by status $status', e, stack);
      rethrow;
    }
  }
}

/// Riverpod Provider: GameRepository instance'ını sağlar
///
/// Kullanım:
/// ```dart
/// final repo = ref.watch(gameRepositoryProvider);
/// final games = await repo.fetchUserGameLogs(userId);
/// ```
final gameRepositoryProvider = Provider<GameRepository>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return GameRepository(supabase);
});

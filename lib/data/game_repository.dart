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
          'source': json['source'],
          'steam_app_id': json['steam_app_id'],
          'psn_title_id': json['psn_title_id'],
          'playtime_minutes': json['playtime_minutes'],
          'last_synced_at': json['last_synced_at'],
          'created_at': json['created_at'],
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
        'source': log.source, // 'manual', 'steam', 'playstation', 'lol', 'valorant', 'tft'
        'updated_at': DateTime.now().toIso8601String(),
        // Steam-specific fields
        if (log.steamAppId != null) 'steam_app_id': log.steamAppId,
        // PlayStation-specific fields
        if (log.psnTitleId != null) 'psn_title_id': log.psnTitleId,
        // Riot Games-specific fields
        if (log.riotGameId != null) 'riot_game_id': log.riotGameId,
        if (log.riotRankedData != null) 'riot_ranked_data': log.riotRankedData,
        'playtime_minutes': log.playtimeMinutes,
        if (log.lastSyncedAt != null)
          'last_synced_at': log.lastSyncedAt!.toIso8601String(),
      };

      // Debug log
      appLogger.info('Saving coverUrl: ${data['game_cover_url']}, playtime: ${log.playtimeMinutes} min');

      // Supabase'e kaydet
      // onConflict: user_id,game_id -> aynı oyun varsa güncelle, yoksa ekle
      await supabase.from('game_logs').upsert(
        data,
        onConflict: 'user_id,game_id',
      );

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

  /// Değerlendirmeyi sil (rating ve notes'u null yap)
  /// Oyun kütüphaneden silinmez, sadece puan ve yorum temizlenir.
  ///
  /// [logId] - Oyun log'unun ID'si
  ///
  /// Örnek:
  /// ```dart
  /// await repo.clearReview('game-123');
  /// ```
  Future<void> clearReview(String logId) async {
    try {
      appLogger.info('Clearing review for game log: $logId');

      await supabase.from('game_logs').update({
        'rating': null,
        'notes': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', logId);

      appLogger.info('Successfully cleared review for game log: $logId');
    } catch (e, stack) {
      appLogger.error('Failed to clear review for game log: $logId', e, stack);
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
          'source': json['source'],
          'steam_app_id': json['steam_app_id'],
          'psn_title_id': json['psn_title_id'],
          'playtime_minutes': json['playtime_minutes'],
          'last_synced_at': json['last_synced_at'],
          'created_at': json['created_at'],
        });
      }).toList();
    } catch (e, stack) {
      appLogger.error('Failed to fetch games by status $status', e, stack);
      rethrow;
    }
  }

  // ============================================
  // STEAM LIBRARY İŞLEMLERİ (Steam Entegrasyonu)
  // ============================================

  /// Steam kütüphanesinden gelen oyunları getir
  ///
  /// [userId] - Kullanıcı ID'si
  /// Returns: Steam'den import edilen oyunlar (oynama saatine göre sıralı)
  ///
  /// Örnek:
  /// ```dart
  /// final steamGames = await repo.fetchSteamLibrary('user-123');
  /// print('Steam: ${steamGames.length} oyun');
  /// ```
  Future<List<GameLog>> fetchSteamLibrary(String userId) async {
    try {
      appLogger.info('Fetching Steam library for user: $userId');

      // Fetch games that are either:
      // 1. source='steam' (directly imported from Steam)
      // 2. have steam_app_id (linked to Steam even if source is different)
      final response = await supabase
          .from('game_logs')
          .select()
          .eq('user_id', userId)
          .or('source.eq.steam,steam_app_id.not.is.null')
          .order('playtime_minutes', ascending: false);

      appLogger.info('Fetched ${(response as List).length} Steam games');

      return (response).map((json) {
        final gameData = json['game_data'] as Map<String, dynamic>;
        final coverUrl = json['game_cover_url'] as String?;

        return GameLog.fromMap({
          'id': json['id'],
          'game': {
            ...gameData,
            'id': json['game_id'],
            'name': json['game_name'],
            if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
          },
          'status': json['status'],
          'rating': json['rating'],
          'notes': json['notes'],
          'source': json['source'],
          'steam_app_id': json['steam_app_id'],
          'psn_title_id': json['psn_title_id'],
          'playtime_minutes': json['playtime_minutes'],
          'last_synced_at': json['last_synced_at'],
          'created_at': json['created_at'],
        });
      }).toList();
    } catch (e, stack) {
      appLogger.error('Failed to fetch Steam library for user $userId', e, stack);
      rethrow;
    }
  }

  /// Manuel olarak eklenen oyunları getir (Koleksiyon)
  ///
  /// [userId] - Kullanıcı ID'si
  /// Returns: Manuel eklenen oyunlar (tarih sırasına göre)
  ///
  /// Örnek:
  /// ```dart
  /// final manualGames = await repo.fetchManualCollection('user-123');
  /// print('Manuel: ${manualGames.length} oyun');
  /// ```
  Future<List<GameLog>> fetchManualCollection(String userId) async {
    try {
      appLogger.info('Fetching manual collection for user: $userId');

      final response = await supabase
          .from('game_logs')
          .select()
          .eq('user_id', userId)
          .eq('source', 'manual')
          .order('created_at', ascending: false);

      appLogger.info('Fetched ${(response as List).length} manual games');

      return (response).map((json) {
        final gameData = json['game_data'] as Map<String, dynamic>;
        final coverUrl = json['game_cover_url'] as String?;

        return GameLog.fromMap({
          'id': json['id'],
          'game': {
            ...gameData,
            'id': json['game_id'],
            'name': json['game_name'],
            if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
          },
          'status': json['status'],
          'rating': json['rating'],
          'notes': json['notes'],
          'source': json['source'],
          'steam_app_id': json['steam_app_id'],
          'playtime_minutes': json['playtime_minutes'],
          'last_synced_at': json['last_synced_at'],
          'created_at': json['created_at'],
        });
      }).toList();
    } catch (e, stack) {
      appLogger.error('Failed to fetch manual collection for user $userId', e, stack);
      rethrow;
    }
  }

  /// Koleksiyon ve istek listesi oyunlarını getir
  /// Manuel eklenen + Steam + PlayStation oyunlarını getirir
  /// (İstek listesi sadece uygulama içi, Steam'den çekilmiyor)
  ///
  /// [userId] - Kullanıcı ID'si
  /// Returns: Tüm kullanıcı oyunları
  Future<List<GameLog>> fetchCollectionAndWishlist(String userId) async {
    try {
      appLogger.info('Fetching collection and wishlist for user: $userId');

      // Fetch all sources: manual, steam, playstation
      final response = await supabase
          .from('game_logs')
          .select()
          .eq('user_id', userId)
          .inFilter('source', ['manual', 'steam', 'playstation'])
          .order('created_at', ascending: false);

      appLogger.info('Fetched ${(response as List).length} collection/wishlist games');

      return (response).map((json) {
        final gameData = json['game_data'] as Map<String, dynamic>;
        final coverUrl = json['game_cover_url'] as String?;

        return GameLog.fromMap({
          'id': json['id'],
          'game': {
            ...gameData,
            'id': json['game_id'],
            'name': json['game_name'],
            if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
          },
          'status': json['status'],
          'rating': json['rating'],
          'notes': json['notes'],
          'source': json['source'],
          'steam_app_id': json['steam_app_id'],
          'psn_title_id': json['psn_title_id'],
          'playtime_minutes': json['playtime_minutes'],
          'last_synced_at': json['last_synced_at'],
          'created_at': json['created_at'],
        });
      }).toList();
    } catch (e, stack) {
      appLogger.error('Failed to fetch collection/wishlist for user $userId', e, stack);
      rethrow;
    }
  }

  // ============================================
  // PLAYSTATION LIBRARY İŞLEMLERİ (PlayStation Entegrasyonu)
  // ============================================

  /// PlayStation kütüphanesinden gelen oyunları getir
  ///
  /// [userId] - Kullanıcı ID'si
  /// Returns: PlayStation'dan import edilen oyunlar
  Future<List<GameLog>> fetchPlayStationLibrary(String userId) async {
    try {
      appLogger.info('Fetching PlayStation library for user: $userId');

      // Fetch games that are either:
      // 1. source='playstation' (directly imported from PSN)
      // 2. have psn_title_id (linked to PSN even if source is different)
      final response = await supabase
          .from('game_logs')
          .select()
          .eq('user_id', userId)
          .or('source.eq.playstation,psn_title_id.not.is.null')
          .order('playtime_minutes', ascending: false);

      appLogger.info('Fetched ${(response as List).length} PlayStation games');

      return (response).map((json) {
        final gameData = json['game_data'] as Map<String, dynamic>;
        final coverUrl = json['game_cover_url'] as String?;

        return GameLog.fromMap({
          'id': json['id'],
          'game': {
            ...gameData,
            'id': json['game_id'],
            'name': json['game_name'],
            if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
          },
          'status': json['status'],
          'rating': json['rating'],
          'notes': json['notes'],
          'source': json['source'],
          'steam_app_id': json['steam_app_id'],
          'psn_title_id': json['psn_title_id'],
          'playtime_minutes': json['playtime_minutes'],
          'last_synced_at': json['last_synced_at'],
          'created_at': json['created_at'],
        });
      }).toList();
    } catch (e, stack) {
      appLogger.error('Failed to fetch PlayStation library for user $userId', e, stack);
      rethrow;
    }
  }

  // ============================================
  // RIOT LIBRARY İŞLEMLERİ (Riot Games Entegrasyonu)
  // ============================================

  /// Riot Games kütüphanesinden gelen oyunları getir (LoL, Valorant, TFT)
  ///
  /// [userId] - Kullanıcı ID'si
  /// Returns: Riot Games'ten import edilen oyunlar
  Future<List<GameLog>> fetchRiotLibrary(String userId) async {
    try {
      appLogger.info('Fetching Riot library for user: $userId');

      // Fetch games that are from Riot by source
      // Source can be 'lol', 'valorant', or 'tft'
      final response = await supabase
          .from('game_logs')
          .select()
          .eq('user_id', userId)
          .inFilter('source', ['lol', 'valorant', 'tft'])
          .order('created_at', ascending: false);

      appLogger.info('Fetched ${(response as List).length} Riot games');

      return (response).map((json) {
        final gameData = json['game_data'] as Map<String, dynamic>;
        final coverUrl = json['game_cover_url'] as String?;

        return GameLog.fromMap({
          'id': json['id'],
          'game': {
            ...gameData,
            'id': json['game_id'],
            'name': json['game_name'],
            if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
          },
          'status': json['status'],
          'rating': json['rating'],
          'notes': json['notes'],
          'source': json['source'],
          'steam_app_id': json['steam_app_id'],
          'psn_title_id': json['psn_title_id'],
          'riot_game_id': json['riot_game_id'],
          'riot_ranked_data': json['riot_ranked_data'],
          'playtime_minutes': json['playtime_minutes'],
          'last_synced_at': json['last_synced_at'],
          'created_at': json['created_at'],
        });
      }).toList();
    } catch (e, stack) {
      appLogger.error('Failed to fetch Riot library for user $userId', e, stack);
      rethrow;
    }
  }

  /// Steam App ID'sine göre oyun getir
  ///
  /// [userId] - Kullanıcı ID'si
  /// [steamAppId] - Steam App ID
  /// Returns: Oyun varsa GameLog, yoksa null
  ///
  /// Örnek:
  /// ```dart
  /// final game = await repo.getBySteamAppId('user-123', 730); // CS:GO
  /// if (game != null) print('Oyun bulundu: ${game.game.name}');
  /// ```
  Future<GameLog?> getBySteamAppId(String userId, int steamAppId) async {
    try {
      appLogger.info('Fetching game by Steam App ID: $steamAppId for user $userId');

      final response = await supabase
          .from('game_logs')
          .select()
          .eq('user_id', userId)
          .eq('steam_app_id', steamAppId)
          .maybeSingle();

      if (response == null) {
        appLogger.info('No game found with Steam App ID: $steamAppId');
        return null;
      }

      final gameData = response['game_data'] as Map<String, dynamic>;
      final coverUrl = response['game_cover_url'] as String?;

      return GameLog.fromMap({
        'id': response['id'],
        'game': {
          ...gameData,
          'id': response['game_id'],
          'name': response['game_name'],
          if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
        },
        'status': response['status'],
        'rating': response['rating'],
        'notes': response['notes'],
        'source': response['source'],
        'steam_app_id': response['steam_app_id'],
        'playtime_minutes': response['playtime_minutes'],
        'last_synced_at': response['last_synced_at'],
        'created_at': response['created_at'],
      });
    } catch (e, stack) {
      appLogger.error('Failed to fetch game by Steam App ID: $steamAppId', e, stack);
      rethrow;
    }
  }

  /// Oyun oynama saatini güncelle
  ///
  /// [gameLogId] - Oyun log ID'si
  /// [playtimeMinutes] - Yeni oynama süresi (dakika)
  ///
  /// Örnek:
  /// ```dart
  /// await repo.updatePlaytime('game-123', 120); // 2 saat
  /// ```
  Future<void> updatePlaytime(String gameLogId, int playtimeMinutes) async {
    try {
      appLogger.info('Updating playtime for game: $gameLogId to $playtimeMinutes minutes');

      await supabase.from('game_logs').update({
        'playtime_minutes': playtimeMinutes,
        'last_synced_at': DateTime.now().toIso8601String(),
      }).eq('id', gameLogId);

      appLogger.info('Successfully updated playtime');
    } catch (e, stack) {
      appLogger.error('Failed to update playtime for game $gameLogId', e, stack);
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

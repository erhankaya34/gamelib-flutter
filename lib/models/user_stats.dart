/// UserStats (Kullanıcı İstatistikleri) Model
///
/// Kullanıcının oyun koleksiyonu hakkında otomatik hesaplanan istatistikler.
/// Bu veriler Supabase trigger'ı tarafından otomatik güncellenir.
///
/// Örnek: Kullanıcı 45 oyun ekledi, 30'unu tamamladı → Stats otomatik güncellendi
class UserStats {
  const UserStats({
    required this.userId,
    required this.totalGames,
    required this.completedGames,
    required this.wishlistGames,
    required this.playingGames,
    required this.droppedGames,
    this.averageRating,
    this.favoriteGenre,
    required this.currentBadgeTier,
  });

  /// Kullanıcı ID'si (Supabase auth.users.id ile eşleşir)
  final String userId;

  /// Toplam oyun sayısı (tüm statuslar dahil)
  final int totalGames;

  /// Tamamlanan oyun sayısı (status = 'completed')
  final int completedGames;

  /// İstek listesindeki oyun sayısı (status = 'wishlist')
  final int wishlistGames;

  /// Oynuyor durumundaki oyun sayısı (status = 'playing')
  final int playingGames;

  /// Bırakılan oyun sayısı (status = 'dropped')
  final int droppedGames;

  /// Ortalama puan (1-10 arası, sadece puanlanan oyunlardan)
  final double? averageRating;

  /// En çok oynanan tür (örn: "Action", "RPG")
  /// Tamamlanan oyunların türlerine bakarak hesaplanır
  final String? favoriteGenre;

  /// Şu anki rozet seviyesi (0-5)
  /// Tamamlanan oyun sayısına göre otomatik hesaplanır
  final int currentBadgeTier;

  /// Bir sonraki rozet seviyesi
  int get nextBadgeTier => currentBadgeTier + 1;

  /// Sonraki rozete kaç oyun kaldığını hesapla
  ///
  /// [badges] listesi verilmeli (tüm rozetler)
  /// Returns: Kalan oyun sayısı, eğer max seviyedeyse 0
  int getProgressToNextBadge(List<dynamic> badges) {
    if (currentBadgeTier >= badges.length - 1) {
      return 0; // Zaten max seviyede
    }

    // Sonraki rozeti bul
    final nextBadge = badges.firstWhere(
      (b) => b.tier == nextBadgeTier,
      orElse: () => null,
    );

    if (nextBadge == null) return 0;

    // Kalan oyun sayısını hesapla
    return nextBadge.requiredGames - completedGames;
  }

  /// Sonraki rozete ilerleme yüzdesi (0.0 - 1.0)
  ///
  /// [badges] listesi verilmeli
  /// Returns: İlerleme yüzdesi (0.0 = hiç, 1.0 = tamamlandı)
  double getProgressPercentage(List<dynamic> badges) {
    if (currentBadgeTier >= badges.length - 1) {
      return 1.0; // Max seviyede
    }

    final nextBadge = badges.firstWhere(
      (b) => b.tier == nextBadgeTier,
      orElse: () => null,
    );

    if (nextBadge == null) return 1.0;

    // Mevcut seviyenin gereken oyun sayısı
    final currentRequired = currentBadgeTier > 0
        ? badges
            .firstWhere(
              (b) => b.tier == currentBadgeTier,
              orElse: () => null,
            )
            ?.requiredGames ??
        0
        : 0;

    // İlerleme hesapla
    final progress = (completedGames - currentRequired) /
        (nextBadge.requiredGames - currentRequired);

    return progress.clamp(0.0, 1.0);
  }

  /// Supabase'den gelen JSON'u UserStats nesnesine çevir
  factory UserStats.fromMap(Map<String, dynamic> json) {
    return UserStats(
      userId: json['user_id'] as String,
      totalGames: json['total_games'] as int? ?? 0,
      completedGames: json['completed_games'] as int? ?? 0,
      wishlistGames: json['wishlist_games'] as int? ?? 0,
      playingGames: json['playing_games'] as int? ?? 0,
      droppedGames: json['dropped_games'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      favoriteGenre: json['favorite_genre'] as String?,
      currentBadgeTier: json['current_badge_tier'] as int? ?? 0,
    );
  }

  /// UserStats nesnesini JSON'a çevir
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'total_games': totalGames,
      'completed_games': completedGames,
      'wishlist_games': wishlistGames,
      'playing_games': playingGames,
      'dropped_games': droppedGames,
      'average_rating': averageRating,
      'favorite_genre': favoriteGenre,
      'current_badge_tier': currentBadgeTier,
    };
  }

  @override
  String toString() {
    return 'UserStats(userId: $userId, totalGames: $totalGames, '
        'completedGames: $completedGames, averageRating: $averageRating, '
        'currentBadgeTier: $currentBadgeTier)';
  }
}

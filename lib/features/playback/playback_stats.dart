/// PLAYBACK - Oyuncu İstatistik Kartı Modelleri
///
/// Spotify Wrapped tarzı paylaşılabilir oyuncu kartı için
/// gerekli veri modelleri ve enumlar.

import '../../models/game_log.dart';

/// Zaman periyodu seçenekleri
enum PlaybackPeriod {
  allTime,
  yearly,
  monthly,
}

extension PlaybackPeriodExtension on PlaybackPeriod {
  String get displayName {
    switch (this) {
      case PlaybackPeriod.allTime:
        return 'Tüm Zamanlar';
      case PlaybackPeriod.yearly:
        return 'Bu Yıl';
      case PlaybackPeriod.monthly:
        return 'Bu Ay';
    }
  }

  String get shortName {
    final now = DateTime.now();
    final months = ['OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN',
                   'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'];
    switch (this) {
      case PlaybackPeriod.allTime:
        return 'ALL TIME';
      case PlaybackPeriod.yearly:
        return '${now.year}';
      case PlaybackPeriod.monthly:
        return months[now.month - 1];
    }
  }
}

/// Oyuncu arketipi - Türlere ve davranışlara göre hesaplanır
enum PlayerArchetype {
  // ═══════════════════════════════════════════
  // TÜR BAZLI (Genre-Based)
  // ═══════════════════════════════════════════
  strategist,       // Strategy/Simulation ağırlıklı
  adventurer,       // Adventure/RPG ağırlıklı
  competitor,       // Shooter/Sports + ranked
  indieHunter,      // Indie türünde 10+ oyun
  actionJunkie,     // Shooter/Action %40+
  horrorMaster,     // Horror türünde 5+ oyun
  puzzleGenius,     // Puzzle türünde 5+ oyun
  sportsFanatic,    // Sports türünde 5+ oyun
  simGuru,          // Simulation türünde 10+ oyun
  retroGamer,       // 2010 öncesi 10+ oyun
  sandboxArchitect, // Sandbox türünde 5+ oyun
  roguelikeExpert,  // Roguelike türünde 5+ oyun
  mobaWarrior,      // MOBA türünde 50+ saat

  // ═══════════════════════════════════════════
  // DAVRANIŞ BAZLI (Behavior-Based)
  // ═══════════════════════════════════════════
  completionist,       // %80+ tamamlama oranı
  storyteller,         // Story-rich + yüksek tamamlama
  marathoner,          // %80 oyunda 15+ saat
  collector,           // <5 saat/oyun ortalaması
  hoarder,             // %50+ oyun hiç oynanmamış
  libraryBaron,        // 100+ oyun
  grandLibrarian,      // 250+ oyun
  speedrunner,         // Ort. <5 saat + %50 completed
  patientGamer,        // 2+ yıl önce çıkmış oyunları oynuyor
  dayOneGamer,         // Son 6 ay çıkmış 5+ oyun
  loyalFan,            // Tek oyunda 200+ saat
  varietySeeker,       // 10+ farklı tür oynamış
  socialGamer,         // Multiplayer ağırlıklı
  soloWolf,            // Singleplayer ağırlıklı
  unfinishedBusiness,  // %50+ dropped status
  backlogWarrior,      // Backlog'dan 10+ oyun bitirmiş

  // ═══════════════════════════════════════════
  // PUANLAMA BAZLI (Rating-Based)
  // ═══════════════════════════════════════════
  harshCritic,        // Ort. puan <6
  positivePlayer,     // Ort. puan >8.5
  hiddenGemHunter,    // Düşük metacritic + yüksek kişisel puan
  aaaLover,           // Metacritic 85+ oyunlara ağırlıklı
  underdogSupporter,  // Metacritic <70 ama kişisel 8+
  pickyPalate,        // 20+ oyun puanlamış, ort >7
  ratingExpert,       // 50+ oyun puanlamış

  // ═══════════════════════════════════════════
  // PLATFORM BAZLI (Platform-Based)
  // ═══════════════════════════════════════════
  multiPlatform,    // %40-60 dağılım
  steamLoyal,       // %90+ Steam
  playstationFan,   // %90+ PlayStation
  pcMasterRace,     // %95+ Steam
  consoleKing,      // %95+ PlayStation
  riotWarrior,      // LoL/Valorant/TFT aktif

  // ═══════════════════════════════════════════
  // FALLBACK
  // ═══════════════════════════════════════════
  gamer,            // Genel oyuncu
}

extension PlayerArchetypeExtension on PlayerArchetype {
  String get displayName {
    switch (this) {
      // Tür bazlı
      case PlayerArchetype.strategist:
        return 'Stratejist';
      case PlayerArchetype.adventurer:
        return 'Maceraperest';
      case PlayerArchetype.competitor:
        return 'Rekabetçi';
      case PlayerArchetype.indieHunter:
        return 'Indie Avcısı';
      case PlayerArchetype.actionJunkie:
        return 'Aksiyon Delisi';
      case PlayerArchetype.horrorMaster:
        return 'Korku Ustası';
      case PlayerArchetype.puzzleGenius:
        return 'Puzzle Dahisi';
      case PlayerArchetype.sportsFanatic:
        return 'Spor Fanatiği';
      case PlayerArchetype.simGuru:
        return 'Simülasyon Gurusu';
      case PlayerArchetype.retroGamer:
        return 'Retro Oyuncu';
      case PlayerArchetype.sandboxArchitect:
        return 'Sandbox Mimarı';
      case PlayerArchetype.roguelikeExpert:
        return 'Roguelike Uzmanı';
      case PlayerArchetype.mobaWarrior:
        return 'MOBA Savaşçısı';
      // Davranış bazlı
      case PlayerArchetype.completionist:
        return 'Completionist';
      case PlayerArchetype.storyteller:
        return 'Hikaye Avcısı';
      case PlayerArchetype.marathoner:
        return 'Maratoncu';
      case PlayerArchetype.collector:
        return 'Koleksiyoncu';
      case PlayerArchetype.hoarder:
        return 'İstifçi';
      case PlayerArchetype.libraryBaron:
        return 'Kütüphane Baronu';
      case PlayerArchetype.grandLibrarian:
        return 'Büyük Kütüphaneci';
      case PlayerArchetype.speedrunner:
        return 'Hızlı Bitirici';
      case PlayerArchetype.patientGamer:
        return 'Sabırlı Oyuncu';
      case PlayerArchetype.dayOneGamer:
        return 'Yeni Oyun Avcısı';
      case PlayerArchetype.loyalFan:
        return 'Sadık Fan';
      case PlayerArchetype.varietySeeker:
        return 'Çeşitlilik Arayıcısı';
      case PlayerArchetype.socialGamer:
        return 'Sosyal Oyuncu';
      case PlayerArchetype.soloWolf:
        return 'Solo Kurt';
      case PlayerArchetype.unfinishedBusiness:
        return 'Yarım Kalan İşler';
      case PlayerArchetype.backlogWarrior:
        return 'Backlog Savaşçısı';
      // Puanlama bazlı
      case PlayerArchetype.harshCritic:
        return 'Sert Eleştirmen';
      case PlayerArchetype.positivePlayer:
        return 'Pozitif Oyuncu';
      case PlayerArchetype.hiddenGemHunter:
        return 'Hidden Gem Avcısı';
      case PlayerArchetype.aaaLover:
        return 'AAA Tutkunu';
      case PlayerArchetype.underdogSupporter:
        return 'Underdog Destekçisi';
      case PlayerArchetype.pickyPalate:
        return 'Seçici Damak';
      case PlayerArchetype.ratingExpert:
        return 'Puanlama Uzmanı';
      // Platform bazlı
      case PlayerArchetype.multiPlatform:
        return 'Çok Platformlu';
      case PlayerArchetype.steamLoyal:
        return 'Steam Sadığı';
      case PlayerArchetype.playstationFan:
        return 'PlayStation Fanatiği';
      case PlayerArchetype.pcMasterRace:
        return 'PC Master Race';
      case PlayerArchetype.consoleKing:
        return 'Konsol Kralı';
      case PlayerArchetype.riotWarrior:
        return 'Riot Savaşçısı';
      // Fallback
      case PlayerArchetype.gamer:
        return 'Oyuncu';
    }
  }

  String get description {
    switch (this) {
      // Tür bazlı
      case PlayerArchetype.strategist:
        return 'Strateji ve simülasyon oyunlarının ustası';
      case PlayerArchetype.adventurer:
        return 'Macera ve RPG dünyalarının kaşifi';
      case PlayerArchetype.competitor:
        return 'Rekabetçi oyunların yıldızı';
      case PlayerArchetype.indieHunter:
        return 'Bağımsız yapımların keşifçisi';
      case PlayerArchetype.actionJunkie:
        return 'Vurdulu kırdılı oyunların fanatiği';
      case PlayerArchetype.horrorMaster:
        return 'Korku oyunlarının cesur kaşifi';
      case PlayerArchetype.puzzleGenius:
        return 'Bulmaca çözmenin ustası';
      case PlayerArchetype.sportsFanatic:
        return 'Sanal sahaların yıldızı';
      case PlayerArchetype.simGuru:
        return 'Her şeyi simüle etmeyi seven';
      case PlayerArchetype.retroGamer:
        return 'Klasiklere sadık kalan';
      case PlayerArchetype.sandboxArchitect:
        return 'Kendi dünyasını inşa eden';
      case PlayerArchetype.roguelikeExpert:
        return 'Ölüm döngülerinin ustası';
      case PlayerArchetype.mobaWarrior:
        return 'Arena savaşlarının gazisi';
      // Davranış bazlı
      case PlayerArchetype.completionist:
        return 'Her oyunu sonuna kadar bitiren';
      case PlayerArchetype.storyteller:
        return 'Hikaye odaklı deneyimlerin tutkunu';
      case PlayerArchetype.marathoner:
        return 'Oyunlarının %80\'ini 15+ saat oynamış - gerçek bir derinlik ustası';
      case PlayerArchetype.collector:
        return 'Geniş bir oyun koleksiyonunun sahibi';
      case PlayerArchetype.hoarder:
        return 'Belki yeni oyun almayı bırakıp kütüphanedekilerle ilgilenme vakti?';
      case PlayerArchetype.libraryBaron:
        return 'Devasa bir koleksiyonun sahibi (100+ oyun)';
      case PlayerArchetype.grandLibrarian:
        return 'Efsanevi bir arşivin koruyucusu (250+ oyun)';
      case PlayerArchetype.speedrunner:
        return 'Oyunları hızla bitiren';
      case PlayerArchetype.patientGamer:
        return 'İndirim bekleyen sabırlı ruh';
      case PlayerArchetype.dayOneGamer:
        return 'Her yeni çıkışı takip eden';
      case PlayerArchetype.loyalFan:
        return 'Tek bir oyuna 200+ saat vermiş - gerçek bir aşık';
      case PlayerArchetype.varietySeeker:
        return '10+ farklı türde oyun deneyimi';
      case PlayerArchetype.socialGamer:
        return 'Arkadaşlarla oynamayı seven';
      case PlayerArchetype.soloWolf:
        return 'Yalnız maceraları tercih eden';
      case PlayerArchetype.unfinishedBusiness:
        return 'Yarıda bırakma konusunda uzman';
      case PlayerArchetype.backlogWarrior:
        return 'Birikmiş oyunlarla savaşan kahraman';
      // Puanlama bazlı
      case PlayerArchetype.harshCritic:
        return 'Yüksek standartlara sahip eleştirmen';
      case PlayerArchetype.positivePlayer:
        return 'Her oyunda güzel şeyler bulan';
      case PlayerArchetype.hiddenGemHunter:
        return 'Gizli hazineleri keşfeden';
      case PlayerArchetype.aaaLover:
        return 'Sadece en iyileri oynayan';
      case PlayerArchetype.underdogSupporter:
        return 'Az bilinen oyunları destekleyen';
      case PlayerArchetype.pickyPalate:
        return 'Kaliteyi bilen seçici bir damak';
      case PlayerArchetype.ratingExpert:
        return 'Her oyunu titizlikle değerlendiren';
      // Platform bazlı
      case PlayerArchetype.multiPlatform:
        return 'Tüm platformlarda aktif';
      case PlayerArchetype.steamLoyal:
        return 'Steam ekosisteminin sadık üyesi';
      case PlayerArchetype.playstationFan:
        return 'PlayStation ailesinin bir parçası';
      case PlayerArchetype.pcMasterRace:
        return 'PC oyuncusu ruhu - %95+ Steam';
      case PlayerArchetype.consoleKing:
        return 'Konsol deneyiminin aşığı';
      case PlayerArchetype.riotWarrior:
        return 'Riot evreni sakini - LoL, Valorant, TFT';
      // Fallback
      case PlayerArchetype.gamer:
        return 'Oyun dünyasının bir parçası';
    }
  }

  String get emoji {
    switch (this) {
      // Tür bazlı
      case PlayerArchetype.strategist:
        return '♟️';
      case PlayerArchetype.adventurer:
        return '🗺️';
      case PlayerArchetype.competitor:
        return '🏆';
      case PlayerArchetype.indieHunter:
        return '🎨';
      case PlayerArchetype.actionJunkie:
        return '💥';
      case PlayerArchetype.horrorMaster:
        return '👻';
      case PlayerArchetype.puzzleGenius:
        return '🧩';
      case PlayerArchetype.sportsFanatic:
        return '⚽';
      case PlayerArchetype.simGuru:
        return '🏗️';
      case PlayerArchetype.retroGamer:
        return '👾';
      case PlayerArchetype.sandboxArchitect:
        return '🏰';
      case PlayerArchetype.roguelikeExpert:
        return '💀';
      case PlayerArchetype.mobaWarrior:
        return '⚔️';
      // Davranış bazlı
      case PlayerArchetype.completionist:
        return '✅';
      case PlayerArchetype.storyteller:
        return '📖';
      case PlayerArchetype.marathoner:
        return '🏃';
      case PlayerArchetype.collector:
        return '🎮';
      case PlayerArchetype.hoarder:
        return '📦';
      case PlayerArchetype.libraryBaron:
        return '📚';
      case PlayerArchetype.grandLibrarian:
        return '🏛️';
      case PlayerArchetype.speedrunner:
        return '⏱️';
      case PlayerArchetype.patientGamer:
        return '🐢';
      case PlayerArchetype.dayOneGamer:
        return '🆕';
      case PlayerArchetype.loyalFan:
        return '💝';
      case PlayerArchetype.varietySeeker:
        return '🌈';
      case PlayerArchetype.socialGamer:
        return '👥';
      case PlayerArchetype.soloWolf:
        return '🐺';
      case PlayerArchetype.unfinishedBusiness:
        return '😅';
      case PlayerArchetype.backlogWarrior:
        return '⚔️';
      // Puanlama bazlı
      case PlayerArchetype.harshCritic:
        return '🧐';
      case PlayerArchetype.positivePlayer:
        return '😊';
      case PlayerArchetype.hiddenGemHunter:
        return '💎';
      case PlayerArchetype.aaaLover:
        return '⭐';
      case PlayerArchetype.underdogSupporter:
        return '🌟';
      case PlayerArchetype.pickyPalate:
        return '🍷';
      case PlayerArchetype.ratingExpert:
        return '📊';
      // Platform bazlı
      case PlayerArchetype.multiPlatform:
        return '🌐';
      case PlayerArchetype.steamLoyal:
        return '💨';
      case PlayerArchetype.playstationFan:
        return '🎮';
      case PlayerArchetype.pcMasterRace:
        return '🖥️';
      case PlayerArchetype.consoleKing:
        return '👑';
      case PlayerArchetype.riotWarrior:
        return '🎯';
      // Fallback
      case PlayerArchetype.gamer:
        return '🎮';
    }
  }
}

/// Tür istatistiği
class GenreStat {
  const GenreStat({
    required this.name,
    required this.hours,
    required this.gameCount,
  });

  final String name;
  final double hours;
  final int gameCount;

  double get percentage => 0; // Provider tarafından hesaplanacak
}

/// Platform istatistiği
class PlatformStat {
  const PlatformStat({
    required this.name,
    required this.hours,
    required this.gameCount,
  });

  final String name;
  final double hours;
  final int gameCount;
}

/// PLAYBACK ana istatistik modeli
class PlaybackStats {
  const PlaybackStats({
    required this.period,
    required this.totalHours,
    required this.totalGames,
    required this.completedGames,
    required this.playingGames,
    required this.platformStats,
    required this.topGenres,
    required this.archetype,
    required this.avgRating,
    required this.ratedGamesCount,
    required this.badgeTier,
    required this.completionRate,
    required this.avgHoursPerGame,
    required this.funComparison,
    this.mostPlayedGame,
    this.hiddenGemsCount = 0,
    this.highestRatedGame,
    this.droppedGamesCount = 0,
    this.wishlistCount = 0,
    this.newGamesThisPeriod = 0,
    this.additionalArchetypes = const [],
    this.topPlayedGames = const [],
  });

  /// Seçili zaman periyodu
  final PlaybackPeriod period;

  /// Toplam oynama süresi (saat)
  final double totalHours;

  /// Toplam oyun sayısı
  final int totalGames;

  /// Tamamlanan oyun sayısı
  final int completedGames;

  /// Şu an oynanan oyun sayısı
  final int playingGames;

  /// Platform bazlı istatistikler
  final Map<String, PlatformStat> platformStats;

  /// En çok oynanan 3 tür
  final List<GenreStat> topGenres;

  /// Hesaplanan oyuncu arketipi
  final PlayerArchetype archetype;

  /// Ortalama verilen puan
  final double avgRating;

  /// Puanlanan oyun sayısı
  final int ratedGamesCount;

  /// Badge seviyesi (0-5)
  final int badgeTier;

  /// Tamamlama oranı (%)
  final double completionRate;

  /// Oyun başı ortalama saat
  final double avgHoursPerGame;

  /// Eğlenceli karşılaştırma metni
  final String funComparison;

  /// En çok oynanan oyun
  final GameLog? mostPlayedGame;

  /// Hidden gem sayısı (düşük metacritic + yüksek kişisel puan)
  final int hiddenGemsCount;

  /// En yüksek puanlanan oyun
  final GameLog? highestRatedGame;

  /// Bırakılan oyun sayısı
  final int droppedGamesCount;

  /// İstek listesindeki oyun sayısı
  final int wishlistCount;

  /// Bu dönemde eklenen yeni oyun sayısı
  final int newGamesThisPeriod;

  /// Ek eşleşen arketipler (ana arketip hariç top 3)
  final List<PlayerArchetype> additionalArchetypes;

  /// En çok oynanan 5 oyun
  final List<GameLog> topPlayedGames;

  /// Steam oynama yüzdesi
  double get steamPercentage {
    final steamHours = platformStats['steam']?.hours ?? 0;
    if (totalHours == 0) return 0;
    return (steamHours / totalHours) * 100;
  }

  /// PlayStation oynama yüzdesi
  double get playstationPercentage {
    final psnHours = platformStats['playstation']?.hours ?? 0;
    if (totalHours == 0) return 0;
    return (psnHours / totalHours) * 100;
  }

  /// Riot Games oynama yüzdesi
  double get riotPercentage {
    final riotHours = platformStats['riot']?.hours ?? 0;
    if (totalHours == 0) return 0;
    return (riotHours / totalHours) * 100;
  }
}

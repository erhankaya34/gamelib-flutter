/// PLAYBACK Provider - İstatistik Hesaplamaları
///
/// Oyuncu istatistiklerini hesaplar ve arketip belirler.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/game_log.dart';
import '../steam_library/steam_library_provider.dart';
import 'playback_stats.dart';

/// Seçili periyod için provider
final selectedPeriodProvider = StateProvider<PlaybackPeriod>((ref) {
  return PlaybackPeriod.allTime;
});

/// PLAYBACK istatistikleri provider
final playbackStatsProvider = FutureProvider.family<PlaybackStats, PlaybackPeriod>((ref, period) async {
  // Combined library'den tüm oyunları al
  final combinedGames = await ref.watch(combinedLibraryProvider.future);
  final allLogs = combinedGames.map((e) => e.log).toList();

  // Periyoda göre filtrele
  final filteredLogs = _filterByPeriod(allLogs, period);

  // İstatistikleri hesapla
  return _calculateStats(filteredLogs, period);
});

/// Periyoda göre oyunları filtrele
List<GameLog> _filterByPeriod(List<GameLog> logs, PlaybackPeriod period) {
  if (period == PlaybackPeriod.allTime) {
    return logs;
  }

  final now = DateTime.now();
  DateTime startDate;

  if (period == PlaybackPeriod.yearly) {
    startDate = DateTime(now.year, 1, 1);
  } else {
    // monthly
    startDate = DateTime(now.year, now.month, 1);
  }

  // createdAt kullan, yoksa lastSyncedAt'i fallback olarak kullan
  // Her ikisi de yoksa oyunu dahil et (timestamp bilgisi yok)
  return logs.where((log) {
    final timestamp = log.createdAt ?? log.lastSyncedAt;
    if (timestamp == null) return true; // Timestamp yoksa dahil et
    return timestamp.isAfter(startDate);
  }).toList();
}

/// Tüm istatistikleri hesapla
PlaybackStats _calculateStats(List<GameLog> logs, PlaybackPeriod period) {
  if (logs.isEmpty) {
    return PlaybackStats(
      period: period,
      totalHours: 0,
      totalGames: 0,
      completedGames: 0,
      playingGames: 0,
      platformStats: {},
      topGenres: [],
      archetype: PlayerArchetype.gamer,
      avgRating: 0,
      ratedGamesCount: 0,
      badgeTier: 0,
      completionRate: 0,
      avgHoursPerGame: 0,
      funComparison: 'Henüz oyun verisi yok',
    );
  }

  // Temel istatistikler
  final totalMinutes = logs.fold<int>(0, (sum, log) => sum + log.playtimeMinutes);
  final totalHours = totalMinutes / 60.0;
  final totalGames = logs.length;

  final completedGames = logs.where((l) => l.status == PlayStatus.completed).length;
  final playingGames = logs.where((l) => l.status == PlayStatus.playing).length;

  // Platform istatistikleri
  final platformStats = _calculatePlatformStats(logs);

  // Tür istatistikleri
  final topGenres = _calculateGenreStats(logs);

  // Puanlama istatistikleri
  final ratedLogs = logs.where((l) => l.rating != null).toList();
  final avgRating = ratedLogs.isNotEmpty
      ? ratedLogs.fold<double>(0, (sum, l) => sum + l.rating!) / ratedLogs.length
      : 0.0;

  // Hidden gems sayısı
  final hiddenGemsCount = _countHiddenGems(logs);

  // Tamamlama oranı
  final completionRate = totalGames > 0 ? (completedGames / totalGames) * 100 : 0.0;

  // Ortalama saat/oyun
  final avgHoursPerGame = totalGames > 0 ? totalHours / totalGames : 0.0;

  // Badge tier (tamamlanan oyun sayısına göre)
  final badgeTier = _calculateBadgeTier(completedGames);

  // En çok oynanan oyun
  final mostPlayedGame = logs.isNotEmpty
      ? logs.reduce((a, b) => a.playtimeMinutes > b.playtimeMinutes ? a : b)
      : null;

  // En yüksek puanlanan oyun
  final highestRatedGame = ratedLogs.isNotEmpty
      ? ratedLogs.reduce((a, b) => (a.rating ?? 0) > (b.rating ?? 0) ? a : b)
      : null;

  // Bırakılan oyun sayısı
  final droppedGamesCount = logs.where((l) => l.status == PlayStatus.dropped).length;

  // İstek listesi sayısı
  final wishlistCount = logs.where((l) => l.status == PlayStatus.wishlist).length;

  // Arketip ve ek arketipler hesapla
  final archetypeResult = _calculateArchetypesWithScores(
    logs: logs,
    platformStats: platformStats,
    topGenres: topGenres,
    avgRating: avgRating,
    completionRate: completionRate,
    avgHoursPerGame: avgHoursPerGame,
    hiddenGemsCount: hiddenGemsCount,
  );
  final archetype = archetypeResult.primary;
  final additionalArchetypes = archetypeResult.additional;

  // En çok oynanan 5 oyun
  final sortedByPlaytime = List<GameLog>.from(logs)
    ..sort((a, b) => b.playtimeMinutes.compareTo(a.playtimeMinutes));
  final topPlayedGames = sortedByPlaytime.take(5).toList();

  // Eğlenceli karşılaştırma
  final funComparison = _generateFunComparison(totalHours);

  return PlaybackStats(
    period: period,
    totalHours: totalHours,
    totalGames: totalGames,
    completedGames: completedGames,
    playingGames: playingGames,
    platformStats: platformStats,
    topGenres: topGenres,
    archetype: archetype,
    avgRating: avgRating,
    ratedGamesCount: ratedLogs.length,
    badgeTier: badgeTier,
    completionRate: completionRate,
    avgHoursPerGame: avgHoursPerGame,
    funComparison: funComparison,
    mostPlayedGame: mostPlayedGame,
    hiddenGemsCount: hiddenGemsCount,
    highestRatedGame: highestRatedGame,
    droppedGamesCount: droppedGamesCount,
    wishlistCount: wishlistCount,
    newGamesThisPeriod: totalGames, // Filtrelenmiş log sayısı = bu dönemde eklenen
    additionalArchetypes: additionalArchetypes,
    topPlayedGames: topPlayedGames,
  );
}

/// Platform bazlı istatistikleri hesapla
Map<String, PlatformStat> _calculatePlatformStats(List<GameLog> logs) {
  final stats = <String, PlatformStat>{};

  // Steam oyunları
  final steamLogs = logs.where((l) => l.source == 'steam' || l.steamAppId != null);
  if (steamLogs.isNotEmpty) {
    final steamMinutes = steamLogs.fold<int>(0, (sum, l) => sum + l.playtimeMinutes);
    stats['steam'] = PlatformStat(
      name: 'Steam',
      hours: steamMinutes / 60.0,
      gameCount: steamLogs.length,
    );
  }

  // PlayStation oyunları
  final psnLogs = logs.where((l) => l.source == 'playstation' || l.psnTitleId != null);
  if (psnLogs.isNotEmpty) {
    final psnMinutes = psnLogs.fold<int>(0, (sum, l) => sum + l.playtimeMinutes);
    stats['playstation'] = PlatformStat(
      name: 'PlayStation',
      hours: psnMinutes / 60.0,
      gameCount: psnLogs.length,
    );
  }

  // Riot oyunları
  final riotLogs = logs.where((l) => l.isRiotGame);
  if (riotLogs.isNotEmpty) {
    final riotMinutes = riotLogs.fold<int>(0, (sum, l) => sum + l.playtimeMinutes);
    stats['riot'] = PlatformStat(
      name: 'Riot Games',
      hours: riotMinutes / 60.0,
      gameCount: riotLogs.length,
    );
  }

  return stats;
}

/// Tür bazlı istatistikleri hesapla (top 3)
List<GenreStat> _calculateGenreStats(List<GameLog> logs) {
  final genreHours = <String, double>{};
  final genreCounts = <String, int>{};

  for (final log in logs) {
    for (final genre in log.game.genres) {
      genreHours[genre] = (genreHours[genre] ?? 0) + log.playtimeHours;
      genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
    }
  }

  // Saate göre sırala ve top 3 al
  final sortedGenres = genreHours.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sortedGenres.take(3).map((e) => GenreStat(
    name: e.key,
    hours: e.value,
    gameCount: genreCounts[e.key] ?? 0,
  )).toList();
}

/// Hidden gems sayısını hesapla
/// Metacritic <70 ama kişisel puan >=8
int _countHiddenGems(List<GameLog> logs) {
  return logs.where((log) {
    final metacritic = log.game.metacriticScore;
    final personalRating = log.rating;
    if (metacritic == null || personalRating == null) return false;
    return metacritic < 70 && personalRating >= 8;
  }).length;
}

/// Badge tier hesapla (tamamlanan oyun sayısına göre)
int _calculateBadgeTier(int completedGames) {
  if (completedGames >= 500) return 5; // Ölümsüz
  if (completedGames >= 250) return 4; // Efsane
  if (completedGames >= 100) return 3; // Uzman
  if (completedGames >= 50) return 2;  // Koleksiyoncu
  if (completedGames >= 25) return 1;  // Oyun Sever
  return 0; // Yeni Oyuncu
}

/// Arketip hesaplama sonucu
class _ArchetypeResult {
  final PlayerArchetype primary;
  final List<PlayerArchetype> additional;

  _ArchetypeResult(this.primary, this.additional);
}

/// Oyuncu arketiplerini skorlarıyla hesapla
_ArchetypeResult _calculateArchetypesWithScores({
  required List<GameLog> logs,
  required Map<String, PlatformStat> platformStats,
  required List<GenreStat> topGenres,
  required double avgRating,
  required double completionRate,
  required double avgHoursPerGame,
  required int hiddenGemsCount,
}) {
  final scores = <PlayerArchetype, double>{};
  final totalHours = platformStats.values.fold<double>(0, (sum, s) => sum + s.hours);
  final now = DateTime.now();

  // ═══════════════════════════════════════════════════════════════
  // PLATFORM BAZLI SKORLAR
  // ═══════════════════════════════════════════════════════════════
  if (totalHours > 0) {
    final steamHours = platformStats['steam']?.hours ?? 0;
    final psnHours = platformStats['playstation']?.hours ?? 0;
    final riotHours = platformStats['riot']?.hours ?? 0;
    final steamPercent = (steamHours / totalHours) * 100;
    final psnPercent = (psnHours / totalHours) * 100;

    // Steam Sadığı: %70-95
    if (steamPercent >= 70 && steamPercent < 95) {
      scores[PlayerArchetype.steamLoyal] = steamPercent;
    }
    // PC Master Race: %95+
    if (steamPercent >= 95) {
      scores[PlayerArchetype.pcMasterRace] = steamPercent + 20;
    }
    // PlayStation Fanatiği: %70-95
    if (psnPercent >= 70 && psnPercent < 95) {
      scores[PlayerArchetype.playstationFan] = psnPercent;
    }
    // Konsol Kralı: %95+
    if (psnPercent >= 95) {
      scores[PlayerArchetype.consoleKing] = psnPercent + 20;
    }
    // Çok Platformlu
    if (steamPercent >= 30 && steamPercent <= 70 && psnPercent >= 30) {
      scores[PlayerArchetype.multiPlatform] = 50 + (50 - (steamPercent - 50).abs());
    }
    // Riot Savaşçısı
    if (riotHours >= 10) {
      scores[PlayerArchetype.riotWarrior] = 50 + (riotHours * 0.5);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TÜR BAZLI SKORLAR (Tüm oyunlardan hesapla)
  // ═══════════════════════════════════════════════════════════════
  final genreCounts = <String, int>{};
  final genreHours = <String, double>{};
  final allGenres = <String>{};

  for (final log in logs) {
    for (final genre in log.game.genres) {
      final g = genre.toLowerCase();
      genreCounts[g] = (genreCounts[g] ?? 0) + 1;
      genreHours[g] = (genreHours[g] ?? 0) + log.playtimeHours;
      allGenres.add(g);
    }
  }

  // Indie Avcısı
  final indieCount = genreCounts.entries
      .where((e) => e.key.contains('indie'))
      .fold<int>(0, (sum, e) => sum + e.value);
  if (indieCount >= 10) {
    scores[PlayerArchetype.indieHunter] = 50 + (indieCount * 2);
  }

  // Aksiyon Delisi (Shooter + Action %40+)
  final actionCount = genreCounts.entries
      .where((e) => e.key.contains('shooter') || e.key.contains('action') || e.key.contains('hack'))
      .fold<int>(0, (sum, e) => sum + e.value);
  if (logs.isNotEmpty && (actionCount / logs.length) >= 0.4) {
    scores[PlayerArchetype.actionJunkie] = 60 + (actionCount * 1.5);
  }

  // Korku Ustası
  final horrorCount = genreCounts.entries
      .where((e) => e.key.contains('horror') || e.key.contains('survival'))
      .fold<int>(0, (sum, e) => sum + e.value);
  if (horrorCount >= 5) {
    scores[PlayerArchetype.horrorMaster] = 40 + (horrorCount * 4);
  }

  // Puzzle Dahisi
  final puzzleCount = genreCounts.entries
      .where((e) => e.key.contains('puzzle') || e.key.contains('brain'))
      .fold<int>(0, (sum, e) => sum + e.value);
  if (puzzleCount >= 5) {
    scores[PlayerArchetype.puzzleGenius] = 40 + (puzzleCount * 4);
  }

  // Spor Fanatiği
  final sportsCount = genreCounts.entries
      .where((e) => e.key.contains('sport') || e.key.contains('racing'))
      .fold<int>(0, (sum, e) => sum + e.value);
  if (sportsCount >= 5) {
    scores[PlayerArchetype.sportsFanatic] = 40 + (sportsCount * 4);
  }

  // Simülasyon Gurusu
  final simCount = genreCounts.entries
      .where((e) => e.key.contains('simulation') || e.key.contains('simulator'))
      .fold<int>(0, (sum, e) => sum + e.value);
  if (simCount >= 10) {
    scores[PlayerArchetype.simGuru] = 50 + (simCount * 2);
  }

  // Sandbox Mimarı
  final sandboxCount = genreCounts.entries
      .where((e) => e.key.contains('sandbox') || e.key.contains('building') || e.key.contains('craft'))
      .fold<int>(0, (sum, e) => sum + e.value);
  if (sandboxCount >= 5) {
    scores[PlayerArchetype.sandboxArchitect] = 40 + (sandboxCount * 4);
  }

  // Roguelike Uzmanı
  final roguelikeCount = genreCounts.entries
      .where((e) => e.key.contains('roguelike') || e.key.contains('roguelite'))
      .fold<int>(0, (sum, e) => sum + e.value);
  if (roguelikeCount >= 5) {
    scores[PlayerArchetype.roguelikeExpert] = 40 + (roguelikeCount * 4);
  }

  // MOBA Savaşçısı
  final mobaHours = genreHours.entries
      .where((e) => e.key.contains('moba') || e.key.contains('multiplayer online battle'))
      .fold<double>(0, (sum, e) => sum + e.value);
  if (mobaHours >= 50) {
    scores[PlayerArchetype.mobaWarrior] = 50 + mobaHours;
  }

  // Mevcut tür skorları (topGenres'den)
  if (topGenres.isNotEmpty) {
    for (final genre in topGenres) {
      final genreName = genre.name.toLowerCase();
      final genreScore = genre.hours * 2;

      if (genreName.contains('strategy') || genreName.contains('tactical')) {
        scores[PlayerArchetype.strategist] = (scores[PlayerArchetype.strategist] ?? 0) + genreScore;
      }
      if (genreName.contains('adventure') || genreName.contains('rpg') || genreName.contains('role-playing')) {
        scores[PlayerArchetype.adventurer] = (scores[PlayerArchetype.adventurer] ?? 0) + genreScore;
      }
      if (genreName.contains('shooter') || genreName.contains('fighting')) {
        scores[PlayerArchetype.competitor] = (scores[PlayerArchetype.competitor] ?? 0) + genreScore;
      }
      if (genreName.contains('visual novel') || genreName.contains('narrative') || genreName.contains('story')) {
        scores[PlayerArchetype.storyteller] = (scores[PlayerArchetype.storyteller] ?? 0) + genreScore;
      }
    }
  }

  // Çeşitlilik Arayıcısı
  if (allGenres.length >= 10) {
    scores[PlayerArchetype.varietySeeker] = 40 + (allGenres.length * 2);
  }

  // ═══════════════════════════════════════════════════════════════
  // DAVRANIŞ BAZLI SKORLAR
  // ═══════════════════════════════════════════════════════════════

  // Kütüphane Baronu (100+ oyun)
  if (logs.length >= 100 && logs.length < 250) {
    scores[PlayerArchetype.libraryBaron] = 60 + (logs.length * 0.2);
  }
  // Büyük Kütüphaneci (250+ oyun)
  if (logs.length >= 250) {
    scores[PlayerArchetype.grandLibrarian] = 80 + (logs.length * 0.1);
  }

  // Completionist
  if (completionRate >= 50) {
    scores[PlayerArchetype.completionist] = completionRate;
  }

  // Retro Oyuncu (2010 öncesi 10+ oyun)
  final retroGames = logs.where((l) {
    final release = l.game.releaseDate;
    return release != null && release.year < 2010;
  }).length;
  if (retroGames >= 10) {
    scores[PlayerArchetype.retroGamer] = 50 + (retroGames * 2);
  }

  // Sabırlı Oyuncu (2+ yıl önce çıkmış oyunlar ağırlıklı)
  final oldGames = logs.where((l) {
    final release = l.game.releaseDate;
    return release != null && now.difference(release).inDays > 730; // 2 yıl
  }).length;
  if (logs.isNotEmpty && (oldGames / logs.length) >= 0.7) {
    scores[PlayerArchetype.patientGamer] = 50 + (oldGames * 0.5);
  }

  // Yeni Oyun Avcısı (son 6 ayda çıkmış 5+ oyun)
  final newGames = logs.where((l) {
    final release = l.game.releaseDate;
    return release != null && now.difference(release).inDays < 180;
  }).length;
  if (newGames >= 5) {
    scores[PlayerArchetype.dayOneGamer] = 50 + (newGames * 5);
  }

  // Sadık Fan (tek oyunda 200+ saat)
  final loyalGame = logs.where((l) => l.playtimeHours >= 200).isNotEmpty;
  if (loyalGame) {
    final maxHours = logs.map((l) => l.playtimeHours).reduce((a, b) => a > b ? a : b);
    scores[PlayerArchetype.loyalFan] = 70 + (maxHours * 0.1);
  }

  // Hızlı Bitirici (ort <5 saat + %50 completed)
  final completedLogs = logs.where((l) => l.status == PlayStatus.completed);
  if (completedLogs.isNotEmpty) {
    final completedAvgHours = completedLogs.map((l) => l.playtimeHours).reduce((a, b) => a + b) / completedLogs.length;
    if (completedAvgHours < 5 && completionRate >= 50) {
      scores[PlayerArchetype.speedrunner] = 50 + ((5 - completedAvgHours) * 10);
    }
  }

  // Sosyal Oyuncu (Multiplayer ağırlıklı)
  final multiplayerCount = genreCounts.entries
      .where((e) => e.key.contains('multiplayer') || e.key.contains('co-op') || e.key.contains('mmo'))
      .fold<int>(0, (sum, e) => sum + e.value);
  if (logs.isNotEmpty && (multiplayerCount / logs.length) >= 0.5) {
    scores[PlayerArchetype.socialGamer] = 50 + (multiplayerCount * 2);
  }

  // Solo Kurt (Singleplayer ağırlıklı)
  final singleplayerCount = genreCounts.entries
      .where((e) => e.key.contains('single') || e.key.contains('singleplayer'))
      .fold<int>(0, (sum, e) => sum + e.value);
  if (logs.isNotEmpty && singleplayerCount > multiplayerCount * 2) {
    scores[PlayerArchetype.soloWolf] = 40 + (singleplayerCount * 1.5);
  }

  // Yarım Kalan İşler (%30+ dropped)
  final droppedCount = logs.where((l) => l.status == PlayStatus.dropped).length;
  if (logs.isNotEmpty && (droppedCount / logs.length) >= 0.3) {
    scores[PlayerArchetype.unfinishedBusiness] = 40 + (droppedCount * 2);
  }

  // Backlog Savaşçısı (backlog'dan 10+ oyun bitirmiş varsayımı - completed sayısına bak)
  final completedCount = logs.where((l) => l.status == PlayStatus.completed).length;
  if (completedCount >= 10) {
    scores[PlayerArchetype.backlogWarrior] = 40 + (completedCount * 1.5);
  }

  if (logs.length >= 5) {
    // Maratoncu: Oyunların %80'i 15+ saat oynanmış
    final gamesOver15Hours = logs.where((l) => l.playtimeHours >= 15).length;
    final marathonPercent = (gamesOver15Hours / logs.length) * 100;
    if (marathonPercent >= 80) {
      scores[PlayerArchetype.marathoner] = marathonPercent + (avgHoursPerGame * 2);
    }

    // İstifçi: Oyunların %50'si hiç oynanmamış (0 saat)
    final unplayedGames = logs.where((l) => l.playtimeMinutes == 0).length;
    final unplayedPercent = (unplayedGames / logs.length) * 100;
    if (unplayedPercent >= 50) {
      scores[PlayerArchetype.hoarder] = unplayedPercent + (unplayedGames * 0.5);
    }

    // Koleksiyoncu: Ortalama düşük ama çok oyun
    if (avgHoursPerGame < 8) {
      scores[PlayerArchetype.collector] = logs.length * 2.0;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PUANLAMA BAZLI SKORLAR
  // ═══════════════════════════════════════════════════════════════
  final ratedLogs = logs.where((l) => l.rating != null).toList();

  if (avgRating > 0) {
    if (avgRating < 6) scores[PlayerArchetype.harshCritic] = (10 - avgRating) * 10;
    if (avgRating > 7) scores[PlayerArchetype.positivePlayer] = avgRating * 10;
  }

  // Hidden gem avcısı
  if (hiddenGemsCount >= 1) {
    scores[PlayerArchetype.hiddenGemHunter] = hiddenGemsCount * 20.0;
  }

  // AAA Tutkunu (Metacritic 85+ oyunlara ağırlıklı)
  final aaaGames = logs.where((l) {
    final meta = l.game.metacriticScore;
    return meta != null && meta >= 85;
  }).length;
  if (logs.isNotEmpty && (aaaGames / logs.length) >= 0.5) {
    scores[PlayerArchetype.aaaLover] = 50 + (aaaGames * 2);
  }

  // Underdog Destekçisi (hiddenGemHunter'ın genişletilmiş hali)
  final underdogCount = logs.where((l) {
    final meta = l.game.metacriticScore;
    final rating = l.rating;
    return meta != null && meta < 70 && rating != null && rating >= 8;
  }).length;
  if (underdogCount >= 3) {
    scores[PlayerArchetype.underdogSupporter] = 40 + (underdogCount * 10);
  }

  // Seçici Damak (20+ oyun puanlamış, ort >7)
  if (ratedLogs.length >= 20 && avgRating > 7) {
    scores[PlayerArchetype.pickyPalate] = 40 + (ratedLogs.length * 0.5) + (avgRating * 5);
  }

  // Puanlama Uzmanı (50+ oyun puanlamış)
  if (ratedLogs.length >= 50) {
    scores[PlayerArchetype.ratingExpert] = 50 + (ratedLogs.length * 0.5);
  }

  // ═══════════════════════════════════════════════════════════════
  // FALLBACK & SONUÇ
  // ═══════════════════════════════════════════════════════════════
  scores[PlayerArchetype.gamer] = 10;

  // Skorlara göre sırala
  final sortedArchetypes = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final primary = sortedArchetypes.first.key;
  // Önce filtrele, sonra top 3 al (primary ve gamer hariç)
  final additional = sortedArchetypes
      .skip(1)
      .where((e) => e.value >= 10 && e.key != PlayerArchetype.gamer)
      .take(3)
      .map((e) => e.key)
      .toList();

  return _ArchetypeResult(primary, additional);
}

/// Eğlenceli karşılaştırma metni oluştur
String _generateFunComparison(double totalHours) {
  if (totalHours < 1) {
    return 'Yeni maceralara hazır!';
  }

  // Film karşılaştırması (ortalama film 2 saat)
  final movies = (totalHours / 2).round();
  if (movies > 0 && movies <= 50) {
    return 'Bu sürede $movies film izleyebilirdin!';
  }

  // Kitap karşılaştırması (ortalama kitap 8 saat)
  final books = (totalHours / 8).round();
  if (books > 0 && books <= 30) {
    return 'Bu sürede $books kitap okuyabilirdin!';
  }

  // Dünya turu karşılaştırması (40,000 km, 5 km/saat yürüyüş)
  final worldTourPercent = ((totalHours * 5) / 40000 * 100).toStringAsFixed(1);
  if (totalHours >= 100 && totalHours < 500) {
    return "Dünya'yı yürüyerek %$worldTourPercent turladın!";
  }

  // Mars yolculuğu (7 ay = ~5000 saat)
  if (totalHours >= 500) {
    final marsPercent = ((totalHours / 5000) * 100).toStringAsFixed(1);
    return "Mars'a gidiş yolculuğunun %$marsPercent'i kadar oynadın!";
  }

  // Maraton karşılaştırması (ortalama 4 saat)
  final marathons = (totalHours / 4).round();
  return '$marathons maraton koşabilirdin!';
}

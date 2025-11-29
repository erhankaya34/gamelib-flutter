import 'game.dart';

enum PlayStatus { wishlist, playing, completed, dropped }

class GameLog {
  const GameLog({
    required this.id,
    required this.game,
    required this.status,
    this.rating,
    this.notes,
    this.source = 'manual',
    this.steamAppId,
    this.playtimeMinutes = 0,
    this.lastSyncedAt,
  });

  final String id;
  final Game game;
  final PlayStatus status;
  final int? rating;
  final String? notes;

  /// Source of the game: 'manual' (user-added) or 'steam' (auto-imported)
  final String source;

  /// Steam App ID for games imported from Steam
  final int? steamAppId;

  /// Total playtime in minutes
  final int playtimeMinutes;

  /// Last time synced from Steam (for auto-imported games)
  final DateTime? lastSyncedAt;

  factory GameLog.fromMap(Map<String, dynamic> data) {
    return GameLog(
      id: data['id'] as String,
      game: Game.fromMap(data['game'] as Map<String, dynamic>),
      status: PlayStatus.values.firstWhere(
        (value) => value.name == data['status'],
        orElse: () => PlayStatus.wishlist,
      ),
      rating: data['rating'] as int?,
      notes: data['notes'] as String?,
      source: data['source'] as String? ?? 'manual',
      steamAppId: data['steam_app_id'] as int?,
      playtimeMinutes: data['playtime_minutes'] as int? ?? 0,
      lastSyncedAt: data['last_synced_at'] != null
          ? DateTime.parse(data['last_synced_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'game': game.toMap(),
      'status': status.name,
      'rating': rating,
      'notes': notes,
      'source': source,
      'steam_app_id': steamAppId,
      'playtime_minutes': playtimeMinutes,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
    };
  }

  /// Helper getter for playtime in hours
  double get playtimeHours => playtimeMinutes / 60.0;

  /// Helper getter to check if this is a Steam game
  bool get isSteamGame => source == 'steam';

  /// Helper getter to check if this is a manual game
  bool get isManualGame => source == 'manual';
}

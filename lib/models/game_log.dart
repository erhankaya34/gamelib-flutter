import 'game.dart';

enum PlayStatus { wishlist, playing, completed, dropped, backlog }

class GameLog {
  const GameLog({
    required this.id,
    required this.game,
    required this.status,
    this.rating,
    this.notes,
    this.source = 'manual',
    this.steamAppId,
    this.psnTitleId,
    this.riotGameId,
    this.riotRankedData,
    this.playtimeMinutes = 0,
    this.lastSyncedAt,
    this.createdAt,
  });

  final String id;
  final Game game;
  final PlayStatus status;
  final int? rating;
  final String? notes;

  /// Source of the game: 'manual', 'steam', 'playstation', 'lol', 'valorant', 'tft'
  final String source;

  /// Steam App ID for games imported from Steam
  final int? steamAppId;

  /// PlayStation title ID for games imported from PSN
  final String? psnTitleId;

  /// Riot game identifier: 'lol', 'valorant', 'tft'
  final String? riotGameId;

  /// Riot ranked stats (tier, rank, LP, wins, losses)
  final Map<String, dynamic>? riotRankedData;

  /// Total playtime in minutes
  final int playtimeMinutes;

  /// Last time synced from source (for auto-imported games)
  final DateTime? lastSyncedAt;

  /// When this game log was created (added to library)
  final DateTime? createdAt;

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
      psnTitleId: data['psn_title_id'] as String?,
      riotGameId: data['riot_game_id'] as String?,
      riotRankedData: data['riot_ranked_data'] as Map<String, dynamic>?,
      playtimeMinutes: data['playtime_minutes'] as int? ?? 0,
      lastSyncedAt: data['last_synced_at'] != null
          ? DateTime.parse(data['last_synced_at'] as String)
          : null,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
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
      'psn_title_id': psnTitleId,
      'riot_game_id': riotGameId,
      'riot_ranked_data': riotRankedData,
      'playtime_minutes': playtimeMinutes,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Helper getter for playtime in hours
  double get playtimeHours => playtimeMinutes / 60.0;

  /// Helper getter to check if this is a Steam game
  bool get isSteamGame => source == 'steam';

  /// Helper getter to check if this is a PlayStation game
  bool get isPlayStationGame => source == 'playstation';

  /// Helper getter to check if this is a Riot game
  bool get isRiotGame => source == 'lol' || source == 'valorant' || source == 'tft';

  /// Helper getter to check if this is a manual game
  bool get isManualGame => source == 'manual';

  /// Creates a copy with specified fields changed
  GameLog copyWith({
    String? id,
    Game? game,
    PlayStatus? status,
    int? rating,
    String? notes,
    String? source,
    int? steamAppId,
    String? psnTitleId,
    String? riotGameId,
    Map<String, dynamic>? riotRankedData,
    int? playtimeMinutes,
    DateTime? lastSyncedAt,
    DateTime? createdAt,
    bool clearRating = false,
    bool clearNotes = false,
  }) {
    return GameLog(
      id: id ?? this.id,
      game: game ?? this.game,
      status: status ?? this.status,
      rating: clearRating ? null : (rating ?? this.rating),
      notes: clearNotes ? null : (notes ?? this.notes),
      source: source ?? this.source,
      steamAppId: steamAppId ?? this.steamAppId,
      psnTitleId: psnTitleId ?? this.psnTitleId,
      riotGameId: riotGameId ?? this.riotGameId,
      riotRankedData: riotRankedData ?? this.riotRankedData,
      playtimeMinutes: playtimeMinutes ?? this.playtimeMinutes,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

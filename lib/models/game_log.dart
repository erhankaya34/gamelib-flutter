import 'game.dart';

enum PlayStatus { wishlist, playing, completed, dropped }

class GameLog {
  const GameLog({
    required this.id,
    required this.game,
    required this.status,
    this.rating,
    this.notes,
  });

  final String id;
  final Game game;
  final PlayStatus status;
  final int? rating;
  final String? notes;

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
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'game': game.toMap(),
      'status': status.name,
      'rating': rating,
      'notes': notes,
    };
  }
}

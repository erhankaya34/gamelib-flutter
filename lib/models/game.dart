class Game {
  const Game({
    required this.id,
    required this.name,
    this.coverUrl,
    this.summary,
  });

  final int id;
  final String name;
  final String? coverUrl;
  final String? summary;

  factory Game.fromMap(Map<String, dynamic> data) {
    return Game(
      id: data['id'] as int,
      name: data['name'] as String,
      coverUrl: data['coverUrl'] as String?,
      summary: data['summary'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'coverUrl': coverUrl,
      'summary': summary,
    };
  }
}

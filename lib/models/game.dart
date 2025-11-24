class Game {
  const Game({
    required this.id,
    required this.name,
    this.coverUrl,
    this.summary,
    this.platforms = const [],
    this.genres = const [],
    this.aggregatedRating,
    this.userRating,
    this.ratingCount,
  });

  final int id;
  final String name;
  final String? coverUrl;
  final String? summary;
   // IGDB data
  final List<String> platforms;
  final List<String> genres;
  final double? aggregatedRating;
  final double? userRating;
  final int? ratingCount;

  factory Game.fromMap(Map<String, dynamic> data) {
    List<String> parseList(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map((e) => e['name'] as String?)
            .whereType<String>()
            .toList();
      }
      return const [];
    }

    String? resolveCover(Map<String, dynamic>? coverData) {
      if (coverData == null) return null;
      final url = coverData['url'] as String?;
      if (url == null) return null;
      return url.startsWith('//') ? 'https:$url' : url;
    }

    return Game(
      id: data['id'] as int,
      name: data['name'] as String? ?? 'Unknown',
      coverUrl: resolveCover(data['cover'] as Map<String, dynamic>?),
      summary: data['summary'] as String?,
      platforms: parseList(data['platforms']),
      genres: parseList(data['genres']),
      aggregatedRating: (data['aggregated_rating'] as num?)?.toDouble(),
      userRating: (data['rating'] as num?)?.toDouble(),
      ratingCount: data['rating_count'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'coverUrl': coverUrl,
      'summary': summary,
      'platforms': platforms,
      'genres': genres,
      'aggregatedRating': aggregatedRating,
      'userRating': userRating,
      'ratingCount': ratingCount,
    };
  }
}

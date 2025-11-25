class Game {
  const Game({
    required this.id,
    required this.name,
    this.coverUrl,
    this.screenshotUrls = const [],
    this.summary,
    this.platforms = const [],
    this.genres = const [],
    this.aggregatedRating,
    this.userRating,
    this.ratingCount,
    this.metacriticScore,
    this.releaseDate,
  });

  final int id;
  final String name;
  final String? coverUrl;
  final List<String> screenshotUrls;
  final String? summary;
  // IGDB data
  final List<String> platforms;
  final List<String> genres;
  final double? aggregatedRating;
  final double? userRating;
  final int? ratingCount;
  final int? metacriticScore;
  final DateTime? releaseDate;

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
      // Convert to high resolution image (1080p for better quality)
      final resolvedUrl = url.startsWith('//') ? 'https:$url' : url;
      return resolvedUrl
          .replaceAll('/t_thumb/', '/t_1080p/')
          .replaceAll('/t_cover_big/', '/t_1080p/');
    }

    List<String> parseScreenshots(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map((e) {
              final url = e['url'] as String?;
              if (url == null) return null;
              final resolvedUrl = url.startsWith('//') ? 'https:$url' : url;
              // Use high resolution screenshots (1080p)
              return resolvedUrl
                  .replaceAll('/t_thumb/', '/t_1080p/')
                  .replaceAll('/t_screenshot_med/', '/t_1080p/');
            })
            .whereType<String>()
            .toList();
      }
      return const [];
    }

    DateTime? parseReleaseDate(dynamic value) {
      if (value == null) return null;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
      return null;
    }

    return Game(
      id: data['id'] as int,
      name: data['name'] as String? ?? 'Unknown',
      // Check for direct coverUrl string first (from database), then fallback to cover map (from IGDB)
      coverUrl: data['coverUrl'] as String? ?? resolveCover(data['cover'] as Map<String, dynamic>?),
      screenshotUrls: parseScreenshots(data['screenshots']),
      summary: data['summary'] as String?,
      platforms: parseList(data['platforms']),
      genres: parseList(data['genres']),
      aggregatedRating: (data['aggregated_rating'] as num?)?.toDouble(),
      userRating: (data['rating'] as num?)?.toDouble(),
      ratingCount: data['rating_count'] as int?,
      metacriticScore: data['aggregated_rating_count'] != null &&
                       (data['aggregated_rating_count'] as int) >= 7
          ? (data['aggregated_rating'] as num?)?.round()
          : null,
      releaseDate: parseReleaseDate(data['first_release_date']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'coverUrl': coverUrl,
      'screenshotUrls': screenshotUrls,
      'summary': summary,
      'platforms': platforms,
      'genres': genres,
      'aggregatedRating': aggregatedRating,
      'userRating': userRating,
      'ratingCount': ratingCount,
      'metacriticScore': metacriticScore,
      'releaseDate': releaseDate?.millisecondsSinceEpoch,
    };
  }
}

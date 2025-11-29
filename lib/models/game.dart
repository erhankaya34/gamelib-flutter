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
      // Handle all IGDB thumbnail formats
      return resolvedUrl
          .replaceAll('/t_thumb/', '/t_1080p/')
          .replaceAll('/t_cover_big/', '/t_1080p/')
          .replaceAll('/t_cover_small/', '/t_1080p/')
          .replaceAll('/t_cover_small_2x/', '/t_1080p/')
          .replaceAll('/t_cover_big_2x/', '/t_1080p/')
          .replaceAll('/t_micro/', '/t_1080p/')
          .replaceAll('/t_logo_med/', '/t_1080p/');
    }

    List<String> parseScreenshots(dynamic value) {
      if (value is List) {
        // Handle both formats:
        // 1. IGDB format: [{url: '...'}, {url: '...'}]
        // 2. DB storage format: ['url1', 'url2']
        return value.map((e) {
          String? url;
          if (e is Map<String, dynamic>) {
            url = e['url'] as String?;
          } else if (e is String) {
            url = e;
          }
          if (url == null) return null;
          final resolvedUrl = url.startsWith('//') ? 'https:$url' : url;
          // Use high resolution screenshots
          return resolvedUrl
              .replaceAll('/t_thumb/', '/t_screenshot_huge/')
              .replaceAll('/t_screenshot_med/', '/t_screenshot_huge/')
              .replaceAll('/t_screenshot_big/', '/t_screenshot_huge/');
        }).whereType<String>().toList();
      }
      return const [];
    }

    DateTime? parseReleaseDate(dynamic value) {
      if (value == null) return null;
      if (value is int) {
        // IGDB format: Unix timestamp (seconds)
        // DB format: millisecondsSinceEpoch
        // Determine which format based on value size
        if (value > 1e12) {
          // Already in milliseconds
          return DateTime.fromMillisecondsSinceEpoch(value);
        } else {
          // In seconds (IGDB format)
          return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        }
      }
      return null;
    }

    return Game(
      id: data['id'] as int,
      name: data['name'] as String? ?? 'Unknown',
      // Check for direct coverUrl string first (from database), then fallback to cover map (from IGDB)
      coverUrl: data['coverUrl'] as String? ?? resolveCover(data['cover'] as Map<String, dynamic>?),
      // Check both DB format (screenshotUrls) and IGDB format (screenshots)
      screenshotUrls: parseScreenshots(data['screenshotUrls'] ?? data['screenshots']),
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
      // Check both IGDB field name and DB storage field name
      releaseDate: parseReleaseDate(data['first_release_date'] ?? data['releaseDate']),
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

  /// Get cover URL optimized for grid/list view (528x748 - retina medium)
  /// Balances quality and performance for library grids
  String? get coverUrlForGrid {
    if (coverUrl == null) return null;
    // For IGDB URLs, use cover_big_2x (528x748) which is good for grids
    if (coverUrl!.contains('images.igdb.com')) {
      return coverUrl!
          .replaceAll('/t_1080p/', '/t_cover_big_2x/')
          .replaceAll('/t_720p/', '/t_cover_big_2x/');
    }
    // Steam header.jpg (460x215) is used for Steam games - always exists
    return coverUrl;
  }

  /// Get cover URL for full-screen detail view (1080p - highest quality)
  String? get coverUrlForDetail {
    if (coverUrl == null) return null;
    // For IGDB URLs, ensure we use 1080p
    if (coverUrl!.contains('images.igdb.com')) {
      return coverUrl!
          .replaceAll('/t_cover_big_2x/', '/t_1080p/')
          .replaceAll('/t_cover_big/', '/t_1080p/')
          .replaceAll('/t_cover_small/', '/t_1080p/')
          .replaceAll('/t_thumb/', '/t_1080p/');
    }
    return coverUrl;
  }

  /// Get small thumbnail for compact lists (264x374)
  String? get coverUrlForThumbnail {
    if (coverUrl == null) return null;
    if (coverUrl!.contains('images.igdb.com')) {
      return coverUrl!
          .replaceAll('/t_1080p/', '/t_cover_big/')
          .replaceAll('/t_720p/', '/t_cover_big/')
          .replaceAll('/t_cover_big_2x/', '/t_cover_big/');
    }
    return coverUrl;
  }
}

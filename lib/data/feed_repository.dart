import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/game.dart';
import 'friend_repository.dart';
import 'igdb_client.dart';
import 'supabase_client.dart';

/// Feed item type
enum FeedItemType {
  activity, // Friend activity
  recommendation, // Game recommendation
}

/// Activity type
enum ActivityType {
  added,
  completed,
  playing,
  dropped,
  planToPlay,
  rated,
}

/// Feed item model
/// Can represent either a friend activity or a game recommendation
class FeedItem {
  const FeedItem({
    required this.type,
    this.activityType,
    this.username,
    this.userId,
    this.game,
    this.rating,
    this.timestamp,
  });

  final FeedItemType type;
  final ActivityType? activityType;
  final String? username;
  final String? userId;
  final Game? game;
  final int? rating;
  final DateTime? timestamp;

  /// Format activity text for display
  String getActivityText() {
    if (type == FeedItemType.recommendation) {
      return 'GameLib Önerisi';
    }

    if (username == null || game == null || activityType == null) {
      return '';
    }

    switch (activityType!) {
      case ActivityType.added:
        return '$username kütüphanesine ${game!.name} ekledi';
      case ActivityType.completed:
        return '$username ${game!.name} oyununu tamamladı!';
      case ActivityType.playing:
        return '$username ${game!.name} oynuyor';
      case ActivityType.dropped:
        return '$username ${game!.name} oyununu bıraktı';
      case ActivityType.planToPlay:
        return '$username ${game!.name} oynamayı planlıyor';
      case ActivityType.rated:
        if (rating != null) {
          return '$username ${game!.name} oyununa $rating/10 verdi';
        }
        return '$username ${game!.name} oyununu değerlendirdi';
    }
  }
}

/// Repository for feed operations
/// Handles both friend activities and game recommendations
class FeedRepository {
  FeedRepository(this.supabase);

  final SupabaseClient supabase;

  /// Get user's feed
  /// Returns friend activities + recommendations if user has <3 friends
  Future<List<FeedItem>> getFeed() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      print('📰 Feed: No current user');
      return [];
    }

    try {
      print('📰 Feed: Fetching for user $currentUserId');

      // Get friend count directly
      final friendCount = await getFriendCount();
      print('📰 Feed: Friend count = $friendCount');

      // Get friend activities
      final activities = await _getFriendActivities();
      print('📰 Feed: Got ${activities.length} activities');

      // If user has <3 friends, add recommendations
      if (friendCount < 3) {
        final recommendations = await _getRecommendations();
        print('📰 Feed: Got ${recommendations.length} recommendations');

        // If both activities and recommendations are empty, return empty list
        // The UI will show a helpful empty state
        if (activities.isEmpty && recommendations.isEmpty) {
          print('📰 Feed: Both empty, returning empty list');
          return [];
        }

        // Interleave recommendations with activities
        final feed = <FeedItem>[];
        var activityIndex = 0;
        var recommendationIndex = 0;

        // Pattern: 2 activities, 1 recommendation, repeat
        while (activityIndex < activities.length ||
            recommendationIndex < recommendations.length) {
          // Add up to 2 activities
          for (var i = 0; i < 2 && activityIndex < activities.length; i++) {
            feed.add(activities[activityIndex++]);
          }

          // Add 1 recommendation
          if (recommendationIndex < recommendations.length) {
            feed.add(recommendations[recommendationIndex++]);
          }
        }

        return feed;
      }

      return activities;
    } catch (e) {
      // Log error but return empty list instead of throwing
      // This prevents the UI from showing error state
      print('Error fetching feed: $e');
      return [];
    }
  }

  /// Get friend count (duplicate from FriendRepository for simplicity)
  Future<int> getFriendCount() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return 0;

    try {
      final result = await supabase
          .from('friendships')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('status', 'accepted');

      return result.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get friend activities from the activities table
  Future<List<FeedItem>> _getFriendActivities() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      // Get friend IDs
      final friendships = await supabase
          .from('friendships')
          .select('friend_id')
          .eq('user_id', currentUserId)
          .eq('status', 'accepted');

      if (friendships.isEmpty) return [];

      final friendIds =
          friendships.map((f) => f['friend_id'] as String).toList();

      // Get activities from friends
      final activities = await supabase
          .from('activities')
          .select('user_id, game_id, game_name, action_type, rating, created_at')
          .inFilter('user_id', friendIds)
          .order('created_at', ascending: false)
          .limit(50);

      if (activities.isEmpty) return [];

      // Get usernames for all friend IDs
      final profiles = await supabase
          .from('profiles')
          .select('id, username')
          .inFilter('id', friendIds);

      final usernameMap = {
        for (var profile in profiles)
          profile['id'] as String: profile['username'] as String
      };

      // Convert to FeedItem objects
      return activities.map<FeedItem>((activity) {
        final userId = activity['user_id'] as String;
        final username = usernameMap[userId];
        final gameName = activity['game_name'] as String;
        final actionType = activity['action_type'] as String;
        final rating = activity['rating'] as int?;
        final createdAt = DateTime.parse(activity['created_at'] as String);

        // Create minimal Game object for display
        final game = Game(
          id: activity['game_id'] as int,
          name: gameName,
          summary: null,
          coverUrl: null,
          screenshotUrls: const [],
          platforms: const [],
          genres: const [],
          aggregatedRating: null,
          userRating: null,
          ratingCount: null,
          metacriticScore: null,
          releaseDate: null,
        );

        // Map action type to ActivityType
        ActivityType? activityType;
        switch (actionType) {
          case 'added':
            activityType = ActivityType.added;
            break;
          case 'completed':
            activityType = ActivityType.completed;
            break;
          case 'playing':
            activityType = ActivityType.playing;
            break;
          case 'dropped':
            activityType = ActivityType.dropped;
            break;
          case 'plan_to_play':
            activityType = ActivityType.planToPlay;
            break;
          case 'rated':
            activityType = ActivityType.rated;
            break;
        }

        return FeedItem(
          type: FeedItemType.activity,
          activityType: activityType,
          username: username,
          userId: userId,
          game: game,
          rating: rating,
          timestamp: createdAt,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to get friend activities: $e');
    }
  }

  /// Get indie game recommendations based on user's favorite genres
  Future<List<FeedItem>> _getRecommendations() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      print('📰 Recommendations: No current user');
      return [];
    }

    try {
      print('📰 Recommendations: Fetching for user $currentUserId');

      // Get user's favorite genres
      final userGenres = await supabase
          .from('user_genres')
          .select('genre_name')
          .eq('user_id', currentUserId);

      final genreNames =
          userGenres.map((g) => g['genre_name'] as String).toList();
      print('📰 Recommendations: User genres = $genreNames');

      // Fetch INDIE game recommendations from IGDB
      final igdbClient = IgdbClient();
      final games = await igdbClient.fetchIndieGames(genreNames);
      print('📰 Recommendations: IGDB returned ${games.length} indie games');

      // Take only 6 games
      final limitedGames = games.take(6).toList();

      // Convert to FeedItem objects
      return limitedGames.map((game) {
        return FeedItem(
          type: FeedItemType.recommendation,
          game: game,
        );
      }).toList();
    } catch (e) {
      // If recommendations fail, return empty list instead of throwing
      // This prevents the entire feed from failing
      print('Error fetching recommendations: $e');
      return [];
    }
  }
}

/// Provider for FeedRepository
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(supabaseProvider));
});

/// Provider for feed items
final feedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final repo = ref.read(feedRepositoryProvider);
  return repo.getFeed();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Repository for friend-related operations
/// Handles friend requests, acceptance/rejection, and friend list management
class FriendRepository {
  FriendRepository(this.supabase);

  final SupabaseClient supabase;

  /// Search users by username
  /// Returns list of users matching the query (excludes current user)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Not authenticated');
    }

    try {
      final results = await supabase
          .from('profiles')
          .select('id, username, email')
          .ilike('username', '%$query%')
          .neq('id', currentUserId)
          .limit(20);

      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  /// Send a friend request to another user
  /// Creates a pending friendship row
  Future<void> sendFriendRequest(String friendId) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Not authenticated');
    }

    try {
      await supabase.from('friendships').insert({
        'user_id': currentUserId,
        'friend_id': friendId,
        'status': 'pending',
        'requested_by': currentUserId,
      });
    } catch (e) {
      throw Exception('Failed to send friend request: $e');
    }
  }

  /// Accept a friend request
  /// Updates the existing row to 'accepted' and creates a reciprocal row
  Future<void> acceptFriendRequest(String friendshipId, String friendId) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Not authenticated');
    }

    try {
      // Update existing friendship to accepted
      await supabase
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', friendshipId);

      // Create reciprocal friendship
      await supabase.from('friendships').insert({
        'user_id': currentUserId,
        'friend_id': friendId,
        'status': 'accepted',
        'requested_by': friendId, // Original requester
      });
    } catch (e) {
      throw Exception('Failed to accept friend request: $e');
    }
  }

  /// Reject a friend request
  /// Updates the friendship status to 'rejected'
  Future<void> rejectFriendRequest(String friendshipId) async {
    try {
      await supabase
          .from('friendships')
          .update({'status': 'rejected'})
          .eq('id', friendshipId);
    } catch (e) {
      throw Exception('Failed to reject friend request: $e');
    }
  }

  /// Remove a friend (unfriend)
  /// Deletes both friendship rows (bi-directional)
  Future<void> removeFriend(String friendId) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Not authenticated');
    }

    try {
      // Delete both rows
      await supabase
          .from('friendships')
          .delete()
          .eq('user_id', currentUserId)
          .eq('friend_id', friendId);

      await supabase
          .from('friendships')
          .delete()
          .eq('user_id', friendId)
          .eq('friend_id', currentUserId);
    } catch (e) {
      throw Exception('Failed to remove friend: $e');
    }
  }

  /// Get list of accepted friends
  /// Returns user profiles of all accepted friends
  Future<List<Map<String, dynamic>>> getFriends() async {
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

      // Get friend profiles
      final profiles = await supabase
          .from('profiles')
          .select('id, username, email')
          .inFilter('id', friendIds);

      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) {
      throw Exception('Failed to get friends: $e');
    }
  }

  /// Get list of pending friend requests (received)
  /// Returns requests where current user is the recipient
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final requests = await supabase
          .from('friendships')
          .select('id, user_id, created_at')
          .eq('friend_id', currentUserId)
          .eq('status', 'pending');

      if (requests.isEmpty) return [];

      final userIds = requests.map((r) => r['user_id'] as String).toList();

      // Get requester profiles
      final profiles = await supabase
          .from('profiles')
          .select('id, username, email')
          .inFilter('id', userIds);

      // Merge data
      return requests.map((req) {
        final profile =
            profiles.firstWhere((p) => p['id'] == req['user_id']);
        return {
          'friendship_id': req['id'],
          'user_id': req['user_id'],
          'username': profile['username'],
          'email': profile['email'],
          'created_at': req['created_at'],
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get pending requests: $e');
    }
  }

  /// Get friend count for current user
  /// Used to determine if user should see recommendations in feed
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

  /// Check if a friendship exists between current user and another user
  /// Returns status: null (no friendship), 'pending', 'accepted', or 'rejected'
  Future<String?> getFriendshipStatus(String userId) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return null;

    try {
      final result = await supabase
          .from('friendships')
          .select('status')
          .eq('user_id', currentUserId)
          .eq('friend_id', userId)
          .maybeSingle();

      return result?['status'] as String?;
    } catch (e) {
      return null;
    }
  }
}

/// Provider for FriendRepository
final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return FriendRepository(ref.watch(supabaseProvider));
});

/// Provider for friends list
final friendsListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(friendRepositoryProvider);
  return repo.getFriends();
});

/// Provider for pending friend requests
final pendingRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(friendRepositoryProvider);
  return repo.getPendingRequests();
});

/// Provider for friend count
final friendCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(friendRepositoryProvider);
  return repo.getFriendCount();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Repository for profile-related operations
/// Handles username validation, onboarding, and profile data
class ProfileRepository {
  ProfileRepository(this.supabase);

  final SupabaseClient supabase;

  /// Check if a username is available (not already taken)
  /// Returns true if username is available, false if taken
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      print('🔍 Checking username availability: "$username", currentUser: $currentUserId');

      // Use ilike for case-insensitive comparison
      // This ensures "User" and "user" are treated as the same username
      var query = supabase
          .from('profiles')
          .select('id, username')
          .ilike('username', username);

      // If checking for current user, exclude their own profile
      // This allows users to keep their existing username when updating profile
      if (currentUserId != null) {
        query = query.neq('id', currentUserId);
      }

      final result = await query.maybeSingle();

      print('🔍 Query result: $result');
      print('🔍 Username available: ${result == null}');

      // null means no other user found with this username = available
      return result == null;
    } catch (e) {
      // If there's an error, assume unavailable for safety
      print('❌ Error checking username: $e');
      throw Exception('Failed to check username availability: $e');
    }
  }

  /// Update the current user's username
  /// Throws an exception if username is already taken or invalid
  Future<void> updateUsername(String username) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Not authenticated');
    }

    try {
      await supabase
          .from('profiles')
          .update({'username': username})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update username: $e');
    }
  }

  /// Mark user's onboarding as completed
  Future<void> completeOnboarding() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Not authenticated');
    }

    try {
      await supabase
          .from('profiles')
          .update({'onboarding_completed': true})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to complete onboarding: $e');
    }
  }

  /// Get a user's profile by user ID
  /// Returns null if profile not found
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      return await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  /// Get current user's profile
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    return getProfile(userId);
  }
}

/// Provider for ProfileRepository
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseProvider));
});

/// Provider for current user's profile
/// Watches auth state and fetches profile when authenticated
final currentProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(authProvider).valueOrNull;
  if (session == null) return null;

  final repo = ref.read(profileRepositoryProvider);
  return repo.getProfile(session.user.id);
});

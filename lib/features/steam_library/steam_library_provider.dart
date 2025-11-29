import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_repository.dart';
import '../../data/steam_library_sync_service.dart';
import '../../data/supabase_client.dart';
import '../../models/game_log.dart';

/// Provider for Steam library games
/// Fetches all Steam-sourced games sorted by playtime
final steamLibraryProvider = FutureProvider<List<GameLog>>((ref) async {
  final userId = ref.watch(supabaseProvider).auth.currentUser?.id;
  if (userId == null) return [];

  final repo = ref.read(gameRepositoryProvider);
  return repo.fetchSteamLibrary(userId);
});

/// Provider for Steam library sync
/// Triggers a full library sync when called
final steamLibrarySyncProvider =
    FutureProvider.family<SyncResult, String>((ref, steamId) async {
  final userId = ref.watch(supabaseProvider).auth.currentUser?.id;
  if (userId == null) {
    throw Exception('User not authenticated');
  }

  final syncService = ref.read(steamLibrarySyncServiceProvider);
  return syncService.syncFullLibrary(userId, steamId);
});

/// Provider for Steam wishlist sync
/// Fetches Steam wishlist and imports to collection wishlist
final steamWishlistSyncProvider =
    FutureProvider.family<SyncResult, String>((ref, steamId) async {
  final userId = ref.watch(supabaseProvider).auth.currentUser?.id;
  if (userId == null) {
    throw Exception('User not authenticated');
  }

  final syncService = ref.read(steamLibrarySyncServiceProvider);
  return syncService.syncWishlist(userId, steamId);
});

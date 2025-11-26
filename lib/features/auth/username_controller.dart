import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_repository.dart';

/// State notifier for username selection flow
class UsernameController extends StateNotifier<AsyncValue<void>> {
  UsernameController(this.ref) : super(const AsyncData(null));

  final Ref ref;

  /// Validate username format and availability
  /// Returns null if valid, error message if invalid
  Future<String?> validateUsername(String username) async {
    // Client-side validation
    if (username.isEmpty) {
      return 'Kullanıcı adı gerekli';
    }

    if (username.length < 3) {
      return 'En az 3 karakter olmalı';
    }

    if (username.length > 20) {
      return 'En fazla 20 karakter olmalı';
    }

    // Check format: alphanumeric + underscore only
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Sadece harf, rakam ve alt çizgi (_) kullanılabilir';
    }

    // Server-side uniqueness check
    try {
      final repo = ref.read(profileRepositoryProvider);
      final isAvailable = await repo.isUsernameAvailable(username);

      if (!isAvailable) {
        return 'Bu kullanıcı adı alınmış';
      }

      return null; // Valid username
    } catch (e) {
      return 'Kontrol edilemedi, tekrar deneyin';
    }
  }

  /// Save username to database
  Future<void> saveUsername(String username) async {
    state = const AsyncLoading();

    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateUsername(username);
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }
}

/// Provider for username controller
final usernameControllerProvider =
    StateNotifierProvider<UsernameController, AsyncValue<void>>((ref) {
  return UsernameController(ref);
});

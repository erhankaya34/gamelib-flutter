import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger.dart';
import '../../data/supabase_client.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this.ref) : super(const AsyncData(null));

  final Ref ref;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      appLogger.info('Auth: sign in attempt for $email');
      try {
        await ref.read(supabaseProvider).auth.signInWithPassword(
              email: email,
              password: password,
            );
        appLogger.info('Auth: sign in success for $email');
      } catch (error, stackTrace) {
        appLogger.error('Auth: sign in failed for $email', error, stackTrace);
        rethrow;
      }
    });
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      appLogger.info('Auth: register attempt for $email');
      try {
        await ref.read(supabaseProvider).auth.signUp(
              email: email,
              password: password,
            );
        appLogger.info('Auth: register success for $email');
      } catch (error, stackTrace) {
        appLogger.error('Auth: register failed for $email', error, stackTrace);
        rethrow;
      }
    });
  }

  Future<void> signOut() async {
    appLogger.info('Auth: sign out');
    try {
      await ref.read(supabaseProvider).auth.signOut();
      appLogger.info('Auth: sign out success');
    } catch (error, stackTrace) {
      appLogger.error('Auth: sign out failed', error, stackTrace);
      rethrow;
    }
  }
}

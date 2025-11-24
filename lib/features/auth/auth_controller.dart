import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger.dart';
import '../../data/supabase_client.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this.ref) : super(const AsyncData(null));

  final Ref ref;

  String _friendlyMessage(Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        return 'E-posta veya şifre hatalı.';
      }
      if (msg.contains('user already registered')) {
        return 'Bu e-posta ile zaten bir hesap var.';
      }
      if (msg.contains('email not confirmed')) {
        return 'E-posta doğrulanmamış. Gelen kutunu kontrol et.';
      }
      if (msg.contains('invalid email') || msg.contains('email format')) {
        return 'Geçerli bir e-posta adresi girin.';
      }
      if (msg.contains('password')) {
        return 'Şifreyle ilgili bir sorun var. Tekrar deneyin.';
      }
      return error.message;
    }
    if (error is AuthRetryableFetchException) {
      return 'Bağlantı hatası. İnternetinizi kontrol edip tekrar deneyin.';
    }
    return 'İşlem başarısız. Lütfen bilgileri kontrol edin ve tekrar deneyin.';
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      appLogger.info('Auth: sign in attempt for $email');
      await ref.read(supabaseProvider).auth.signInWithPassword(
            email: email,
            password: password,
          );
      appLogger.info('Auth: sign in success for $email');
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      final message = _friendlyMessage(error);
      appLogger.error('Auth: sign in failed for $email', error, stackTrace);
      state = AsyncError(AuthFailure(message), stackTrace);
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      appLogger.info('Auth: register attempt for $email');
      await ref.read(supabaseProvider).auth.signUp(
            email: email,
            password: password,
          );
      appLogger.info('Auth: register success for $email');
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      final message = _friendlyMessage(error);
      appLogger.error('Auth: register failed for $email', error, stackTrace);
      state = AsyncError(AuthFailure(message), stackTrace);
    }
  }

  Future<void> signOut() async {
    appLogger.info('Auth: sign out');
    try {
      await ref.read(supabaseProvider).auth.signOut();
      appLogger.info('Auth: sign out success');
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      appLogger.error('Auth: sign out failed', error, stackTrace);
      state = AsyncError(AuthFailure(_friendlyMessage(error)), stackTrace);
    }
  }
}

class AuthFailure {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

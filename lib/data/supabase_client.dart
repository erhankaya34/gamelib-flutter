import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logger.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authProvider = StreamProvider<Session?>((ref) {
  final supabase = ref.watch(supabaseProvider);

  Stream<Session?> authChanges() async* {
    final initial = supabase.auth.currentSession;
    appLogger.info(
      'Auth: initial session ${initial?.user.id ?? 'none'}',
    );
    yield initial;

    await for (final event in supabase.auth.onAuthStateChange) {
      appLogger.info(
        'Auth: state change ${event.event.name}, session ${event.session?.user.id ?? 'none'}',
      );
      yield event.session;
    }
  }

  return authChanges();
});

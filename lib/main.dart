import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell.dart';
import 'core/logger.dart';
import 'core/theme.dart';
import 'core/utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final url = supabaseUrl;
  final anonKey = supabaseAnonKey;

  appLogger.info('Supabase env: url=$url, anonKey=${maskKey(anonKey)}');

  if (url.isEmpty || anonKey.isEmpty) {
    throw StateError('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
  }
  if (!isValidSupabaseUrl(url)) {
    throw StateError(
      'Invalid SUPABASE_URL "$url". Copy the Project URL from Supabase Settings → API (format: https://<project-ref>.supabase.co).',
    );
  }

  await Supabase.initialize(
    url: url,
    anonKey: anonKey,
  );

  runApp(const ProviderScope(child: GameLibApp()));
}

class GameLibApp extends ConsumerWidget {
  const GameLibApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'GameLib',
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

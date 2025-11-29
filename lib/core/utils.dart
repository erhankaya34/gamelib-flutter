import 'package:flutter_dotenv/flutter_dotenv.dart';

String get supabaseUrl => sanitizeSupabaseUrl(dotenv.env['SUPABASE_URL']);
String get supabaseAnonKey => (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

String get igdbClientId => (dotenv.env['IGDB_CLIENT_ID'] ?? '').trim();
String get igdbAccessToken => (dotenv.env['IGDB_ACCESS_TOKEN'] ?? '').trim();

String get steamApiKey => (dotenv.env['STEAM_API_KEY'] ?? '').trim();

const double pagePadding = 16.0;

String sanitizeSupabaseUrl(String? raw) {
  final trimmed = (raw ?? '').trim().replaceAll(RegExp(r'/+$'), '');
  return trimmed;
}

bool isValidSupabaseUrl(String url) {
  final pattern = RegExp(r'^https:\/\/[a-zA-Z0-9\-]+\.supabase\.co$');
  return pattern.hasMatch(url);
}

String maskKey(String key) {
  final cleaned = key.trim();
  if (cleaned.length <= 8) return '***';
  return '${cleaned.substring(0, 4)}...${cleaned.substring(cleaned.length - 4)}';
}

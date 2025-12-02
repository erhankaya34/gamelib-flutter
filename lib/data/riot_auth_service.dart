import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/logger.dart';
import '../core/utils.dart';

/// Provider for RiotAuthService
final riotAuthServiceProvider = Provider<RiotAuthService>((ref) {
  return RiotAuthService();
});

/// Riot Games RSO (Riot Sign On) OAuth tokens
class RiotTokens {
  const RiotTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;

  factory RiotTokens.fromJson(Map<String, dynamic> json) {
    return RiotTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
      tokenType: json['token_type'] as String,
    );
  }
}

/// Riot Account information
class RiotAccount {
  const RiotAccount({
    required this.puuid,
    required this.gameName,
    required this.tagLine,
  });

  final String puuid;
  final String gameName;
  final String tagLine;

  /// Full Riot ID (gameName#tagLine)
  String get riotId => '$gameName#$tagLine';

  factory RiotAccount.fromJson(Map<String, dynamic> json) {
    return RiotAccount(
      puuid: json['puuid'] as String,
      gameName: json['gameName'] as String,
      tagLine: json['tagLine'] as String,
    );
  }
}

/// Service for handling Riot Sign On (RSO) OAuth2 authentication
class RiotAuthService {
  // RSO OAuth2 endpoints
  static const _authUrl = 'https://auth.riotgames.com/authorize';
  static const _tokenUrl = 'https://auth.riotgames.com/token';
  static const _accountUrl = 'https://americas.api.riotgames.com/riot/account/v1/accounts/me';

  // Deep link scheme for this app
  static const _redirectScheme = 'gamelib';

  // Supabase Edge Function URL (exchanges code and redirects to app)
  String get _redirectUri => '$supabaseUrl/functions/v1/riot-callback';

  // Required scopes for full access
  // openid: Required for OAuth
  // offline_access: For refresh tokens
  // cpid: Current platform ID (to determine region)
  static const _scopes = 'openid offline_access cpid';

  /// Start RSO OAuth flow
  /// Opens browser with Riot login page
  Future<void> startRiotAuth() async {
    appLogger.info('Riot Auth: Starting RSO OAuth flow');

    // Build RSO authorization URL
    // Note: client_id will be added by the Edge Function
    final params = {
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope': _scopes,
    };

    // The actual URL will go through our Edge Function which adds client_id
    final uri = Uri.parse('$supabaseUrl/functions/v1/riot-auth-start').replace(
      queryParameters: params,
    );

    appLogger.info('Riot Auth: Opening URL: $uri');

    // Launch browser
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      appLogger.info('Riot Auth: Browser launched');
    } else {
      appLogger.error('Riot Auth: Could not launch URL');
      throw Exception('Could not open Riot login page');
    }
  }

  /// Parse Riot account info from OAuth callback URI
  /// Returns RiotAccount if successful, null otherwise
  RiotAccount? parseAccountFromCallback(Uri callbackUri) {
    appLogger.info('Riot Auth: Parsing callback URI: $callbackUri');

    try {
      final puuid = callbackUri.queryParameters['puuid'];
      final gameName = callbackUri.queryParameters['game_name'];
      final tagLine = callbackUri.queryParameters['tag_line'];

      if (puuid == null || gameName == null || tagLine == null) {
        appLogger.warning('Riot Auth: Missing account info in callback');
        return null;
      }

      final account = RiotAccount(
        puuid: puuid,
        gameName: gameName,
        tagLine: tagLine,
      );

      appLogger.info('Riot Auth: Successfully parsed account: ${account.riotId}');
      return account;
    } catch (e, stack) {
      appLogger.error('Riot Auth: Error parsing callback', e, stack);
      return null;
    }
  }

  /// Parse tokens from OAuth callback URI
  /// Returns RiotTokens if successful, null otherwise
  RiotTokens? parseTokensFromCallback(Uri callbackUri) {
    appLogger.info('Riot Auth: Parsing tokens from callback');

    try {
      final accessToken = callbackUri.queryParameters['access_token'];
      final refreshToken = callbackUri.queryParameters['refresh_token'];
      final expiresIn = callbackUri.queryParameters['expires_in'];

      if (accessToken == null || refreshToken == null) {
        appLogger.warning('Riot Auth: Missing tokens in callback');
        return null;
      }

      return RiotTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: int.tryParse(expiresIn ?? '3600') ?? 3600,
        tokenType: 'Bearer',
      );
    } catch (e, stack) {
      appLogger.error('Riot Auth: Error parsing tokens', e, stack);
      return null;
    }
  }

  /// Get redirect scheme for configuration
  static String get redirectScheme => _redirectScheme;
}

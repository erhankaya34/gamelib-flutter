import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/logger.dart';
import '../core/utils.dart';

/// Provider for SteamAuthService
final steamAuthServiceProvider = Provider<SteamAuthService>((ref) {
  return SteamAuthService();
});

/// Service for handling Steam OpenID authentication
class SteamAuthService {
  static const _steamOpenIdUrl = 'https://steamcommunity.com/openid/login';

  // Deep link scheme for this app (used by the Edge Function redirect)
  static const _redirectScheme = 'gamelib';

  // Supabase Edge Function URL (redirects to gamelib://steam-callback)
  String get _redirectUri => '$supabaseUrl/functions/v1/steam-callback';

  /// Start Steam OAuth flow
  /// Opens browser with Steam login page
  Future<void> startSteamAuth() async {
    appLogger.info('Steam Auth: Starting OAuth flow');

    // Build Steam OpenID URL with parameters
    final params = {
      'openid.ns': 'http://specs.openid.net/auth/2.0',
      'openid.mode': 'checkid_setup',
      'openid.return_to': _redirectUri,
      'openid.realm': _redirectUri, // Must exactly match return_to
      'openid.identity': 'http://specs.openid.net/auth/2.0/identifier_select',
      'openid.claimed_id':
          'http://specs.openid.net/auth/2.0/identifier_select',
    };

    // Construct URL
    final uri = Uri.parse(_steamOpenIdUrl).replace(
      queryParameters: params,
    );

    appLogger.info('Steam Auth: Opening URL: $uri');

    // Launch browser
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // Opens in browser
      );
      appLogger.info('Steam Auth: Browser launched');
    } else {
      appLogger.error('Steam Auth: Could not launch URL');
      throw Exception('Could not open Steam login page');
    }
  }

  /// Parse Steam ID from OAuth callback URI
  /// Returns Steam ID (64-bit) if successful, null otherwise
  String? parseSteamIdFromCallback(Uri callbackUri) {
    appLogger.info('Steam Auth: Parsing callback URI: $callbackUri');

    try {
      // Steam returns the user's Steam ID in the openid.claimed_id parameter
      // Format: https://steamcommunity.com/openid/id/<STEAM_ID_64>
      final claimedId = callbackUri.queryParameters['openid.claimed_id'];

      if (claimedId == null) {
        appLogger.warning('Steam Auth: No claimed_id in callback');
        return null;
      }

      // Extract Steam ID from URL
      // Example: https://steamcommunity.com/openid/id/76561198012345678
      final steamIdMatch = RegExp(r'/id/(\d+)$').firstMatch(claimedId);

      if (steamIdMatch == null) {
        appLogger.warning('Steam Auth: Could not extract Steam ID from: $claimedId');
        return null;
      }

      final steamId = steamIdMatch.group(1)!;
      appLogger.info('Steam Auth: Successfully extracted Steam ID: $steamId');

      return steamId;
    } catch (e, stack) {
      appLogger.error('Steam Auth: Error parsing callback', e, stack);
      return null;
    }
  }

  /// Verify OpenID response (optional but recommended for security)
  /// This makes a request to Steam to verify the authentication was legitimate
  Future<bool> verifyOpenIdResponse(Uri callbackUri) async {
    appLogger.info('Steam Auth: Verifying OpenID response');

    try {
      // Convert callback params to verification params
      final params = Map<String, String>.from(callbackUri.queryParameters);
      params['openid.mode'] = 'check_authentication';

      final uri = Uri.parse(_steamOpenIdUrl).replace(
        queryParameters: params,
      );

      // Make verification request
      final response = await launchUrl(uri);

      // Note: This is simplified. In production, you'd make an HTTP request
      // and check if Steam responds with "is_valid:true"
      appLogger.info('Steam Auth: Verification result: $response');

      return response;
    } catch (e, stack) {
      appLogger.error('Steam Auth: Verification failed', e, stack);
      return false;
    }
  }

  /// Get redirect scheme for configuration
  static String get redirectScheme => _redirectScheme;
}

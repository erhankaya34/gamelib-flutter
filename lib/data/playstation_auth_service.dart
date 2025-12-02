import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/logger.dart';

/// Provider for PlayStationAuthService
final playstationAuthServiceProvider = Provider<PlayStationAuthService>((ref) {
  return PlayStationAuthService();
});

/// Authentication tokens for PSN API
class PSNAuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final DateTime obtainedAt;

  PSNAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.obtainedAt,
  });

  bool get isExpired {
    final expiry = obtainedAt.add(Duration(seconds: expiresIn));
    return DateTime.now().isAfter(expiry);
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_in': expiresIn,
        'obtained_at': obtainedAt.toIso8601String(),
      };

  factory PSNAuthTokens.fromJson(Map<String, dynamic> json) => PSNAuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresIn: json['expires_in'] as int,
        obtainedAt: DateTime.parse(json['obtained_at'] as String),
      );
}

/// Service for handling PlayStation Network authentication
/// Uses reverse-engineered PSN API (similar to psn-api npm package)
class PlayStationAuthService {
  static const _authBaseUrl = 'https://ca.account.sony.com/api';
  static const _npssoUrl = '$_authBaseUrl/v1/ssocookie';

  // OAuth endpoints
  static const _authorizationUrl =
      'https://ca.account.sony.com/api/authz/v3/oauth/authorize';
  static const _tokenUrl = 'https://ca.account.sony.com/api/authz/v3/oauth/token';

  // Client credentials (from PSNAWP - PlayStation Network API Wrapper)
  static const _clientId = '09515159-7237-4370-9b40-3806e67c0891';
  // Basic auth header: base64(clientId:clientSecret)
  static const _basicAuth = 'MDk1MTUxNTktNzIzNy00MzcwLTliNDAtMzgwNmU2N2MwODkxOnVjUGprYTV0bnRCMktxc1A=';
  static const _scope = 'psn:mobile.v2.core psn:clientapp';

  // URLs for WebView login
  static const loginUrl = 'https://my.playstation.com/signin';
  static const accountUrl = 'https://my.playstation.com';

  /// URL to get NPSSO token after login
  static const npssoTokenUrl = 'https://ca.account.sony.com/api/v1/ssocookie';

  /// Exchange NPSSO token for access code
  Future<String?> exchangeNpssoForAccessCode(String npsso) async {
    appLogger.info('PSN Auth: Exchanging NPSSO for access code');

    try {
      final params = {
        'access_type': 'offline',
        'client_id': _clientId,
        'redirect_uri': 'com.scee.psxandroid.scecompcall://redirect',
        'response_type': 'code',
        'scope': _scope,
      };

      final uri = Uri.parse(_authorizationUrl).replace(queryParameters: params);

      // Use HttpClient to prevent auto-redirect following
      final httpClient = HttpClient();
      httpClient.autoUncompress = false;

      final request = await httpClient.getUrl(uri);
      request.headers.set('Cookie', 'npsso=$npsso');
      request.followRedirects = false;

      final response = await request.close();

      appLogger.info('PSN Auth: Authorization response status: ${response.statusCode}');

      // Check for redirect (302 or 303)
      if (response.statusCode == 302 || response.statusCode == 303) {
        final location = response.headers.value('location');
        appLogger.info('PSN Auth: Redirect location: $location');

        if (location != null) {
          // Parse the redirect URI to extract the code
          // URI looks like: com.scee.psxandroid.scecompcall://redirect/?code=xxx&cid=yyy
          final codeMatch = RegExp(r'code=([^&]+)').firstMatch(location);
          if (codeMatch != null) {
            final code = codeMatch.group(1);
            appLogger.info('PSN Auth: Got access code from redirect');
            httpClient.close();
            return code;
          }
        }
      }

      // Read response body for error info
      final body = await response.transform(utf8.decoder).join();
      appLogger.warning('PSN Auth: Could not get access code. Response: $body');
      httpClient.close();
      return null;
    } catch (e, stack) {
      appLogger.error('PSN Auth: Error exchanging NPSSO', e, stack);
      return null;
    }
  }

  /// Exchange access code for auth tokens
  Future<PSNAuthTokens?> exchangeCodeForTokens(String accessCode) async {
    appLogger.info('PSN Auth: Exchanging access code for tokens');

    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic $_basicAuth',
        },
        body: {
          'code': accessCode,
          'grant_type': 'authorization_code',
          'redirect_uri': 'com.scee.psxandroid.scecompcall://redirect',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        appLogger.info('PSN Auth: Got tokens successfully');

        return PSNAuthTokens(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
          expiresIn: data['expires_in'] as int,
          obtainedAt: DateTime.now(),
        );
      }

      appLogger.warning('PSN Auth: Token exchange failed: ${response.body}');
      return null;
    } catch (e, stack) {
      appLogger.error('PSN Auth: Error exchanging code for tokens', e, stack);
      return null;
    }
  }

  /// Refresh access token using refresh token
  Future<PSNAuthTokens?> refreshTokens(String refreshToken) async {
    appLogger.info('PSN Auth: Refreshing tokens');

    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic $_basicAuth',
        },
        body: {
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
          'scope': _scope,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        appLogger.info('PSN Auth: Tokens refreshed successfully');

        return PSNAuthTokens(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
          expiresIn: data['expires_in'] as int,
          obtainedAt: DateTime.now(),
        );
      }

      appLogger.warning('PSN Auth: Token refresh failed: ${response.body}');
      return null;
    } catch (e, stack) {
      appLogger.error('PSN Auth: Error refreshing tokens', e, stack);
      return null;
    }
  }

  /// Complete authentication flow from NPSSO
  Future<PSNAuthTokens?> authenticateWithNpsso(String npsso) async {
    appLogger.info('PSN Auth: Starting full authentication with NPSSO');

    // Step 1: Exchange NPSSO for access code
    final accessCode = await exchangeNpssoForAccessCode(npsso);
    if (accessCode == null) {
      appLogger.error('PSN Auth: Failed to get access code');
      return null;
    }

    // Step 2: Exchange access code for tokens
    final tokens = await exchangeCodeForTokens(accessCode);
    if (tokens == null) {
      appLogger.error('PSN Auth: Failed to get tokens');
      return null;
    }

    appLogger.info('PSN Auth: Authentication successful');
    return tokens;
  }
}

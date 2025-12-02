import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger.dart';
import 'profile_repository.dart';
import 'riot_auth_service.dart';

/// Provider for Riot callback handler
final riotCallbackHandlerProvider = Provider<RiotCallbackHandler>((ref) {
  return RiotCallbackHandler(ref);
});

/// Handles Riot Games RSO OAuth callback deep links
class RiotCallbackHandler {
  RiotCallbackHandler(this._ref) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<Uri>? _sub;
  final _appLinks = AppLinks();

  // Callbacks for success/error
  void Function(RiotAccount account)? onAccountReceived;
  void Function(String error)? onError;

  /// Initialize deep link listener
  void _init() {
    appLogger.info('Riot Callback Handler: Initializing');

    // Listen for incoming deep links
    _sub = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (err) {
        appLogger.error('Riot Callback Handler: Stream error', err);
        onError?.call('Deep link hatası: $err');
      },
    );
  }

  /// Handle incoming deep link
  Future<void> _handleDeepLink(Uri uri) async {
    appLogger.info('Riot Callback Handler: Received deep link: $uri');

    // Check if this is a Riot callback
    if (uri.scheme != RiotAuthService.redirectScheme ||
        uri.host != 'riot-callback') {
      appLogger.info('Riot Callback Handler: Not a Riot callback, ignoring');
      return;
    }

    // Check for error in callback
    final error = uri.queryParameters['error'];
    if (error != null) {
      final errorDesc = uri.queryParameters['error_description'] ?? error;
      appLogger.error('Riot Callback Handler: OAuth error: $errorDesc');
      onError?.call('Riot bağlantı hatası: $errorDesc');
      return;
    }

    try {
      // Parse account info from callback
      final riotAuthService = _ref.read(riotAuthServiceProvider);
      final account = riotAuthService.parseAccountFromCallback(uri);

      if (account == null) {
        appLogger.error('Riot Callback Handler: Could not parse account info');
        onError?.call('Riot hesap bilgisi alınamadı');
        return;
      }

      // Parse tokens from callback
      final tokens = riotAuthService.parseTokensFromCallback(uri);
      if (tokens == null) {
        appLogger.error('Riot Callback Handler: Could not parse tokens');
        onError?.call('Riot token bilgisi alınamadı');
        return;
      }

      appLogger.info('Riot Callback Handler: Successfully received account: ${account.riotId}');

      // Save to profile
      final profileRepo = _ref.read(profileRepositoryProvider);
      await profileRepo.linkRiotAccount(
        puuid: account.puuid,
        gameName: account.gameName,
        tagLine: account.tagLine,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      appLogger.info('Riot Callback Handler: Riot account linked successfully');

      // Notify success
      onAccountReceived?.call(account);
    } catch (e, stack) {
      appLogger.error('Riot Callback Handler: Error processing callback', e, stack);
      onError?.call('Riot bağlantı hatası: $e');
    }
  }

  /// Check for initial deep link (when app is opened from deep link)
  Future<void> checkInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        appLogger.info('Riot Callback Handler: Initial link found: $uri');
        await _handleDeepLink(uri);
      }
    } catch (e) {
      appLogger.error('Riot Callback Handler: Error checking initial link', e);
    }
  }

  /// Dispose resources
  void dispose() {
    _sub?.cancel();
  }
}

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger.dart';
import 'profile_repository.dart';
import 'steam_auth_service.dart';
import 'steam_service.dart';

/// Provider for Steam callback handler
final steamCallbackHandlerProvider = Provider<SteamCallbackHandler>((ref) {
  return SteamCallbackHandler(ref);
});

/// Handles Steam OAuth callback deep links
class SteamCallbackHandler {
  SteamCallbackHandler(this._ref) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<Uri>? _sub;
  final _appLinks = AppLinks();

  // Callback for when Steam ID is successfully retrieved
  void Function(String steamId)? onSteamIdReceived;
  void Function(String error)? onError;

  /// Initialize deep link listener
  void _init() {
    appLogger.info('Steam Callback Handler: Initializing');

    // Listen for incoming deep links
    _sub = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (err) {
        appLogger.error('Steam Callback Handler: Stream error', err);
        onError?.call('Deep link hatası: $err');
      },
    );
  }

  /// Handle incoming deep link
  Future<void> _handleDeepLink(Uri uri) async {
    appLogger.info('Steam Callback Handler: Received deep link: $uri');

    // Check if this is a Steam callback
    if (uri.scheme != SteamAuthService.redirectScheme ||
        uri.host != 'steam-callback') {
      appLogger.info('Steam Callback Handler: Not a Steam callback, ignoring');
      return;
    }

    try {
      // Parse Steam ID from callback
      final steamAuthService = _ref.read(steamAuthServiceProvider);
      final steamId = steamAuthService.parseSteamIdFromCallback(uri);

      if (steamId == null) {
        appLogger.error('Steam Callback Handler: Could not parse Steam ID');
        onError?.call('Steam ID alınamadı');
        return;
      }

      appLogger.info('Steam Callback Handler: Successfully received Steam ID: $steamId');

      // Fetch Steam user data
      final steamService = _ref.read(steamServiceProvider);
      final userData = await steamService.fetchUserData(steamId);

      // Save to profile
      final profileRepo = _ref.read(profileRepositoryProvider);
      await profileRepo.linkSteamAccount(steamId, userData.toJson());

      appLogger.info('Steam Callback Handler: Steam account linked successfully');

      // Notify success
      onSteamIdReceived?.call(steamId);
    } catch (e, stack) {
      appLogger.error('Steam Callback Handler: Error processing callback', e, stack);
      onError?.call('Steam bağlantı hatası: $e');
    }
  }

  /// Check for initial deep link (when app is opened from deep link)
  Future<void> checkInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        appLogger.info('Steam Callback Handler: Initial link found: $uri');
        await _handleDeepLink(uri);
      }
    } catch (e) {
      appLogger.error('Steam Callback Handler: Error checking initial link', e);
    }
  }

  /// Dispose resources
  void dispose() {
    _sub?.cancel();
  }
}

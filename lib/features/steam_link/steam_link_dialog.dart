import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger.dart';
import '../../core/theme.dart';
import '../../data/profile_repository.dart';
import '../../data/steam_auth_service.dart';
import '../../data/steam_callback_handler.dart';
import '../../data/steam_library_sync_service.dart';
import '../library/library_controller.dart';

/// Global function to show Steam link dialog from anywhere
void showSteamLinkDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => const SteamLinkDialog(),
  );
}

/// Steam link dialog - Uses OAuth flow
class SteamLinkDialog extends ConsumerStatefulWidget {
  const SteamLinkDialog({super.key});

  @override
  ConsumerState<SteamLinkDialog> createState() => _SteamLinkDialogState();
}

class _SteamLinkDialogState extends ConsumerState<SteamLinkDialog> {
  bool _isLinking = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _setupCallbackHandler();
  }

  void _setupCallbackHandler() {
    final callbackHandler = ref.read(steamCallbackHandlerProvider);

    // Set callback for successful Steam ID retrieval
    callbackHandler.onSteamIdReceived = (steamId) async {
      if (mounted) {
        setState(() => _statusMessage = 'Steam kütüphanesi senkronize ediliyor...');

        try {
          // Trigger Steam library sync
          appLogger.info('Steam Link Dialog: Starting library sync for Steam ID: $steamId');
          final syncService = ref.read(steamLibrarySyncServiceProvider);
          final userId = ref.read(currentProfileProvider).value?['id'] as String?;

          if (userId != null) {
            final result = await syncService.syncFullLibrary(userId, steamId);
            appLogger.info('Steam Link Dialog: Sync completed - $result');

            // Refresh library to show new games
            ref.invalidate(libraryControllerProvider);
            ref.invalidate(currentProfileProvider);

            setState(() => _isLinking = false);

            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Steam hesabı bağlandı! ${result.imported} oyun eklendi.',
                ),
                backgroundColor: AppTheme.mint,
              ),
            );
          } else {
            throw Exception('Kullanıcı ID bulunamadı');
          }
        } catch (e, stack) {
          appLogger.error('Steam Link Dialog: Failed to sync library', e, stack);

          // Still show success for account link, but warn about sync
          setState(() => _isLinking = false);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Steam hesabı bağlandı, ancak kütüphane senkronizasyonu başarısız: $e'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    };

    // Set callback for errors
    callbackHandler.onError = (error) {
      if (mounted) {
        setState(() {
          _isLinking = false;
          _statusMessage = error;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      }
    };
  }

  Future<void> _startSteamOAuth() async {
    setState(() {
      _isLinking = true;
      _statusMessage = 'Steam\'e yönlendiriliyor...';
    });

    try {
      final steamAuthService = ref.read(steamAuthServiceProvider);
      await steamAuthService.startSteamAuth();

      if (mounted) {
        setState(() {
          _statusMessage = 'Steam\'de giriş yapın ve yetkilendirin';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
          _statusMessage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Steam OAuth başlatılamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.slate,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1b2838), Color(0xFF2a475e)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF66C0F4),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.videogame_asset_rounded,
              color: Color(0xFF66C0F4),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Steam ile Bağlan',
            style: TextStyle(color: AppTheme.cream),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Steam hesabınızla güvenli bir şekilde bağlanın.',
            style: TextStyle(
              color: AppTheme.lavenderGray,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.deepNavy,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF66C0F4).withOpacity(0.3),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.mint, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Güvenli Steam OAuth',
                      style: TextStyle(
                        color: AppTheme.cream,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• Şifrenizi paylaşmanıza gerek yok\n'
                  '• Steam profiliniz otomatik alınır\n'
                  '• Oyun kütüphaneniz senkronize edilir',
                  style: TextStyle(
                    color: AppTheme.lavenderGray,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lavender.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (_isLinking)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppTheme.lavender),
                      ),
                    )
                  else
                    const Icon(Icons.info_outline, color: AppTheme.lavender, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: const TextStyle(
                        color: AppTheme.lavender,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLinking ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          onPressed: _isLinking ? null : _startSteamOAuth,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF66C0F4),
            foregroundColor: const Color(0xFF1b2838),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          icon: const Icon(Icons.videogame_asset_rounded, size: 20),
          label: const Text(
            'Steam ile Bağlan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

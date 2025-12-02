import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger.dart';
import '../../core/theme.dart';
import '../../data/profile_repository.dart';
import '../../data/riot_auth_service.dart';
import '../../data/riot_callback_handler.dart';
import '../../data/riot_service.dart';
import '../library/library_controller.dart';

/// Riot Games brand colors
class RiotColors {
  static const Color red = Color(0xFFD32936);
  static const Color darkRed = Color(0xFF8B1721);
  static const Color black = Color(0xFF111111);
  static const Color white = Color(0xFFECECEC);
}

/// Global function to show Riot link dialog from anywhere
void showRiotLinkDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => const RiotLinkDialog(),
  );
}

/// Riot Games link dialog - Uses RSO OAuth flow or manual test mode
class RiotLinkDialog extends ConsumerStatefulWidget {
  const RiotLinkDialog({super.key});

  @override
  ConsumerState<RiotLinkDialog> createState() => _RiotLinkDialogState();
}

class _RiotLinkDialogState extends ConsumerState<RiotLinkDialog> {
  bool _isLinking = false;
  String? _statusMessage;
  bool _isTestMode = false;
  final _riotIdController = TextEditingController();
  final _regionController = TextEditingController(text: 'tr1');

  // Available regions for dropdown
  static const _regions = {
    'tr1': 'Türkiye',
    'euw1': 'Avrupa Batı',
    'eun1': 'Avrupa Kuzey & Doğu',
    'na1': 'Kuzey Amerika',
    'kr': 'Kore',
    'jp1': 'Japonya',
    'br1': 'Brezilya',
    'la1': 'Latin Amerika Kuzey',
    'la2': 'Latin Amerika Güney',
    'oc1': 'Okyanusya',
    'ru': 'Rusya',
  };

  @override
  void initState() {
    super.initState();
    _setupCallbackHandler();
  }

  @override
  void dispose() {
    _riotIdController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  void _setupCallbackHandler() {
    final callbackHandler = ref.read(riotCallbackHandlerProvider);

    // Set callback for successful account retrieval
    callbackHandler.onAccountReceived = (account) async {
      if (mounted) {
        setState(() => _statusMessage = 'Riot hesabı bağlandı: ${account.riotId}');

        try {
          appLogger.info('Riot Link Dialog: Account linked successfully: ${account.riotId}');

          // Refresh profile to show linked account
          ref.invalidate(libraryControllerProvider);
          ref.invalidate(currentProfileProvider);

          setState(() => _isLinking = false);

          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Riot hesabı bağlandı! ${account.riotId}',
              ),
              backgroundColor: RiotColors.red,
            ),
          );
        } catch (e, stack) {
          appLogger.error('Riot Link Dialog: Failed after linking', e, stack);

          setState(() => _isLinking = false);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Riot hesabı bağlandı, ancak bir hata oluştu: $e'),
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

  Future<void> _startRiotOAuth() async {
    setState(() {
      _isLinking = true;
      _statusMessage = 'Riot Games\'e yönlendiriliyor...';
    });

    try {
      final riotAuthService = ref.read(riotAuthServiceProvider);
      await riotAuthService.startRiotAuth();

      if (mounted) {
        setState(() {
          _statusMessage = 'Riot hesabınızla giriş yapın';
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
            content: Text('Riot OAuth başlatılamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Test mode: Link account using Riot ID (gameName#tagLine)
  Future<void> _linkWithRiotId() async {
    final riotId = _riotIdController.text.trim();
    final region = _regionController.text;

    if (!riotId.contains('#')) {
      setState(() => _statusMessage = 'Geçersiz format. Örnek: Faker#KR1');
      return;
    }

    final parts = riotId.split('#');
    final gameName = parts[0];
    final tagLine = parts[1];

    setState(() {
      _isLinking = true;
      _statusMessage = 'Riot hesabı aranıyor...';
    });

    try {
      // In test mode, we'll save the account without OAuth tokens
      // The API calls will use the development key from environment
      final profileRepo = ref.read(profileRepositoryProvider);

      // Generate a placeholder PUUID for test mode
      // In production, this would come from the OAuth flow
      final testPuuid = 'TEST_${gameName}_${tagLine}_${DateTime.now().millisecondsSinceEpoch}';

      await profileRepo.linkRiotAccount(
        puuid: testPuuid,
        gameName: gameName,
        tagLine: tagLine,
        accessToken: 'TEST_MODE',
        refreshToken: 'TEST_MODE',
        region: region,
      );

      appLogger.info('Riot Link Dialog: Test mode - Account linked: $gameName#$tagLine');

      // Refresh providers
      ref.invalidate(libraryControllerProvider);
      ref.invalidate(currentProfileProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test modu: $gameName#$tagLine bağlandı!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e, stack) {
      appLogger.error('Riot Link Dialog: Test mode failed', e, stack);
      if (mounted) {
        setState(() {
          _isLinking = false;
          _statusMessage = 'Hata: $e';
        });
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
                colors: [RiotColors.black, RiotColors.darkRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: RiotColors.red,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: RiotColors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isTestMode ? 'Test Modu' : 'Riot Games ile Bağlan',
              style: const TextStyle(color: AppTheme.cream),
            ),
          ),
          // Test mode toggle (only in debug mode)
          if (kDebugMode)
            IconButton(
              icon: Icon(
                _isTestMode ? Icons.science : Icons.science_outlined,
                color: _isTestMode ? Colors.orange : AppTheme.lavenderGray,
                size: 20,
              ),
              onPressed: () => setState(() => _isTestMode = !_isTestMode),
              tooltip: 'Test Modu',
            ),
        ],
      ),
      content: _isTestMode ? _buildTestModeContent() : _buildOAuthContent(),
      actions: [
        TextButton(
          onPressed: _isLinking ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        if (_isTestMode)
          FilledButton.icon(
            onPressed: _isLinking ? null : _linkWithRiotId,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            icon: const Icon(Icons.science, size: 20),
            label: const Text(
              'Test Bağla',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          )
        else
          FilledButton.icon(
            onPressed: _isLinking ? null : _startRiotOAuth,
            style: FilledButton.styleFrom(
              backgroundColor: RiotColors.red,
              foregroundColor: RiotColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            icon: const Icon(Icons.sports_esports_rounded, size: 20),
            label: const Text(
              'Riot ile Bağlan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
      ],
    );
  }

  Widget _buildTestModeContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Test modu - OAuth olmadan hesap bağlama.\nSadece geliştirme için kullanın.',
                  style: TextStyle(color: Colors.orange, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _riotIdController,
          style: const TextStyle(color: AppTheme.cream),
          decoration: InputDecoration(
            labelText: 'Riot ID',
            hintText: 'Örnek: Faker#KR1',
            hintStyle: TextStyle(color: AppTheme.lavenderGray.withOpacity(0.5)),
            labelStyle: const TextStyle(color: AppTheme.lavenderGray),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.lavenderGray.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.orange),
            ),
            prefixIcon: const Icon(Icons.person, color: AppTheme.lavenderGray),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _regionController.text,
          dropdownColor: AppTheme.slate,
          style: const TextStyle(color: AppTheme.cream),
          decoration: InputDecoration(
            labelText: 'Bölge',
            labelStyle: const TextStyle(color: AppTheme.lavenderGray),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.lavenderGray.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.orange),
            ),
            prefixIcon: const Icon(Icons.public, color: AppTheme.lavenderGray),
          ),
          items: _regions.entries.map((e) {
            return DropdownMenuItem(
              value: e.key,
              child: Text(e.value),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              _regionController.text = value;
            }
          },
        ),
        const SizedBox(height: 12),
        // Game badges
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GameBadge(label: 'LoL', color: const Color(0xFF0AC8B9)),
            const SizedBox(width: 8),
            _GameBadge(label: 'VAL', color: RiotColors.red),
            const SizedBox(width: 8),
            _GameBadge(label: 'TFT', color: const Color(0xFFCDA65E)),
          ],
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RiotColors.red.withOpacity(0.1),
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
                      valueColor: AlwaysStoppedAnimation(Colors.orange),
                    ),
                  )
                else
                  const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOAuthContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Riot hesabınızla güvenli bir şekilde bağlanın.',
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
              color: RiotColors.red.withOpacity(0.3),
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
                    'Riot Sign On (RSO)',
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
                '• League of Legends istatistikleri\n'
                '• Valorant istatistikleri\n'
                '• TFT istatistikleri',
                style: TextStyle(
                  color: AppTheme.lavenderGray,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Game icons row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GameBadge(
              label: 'LoL',
              color: const Color(0xFF0AC8B9),
            ),
            const SizedBox(width: 8),
            _GameBadge(
              label: 'VAL',
              color: RiotColors.red,
            ),
            const SizedBox(width: 8),
            _GameBadge(
              label: 'TFT',
              color: const Color(0xFFCDA65E),
            ),
          ],
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RiotColors.red.withOpacity(0.1),
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
                      valueColor: AlwaysStoppedAnimation(RiotColors.red),
                    ),
                  )
                else
                  const Icon(Icons.info_outline, color: RiotColors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(
                      color: RiotColors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GameBadge extends StatelessWidget {
  const _GameBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

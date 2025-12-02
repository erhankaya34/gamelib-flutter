import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/logger.dart';
import '../../core/theme.dart';
import '../../data/game_repository.dart';
import '../../data/profile_repository.dart';
import '../../data/supabase_client.dart';
import '../../data/valorant_service.dart';
import '../../models/game.dart';
import '../../models/game_log.dart';
import '../library/library_controller.dart';
import '../steam_library/steam_library_provider.dart';

/// Valorant brand colors
class ValorantColors {
  static const Color red = Color(0xFFFF4655);
  static const Color darkRed = Color(0xFFBD3944);
  static const Color black = Color(0xFF0F1923);
  static const Color cream = Color(0xFFECE8E1);
}

/// Global function to show Valorant link dialog
void showValorantLinkDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => const ValorantLinkDialog(),
  );
}

/// Valorant link dialog - Links account using Riot ID
class ValorantLinkDialog extends ConsumerStatefulWidget {
  const ValorantLinkDialog({super.key});

  @override
  ConsumerState<ValorantLinkDialog> createState() => _ValorantLinkDialogState();
}

class _ValorantLinkDialogState extends ConsumerState<ValorantLinkDialog> {
  bool _isLinking = false;
  String? _statusMessage;
  bool _isError = false;
  final _riotIdController = TextEditingController();
  String _selectedRegion = 'eu';

  static const _regions = {
    'eu': 'Avrupa',
    'na': 'Kuzey Amerika',
    'ap': 'Asya Pasifik',
    'kr': 'Kore',
    'latam': 'Latin Amerika',
    'br': 'Brezilya',
  };

  @override
  void dispose() {
    _riotIdController.dispose();
    super.dispose();
  }

  /// Creates Valorant game entry in the library
  Future<void> _createValorantGameEntry(ValorantProfile profile) async {
    final userId = ref.read(supabaseProvider).auth.currentUser?.id;
    if (userId == null) return;

    final gameRepo = ref.read(gameRepositoryProvider);

    // Valorant game info - IGDB ID for Valorant
    const valorantIgdbId = 126459; // Valorant's IGDB ID
    const valorantName = 'VALORANT';
    const valorantCoverUrl = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co2mvt.webp';

    // Calculate playtime from account level
    // Henrik's stored-matches only has partial data, account level is more reliable
    final valorantService = ref.read(valorantServiceProvider);
    final accountLevel = profile.account.accountLevel ?? 0;
    final playtimeMinutes = valorantService.calculatePlaytimeFromLevel(accountLevel);

    // Build ranked data from MMR info
    Map<String, dynamic>? rankedData;
    if (profile.mmr != null) {
      rankedData = {
        'tier': profile.mmr!.currentTier,
        'tierName': profile.mmr!.currentTierPatched,
        'rankingInTier': profile.mmr!.rankingInTier,
        'elo': profile.mmr!.elo,
      };
    }

    // Create the game
    final game = Game(
      id: valorantIgdbId,
      name: valorantName,
      coverUrl: valorantCoverUrl,
      genres: ['Shooter', 'Tactical'],
      platforms: ['PC'],
    );

    final gameLog = GameLog(
      id: const Uuid().v4(),
      game: game,
      status: PlayStatus.playing,
      source: 'valorant',
      riotGameId: 'valorant',
      riotRankedData: rankedData,
      playtimeMinutes: playtimeMinutes,
      lastSyncedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await gameRepo.upsertGameLog(userId, gameLog);
    appLogger.info('Valorant: Game entry created with ${playtimeMinutes}min playtime');
  }

  Future<void> _linkAccount() async {
    final riotId = _riotIdController.text.trim();

    if (!riotId.contains('#')) {
      setState(() {
        _statusMessage = 'Geçersiz format. Örnek: Oyuncu#TR1';
        _isError = true;
      });
      return;
    }

    final parts = riotId.split('#');
    final name = parts[0];
    final tag = parts[1];

    setState(() {
      _isLinking = true;
      _statusMessage = 'Hesap aranıyor...';
      _isError = false;
    });

    try {
      final valorantService = ref.read(valorantServiceProvider);

      // Fetch full profile
      final profile = await valorantService.getFullProfile(
        name,
        tag,
        region: _selectedRegion,
      );

      if (profile == null) {
        setState(() {
          _isLinking = false;
          _statusMessage = 'Hesap bulunamadı. Riot ID\'yi kontrol edin.';
          _isError = true;
        });
        return;
      }

      appLogger.info('Valorant: Account found - ${profile.account.riotId}');
      setState(() => _statusMessage = 'Veriler alınıyor...');

      // Save to profile
      final profileRepo = ref.read(profileRepositoryProvider);
      await profileRepo.linkRiotAccount(
        puuid: profile.account.puuid,
        gameName: profile.account.name,
        tagLine: profile.account.tag,
        accessToken: 'VALORANT_HENRIK_API', // Marker for Valorant-only
        refreshToken: 'N/A',
        region: _selectedRegion,
        riotData: profile.toJson(),
      );

      appLogger.info('Valorant: Account linked successfully');

      // Create Valorant game entry in library
      setState(() => _statusMessage = 'Kütüphaneye ekleniyor...');
      await _createValorantGameEntry(profile);

      // Refresh providers
      ref.invalidate(libraryControllerProvider);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(riotLibraryProvider);
      ref.invalidate(combinedLibraryProvider);

      if (mounted) {
        Navigator.of(context).pop();

        final rankText = profile.mmr != null
            ? ' - ${profile.mmr!.currentTierPatched}'
            : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${profile.account.riotId}$rankText bağlandı!'),
                ),
              ],
            ),
            backgroundColor: ValorantColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stack) {
      appLogger.error('Valorant: Link failed', e, stack);
      if (mounted) {
        setState(() {
          _isLinking = false;
          _statusMessage = 'Bağlantı hatası: $e';
          _isError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ValorantColors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ValorantColors.red.withOpacity(0.3)),
      ),
      title: Row(
        children: [
          // Valorant logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ValorantColors.red, ValorantColors.darkRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(24, 24),
                painter: _ValorantLogoPainter(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VALORANT',
                  style: TextStyle(
                    color: ValorantColors.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Hesabını Bağla',
                  style: TextStyle(
                    color: ValorantColors.cream,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ValorantColors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ValorantColors.red.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: ValorantColors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Riot ID\'nizi girin. Hesabınız herkese açık olmalıdır.',
                    style: TextStyle(
                      color: ValorantColors.cream.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Riot ID input
          TextField(
            controller: _riotIdController,
            style: const TextStyle(color: ValorantColors.cream),
            decoration: InputDecoration(
              labelText: 'Riot ID',
              hintText: 'Oyuncu#TR1',
              hintStyle: TextStyle(color: ValorantColors.cream.withOpacity(0.3)),
              labelStyle: TextStyle(color: ValorantColors.cream.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ValorantColors.cream.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ValorantColors.red),
              ),
              prefixIcon: Icon(Icons.person, color: ValorantColors.cream.withOpacity(0.5)),
            ),
            onSubmitted: (_) => _linkAccount(),
          ),
          const SizedBox(height: 12),

          // Region dropdown
          DropdownButtonFormField<String>(
            value: _selectedRegion,
            dropdownColor: ValorantColors.black,
            style: const TextStyle(color: ValorantColors.cream),
            decoration: InputDecoration(
              labelText: 'Bölge',
              labelStyle: TextStyle(color: ValorantColors.cream.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ValorantColors.cream.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ValorantColors.red),
              ),
              prefixIcon: Icon(Icons.public, color: ValorantColors.cream.withOpacity(0.5)),
            ),
            items: _regions.entries.map((e) {
              return DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedRegion = value);
              }
            },
          ),
          const SizedBox(height: 16),

          // What you'll get section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alınacak veriler:',
                  style: TextStyle(
                    color: ValorantColors.cream.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildFeatureRow(Icons.military_tech, 'Rank ve MMR bilgisi'),
                _buildFeatureRow(Icons.history, 'Maç geçmişi'),
                _buildFeatureRow(Icons.bar_chart, 'KDA, Win Rate, HS%'),
                _buildFeatureRow(Icons.timer, 'Toplam oyun süresi'),
              ],
            ),
          ),

          // Status message
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_isError ? Colors.red : ValorantColors.red).withOpacity(0.1),
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
                        valueColor: AlwaysStoppedAnimation(ValorantColors.red),
                      ),
                    )
                  else
                    Icon(
                      _isError ? Icons.error_outline : Icons.check_circle,
                      color: _isError ? Colors.red : ValorantColors.red,
                      size: 16,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _isError ? Colors.red : ValorantColors.red,
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
          child: Text(
            'İptal',
            style: TextStyle(color: ValorantColors.cream.withOpacity(0.6)),
          ),
        ),
        FilledButton(
          onPressed: _isLinking ? null : _linkAccount,
          style: FilledButton.styleFrom(
            backgroundColor: ValorantColors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLinking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Text(
                  'BAĞLA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: ValorantColors.red.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: ValorantColors.cream.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Official Valorant logo painter from Simple Icons
class _ValorantLogoPainter extends CustomPainter {
  _ValorantLogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    // Right side path
    final path1 = Path();
    path1.moveTo(23.792 * scaleX, 2.152 * scaleY);
    path1.cubicTo(
      23.752 * scaleX, 2.182 * scaleY,
      23.712 * scaleX, 2.212 * scaleY,
      23.694 * scaleX, 2.235 * scaleY,
    );
    path1.cubicTo(
      20.31 * scaleX, 6.465 * scaleY,
      16.925 * scaleX, 10.695 * scaleY,
      13.544 * scaleX, 14.925 * scaleY,
    );
    path1.cubicTo(
      13.437 * scaleX, 15.018 * scaleY,
      13.519 * scaleX, 15.213 * scaleY,
      13.663 * scaleX, 15.19 * scaleY,
    );
    path1.cubicTo(
      16.102 * scaleX, 15.193 * scaleY,
      18.54 * scaleX, 15.19 * scaleY,
      20.979 * scaleX, 15.191 * scaleY,
    );
    path1.cubicTo(
      21.212 * scaleX, 15.191 * scaleY,
      21.427 * scaleX, 15.08 * scaleY,
      21.531 * scaleX, 14.941 * scaleY,
    );
    path1.cubicTo(
      22.305 * scaleX, 13.974 * scaleY,
      23.081 * scaleX, 13.007 * scaleY,
      23.855 * scaleX, 12.038 * scaleY,
    );
    path1.cubicTo(
      23.931 * scaleX, 11.87 * scaleY,
      23.999 * scaleX, 11.69 * scaleY,
      23.999 * scaleX, 11.548 * scaleY,
    );
    path1.lineTo(23.999 * scaleX, 2.318 * scaleY);
    path1.cubicTo(
      24.015 * scaleX, 2.208 * scaleY,
      23.899 * scaleX, 2.112 * scaleY,
      23.795 * scaleX, 2.151 * scaleY,
    );
    path1.close();

    // Left side path
    final path2 = Path();
    path2.moveTo(0.077 * scaleX, 2.166 * scaleY);
    path2.cubicTo(
      0.0 * scaleX, 2.204 * scaleY,
      0.003 * scaleX, 2.298 * scaleY,
      0.001 * scaleX, 2.371 * scaleY,
    );
    path2.lineTo(0.001 * scaleX, 11.596 * scaleY);
    path2.cubicTo(
      0.001 * scaleX, 11.776 * scaleY,
      0.06 * scaleX, 11.916 * scaleY,
      0.159 * scaleX, 12.059 * scaleY,
    );
    path2.lineTo(7.799 * scaleX, 21.609 * scaleY);
    path2.cubicTo(
      7.919 * scaleX, 21.761 * scaleY,
      8.107 * scaleX, 21.859 * scaleY,
      8.304 * scaleX, 21.856 * scaleY,
    );
    path2.lineTo(15.669 * scaleX, 21.856 * scaleY);
    path2.cubicTo(
      15.811 * scaleX, 21.876 * scaleY,
      15.891 * scaleX, 21.682 * scaleY,
      15.785 * scaleX, 21.591 * scaleY,
    );
    path2.cubicTo(
      10.661 * scaleX, 15.176 * scaleY,
      5.526 * scaleX, 8.766 * scaleY,
      0.4 * scaleX, 2.35 * scaleY,
    );
    path2.cubicTo(
      0.32 * scaleX, 2.256 * scaleY,
      0.226 * scaleX, 2.078 * scaleY,
      0.078 * scaleX, 2.166 * scaleY,
    );
    path2.close();

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _ValorantLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

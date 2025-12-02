import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/fire_theme.dart';
import '../../core/ui_constants.dart';
import '../../data/profile_repository.dart';
import '../../data/steam_library_sync_service.dart';
import '../../data/supabase_client.dart';
import '../../models/game_log.dart';
import '../library/library_controller.dart';
import '../search/game_detail_screen.dart';
import '../steam_library/steam_library_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with TickerProviderStateMixin {
  late AnimationController _flameController;
  late AnimationController _emberController;

  @override
  void initState() {
    super.initState();
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _emberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _flameController.dispose();
    _emberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(libraryControllerProvider);

    return Scaffold(
      backgroundColor: UIConstants.bgPrimary,
      body: Stack(
        children: [
          // Fire Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _flameController,
              builder: (context, child) {
                return CustomPaint(
                  painter: FireBackgroundPainter(
                    progress: _flameController.value,
                    intensity: 0.6,
                  ),
                );
              },
            ),
          ),

          // Ember Particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _emberController,
              builder: (context, child) {
                return CustomPaint(
                  painter: EmberParticlesPainter(
                    progress: _emberController.value,
                    particleCount: 10,
                    intensity: 0.5,
                  ),
                );
              },
            ),
          ),

          // Gradient Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      UIConstants.bgPrimary.withOpacity(0.7),
                      UIConstants.bgPrimary.withOpacity(0.95),
                    ],
                    stops: const [0.0, 0.3, 0.6],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Fire Header
                _FireLibraryHeader(flameController: _flameController),

                // Content
                Expanded(
                  child: logsAsync.when(
                    data: (logs) {
                      final ratedGames = logs
                          .where((log) => log.rating != null)
                          .toList();

                      ratedGames.sort((a, b) {
                        final aRating = a.rating ?? 0;
                        final bRating = b.rating ?? 0;
                        return bRating.compareTo(aRating);
                      });

                      return _CollectionTab(games: ratedGames, ref: ref);
                    },
                    loading: () => const Center(
                      child: FireLoadingIndicator(),
                    ),
                    error: (error, stack) => _FireErrorState(
                      message: error.toString(),
                      onRetry: () => ref.read(libraryControllerProvider.notifier).refresh(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FireLibraryHeader extends StatelessWidget {
  const _FireLibraryHeader({required this.flameController});

  final AnimationController flameController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: flameController,
            builder: (context, child) {
              return Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      UIConstants.fireYellow,
                      Color.lerp(
                        UIConstants.fireOrange,
                        UIConstants.fireRed,
                        flameController.value,
                      )!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: UIConstants.fireOrange.withOpacity(0.5 + flameController.value * 0.3),
                      blurRadius: 8 + flameController.value * 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [UIConstants.fireYellow, UIConstants.fireOrange],
            ).createShader(bounds),
            child: const Text(
              'KAYITLARIM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _FireErrorState extends StatelessWidget {
  const _FireErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    UIConstants.fireRed.withOpacity(0.2),
                    UIConstants.fireOrange.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: UIConstants.fireRed.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: UIConstants.fireRed,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bir hata oluştu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            FireButton(
              onTap: onRetry,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Tekrar Dene',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionTab extends ConsumerWidget {
  const _CollectionTab({required this.games, required this.ref});

  final List<GameLog> games;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (games.isEmpty) {
      return _FireEmptyCollectionState();
    }

    final steamLibrary = ref.watch(steamLibraryProvider).valueOrNull ?? [];
    final psnLibrary = ref.watch(playstationLibraryProvider).valueOrNull ?? [];

    final steamGameNames = steamLibrary
        .map((g) => g.game.name.toLowerCase().trim())
        .toSet();

    final psnGameNames = psnLibrary
        .map((g) => g.game.name.toLowerCase().trim())
        .toSet();

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryControllerProvider.notifier).refresh(),
      color: UIConstants.fireOrange,
      backgroundColor: UIConstants.bgSecondary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final log = games[index];
          final gameName = log.game.name.toLowerCase().trim();

          final isOnSteam = log.source == 'steam' ||
              log.steamAppId != null ||
              steamGameNames.contains(gameName);

          final isOnPlayStation = log.source == 'playstation' ||
              log.psnTitleId != null ||
              psnGameNames.contains(gameName);

          return Dismissible(
            key: Key(log.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [UIConstants.fireRed, UIConstants.fireOrange],
                ),
                borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: UIConstants.fireRed.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                  SizedBox(height: 4),
                  Text(
                    'Sil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            confirmDismiss: (direction) => _showDeleteConfirmDialog(
              context,
              log.game.name,
            ),
            onDismissed: (direction) async {
              await ref.read(libraryControllerProvider.notifier).clearReview(log.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${log.game.name} değerlendirmesi silindi'),
                    backgroundColor: UIConstants.bgSecondary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                    ),
                  ),
                );
              }
            },
            child: _FireGameCard(
              log: log,
              index: index,
              isOnSteam: isOnSteam,
              isOnPlayStation: isOnPlayStation,
            ).animate().fadeIn(
              delay: Duration(milliseconds: index * 50),
              duration: 400.ms,
            ).slideX(begin: 0.1, end: 0),
          );
        },
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog(BuildContext context, String gameName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        ),
        title: Text(
          'Değerlendirmeyi Sil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$gameName" için değerlendirmeni silmek istediğinden emin misin?',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    UIConstants.fireOrange.withOpacity(0.15),
                    UIConstants.fireYellow.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                border: Border.all(
                  color: UIConstants.fireOrange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: UIConstants.fireOrange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Oyun kütüphanenden silinmeyecek.',
                      style: TextStyle(
                        color: UIConstants.fireOrange,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'İptal',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
          FireButton(
            onTap: () => Navigator.of(context).pop(true),
            gradientColors: [UIConstants.fireRed, UIConstants.fireOrange],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Text(
              'Sil',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FireEmptyCollectionState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  UIConstants.fireOrange.withOpacity(0.2),
                  UIConstants.fireRed.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: UIConstants.fireOrange.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Icon(
              Icons.collections_bookmark_outlined,
              size: 56,
              color: UIConstants.fireOrange,
            ),
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [UIConstants.fireYellow, UIConstants.fireOrange],
            ).createShader(bounds),
            child: const Text(
              'Koleksiyon Boş',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Oynadığın oyunları buraya ekle',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

class _FireGameCard extends StatelessWidget {
  const _FireGameCard({
    required this.log,
    required this.index,
    this.isWishlist = false,
    this.isOnSteam = false,
    this.isOnPlayStation = false,
  });

  final GameLog log;
  final int index;
  final bool isWishlist;
  final bool isOnSteam;
  final bool isOnPlayStation;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(game: log.game),
          ),
        );
      },
      child: Container(
        height: 150,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              UIConstants.fireOrange.withOpacity(0.12),
              UIConstants.fireRed.withOpacity(0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          border: Border.all(
            color: UIConstants.fireOrange.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: UIConstants.fireOrange.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          child: Stack(
            children: [
              // Background image
              if (log.game.coverUrlForGrid != null)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: log.game.coverUrlForGrid!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),

              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF0D0D0D).withOpacity(0.98),
                        const Color(0xFF0D0D0D).withOpacity(0.85),
                        const Color(0xFF0D0D0D).withOpacity(0.5),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Game cover with fire glow
                    Container(
                      width: 80,
                      height: 110,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: UIConstants.fireOrange.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: log.game.coverUrlForGrid != null
                            ? CachedNetworkImage(
                                imageUrl: log.game.coverUrlForGrid!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _FireGamePlaceholder(),
                              )
                            : _FireGamePlaceholder(),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Game info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Game name
                          Text(
                            log.game.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 8),

                          // Platform logos
                          if (isOnSteam || isOnPlayStation)
                            _FirePlatformLogos(
                              isOnSteam: isOnSteam,
                              isOnPlayStation: isOnPlayStation,
                            ),

                          // Rating or playtime
                          if (log.rating != null || log.playtimeMinutes > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  if (log.rating != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            UIConstants.fireYellow.withOpacity(0.2),
                                            UIConstants.fireOrange.withOpacity(0.1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: UIConstants.fireYellow.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star_rounded,
                                            size: 14,
                                            color: UIConstants.fireYellow,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${log.rating}/10',
                                            style: TextStyle(
                                              color: UIConstants.fireYellow,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (log.playtimeMinutes > 0) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: UIConstants.fireOrange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: UIConstants.fireOrange.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.schedule_rounded,
                                            size: 12,
                                            color: UIConstants.fireOrange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${log.playtimeHours.toStringAsFixed(1)}s',
                                            style: TextStyle(
                                              color: UIConstants.fireOrange,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                          // Valorant stats
                          if (log.riotRankedData != null)
                            _ValorantStatsRow(data: log.riotRankedData!),
                        ],
                      ),
                    ),

                    // Chevron with fire glow
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            UIConstants.fireOrange.withOpacity(0.15),
                            UIConstants.fireRed.withOpacity(0.08),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: UIConstants.fireOrange.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FireGamePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: UIConstants.fireGradient,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.sports_esports_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

class _FirePlatformLogos extends StatelessWidget {
  const _FirePlatformLogos({
    required this.isOnSteam,
    required this.isOnPlayStation,
    this.isOnXbox = false,
  });

  final bool isOnSteam;
  final bool isOnPlayStation;
  final bool isOnXbox;

  @override
  Widget build(BuildContext context) {
    final platforms = <Widget>[];

    if (isOnSteam) {
      platforms.add(_buildPlatformIcon(
        icon: FontAwesomeIcons.steam,
        color: UIConstants.fireOrange,
      ));
    }
    if (isOnPlayStation) {
      platforms.add(_buildPlatformIcon(
        icon: FontAwesomeIcons.playstation,
        color: UIConstants.fireOrange,
      ));
    }
    if (isOnXbox) {
      platforms.add(_buildPlatformIcon(
        icon: FontAwesomeIcons.xbox,
        color: UIConstants.fireOrange,
      ));
    }

    if (platforms.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < platforms.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          platforms[i],
        ],
      ],
    );
  }

  Widget _buildPlatformIcon({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.25),
            color.withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: FaIcon(icon, size: 14, color: color),
    );
  }
}

class _ValorantStatsRow extends StatelessWidget {
  const _ValorantStatsRow({required this.data});

  final Map<String, dynamic> data;

  static const _valorantRed = Color(0xFFFF4655);

  @override
  Widget build(BuildContext context) {
    final stats = data['stats'] as Map<String, dynamic>?;
    final mmr = data['mmr'] as Map<String, dynamic>?;

    final rank = mmr?['current_tier_patched'] as String?;
    final winRate = stats?['win_rate'] as double?;
    final avgKda = stats?['avg_kda'] as double?;
    final avgHsPercent = stats?['avg_hs_percent'] as double?;

    if (rank == null && winRate == null && avgKda == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (rank != null && rank != 'Unranked')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _valorantRed.withOpacity(0.2),
                    _valorantRed.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _valorantRed.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.military_tech, size: 12, color: _valorantRed),
                  const SizedBox(width: 3),
                  Text(
                    rank,
                    style: TextStyle(
                      color: _valorantRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (winRate != null)
            _buildStatChip(
              icon: Icons.emoji_events,
              value: '${winRate.toStringAsFixed(1)}%',
              color: UIConstants.accentGreen,
            ),
          if (avgKda != null)
            _buildStatChip(
              icon: Icons.flash_on,
              value: 'KDA ${avgKda.toStringAsFixed(2)}',
              color: UIConstants.fireOrange,
            ),
          if (avgHsPercent != null)
            _buildStatChip(
              icon: Icons.gps_fixed,
              value: 'HS ${avgHsPercent.toStringAsFixed(1)}%',
              color: UIConstants.fireYellow,
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/platform_icons.dart';
import '../../core/ui_constants.dart';
import '../../data/profile_repository.dart';
import '../../data/steam_library_sync_service.dart';
import '../../data/supabase_client.dart';
import '../../models/game_log.dart';
import '../library/library_controller.dart';
import '../search/game_detail_screen.dart';
import '../steam_link/steam_link_dialog.dart';
import 'steam_library_provider.dart';

/// Combined library screen showing games from all connected platforms
/// Now includes tabs for Library and Wishlist
class SteamLibraryScreen extends ConsumerStatefulWidget {
  const SteamLibraryScreen({super.key});

  @override
  ConsumerState<SteamLibraryScreen> createState() => _SteamLibraryScreenState();
}

class _SteamLibraryScreenState extends ConsumerState<SteamLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _syncLibrary(BuildContext context) async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    final steamId = profile?['steam_id'] as String?;

    if (steamId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Henüz bir platform bağlı değil'),
            backgroundColor: UIConstants.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    // Show loading dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: UIConstants.bgSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          ),
          content: Row(
            children: [
              CircularProgressIndicator(color: UIConstants.accentPurple),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Kütüphane senkronize ediliyor...',
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    try {
      final syncService = ref.read(steamLibrarySyncServiceProvider);
      final userId = ref.read(supabaseProvider).auth.currentUser?.id;

      if (userId == null) throw Exception('Kullanıcı bulunamadı');

      // Sync both library and wishlist
      await syncService.syncFullLibrary(userId, steamId);
      final wishlistResult = await syncService.syncWishlist(userId, steamId);

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show result
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kütüphane güncellendi! ${wishlistResult.imported} yeni istek listesi oyunu',
            ),
            backgroundColor: UIConstants.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        ref.invalidate(steamLibraryProvider);
        ref.invalidate(libraryControllerProvider);
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: UIConstants.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final steamLibraryAsync = ref.watch(steamLibraryProvider);
    final libraryAsync = ref.watch(libraryControllerProvider);

    // Get wishlist from library controller
    final wishlistGames = libraryAsync.valueOrNull
            ?.where((log) => log.status == PlayStatus.wishlist)
            .toList() ??
        [];

    return Scaffold(
      backgroundColor: UIConstants.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _LibraryHeader(onSync: () => _syncLibrary(context)),

            // Connected platforms bar
            profileAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (profile) {
                final steamConnected = profile?['steam_id'] != null;
                return _ConnectedPlatformsBar(
                  connectedPlatforms: {
                    if (steamConnected) GamePlatform.steam,
                  },
                );
              },
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              decoration: BoxDecoration(
                color: UIConstants.bgSecondary,
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: UIConstants.accentPurple,
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.5),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                tabs: [
                  const Tab(text: 'Kütüphane'),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('İstek Listesi'),
                        if (wishlistGames.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: UIConstants.accentYellow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              wishlistGames.length.toString(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: profileAsync.when(
                loading: () => const LoadingState(message: 'Yükleniyor...'),
                error: (e, st) => _ErrorState(
                  message: 'Hata: $e',
                  onRetry: () => ref.invalidate(currentProfileProvider),
                ),
                data: (profile) {
                  final steamLinked = profile?['steam_id'] != null;

                  if (!steamLinked) {
                    return const _NoPlatformLinkedState();
                  }

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      // Library Tab
                      _LibraryTab(
                        steamLibraryAsync: steamLibraryAsync,
                        onRefresh: () => ref.invalidate(steamLibraryProvider),
                      ),
                      // Wishlist Tab
                      _WishlistTab(
                        games: wishlistGames,
                        onRefresh: () =>
                            ref.read(libraryControllerProvider.notifier).refresh(),
                        onSyncSteam: () => _syncLibrary(context),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// LIBRARY HEADER
// ============================================

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.onSync});

  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UIConstants.pagePadding,
        16,
        UIConstants.pagePadding,
        8,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: UIConstants.purpleGradient),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'KÜTÜPHANEM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          _HeaderButton(
            icon: Icons.sync_rounded,
            tooltip: 'Senkronize Et',
            onPressed: onSync,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: UIConstants.accentPurple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
            border: Border.all(
              color: UIConstants.accentPurple.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: UIConstants.accentPurple,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ============================================
// CONNECTED PLATFORMS BAR
// ============================================

class _ConnectedPlatformsBar extends StatelessWidget {
  const _ConnectedPlatformsBar({required this.connectedPlatforms});

  final Set<GamePlatform> connectedPlatforms;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.pagePadding,
        vertical: 4,
      ),
      child: Row(
        children: [
          Text(
            'Bağlı:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          ...PlatformConfig.mainPlatforms.map((platform) {
            final isConnected = connectedPlatforms.contains(platform.platform);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: isConnected
                    ? null
                    : () {
                        if (platform.platform == GamePlatform.steam) {
                          showSteamLinkDialog(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${platform.name} yakında eklenecek!'),
                              backgroundColor: UIConstants.bgTertiary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? platform.activeColor.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isConnected
                          ? platform.activeColor.withOpacity(0.4)
                          : Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: PlatformIcon(
                    platform: platform,
                    isActive: isConnected,
                    size: 12,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================
// LIBRARY TAB
// ============================================

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    required this.steamLibraryAsync,
    required this.onRefresh,
  });

  final AsyncValue<List<GameLog>> steamLibraryAsync;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return steamLibraryAsync.when(
      loading: () => const LoadingState(message: 'Kütüphane yükleniyor...'),
      error: (e, st) => _ErrorState(
        message: 'Hata: $e',
        onRetry: onRefresh,
      ),
      data: (games) {
        if (games.isEmpty) {
          return const _EmptyLibraryState();
        }

        // Stats
        final totalHours = games.fold<double>(
          0,
          (sum, g) => sum + g.playtimeHours,
        );

        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          color: UIConstants.accentPurple,
          backgroundColor: UIConstants.bgSecondary,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: UIConstants.pagePadding),
            itemCount: games.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _StatsRow(
                    gameCount: games.length,
                    totalHours: totalHours,
                    platformCount: 1,
                  ),
                ).animate().fadeIn(duration: 400.ms);
              }

              final gameIndex = index - 1;
              return _LibraryGameCard(
                game: games[gameIndex],
                platforms: {GamePlatform.steam},
              )
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: 50 * (gameIndex % 10)),
                    duration: 400.ms,
                  )
                  .slideX(begin: 0.05, end: 0);
            },
          ),
        );
      },
    );
  }
}

// ============================================
// WISHLIST TAB
// ============================================

class _WishlistTab extends StatelessWidget {
  const _WishlistTab({
    required this.games,
    required this.onRefresh,
    required this.onSyncSteam,
  });

  final List<GameLog> games;
  final VoidCallback onRefresh;
  final VoidCallback onSyncSteam;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return _EmptyWishlistState(onSyncSteam: onSyncSteam);
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: UIConstants.accentYellow,
      backgroundColor: UIConstants.bgSecondary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: UIConstants.pagePadding),
        itemCount: games.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Sync button at top
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: onSyncSteam,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: UIConstants.accentSteam.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                    border: Border.all(
                      color: UIConstants.accentSteam.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.steam,
                        size: 20,
                        color: UIConstants.accentSteam,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Steam İstek Listesini Güncelle',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'İstek listenizdeki oyunları senkronize edin',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.sync_rounded,
                        color: UIConstants.accentSteam,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms);
          }

          final gameIndex = index - 1;
          return _WishlistGameCard(game: games[gameIndex])
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: 50 * (gameIndex % 10)),
                duration: 400.ms,
              )
              .slideX(begin: 0.05, end: 0);
        },
      ),
    );
  }
}

class _EmptyWishlistState extends StatelessWidget {
  const _EmptyWishlistState({required this.onSyncSteam});

  final VoidCallback onSyncSteam;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: UIConstants.accentYellow.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 48,
                color: UIConstants.accentYellow.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'İstek Listesi Boş',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Steam istek listenizi senkronize edin veya oyunları manuel olarak ekleyin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onSyncSteam,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: UIConstants.steamGradient),
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: UIConstants.accentSteam.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.steam,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Steam\'den Çek',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// WISHLIST GAME CARD
// ============================================

class _WishlistGameCard extends StatelessWidget {
  const _WishlistGameCard({required this.game});

  final GameLog game;

  String? get _coverUrl => game.game.coverUrlForGrid;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(game: game.game),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: UIConstants.bgSecondary,
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          border: Border.all(
            color: UIConstants.accentYellow.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          child: SizedBox(
            height: 90,
            child: Row(
              children: [
                // Game cover
                if (_coverUrl != null)
                  CachedNetworkImage(
                    imageUrl: _coverUrl!,
                    width: 68,
                    height: 90,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: UIConstants.bgTertiary,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: UIConstants.bgTertiary,
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 24,
                        color: Colors.white24,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 68,
                    height: 90,
                    color: UIConstants.bgTertiary,
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 24,
                      color: Colors.white24,
                    ),
                  ),

                // Game info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Game name
                        Flexible(
                          child: Text(
                            game.game.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Wishlist badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: UIConstants.accentYellow.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 10,
                                color: UIConstants.accentYellow,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'İstek Listesi',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: UIConstants.accentYellow,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Chevron
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// STATS ROW
// ============================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.gameCount,
    required this.totalHours,
    required this.platformCount,
  });

  final int gameCount;
  final double totalHours;
  final int platformCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            icon: Icons.games_rounded,
            value: gameCount.toString(),
            label: 'Oyun',
            gradient: UIConstants.purpleGradient,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatItem(
            icon: Icons.access_time_rounded,
            value: totalHours.toStringAsFixed(0),
            label: 'Saat',
            gradient: UIConstants.violetGradient,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatItem(
            icon: Icons.link_rounded,
            value: platformCount.toString(),
            label: 'Platform',
            gradient: UIConstants.greenGradient,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.gradient,
  });

  final IconData icon;
  final String value;
  final String label;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UIConstants.bgSecondary,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(
          color: gradient[0].withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// EMPTY STATES
// ============================================

class _NoPlatformLinkedState extends StatelessWidget {
  const _NoPlatformLinkedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: UIConstants.accentPurple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.link_off_rounded,
                size: 48,
                color: UIConstants.accentPurple.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Platform Bağlayın',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Oyun kütüphanelerinizi görmek için bir platform hesabı bağlayın.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // Platform connect buttons
            ...PlatformConfig.mainPlatforms.map((platform) {
              final isComingSoon = platform.platform != GamePlatform.steam;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: isComingSoon
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${platform.name} yakında eklenecek!'),
                              backgroundColor: UIConstants.bgTertiary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      : () => showSteamLinkDialog(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isComingSoon
                          ? Colors.white.withOpacity(0.05)
                          : platform.activeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                      border: Border.all(
                        color: isComingSoon
                            ? Colors.white.withOpacity(0.1)
                            : platform.activeColor.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PlatformIcon(
                          platform: platform,
                          isActive: !isComingSoon,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isComingSoon
                              ? '${platform.name} (Yakında)'
                              : '${platform.name} Bağla',
                          style: TextStyle(
                            color: isComingSoon
                                ? Colors.white.withOpacity(0.3)
                                : platform.activeColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.games_rounded,
        title: 'Kütüphane Boş',
        subtitle: 'Bağlı platformlarınızda henüz oyun bulunmuyor.',
        iconColor: UIConstants.accentPurple,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

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
                color: UIConstants.accentRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: UIConstants.accentRed,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: UIConstants.bgSecondary,
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Tekrar Dene',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// LIBRARY GAME CARD
// ============================================

class _LibraryGameCard extends StatelessWidget {
  const _LibraryGameCard({
    required this.game,
    required this.platforms,
  });

  final GameLog game;
  final Set<GamePlatform> platforms;

  String? get _coverUrl => game.game.coverUrlForGrid;

  @override
  Widget build(BuildContext context) {
    final playtimeHours = game.playtimeHours;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(game: game.game),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: UIConstants.bgSecondary,
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          border: Border.all(
            color: UIConstants.accentPurple.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          child: SizedBox(
            height: 100,
            child: Row(
              children: [
                // Game cover
                if (_coverUrl != null)
                  CachedNetworkImage(
                    imageUrl: _coverUrl!,
                    width: 75,
                    height: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: UIConstants.bgTertiary,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: UIConstants.accentPurple,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: UIConstants.bgTertiary,
                      child: const Icon(
                        Icons.games_rounded,
                        size: 24,
                        color: Colors.white24,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 75,
                    height: 100,
                    color: UIConstants.bgTertiary,
                    child: const Icon(
                      Icons.games_rounded,
                      size: 24,
                      color: Colors.white24,
                    ),
                  ),

                // Game info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Game name
                        Text(
                          game.game.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Playtime
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: UIConstants.accentViolet,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${playtimeHours.toStringAsFixed(1)} saat',
                              style: TextStyle(
                                color: UIConstants.accentViolet,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Platform icons row
                        PlatformIconRow(
                          activePlatforms: platforms,
                          iconSize: 12,
                          spacing: 6,
                        ),
                      ],
                    ),
                  ),
                ),

                // Chevron
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

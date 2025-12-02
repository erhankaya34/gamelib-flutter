import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/fire_theme.dart';
import '../../core/platform_icons.dart';
import '../../core/ui_constants.dart';
import '../../data/profile_repository.dart';
import '../../data/steam_library_sync_service.dart';
import '../../data/supabase_client.dart';
import '../../data/valorant_service.dart';
import '../../models/game_log.dart';
import '../library/library_controller.dart';
import '../playstation_link/playstation_link_dialog.dart';
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
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _flameController;
  late AnimationController _emberController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _tabController.dispose();
    _flameController.dispose();
    _emberController.dispose();
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
              CircularProgressIndicator(color: UIConstants.fireOrange),
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

      // Sync library only (wishlist is app-only, not synced from Steam)
      final result = await syncService.syncFullLibrary(userId, steamId);

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show result
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kütüphane güncellendi! ${result.imported} yeni oyun eklendi',
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
    final playstationLibraryAsync = ref.watch(playstationLibraryProvider);
    final libraryAsync = ref.watch(libraryControllerProvider);

    // Get wishlist from library controller
    final wishlistGames = libraryAsync.valueOrNull
            ?.where((log) => log.status == PlayStatus.wishlist)
            .toList() ??
        [];

    return Scaffold(
      backgroundColor: UIConstants.bgPrimary,
      body: Stack(
        children: [
          // Fire background
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

          // Ember particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _emberController,
              builder: (context, child) {
                return CustomPaint(
                  painter: EmberParticlesPainter(
                    progress: _emberController.value,
                    particleCount: 12,
                  ),
                );
              },
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                _FireLibraryHeader(onSync: () => _syncLibrary(context)),

                // Connected platforms bar
                profileAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (profile) {
                    final steamConnected = profile?['steam_id'] != null;
                    final psnConnected = profile?['psn_id'] != null;
                    final riotConnected = profile?['riot_puuid'] != null;
                    return _FireConnectedPlatformsBar(
                      connectedPlatforms: {
                        if (steamConnected) GamePlatform.steam,
                        if (psnConnected) GamePlatform.playstation,
                        if (riotConnected) GamePlatform.valorant,
                      },
                    );
                  },
                ),

                // Tab Bar - Fire styled
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  decoration: BoxDecoration(
                    color: UIConstants.bgSecondary.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                    border: Border.all(
                      color: UIConstants.fireOrange.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: LinearGradient(colors: UIConstants.fireGradient),
                      borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                      boxShadow: [
                        BoxShadow(
                          color: UIConstants.fireOrange.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                                  gradient: LinearGradient(
                                    colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                                  ),
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
                    loading: () => const _FireLoadingState(message: 'Yükleniyor...'),
                    error: (e, st) => _FireErrorState(
                      message: 'Hata: $e',
                      onRetry: () => ref.invalidate(currentProfileProvider),
                    ),
                    data: (profile) {
                      final steamLinked = profile?['steam_id'] != null;
                      final psnLinked = profile?['psn_id'] != null;
                      final riotLinked = profile?['riot_puuid'] != null;

                      if (!steamLinked && !psnLinked && !riotLinked) {
                        return const _FireNoPlatformLinkedState();
                      }

                      // Calculate platform count
                      final platformCount = (steamLinked ? 1 : 0) + (psnLinked ? 1 : 0) + (riotLinked ? 1 : 0);

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          // Library Tab
                          _FireLibraryTab(
                            onRefresh: () {
                              ref.invalidate(steamLibraryProvider);
                              ref.invalidate(playstationLibraryProvider);
                              ref.invalidate(riotLibraryProvider);
                              ref.invalidate(combinedLibraryProvider);
                            },
                            platformCount: platformCount,
                            steamLinked: steamLinked,
                            psnLinked: psnLinked,
                            riotLinked: riotLinked,
                          ),
                          // Wishlist Tab
                          _FireWishlistTab(
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
        ],
      ),
    );
  }
}

// ============================================
// FIRE LIBRARY HEADER
// ============================================

class _FireLibraryHeader extends StatelessWidget {
  const _FireLibraryHeader({required this.onSync});

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
              gradient: LinearGradient(colors: UIConstants.fireGradient),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: UIConstants.fireOrange.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [UIConstants.fireYellow, UIConstants.fireOrange],
              ).createShader(bounds),
              child: const Text(
                'KÜTÜPHANEM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          _FireHeaderButton(
            icon: Icons.sync_rounded,
            tooltip: 'Senkronize Et',
            onPressed: onSync,
          ),
        ],
      ),
    );
  }
}

class _FireHeaderButton extends StatelessWidget {
  const _FireHeaderButton({
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
            gradient: LinearGradient(
              colors: [
                UIConstants.fireOrange.withOpacity(0.2),
                UIConstants.fireRed.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
            border: Border.all(
              color: UIConstants.fireOrange.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: UIConstants.fireOrange.withOpacity(0.2),
                blurRadius: 8,
              ),
            ],
          ),
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [UIConstants.fireYellow, UIConstants.fireOrange],
            ).createShader(bounds),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// FIRE CONNECTED PLATFORMS BAR
// ============================================

class _FireConnectedPlatformsBar extends StatelessWidget {
  const _FireConnectedPlatformsBar({required this.connectedPlatforms});

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
              color: UIConstants.fireYellow.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
                        } else if (platform.platform == GamePlatform.playstation) {
                          showPlayStationLinkDialog(context);
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
                    boxShadow: isConnected
                        ? [
                            BoxShadow(
                              color: platform.activeColor.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
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
// FIRE LIBRARY TAB
// ============================================

class _FireLibraryTab extends ConsumerStatefulWidget {
  const _FireLibraryTab({
    required this.onRefresh,
    required this.platformCount,
    required this.steamLinked,
    required this.psnLinked,
    required this.riotLinked,
  });

  final VoidCallback onRefresh;
  final int platformCount;
  final bool steamLinked;
  final bool psnLinked;
  final bool riotLinked;

  @override
  ConsumerState<_FireLibraryTab> createState() => _FireLibraryTabState();
}

class _FireLibraryTabState extends ConsumerState<_FireLibraryTab> {
  // null = all platforms, otherwise filter by selected platform
  GamePlatform? _selectedPlatform;

  @override
  Widget build(BuildContext context) {
    final combinedAsync = ref.watch(combinedLibraryProvider);

    return combinedAsync.when(
      loading: () => const _FireLoadingState(message: 'Kütüphane yükleniyor...'),
      error: (e, st) => _FireErrorState(
        message: 'Hata: $e',
        onRetry: widget.onRefresh,
      ),
      data: (allGames) {
        if (allGames.isEmpty) {
          return const _FireEmptyLibraryState();
        }

        // Filter games by selected platform
        final filteredGames = _selectedPlatform == null
            ? allGames
            : allGames.where((e) => e.platforms.contains(_selectedPlatform)).toList();

        // Stats - always show total (unfiltered) count
        final totalHours = allGames.fold<double>(
          0,
          (sum, entry) => sum + entry.log.playtimeHours,
        );

        // Calculate header item count: stats row + filter row + (valorant panel if selected)
        final showValorantPanel = _selectedPlatform == GamePlatform.valorant;
        final headerItemCount = showValorantPanel ? 3 : 2;

        return RefreshIndicator(
          onRefresh: () async => widget.onRefresh(),
          color: UIConstants.fireOrange,
          backgroundColor: UIConstants.bgSecondary,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: UIConstants.pagePadding),
            itemCount: filteredGames.length + headerItemCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FireStatsRow(
                    gameCount: allGames.length, // Always show total count
                    totalHours: totalHours,
                    platformCount: widget.platformCount,
                  ),
                ).animate().fadeIn(duration: 400.ms);
              }

              if (index == 1) {
                // Platform filter chips
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _FirePlatformFilterRow(
                    selectedPlatform: _selectedPlatform,
                    steamLinked: widget.steamLinked,
                    psnLinked: widget.psnLinked,
                    riotLinked: widget.riotLinked,
                    filteredCount: filteredGames.length,
                    onFilterChanged: (platform) {
                      setState(() {
                        _selectedPlatform = platform;
                      });
                    },
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
              }

              // Valorant Stats Panel (only when Valorant filter is selected)
              if (index == 2 && showValorantPanel) {
                return const _FireValorantStatsPanel()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 150.ms)
                    .slideY(begin: 0.1, end: 0);
              }

              // Calculate game index based on header items
              final gameIndex = index - headerItemCount;
              if (gameIndex < 0 || gameIndex >= filteredGames.length) {
                return const SizedBox.shrink();
              }
              final entry = filteredGames[gameIndex];
              return _FireLibraryGameCard(
                game: entry.log,
                platforms: entry.platforms,
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
// FIRE PLATFORM FILTER ROW
// ============================================

class _FirePlatformFilterRow extends StatelessWidget {
  const _FirePlatformFilterRow({
    required this.selectedPlatform,
    required this.steamLinked,
    required this.psnLinked,
    required this.riotLinked,
    required this.filteredCount,
    required this.onFilterChanged,
  });

  final GamePlatform? selectedPlatform;
  final bool steamLinked;
  final bool psnLinked;
  final bool riotLinked;
  final int filteredCount;
  final ValueChanged<GamePlatform?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Filter chips in a flexible container
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // All platforms chip
                _FireFilterChip(
                  label: 'Tümü',
                  isSelected: selectedPlatform == null,
                  onTap: () => onFilterChanged(null),
                ),
                const SizedBox(width: 8),

                // Steam chip
                if (steamLinked)
                  _FireFilterChip(
                    label: 'Steam',
                    icon: FontAwesomeIcons.steam,
                    color: UIConstants.fireOrange,
                    isSelected: selectedPlatform == GamePlatform.steam,
                    onTap: () => onFilterChanged(
                      selectedPlatform == GamePlatform.steam ? null : GamePlatform.steam,
                    ),
                  ),
                if (steamLinked) const SizedBox(width: 8),

                // PlayStation chip
                if (psnLinked)
                  _FireFilterChip(
                    label: 'PlayStation',
                    icon: FontAwesomeIcons.playstation,
                    color: UIConstants.fireOrange,
                    isSelected: selectedPlatform == GamePlatform.playstation,
                    onTap: () => onFilterChanged(
                      selectedPlatform == GamePlatform.playstation ? null : GamePlatform.playstation,
                    ),
                  ),
                if (psnLinked) const SizedBox(width: 8),

                // Valorant chip (only show if riot linked)
                if (riotLinked)
                  _FireFilterChip(
                    label: 'Valorant',
                    useValorantIcon: true,
                    color: UIConstants.fireOrange, // Fire theme consistency
                    isSelected: selectedPlatform == GamePlatform.valorant,
                    onTap: () => onFilterChanged(
                      selectedPlatform == GamePlatform.valorant ? null : GamePlatform.valorant,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Filtered count indicator
        if (selectedPlatform != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  UIConstants.fireOrange.withOpacity(0.2),
                  UIConstants.fireRed.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: UIConstants.fireOrange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              '$filteredCount oyun',
              style: TextStyle(
                color: UIConstants.fireYellow,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FireFilterChip extends StatelessWidget {
  const _FireFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.color,
    this.isDisabled = false,
    this.useValorantIcon = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool isSelected;
  final bool isDisabled;
  final bool useValorantIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? UIConstants.fireOrange;
    final effectiveOpacity = isDisabled ? 0.4 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withOpacity(0.2 * effectiveOpacity)
              : UIConstants.bgSecondary.withOpacity(0.7 * effectiveOpacity),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor.withOpacity(0.5 * effectiveOpacity)
                : Colors.white.withOpacity(0.1 * effectiveOpacity),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withOpacity(0.2),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              FaIcon(
                icon!,
                size: 12,
                color: isSelected
                    ? chipColor.withOpacity(effectiveOpacity)
                    : Colors.white.withOpacity(0.5 * effectiveOpacity),
              ),
              const SizedBox(width: 6),
            ] else if (useValorantIcon) ...[
              ValorantIcon(
                size: 14,
                color: isSelected
                    ? chipColor.withOpacity(effectiveOpacity)
                    : Colors.white.withOpacity(0.5 * effectiveOpacity),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? chipColor.withOpacity(effectiveOpacity)
                    : Colors.white.withOpacity(0.7 * effectiveOpacity),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// FIRE WISHLIST TAB
// ============================================

class _FireWishlistTab extends StatelessWidget {
  const _FireWishlistTab({
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
      return _FireEmptyWishlistState(onSyncSteam: onSyncSteam);
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: UIConstants.fireYellow,
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
                    gradient: LinearGradient(
                      colors: [
                        UIConstants.fireOrange.withOpacity(0.15),
                        UIConstants.fireOrange.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                    border: Border.all(
                      color: UIConstants.fireOrange.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: UIConstants.fireOrange.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.steam,
                        size: 20,
                        color: UIConstants.fireOrange,
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
                        color: UIConstants.fireOrange,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms);
          }

          final gameIndex = index - 1;
          return _FireWishlistGameCard(game: games[gameIndex])
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

class _FireEmptyWishlistState extends StatelessWidget {
  const _FireEmptyWishlistState({required this.onSyncSteam});

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
                gradient: RadialGradient(
                  colors: [
                    UIConstants.fireYellow.withOpacity(0.2),
                    UIConstants.fireOrange.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                ).createShader(bounds),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [UIConstants.fireYellow, UIConstants.fireOrange],
              ).createShader(bounds),
              child: const Text(
                'İstek Listesi Boş',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
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
                  gradient: LinearGradient(colors: [UIConstants.fireOrange, UIConstants.fireRed]),
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: UIConstants.fireOrange.withOpacity(0.4),
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
// FIRE WISHLIST GAME CARD
// ============================================

class _FireWishlistGameCard extends StatelessWidget {
  const _FireWishlistGameCard({required this.game});

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
          color: UIConstants.bgSecondary.withOpacity(0.8),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          border: Border.all(
            color: UIConstants.fireYellow.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: UIConstants.fireYellow.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
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

                        // Wishlist badge with fire gradient
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                UIConstants.fireYellow.withOpacity(0.2),
                                UIConstants.fireOrange.withOpacity(0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: UIConstants.fireYellow.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                                ).createShader(bounds),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'İstek Listesi',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: UIConstants.fireYellow,
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
                    color: UIConstants.fireOrange.withOpacity(0.4),
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
// FIRE STATS ROW
// ============================================

class _FireStatsRow extends StatelessWidget {
  const _FireStatsRow({
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
          child: _FireStatItem(
            icon: Icons.games_rounded,
            value: gameCount.toString(),
            label: 'Oyun',
            gradient: UIConstants.fireGradient,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FireStatItem(
            icon: Icons.access_time_rounded,
            value: totalHours.toStringAsFixed(0),
            label: 'Saat',
            gradient: [UIConstants.fireOrange, UIConstants.fireRed],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FireStatItem(
            icon: Icons.link_rounded,
            value: platformCount.toString(),
            label: 'Platform',
            gradient: [UIConstants.fireYellow, UIConstants.fireOrange],
          ),
        ),
      ],
    );
  }
}

class _FireStatItem extends StatelessWidget {
  const _FireStatItem({
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
        color: UIConstants.bgSecondary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(
          color: gradient[0].withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(colors: gradient).createShader(bounds),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
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
// FIRE EMPTY STATES
// ============================================

class _FireNoPlatformLinkedState extends StatelessWidget {
  const _FireNoPlatformLinkedState();

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
                gradient: RadialGradient(
                  colors: [
                    UIConstants.fireOrange.withOpacity(0.2),
                    UIConstants.fireRed.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                ).createShader(bounds),
                child: const Icon(
                  Icons.link_off_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [UIConstants.fireYellow, UIConstants.fireOrange],
              ).createShader(bounds),
              child: const Text(
                'Platform Bağlayın',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
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
              final isSupported = platform.platform == GamePlatform.steam ||
                  platform.platform == GamePlatform.playstation;
              final isComingSoon = !isSupported;
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
                      : () {
                          if (platform.platform == GamePlatform.steam) {
                            showSteamLinkDialog(context);
                          } else if (platform.platform == GamePlatform.playstation) {
                            showPlayStationLinkDialog(context);
                          }
                        },
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
                      boxShadow: isComingSoon
                          ? null
                          : [
                              BoxShadow(
                                color: platform.activeColor.withOpacity(0.15),
                                blurRadius: 8,
                              ),
                            ],
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

class _FireEmptyLibraryState extends StatelessWidget {
  const _FireEmptyLibraryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  UIConstants.fireOrange.withOpacity(0.2),
                  UIConstants.fireRed.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [UIConstants.fireYellow, UIConstants.fireOrange],
              ).createShader(bounds),
              child: const Icon(
                Icons.games_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [UIConstants.fireYellow, UIConstants.fireOrange],
            ).createShader(bounds),
            child: const Text(
              'Kütüphane Boş',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bağlı platformlarınızda henüz oyun bulunmuyor.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _FireErrorState extends StatelessWidget {
  const _FireErrorState({
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
                gradient: RadialGradient(
                  colors: [
                    UIConstants.fireRed.withOpacity(0.2),
                    UIConstants.fireRed.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: UIConstants.fireRed,
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
                  gradient: LinearGradient(colors: UIConstants.fireGradient),
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: UIConstants.fireOrange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Tekrar Dene',
                  style: TextStyle(
                    color: Colors.white,
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

class _FireLoadingState extends StatelessWidget {
  const _FireLoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: UIConstants.fireOrange,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// FIRE LIBRARY GAME CARD
// ============================================

class _FireLibraryGameCard extends ConsumerWidget {
  const _FireLibraryGameCard({
    required this.game,
    required this.platforms,
  });

  final GameLog game;
  final Set<GamePlatform> platforms;

  String? get _coverUrl => game.game.coverUrlForGrid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playtimeHours = game.playtimeHours;
    final hasRating = game.rating != null;
    final canRate = playtimeHours >= 2;

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
          color: UIConstants.bgSecondary.withOpacity(0.8),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          border: Border.all(
            color: hasRating
                ? UIConstants.fireYellow.withOpacity(0.3)
                : UIConstants.fireOrange.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: hasRating
                  ? UIConstants.fireYellow.withOpacity(0.08)
                  : UIConstants.fireOrange.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
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

                        // Playtime and Rating row
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: UIConstants.fireOrange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${playtimeHours.toStringAsFixed(1)} saat',
                              style: TextStyle(
                                color: UIConstants.fireOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (hasRating) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: UIConstants.fireYellow,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${game.rating}/10',
                                style: TextStyle(
                                  color: UIConstants.fireYellow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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

                // Rate button (only if 2+ hours and not rated yet)
                if (canRate && !hasRating)
                  GestureDetector(
                    onTap: () => _showRatingDialog(context, ref),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            UIConstants.fireYellow.withOpacity(0.2),
                            UIConstants.fireOrange.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: UIConstants.fireYellow.withOpacity(0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: UIConstants.fireYellow.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                            ).createShader(bounds),
                            child: const Icon(
                              Icons.star_outline_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Değerlendir',
                            style: TextStyle(
                              color: UIConstants.fireYellow,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (hasRating)
                  // Edit rating button
                  GestureDetector(
                    onTap: () => _showRatingDialog(context, ref),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.edit_rounded,
                        color: UIConstants.fireYellow.withOpacity(0.6),
                        size: 18,
                      ),
                    ),
                  )
                else
                  // Chevron (not ratable yet)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: UIConstants.fireOrange.withOpacity(0.4),
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

  Future<void> _showRatingDialog(BuildContext context, WidgetRef ref) async {
    final ratingController = TextEditingController(
      text: game.rating?.toString() ?? '8',
    );
    final notesController = TextEditingController(
      text: game.notes ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
              color: UIConstants.bgSecondary.withOpacity(0.98),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            padding: EdgeInsets.only(
              left: UIConstants.pagePadding,
              right: UIConstants.pagePadding,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + UIConstants.pagePadding,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: UIConstants.fireGradient,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: UIConstants.fireOrange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Oyunu Değerlendir',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              game.game.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Rating input
                  Text(
                    'PUAN (1-10)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: UIConstants.fireYellow.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ratingController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '1-10 arası bir puan verin',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      prefixIcon: Icon(
                        Icons.star_rounded,
                        color: UIConstants.fireYellow,
                      ),
                      filled: true,
                      fillColor: UIConstants.bgTertiary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: UIConstants.fireYellow.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Notes input
                  Text(
                    'YORUM (OPSİYONEL)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: UIConstants.fireOrange.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Düşüncelerinizi yazın...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 48),
                        child: Icon(
                          Icons.note_rounded,
                          color: UIConstants.fireOrange,
                        ),
                      ),
                      filled: true,
                      fillColor: UIConstants.bgTertiary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: UIConstants.fireOrange.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  GestureDetector(
                    onTap: () async {
                      final rating = int.tryParse(ratingController.text);
                      if (rating == null || rating < 1 || rating > 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Lütfen 1-10 arası bir puan girin'),
                            backgroundColor: UIConstants.fireRed,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                        return;
                      }

                      try {
                        // Update the game log with rating and notes
                        final updatedLog = GameLog(
                          id: game.id,
                          game: game.game,
                          status: game.status,
                          rating: rating,
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          source: game.source,
                          steamAppId: game.steamAppId,
                          psnTitleId: game.psnTitleId,
                          playtimeMinutes: game.playtimeMinutes,
                          lastSyncedAt: game.lastSyncedAt,
                        );

                        await ref.read(libraryControllerProvider.notifier).upsertLog(updatedLog);

                        // Refresh combined library provider
                        ref.invalidate(combinedLibraryProvider);

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${game.game.name} için $rating/10 puan kaydedildi'),
                              backgroundColor: UIConstants.accentGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Hata: $e'),
                              backgroundColor: UIConstants.fireRed,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: UIConstants.fireGradient,
                        ),
                        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                        boxShadow: [
                          BoxShadow(
                            color: UIConstants.fireOrange.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Kaydet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================
// FIRE VALORANT STATS PANEL
// ============================================

/// Premium Valorant stats panel with fire theme
/// Shows rank, stats, and player info from Henrik API
class _FireValorantStatsPanel extends ConsumerWidget {
  const _FireValorantStatsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(valorantProfileProvider);

    return profileAsync.when(
      loading: () => _buildLoadingState(),
      error: (e, _) => _buildErrorState(),
      data: (profile) {
        if (profile == null) {
          return _buildNoDataState();
        }
        return _buildStatsPanel(profile);
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Center(
        child: CircularProgressIndicator(
          color: UIConstants.fireOrange,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: UIConstants.fireRed, size: 20),
          const SizedBox(width: 12),
          Text(
            'Valorant verileri yüklenemedi',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          ValorantIcon(size: 20, color: UIConstants.fireOrange),
          const SizedBox(width: 12),
          Text(
            'Valorant istatistikleri bulunamadı',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          UIConstants.bgSecondary.withOpacity(0.95),
          UIConstants.bgSecondary.withOpacity(0.85),
        ],
      ),
      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      border: Border.all(
        color: UIConstants.fireOrange.withOpacity(0.25),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: UIConstants.fireOrange.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildStatsPanel(ValorantProfile profile) {
    final account = profile.account;
    final mmr = profile.mmr;
    final stats = profile.stats;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Valorant branding
          _buildHeader(account),

          // Rank Card
          if (mmr != null) _buildRankCard(mmr),

          // Stats Grid
          if (stats != null) _buildStatsGrid(stats),

          // Most Played Info
          if (stats?.mostPlayedAgent != null || stats?.mostPlayedMap != null)
            _buildMostPlayedSection(stats!),
        ],
      ),
    );
  }

  Widget _buildHeader(ValorantAccount account) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            UIConstants.fireOrange.withOpacity(0.15),
            UIConstants.fireRed.withOpacity(0.08),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(UIConstants.radiusLarge - 1),
          topRight: Radius.circular(UIConstants.radiusLarge - 1),
        ),
      ),
      child: Row(
        children: [
          // Valorant Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [UIConstants.fireOrange, UIConstants.fireRed],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: UIConstants.fireOrange.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: ValorantIcon(size: 22, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),

          // Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                      ).createShader(bounds),
                      child: Text(
                        account.riotId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 12,
                      color: UIConstants.fireYellow.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Seviye ${account.accountLevel ?? 0}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Player Card Image
          if (account.cardUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                account.cardUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRankCard(ValorantMMR mmr) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            UIConstants.bgTertiary.withOpacity(0.8),
            UIConstants.bgTertiary.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: UIConstants.fireYellow.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Rank Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  UIConstants.fireYellow.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.network(
              mmr.rankIconUrl,
              width: 56,
              height: 56,
              errorBuilder: (_, __, ___) => Icon(
                Icons.military_tech_rounded,
                size: 40,
                color: UIConstants.fireYellow,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Rank Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mmr.currentTierPatched,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // RR Points
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: UIConstants.fireOrange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: UIConstants.fireOrange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${mmr.rankingInTier} RR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: UIConstants.fireOrange,
                        ),
                      ),
                    ),
                    if (mmr.mmrChangeToLastGame != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        mmr.mmrChangeToLastGame! >= 0
                            ? '+${mmr.mmrChangeToLastGame}'
                            : '${mmr.mmrChangeToLastGame}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: mmr.mmrChangeToLastGame! >= 0
                              ? UIConstants.accentGreen
                              : UIConstants.fireRed,
                        ),
                      ),
                    ],
                  ],
                ),
                // Peak Rank
                if (mmr.peakTierPatched != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 14,
                        color: UIConstants.fireYellow.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Peak: ${mmr.peakTierPatched}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (mmr.peakSeason != null) ...[
                        Text(
                          ' (${mmr.peakSeason})',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.35),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(ValorantPlayerStats stats) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatBox(
              label: 'Win Rate',
              value: '${stats.winRate.toStringAsFixed(1)}%',
              icon: Icons.trending_up_rounded,
              gradient: [UIConstants.accentGreen, UIConstants.accentGreen.withOpacity(0.7)],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatBox(
              label: 'K/D/A',
              value: stats.avgKda.toStringAsFixed(2),
              icon: Icons.gps_fixed_rounded,
              gradient: [UIConstants.fireOrange, UIConstants.fireRed],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatBox(
              label: 'HS%',
              value: '${stats.avgHeadshotPercent.toStringAsFixed(1)}%',
              icon: Icons.sports_mma_rounded,
              gradient: [UIConstants.fireYellow, UIConstants.fireOrange],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatBox(
              label: 'Maç',
              value: '${stats.totalMatches}',
              icon: Icons.sports_esports_rounded,
              gradient: [UIConstants.accentPurple, UIConstants.accentPurple.withOpacity(0.7)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMostPlayedSection(ValorantPlayerStats stats) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UIConstants.bgTertiary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (stats.mostPlayedAgent != null) ...[
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          UIConstants.fireOrange.withOpacity(0.2),
                          UIConstants.fireRed.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: UIConstants.fireOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Favori Ajan',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          stats.mostPlayedAgent!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (stats.mostPlayedAgent != null && stats.mostPlayedMap != null)
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.white.withOpacity(0.1),
            ),
          if (stats.mostPlayedMap != null) ...[
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          UIConstants.fireYellow.withOpacity(0.2),
                          UIConstants.fireOrange.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.map_rounded,
                      size: 18,
                      color: UIConstants.fireYellow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Favori Harita',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          stats.mostPlayedMap!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Individual stat box for the stats grid
class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: UIConstants.bgTertiary.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: gradient[0].withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(colors: gradient).createShader(bounds),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.45),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

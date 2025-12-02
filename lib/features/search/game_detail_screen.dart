import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/ui_constants.dart';
import '../../data/igdb_client.dart';
import '../../models/game.dart';
import '../../models/game_log.dart';
import '../library/library_controller.dart';
import '../steam_library/steam_library_provider.dart';

// UUID generator for creating new game log IDs
const _uuid = Uuid();

final gameDetailProvider = FutureProvider.family<Game?, int>((ref, id) async {
  return ref.read(igdbClientProvider).fetchGameById(id);
});

/// Provider to check if a game is in ANY library (manual OR Steam)
/// Now also includes name-based matching for better accuracy
final isGameInAnyLibraryProvider =
    Provider.family<bool, int>((ref, gameId) {
  // Check manual library
  final manualGames = ref.watch(libraryControllerProvider).valueOrNull ?? [];
  final isInManual = manualGames.any((log) => log.game.id == gameId);

  // Check Steam library
  final steamGames = ref.watch(steamLibraryProvider).valueOrNull ?? [];
  final isInSteam = steamGames.any((log) => log.game.id == gameId);

  return isInManual || isInSteam;
});

/// Provider to check if a game is in ANY library by name (for search results)
final isGameInAnyLibraryByNameProvider =
    Provider.family<bool, String>((ref, gameName) {
  final normalizedName = gameName.toLowerCase().trim();

  // Check manual library
  final manualGames = ref.watch(libraryControllerProvider).valueOrNull ?? [];
  final isInManual = manualGames.any(
    (log) => log.game.name.toLowerCase().trim() == normalizedName,
  );

  // Check Steam library
  final steamGames = ref.watch(steamLibraryProvider).valueOrNull ?? [];
  final isInSteam = steamGames.any(
    (log) => log.game.name.toLowerCase().trim() == normalizedName,
  );

  return isInManual || isInSteam;
});

String _formatDate(DateTime date) {
  final months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({super.key, required this.game});

  final Game game;

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Check if two game names are similar enough to be considered the same game
  bool _namesAreSimilar(String name1, String name2) {
    final n1 = name1.toLowerCase().trim();
    final n2 = name2.toLowerCase().trim();
    if (n1 == n2) return true;
    if (n1.contains(n2) || n2.contains(n1)) return true;
    final w1 = n1.split(RegExp(r'[\s:]+'));
    final w2 = n2.split(RegExp(r'[\s:]+'));
    if (w1.isNotEmpty && w2.isNotEmpty && w1.first == w2.first) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(gameDetailProvider(widget.game.id));
    final igdbGame = detailAsync.valueOrNull;

    final detail = (igdbGame != null && _namesAreSimilar(widget.game.name, igdbGame.name))
        ? igdbGame
        : widget.game;

    final existingLog = ref
        .watch(libraryControllerProvider)
        .valueOrNull
        ?.where((l) => l.game.id == widget.game.id)
        .firstOrNull;
    final isInLibrary = existingLog != null;

    final isInAnyLibrary = ref.watch(isGameInAnyLibraryProvider(widget.game.id));

    // Check if game can be rated (must be in library with 2+ hours)
    final ratingCheck = ref.watch(canRateGameProvider(widget.game.id));

    final double parallaxOffset = (_scrollOffset * 0.5).clamp(0.0, 100.0);
    final double opacity = (1.0 - (_scrollOffset / 200)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: UIConstants.bgPrimary,
      body: Stack(
        children: [
          // Main content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Parallax header
              SliverAppBar(
                expandedHeight: 420,
                pinned: true,
                elevation: 0,
                backgroundColor: UIConstants.bgPrimary,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: UIConstants.bgSecondary.withOpacity(0.9),
                      shape: BoxShape.circle,
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
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background image with parallax
                      Transform.translate(
                        offset: Offset(0, -parallaxOffset),
                        child: Hero(
                          tag: 'game-cover-${widget.game.id}',
                          child: detail.coverUrlForDetail != null
                              ? CachedNetworkImage(
                                  imageUrl: detail.coverUrlForDetail!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: UIConstants.bgSecondary,
                                  ),
                                )
                              : Container(
                                  color: UIConstants.bgSecondary,
                                  child: const Icon(
                                    Icons.videogame_asset_rounded,
                                    size: 80,
                                    color: Colors.white24,
                                  ),
                                ),
                        ),
                      ),

                      // Gradient overlays
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                UIConstants.bgPrimary.withOpacity(0.3),
                                UIConstants.bgPrimary.withOpacity(0.8),
                                UIConstants.bgPrimary,
                              ],
                              stops: const [0.0, 0.4, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Game title at bottom
                      Positioned(
                        left: UIConstants.pagePadding,
                        right: UIConstants.pagePadding,
                        bottom: 20,
                        child: Opacity(
                          opacity: opacity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Accent line above title
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: UIConstants.fireGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: UIConstants.fireOrange.withOpacity(0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Game title
                              Text(
                                detail.name,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Badges row
                              Row(
                                children: [
                                  // Release date badge
                                  if (detail.releaseDate != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            UIConstants.fireOrange.withOpacity(0.2),
                                            UIConstants.fireRed.withOpacity(0.15),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: UIConstants.fireOrange.withOpacity(0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 12,
                                            color: UIConstants.fireOrange,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _formatDate(detail.releaseDate!),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: UIConstants.fireOrange,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  // In Library badge
                                  if (isInAnyLibrary)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: UIConstants.accentGreen.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: UIConstants.accentGreen.withOpacity(0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 14,
                                            color: UIConstants.accentGreen,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Kütüphanede',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: UIConstants.accentGreen,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    UIConstants.pagePadding,
                    UIConstants.pagePadding,
                    UIConstants.pagePadding,
                    120,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating cards
                      if (detail.aggregatedRating != null ||
                          detail.userRating != null ||
                          detail.metacriticScore != null)
                        _RatingSection(game: detail)
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 500.ms)
                            .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: UIConstants.sectionSpacing),

                      // Platform icons
                      if (detail.platforms.isNotEmpty)
                        _PlatformSection(platforms: detail.platforms)
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 500.ms)
                            .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: UIConstants.sectionSpacing),

                      // Genres
                      if (detail.genres.isNotEmpty)
                        _GenreSection(genres: detail.genres)
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 500.ms)
                            .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: UIConstants.sectionSpacing),

                      // Summary
                      if (detail.summary != null)
                        _SummarySection(summary: detail.summary!)
                            .animate()
                            .fadeIn(delay: 500.ms, duration: 500.ms)
                            .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: UIConstants.sectionSpacing),

                      // Screenshots
                      if (detail.screenshotUrls.isNotEmpty)
                        _ScreenshotSection(screenshots: detail.screenshotUrls)
                            .animate()
                            .fadeIn(delay: 600.ms, duration: 500.ms)
                            .slideY(begin: 0.1, end: 0),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom action button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(UIConstants.pagePadding),
                  decoration: BoxDecoration(
                    color: UIConstants.bgSecondary.withOpacity(0.9),
                    border: Border(
                      top: BorderSide(
                        color: UIConstants.fireOrange.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: GestureDetector(
                      onTap: () => _showAddDialog(context, ref, detail, existingLog, ratingCheck.canRate),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isInLibrary
                                ? [UIConstants.fireOrange, UIConstants.fireRed]
                                : (isInAnyLibrary ? UIConstants.fireGradient : [UIConstants.fireYellow, UIConstants.fireOrange]),
                          ),
                          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                          boxShadow: [
                            BoxShadow(
                              color: UIConstants.fireOrange.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isInLibrary
                                  ? Icons.edit_rounded
                                  : (isInAnyLibrary ? Icons.add_rounded : Icons.favorite_rounded),
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isInLibrary
                                  ? 'Düzenle'
                                  : (isInAnyLibrary ? 'Koleksiyona Ekle' : 'İstek Listesine Ekle'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref, Game game, GameLog? existingLog, bool canRate) async {
    final isEditing = existingLog != null;
    final isInAnyLibrary = ref.read(isGameInAnyLibraryProvider(game.id));
    final ratingController = TextEditingController(
      text: existingLog?.rating?.toString() ?? '8',
    );
    final noteController = TextEditingController(
      text: existingLog?.notes ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // If game is not in any library, default to wishlist and only allow wishlist
        PlayStatus selectedStatus = isInAnyLibrary
            ? (existingLog?.status ?? PlayStatus.completed)
            : PlayStatus.wishlist;

        return StatefulBuilder(
          builder: (context, setState) {
            final showRating = selectedStatus != PlayStatus.wishlist;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                              child: Icon(
                                isEditing ? Icons.edit_rounded : Icons.add_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              isEditing ? 'Oyunu Düzenle' : 'Kütüphaneye Ekle',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Info banner for games not in library
                        if (!isInAnyLibrary) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  UIConstants.fireOrange.withOpacity(0.1),
                                  UIConstants.fireRed.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: UIConstants.fireOrange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        UIConstants.fireOrange.withOpacity(0.2),
                                        UIConstants.fireRed.withOpacity(0.15),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    color: UIConstants.fireOrange,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Bu oyun kütüphanenizde yok',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Değerlendirme yapabilmek için oyuna sahip olmalı ve en az 2 saat oynamış olmalısınız.',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Status Selection
                        Text(
                          'DURUM',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Show only wishlist if game is not in library
                        if (!isInAnyLibrary) ...[
                          _StatusChip(
                            icon: Icons.favorite_rounded,
                            label: 'İstek Listesine Ekle',
                            selected: true,
                            onTap: () {},
                            color: UIConstants.accentYellow,
                          ),
                        ] else ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StatusChip(
                                icon: Icons.favorite_rounded,
                                label: 'İstek Listesi',
                                selected: selectedStatus == PlayStatus.wishlist,
                                onTap: () => setState(() => selectedStatus = PlayStatus.wishlist),
                                color: UIConstants.accentYellow,
                              ),
                              _StatusChip(
                                icon: Icons.play_circle_rounded,
                                label: 'Oynuyor',
                                selected: selectedStatus == PlayStatus.playing,
                                onTap: () => setState(() => selectedStatus = PlayStatus.playing),
                                color: UIConstants.fireOrange,
                              ),
                              _StatusChip(
                                icon: Icons.check_circle_rounded,
                                label: 'Tamamlandı',
                                selected: selectedStatus == PlayStatus.completed,
                                onTap: () => setState(() => selectedStatus = PlayStatus.completed),
                                color: UIConstants.accentGreen,
                              ),
                              _StatusChip(
                                icon: Icons.cancel_rounded,
                                label: 'Bırakıldı',
                                selected: selectedStatus == PlayStatus.dropped,
                                onTap: () => setState(() => selectedStatus = PlayStatus.dropped),
                                color: UIConstants.accentRed,
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Rating (only if not wishlist AND can rate - 2+ hours in library)
                        if (showRating && canRate) ...[
                          _buildTextField(
                            controller: ratingController,
                            label: 'Puan (1-10)',
                            hint: 'Oyuna verdiğin puan',
                            icon: Icons.star_rounded,
                            iconColor: UIConstants.accentYellow,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                        ] else if (showRating && !canRate) ...[
                          // Show info that rating requires 2+ hours
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  UIConstants.fireYellow.withOpacity(0.1),
                                  UIConstants.fireOrange.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: UIConstants.fireYellow.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: UIConstants.fireYellow,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Değerlendirme yapabilmek için bu oyunu en az 2 saat oynamış olmalısınız',
                                    style: TextStyle(
                                      color: UIConstants.fireYellow,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Notes (only show if game is in library)
                        if (isInAnyLibrary) ...[
                          _buildTextField(
                            controller: noteController,
                            label: 'Yorum / Not (opsiyonel)',
                            hint: 'Düşüncelerini yaz...',
                            icon: Icons.note_rounded,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Action Buttons
                        Row(
                          children: [
                            // Save Button (no delete - games cannot be removed from library)
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  // Rating is only allowed if canRate is true (2+ hours in library)
                                  final rating = (showRating && canRate) ? int.tryParse(ratingController.text) : null;
                                  final clampedRating = rating == null ? null : rating.clamp(1, 10);

                                  try {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text('Kaydediliyor...'),
                                          ],
                                        ),
                                        backgroundColor: UIConstants.bgTertiary,
                                        duration: const Duration(seconds: 30),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );

                                    await ref.read(libraryControllerProvider.notifier).upsertLog(
                                          GameLog(
                                            id: existingLog?.id ?? _uuid.v4(),
                                            game: game,
                                            status: selectedStatus,
                                            rating: clampedRating,
                                            notes: noteController.text.trim().isEmpty
                                                ? null
                                                : noteController.text.trim(),
                                          ),
                                        );

                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(_getStatusMessage(selectedStatus)),
                                        backgroundColor: UIConstants.accentGreen,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Hata: $e'),
                                        backgroundColor: UIConstants.accentRed,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
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
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    Color? iconColor,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: UIConstants.bgTertiary,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(
          color: UIConstants.fireOrange.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: iconColor ?? UIConstants.fireOrange),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  String _getStatusMessage(PlayStatus status) {
    switch (status) {
      case PlayStatus.wishlist:
        return 'İstek listesine eklendi';
      case PlayStatus.playing:
        return 'Oynuyor olarak işaretlendi';
      case PlayStatus.completed:
        return 'Koleksiyona eklendi';
      case PlayStatus.dropped:
        return 'Bırakıldı olarak işaretlendi';
      case PlayStatus.backlog:
        return 'Backlog\'a eklendi';
    }
  }
}

// ============================================
// SECTION HEADER WIDGET
// ============================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.accentColor,
  });

  final String title;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? UIConstants.fireOrange;
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: accentColor != null
                  ? [accentColor!, accentColor!.withOpacity(0.7)]
                  : [UIConstants.fireYellow, UIConstants.fireOrange],
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

// ============================================
// RATING SECTION
// ============================================

class _RatingSection extends StatelessWidget {
  const _RatingSection({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Puanlar'),
        const SizedBox(height: 16),
        Row(
          children: [
            if (game.metacriticScore != null)
              Expanded(
                child: _RatingCard(
                  label: 'Metacritic',
                  score: game.metacriticScore!.toDouble(),
                  icon: Icons.sports_esports_rounded,
                  gradient: _getMetacriticGradient(game.metacriticScore!),
                ),
              ),
            if (game.metacriticScore != null && game.userRating != null)
              const SizedBox(width: 12),
            if (game.userRating != null)
              Expanded(
                child: _RatingCard(
                  label: 'IGDB',
                  score: game.userRating!,
                  icon: Icons.people_rounded,
                  gradient: UIConstants.fireGradient,
                  count: game.ratingCount,
                ),
              ),
          ],
        ),
      ],
    );
  }

  List<Color> _getMetacriticGradient(int score) {
    if (score >= 75) return UIConstants.greenGradient;
    if (score >= 50) return UIConstants.yellowGradient;
    return UIConstants.redGradient;
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.label,
    required this.score,
    required this.icon,
    required this.gradient,
    this.count,
  });

  final String label;
  final double score;
  final IconData icon;
  final List<Color> gradient;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UIConstants.cardPadding),
      decoration: BoxDecoration(
        color: UIConstants.bgSecondary,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(
          color: gradient[0].withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Icon with gradient background
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          // Score
          Text(
            score.round().toString(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
              shadows: [
                Shadow(
                  color: gradient[0].withOpacity(0.5),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          if (count != null) ...[
            const SizedBox(height: 4),
            Text(
              '$count oy',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================
// PLATFORM SECTION
// ============================================

class _PlatformSection extends StatelessWidget {
  const _PlatformSection({required this.platforms});

  final List<String> platforms;

  IconData _getPlatformIcon(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('playstation') || lower.contains('ps5') || lower.contains('ps4')) {
      return FontAwesomeIcons.playstation;
    }
    if (lower.contains('xbox')) return FontAwesomeIcons.xbox;
    if (lower.contains('switch') || lower.contains('nintendo')) {
      return FontAwesomeIcons.gamepad;
    }
    if (lower.contains('pc') || lower.contains('windows') || lower.contains('steam')) {
      return FontAwesomeIcons.steam;
    }
    if (lower.contains('mac') || lower.contains('macos')) return FontAwesomeIcons.apple;
    if (lower.contains('linux')) return FontAwesomeIcons.linux;
    if (lower.contains('ios')) return FontAwesomeIcons.appStore;
    if (lower.contains('android')) return FontAwesomeIcons.android;
    return FontAwesomeIcons.gamepad;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Platformlar', accentColor: UIConstants.fireOrange),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: platforms.take(8).map((platform) {
            final icon = _getPlatformIcon(platform);
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: UIConstants.bgSecondary,
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(
                    icon,
                    size: 16,
                    color: UIConstants.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    platform,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: UIConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ============================================
// GENRE SECTION
// ============================================

class _GenreSection extends StatelessWidget {
  const _GenreSection({required this.genres});

  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Türler', accentColor: UIConstants.fireOrange),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: genres.asMap().entries.map((entry) {
            final index = entry.key;
            final genre = entry.value;
            // Rotate through fire accent colors
            final gradients = [
              UIConstants.fireGradient,
              [UIConstants.fireOrange, UIConstants.fireRed],
              [UIConstants.fireYellow, UIConstants.fireOrange],
              UIConstants.greenGradient,
            ];
            final gradient = gradients[index % gradients.length];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: gradient[0].withOpacity(0.15),
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                border: Border.all(
                  color: gradient[0].withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                genre,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: gradient[0],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ============================================
// SUMMARY SECTION
// ============================================

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Hakkında'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(UIConstants.cardPadding),
          decoration: BoxDecoration(
            color: UIConstants.bgSecondary,
            borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Text(
            summary,
            style: TextStyle(
              fontSize: 15,
              height: 1.7,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================
// SCREENSHOT SECTION
// ============================================

class _ScreenshotSection extends StatelessWidget {
  const _ScreenshotSection({required this.screenshots});

  final List<String> screenshots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Ekran Görüntüleri', accentColor: UIConstants.accentGreen),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: screenshots.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withOpacity(0.95),
                    builder: (context) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          Center(
                            child: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: CachedNetworkImage(
                                imageUrl: screenshots[index],
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 50,
                            right: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: UIConstants.bgSecondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 30,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: UIConstants.bgSecondary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${index + 1} / ${screenshots.length}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < screenshots.length - 1 ? 12 : 0,
                  ),
                  width: 320,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                        child: CachedNetworkImage(
                          imageUrl: screenshots[index],
                          fit: BoxFit.cover,
                          width: 320,
                          height: 200,
                          placeholder: (context, url) => Container(
                            color: UIConstants.bgSecondary,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: UIConstants.fireOrange,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Fullscreen hint
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: UIConstants.bgPrimary.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================
// STATUS CHIP WIDGET
// ============================================

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : UIConstants.bgTertiary,
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.1),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? color : Colors.white.withOpacity(0.4),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.white.withOpacity(0.4),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

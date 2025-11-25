import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/igdb_client.dart';
import '../../models/game.dart';
import '../../models/game_log.dart';
import '../library/library_controller.dart';

// UUID generator for creating new game log IDs
const _uuid = Uuid();

final gameDetailProvider = FutureProvider.family<Game?, int>((ref, id) async {
  return ref.read(igdbClientProvider).fetchGameById(id);
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

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(gameDetailProvider(widget.game.id));
    final detail = detailAsync.value ?? widget.game;

    // AsyncValue olduğu için valueOrNull ile veriyi al
    final existingLog = ref
        .watch(libraryControllerProvider)
        .valueOrNull
        ?.where((l) => l.game.id == widget.game.id)
        .firstOrNull;
    final isInLibrary = existingLog != null;

    // Calculate parallax effect
    final double parallaxOffset = (_scrollOffset * 0.5).clamp(0.0, 100.0);
    final double opacity = (1.0 - (_scrollOffset / 200)).clamp(0.0, 1.0);

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Parallax header
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                          child: detail.coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: detail.coverUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: AppTheme.charcoal,
                                  ),
                                )
                              : Container(
                                  color: AppTheme.charcoal,
                                  child: const Icon(
                                    Icons.videogame_asset,
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
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.7),
                                Theme.of(context).scaffoldBackgroundColor,
                              ],
                              stops: const [0.0, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Game title at bottom
                      Positioned(
                        left: pagePadding,
                        right: pagePadding,
                        bottom: 20,
                        child: Opacity(
                          opacity: opacity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detail.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.8),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                              ),
                              if (detail.releaseDate != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _formatDate(detail.releaseDate!),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.8),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                    pagePadding,
                    pagePadding,
                    pagePadding,
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
                            .fadeIn(delay: 200.ms, duration: 600.ms)
                            .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 24),

                      // Platform icons
                      if (detail.platforms.isNotEmpty)
                        _PlatformSection(platforms: detail.platforms)
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 600.ms)
                            .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 24),

                      // Genres
                      if (detail.genres.isNotEmpty)
                        _GenreSection(genres: detail.genres)
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 600.ms)
                            .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 24),

                      // Summary
                      if (detail.summary != null)
                        _SummarySection(summary: detail.summary!)
                            .animate()
                            .fadeIn(delay: 500.ms, duration: 600.ms)
                            .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 24),

                      // Screenshots
                      if (detail.screenshotUrls.isNotEmpty)
                        _ScreenshotSection(screenshots: detail.screenshotUrls)
                            .animate()
                            .fadeIn(delay: 600.ms, duration: 600.ms)
                            .slideY(begin: 0.1, end: 0),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom action button with glassmorphism
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(pagePadding),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoal.withOpacity(0.8),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: FilledButton.icon(
                      onPressed: () => _showAddDialog(context, ref, detail, existingLog),
                      icon: Icon(isInLibrary ? Icons.edit : Icons.add),
                      label: Text(
                        isInLibrary ? 'Düzenle' : 'Koleksiyona Ekle',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
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

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref, Game game, GameLog? existingLog) async {
    final isEditing = existingLog != null;
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
        // selectedStatus MUST be outside StatefulBuilder to persist
        PlayStatus selectedStatus = existingLog?.status ?? PlayStatus.completed;

        return StatefulBuilder(
          builder: (context, setState) {
            final showRating = selectedStatus != PlayStatus.wishlist;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.charcoal.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: pagePadding,
                    right: pagePadding,
                    top: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + pagePadding,
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
                                color: AppTheme.accentGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isEditing ? Icons.edit : Icons.add_circle_outline,
                                color: AppTheme.accentGold,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                isEditing ? 'Oyunu Düzenle' : 'Kütüphaneye Ekle',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Status Selection
                        Text(
                          'Durum',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.grey[400],
                              ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusChip(
                              label: '❤️ İstek Listesi',
                              selected: selectedStatus == PlayStatus.wishlist,
                              onTap: () => setState(() => selectedStatus = PlayStatus.wishlist),
                              color: Colors.orange,
                            ),
                            _StatusChip(
                              label: '🎮 Oynuyor',
                              selected: selectedStatus == PlayStatus.playing,
                              onTap: () => setState(() => selectedStatus = PlayStatus.playing),
                              color: Colors.blue,
                            ),
                            _StatusChip(
                              label: '✅ Tamamlandı',
                              selected: selectedStatus == PlayStatus.completed,
                              onTap: () => setState(() => selectedStatus = PlayStatus.completed),
                              color: Colors.green,
                            ),
                            _StatusChip(
                              label: '❌ Bırakıldı',
                              selected: selectedStatus == PlayStatus.dropped,
                              onTap: () => setState(() => selectedStatus = PlayStatus.dropped),
                              color: Colors.red,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Rating (only if not wishlist)
                        if (showRating) ...[
                          TextField(
                            controller: ratingController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Puan (1-10)',
                              helperText: 'Oyuna verdiğin puan',
                              prefixIcon: Icon(Icons.star, color: Colors.amber),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Notes
                        TextField(
                          controller: noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Yorum / Not (opsiyonel)',
                            prefixIcon: Icon(Icons.note_outlined),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            // Delete Button (only when editing)
                            if (isEditing) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    // Confirm deletion
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Oyunu Sil'),
                                        content: const Text(
                                          'Bu oyunu kütüphanenden silmek istediğinden emin misin?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('İptal'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text('Sil'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true && existingLog != null) {
                                      ref.read(libraryControllerProvider.notifier).deleteLog(existingLog.id);
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Oyun kütüphaneden silindi'),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Sil'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    minimumSize: const Size(0, 56),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            // Save Button
                            Expanded(
                              flex: isEditing ? 2 : 1,
                              child: FilledButton(
                                onPressed: () {
                                  // Rating only if not wishlist
                                  final rating = showRating ? int.tryParse(ratingController.text) : null;
                                  final clampedRating = rating == null ? null : rating.clamp(1, 10);

                                  ref.read(libraryControllerProvider.notifier).upsertLog(
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
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_getStatusMessage(selectedStatus)),
                                      backgroundColor: AppTheme.accentGold,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 56),
                                ),
                                child: const Text('Kaydet'),
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
    }
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Puanlar',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (game.metacriticScore != null)
              Expanded(
                child: _GlassRatingCard(
                  label: 'Metacritic',
                  score: game.metacriticScore!.toDouble(),
                  icon: Icons.sports_esports,
                  color: _getMetacriticColor(game.metacriticScore!),
                ),
              ),
            if (game.metacriticScore != null && game.userRating != null)
              const SizedBox(width: 12),
            if (game.userRating != null)
              Expanded(
                child: _GlassRatingCard(
                  label: 'IGDB',
                  score: game.userRating!,
                  icon: Icons.people,
                  color: Colors.blue,
                  count: game.ratingCount,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _getMetacriticColor(int score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.yellow.shade700;
    return Colors.red;
  }
}

class _GlassRatingCard extends StatelessWidget {
  const _GlassRatingCard({
    required this.label,
    required this.score,
    required this.icon,
    required this.color,
    this.count,
  });

  final String label;
  final double score;
  final IconData icon;
  final Color color;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.darkGray.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                score.round().toString(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white60,
                    ),
              ),
              if (count != null) ...[
                const SizedBox(height: 4),
                Text(
                  '$count oy',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withOpacity(0.4),
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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

  Color _getPlatformColor(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('playstation')) return const Color(0xFF003791);
    if (lower.contains('xbox')) return const Color(0xFF107C10);
    if (lower.contains('switch') || lower.contains('nintendo')) {
      return const Color(0xFFE60012);
    }
    if (lower.contains('pc') || lower.contains('windows') || lower.contains('steam')) {
      return const Color(0xFF1B2838);
    }
    if (lower.contains('mac')) return const Color(0xFF000000);
    if (lower.contains('linux')) return const Color(0xFFFCC624);
    if (lower.contains('ios')) return const Color(0xFF0A84FF);
    if (lower.contains('android')) return const Color(0xFF3DDC84);
    return AppTheme.mediumGray;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platformlar',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: platforms.take(8).map((platform) {
            final icon = _getPlatformIcon(platform);
            final color = _getPlatformColor(platform);
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(
                        icon,
                        size: 20,
                        color: color,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        platform.length > 12
                            ? platform.substring(0, 12)
                            : platform,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _GenreSection extends StatelessWidget {
  const _GenreSection({required this.genres});

  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Türler',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: genres.map((genre) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentGold.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                genre,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentGold,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hakkında',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.darkGray.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                summary,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.8,
                      color: Colors.white70,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScreenshotSection extends StatelessWidget {
  const _ScreenshotSection({required this.screenshots});

  final List<String> screenshots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ekran Görüntüleri',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: screenshots.length,
            itemBuilder: (context, index) {
              return Container(
                margin: EdgeInsets.only(
                  right: index < screenshots.length - 1 ? 12 : 0,
                ),
                width: 320,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: screenshots[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.darkGray,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
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
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
          border: Border.all(
            color: selected ? color : Colors.grey.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.grey[400],
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

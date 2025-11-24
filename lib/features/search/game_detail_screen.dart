import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../data/igdb_client.dart';
import '../../models/game.dart';
import '../../models/game_log.dart';
import '../library/library_controller.dart';

final gameDetailProvider = FutureProvider.family<Game?, int>((ref, id) async {
  return ref.read(igdbClientProvider).fetchGameById(id);
});

class GameDetailScreen extends ConsumerWidget {
  const GameDetailScreen({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(gameDetailProvider(game.id));
    final detail = detailAsync.value ?? game;
    final existingLog = ref.watch(libraryControllerProvider.select(
      (logs) => logs.firstWhere(
        (l) => l.game.id == game.id,
        orElse: () => const GameLog(
          id: '',
          game: Game(id: 0, name: ''),
          status: PlayStatus.wishlist,
        ),
      ),
    ));
    final isInLibrary = existingLog.id.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(pagePadding, pagePadding, pagePadding, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CoverImage(url: detail.coverUrl),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
                        ),
                        const SizedBox(height: 6),
                        if (detail.platforms.isNotEmpty)
                          _PlatformRow(platforms: detail.platforms),
                        if (detail.genres.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _PillWrap(
                              label: 'Tür',
                              values: detail.genres,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (detail.aggregatedRating != null)
                              _RatingBadge(
                                label: 'Metacritic',
                                value: detail.aggregatedRating!,
                                color: Colors.amber,
                              ),
                            if (detail.userRating != null)
                              _RatingBadge(
                                label: 'Kullanıcı',
                                value: detail.userRating!,
                                color: Colors.blueAccent,
                                count: detail.ratingCount,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (detail.summary != null)
                Text(
                  detail.summary!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.5, color: Colors.white70),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, pagePadding),
        child: FilledButton.icon(
          onPressed: isInLibrary ? null : () => _showAddDialog(context, ref, detail),
          icon: Icon(isInLibrary ? Icons.check : Icons.add),
          label: Text(isInLibrary ? 'Koleksiyonda' : 'Koleksiyona ekle'),
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref, Game game) async {
    final ratingController = TextEditingController(text: '8');
    final noteController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: pagePadding,
            right: pagePadding,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Koleksiyona ekle',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ratingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Puan (1-10)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Yorum / Not',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final rating = int.tryParse(ratingController.text);
                    final clampedRating = rating == null
                        ? null
                        : rating.clamp(1, 10);
                    ref.read(libraryControllerProvider.notifier).upsertLog(
                          GameLog(
                            id: 'game-${game.id}',
                            game: game,
                            status: PlayStatus.completed,
                            rating: clampedRating,
                            notes: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                          ),
                        );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Koleksiyona eklendi')),
                    );
                  },
                  child: const Text('Kaydet'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    if (url == null) {
      return Container(
        width: 110,
        height: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: radius,
        ),
        child: const Icon(Icons.videogame_asset, size: 40),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url!,
        width: 110,
        height: 150,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _PillWrap extends StatelessWidget {
  const _PillWrap({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final chips = values.take(4).map((value) {
      return Chip(
        label: Text(value),
        visualDensity: VisualDensity.compact,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: -4,
          children: chips,
        ),
      ],
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({
    required this.label,
    required this.value,
    this.count,
    this.color,
  });

  final String label;
  final double value;
  final int? count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final score = value.round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count != null ? '$label $score (${count}r)' : '$label $score',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({required this.platforms});
  final List<String> platforms;

  ({String label, Color color}) _badgeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('playstation')) return (label: 'PS', color: const Color(0xFF003791));
    if (lower.contains('xbox')) return (label: 'Xbox', color: const Color(0xFF107C10));
    if (lower.contains('switch') || lower.contains('nintendo')) {
      return (label: 'Switch', color: const Color(0xFFE60012));
    }
    if (lower.contains('pc') || lower.contains('windows') || lower.contains('steam')) {
      return (label: 'PC', color: const Color(0xFF999999));
    }
    if (lower.contains('mac')) return (label: 'Mac', color: const Color(0xFF666666));
    if (lower.contains('linux')) return (label: 'Linux', color: const Color(0xFF6CBB5A));
    if (lower.contains('ios')) return (label: 'iOS', color: const Color(0xFFA2AAAD));
    if (lower.contains('android')) return (label: 'Android', color: const Color(0xFF3DDC84));
    return (label: name.length > 8 ? name.substring(0, 8) : name, color: const Color(0xFF444444));
  }

  @override
  Widget build(BuildContext context) {
    final chips = platforms.take(6).map((p) {
      final badge = _badgeFor(p);
      return Chip(
        backgroundColor: badge.color,
        label: Text(
          badge.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      );
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Platformlar', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: -4,
          children: chips,
        ),
      ],
    );
  }
}

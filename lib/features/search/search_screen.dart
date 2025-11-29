import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/ui_constants.dart';
import '../library/library_controller.dart';
import 'game_detail_screen.dart';
import 'search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  static const _minChars = 4;
  static const _debounceDuration = Duration(milliseconds: 350);

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    await ref.read(searchControllerProvider.notifier).search(_queryController.text);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < _minChars) {
      ref.read(searchControllerProvider.notifier).search('');
      return;
    }
    _debounce = Timer(_debounceDuration, _runSearch);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchControllerProvider);

    return Scaffold(
      backgroundColor: UIConstants.bgPrimary,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: _SearchHeader(),
            ),

            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _SearchBar(
                  controller: _queryController,
                  focusNode: _focusNode,
                  onChanged: _onQueryChanged,
                  onSubmitted: (_) => _runSearch(),
                ),
              ),
            ),

            // Loading indicator
            if (searchState.isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      backgroundColor: UIConstants.bgSecondary,
                      valueColor: AlwaysStoppedAnimation(UIConstants.accentPurple),
                      minHeight: 3,
                    ),
                  ),
                ),
              ),

            // Error message
            if (searchState.hasError)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: UIConstants.accentRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                      border: Border.all(
                        color: UIConstants.accentRed.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: UIConstants.accentRed,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            searchState.error.toString(),
                            style: const TextStyle(color: UIConstants.accentRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Results
            searchState.when(
              data: (results) {
                if (results.isEmpty && _queryController.text.trim().length >= _minChars) {
                  return SliverFillRemaining(
                    child: _NoResultsState(),
                  );
                }

                if (results.isEmpty) {
                  final trendingAsync = ref.watch(trendingGamesProvider);
                  return trendingAsync.when(
                    data: (trendingGames) {
                      if (trendingGames.isEmpty) {
                        return SliverFillRemaining(
                          child: _EmptySearchState(),
                        );
                      }
                      return _TrendingGamesSection(games: trendingGames);
                    },
                    loading: () => SliverFillRemaining(
                      child: const Center(
                        child: CircularProgressIndicator(color: UIConstants.accentPurple),
                      ),
                    ),
                    error: (error, _) => SliverFillRemaining(
                      child: _ErrorState(message: error.toString()),
                    ),
                  );
                }

                final library = ref.watch(libraryControllerProvider).valueOrNull ?? [];
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final game = results[index];
                        final inLibrary = library.any((log) => log.game.id == game.id);
                        return _GameCard(
                          game: game,
                          inLibrary: inLibrary,
                          index: index,
                        );
                      },
                      childCount: results.length,
                    ),
                  ),
                );
              },
              loading: () => SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const _ShimmerGameCard(),
                    childCount: 5,
                  ),
                ),
              ),
              error: (error, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: UIConstants.accentPurple,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'OYUN ARA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: UIConstants.bgSecondary,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(
          color: UIConstants.accentPurple.withOpacity(0.2),
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Oyun ara (min. 4 karakter)',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 15,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: UIConstants.accentPurple,
            size: 22,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: Colors.white.withOpacity(0.5),
                    size: 20,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }
}

class _TrendingGamesSection extends ConsumerWidget {
  const _TrendingGamesSection({required this.games});

  final List<dynamic> games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider).valueOrNull ?? [];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: UIConstants.purpleGradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.trending_up_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Trend Oyunlar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: UIConstants.accentPurple.withOpacity(0.6),
                      size: 18,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
            }

            final game = games[index - 1];
            final inLibrary = library.any((log) => log.game.id == game.id);
            return _GameCard(
              game: game,
              inLibrary: inLibrary,
              index: index - 1,
            );
          },
          childCount: games.length + 1,
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.inLibrary,
    required this.index,
  });

  final dynamic game;
  final bool inLibrary;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(game: game),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: UIConstants.bgSecondary,
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          border: Border.all(
            color: inLibrary
                ? UIConstants.accentGreen.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover image
              Hero(
                tag: 'game-cover-${game.id}',
                child: Container(
                  width: 75,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: UIConstants.accentPurple.withOpacity(0.2),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: game.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: game.coverUrlForGrid ?? game.coverUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: UIConstants.bgTertiary,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: UIConstants.accentPurple,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => _GamePlaceholder(),
                          )
                        : _GamePlaceholder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Game info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (game.releaseDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${game.releaseDate!.year}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (game.genres.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: game.genres.take(2).map<Widget>((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: UIConstants.accentPurple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              genre,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: UIConstants.accentPurple,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (inLibrary) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: UIConstants.accentGreen,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Koleksiyonda',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: UIConstants.accentGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: 50 * index),
      duration: 400.ms,
    ).slideX(begin: 0.1, end: 0);
  }
}

class _GamePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: UIConstants.bgTertiary,
      child: const Center(
        child: Icon(
          Icons.sports_esports_rounded,
          color: UIConstants.accentPurple,
          size: 28,
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
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
              Icons.sports_esports_rounded,
              size: 56,
              color: UIConstants.accentPurple.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Oyun Ara',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'En az 4 karakter girin',
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

class _NoResultsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
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
              Icons.search_off_rounded,
              size: 56,
              color: UIConstants.accentYellow.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sonuç Bulunamadı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Farklı bir arama terimi deneyin',
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UIConstants.accentRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: UIConstants.accentRed,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bir Hata Oluştu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ShimmerGameCard extends StatelessWidget {
  const _ShimmerGameCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UIConstants.bgSecondary,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      ),
      child: Shimmer.fromColors(
        baseColor: UIConstants.bgTertiary,
        highlightColor: UIConstants.bgSecondary,
        child: Row(
          children: [
            Container(
              width: 75,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 60,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
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

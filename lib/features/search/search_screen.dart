import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/utils.dart';
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
  Timer? _debounce;
  static const _minChars = 4;
  static const _debounceDuration = Duration(milliseconds: 350);

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
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
      body: CustomScrollView(
        slivers: [
          // Modern animated app bar
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).scaffoldBackgroundColor,
                      Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(pagePadding, 60, pagePadding, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Oyun Ara',
                      style: Theme.of(context).textTheme.headlineSmall,
                    )
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: -0.2, end: 0),
                  ],
                ),
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, 16),
              child: _ModernSearchBar(
                controller: _queryController,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _runSearch(),
                onSearch: _runSearch,
              ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: -0.1, end: 0),
            ),
          ),

          // Loading indicator
          if (searchState.isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: pagePadding),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 3,
                  ),
                ),
              ),
            ),

          // Error message
          if (searchState.hasError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(pagePadding),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          searchState.error.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .shake(duration: 400.ms)
                    .fadeIn(),
              ),
            ),

          // Results
          searchState.when(
            data: (results) {
              if (results.isEmpty && _queryController.text.trim().length >= _minChars) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.white24,
                        )
                            .animate(onPlay: (controller) => controller.repeat())
                            .fadeIn(duration: 600.ms)
                            .scale(delay: 200.ms),
                        const SizedBox(height: 16),
                        Text(
                          'Sonuç bulunamadı',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white60,
                              ),
                        ).animate().fadeIn(delay: 400.ms),
                      ],
                    ),
                  ),
                );
              }

              if (results.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videogame_asset_outlined,
                          size: 64,
                          color: Colors.white24,
                        )
                            .animate(onPlay: (controller) => controller.repeat(reverse: true))
                            .scale(duration: 2.seconds),
                        const SizedBox(height: 16),
                        Text(
                          'Aramaya başlamak için\nen az 4 karakter girin',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white60,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // AsyncValue olduğu için valueOrNull ile veriyi al
              final library = ref.watch(libraryControllerProvider).valueOrNull ?? [];
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, pagePadding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final game = results[index];
                      final inLibrary = library.any((log) => log.game.id == game.id);
                      return _GameCard(
                        game: game,
                        inLibrary: inLibrary,
                        onTap: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  GameDetailScreen(game: game),
                              transitionsBuilder:
                                  (context, animation, secondaryAnimation, child) {
                                const begin = Offset(1.0, 0.0);
                                const end = Offset.zero;
                                const curve = Curves.easeInOutCubic;
                                final tween = Tween(begin: begin, end: end)
                                    .chain(CurveTween(curve: curve));
                                final offsetAnimation = animation.drive(tween);

                                return SlideTransition(
                                  position: offsetAnimation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                              transitionDuration: const Duration(milliseconds: 400),
                            ),
                          );
                        },
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 50 * index),
                            duration: 400.ms,
                          )
                          .slideX(
                            begin: 0.1,
                            end: 0,
                            delay: Duration(milliseconds: 50 * index),
                            duration: 400.ms,
                            curve: Curves.easeOutCubic,
                          );
                    },
                    childCount: results.length,
                  ),
                ),
              );
            },
            loading: () => SliverPadding(
              padding: const EdgeInsets.all(pagePadding),
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
    );
  }
}

class _ModernSearchBar extends StatelessWidget {
  const _ModernSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSearch,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: 'Oyun ara',
          hintText: 'Başlık girin (min. 4 karakter)',
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.inLibrary,
    required this.onTap,
  });

  final dynamic game;
  final bool inLibrary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: inLibrary
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image with Hero animation
                Hero(
                  tag: 'game-cover-${game.id}',
                  child: Container(
                    width: 80,
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: game.coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: game.coverUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.videogame_asset, size: 32),
                              ),
                            )
                          : Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.videogame_asset, size: 32),
                            ),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (game.releaseDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${game.releaseDate!.year}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white54,
                              ),
                        ),
                      ],
                      if (game.genres.isNotEmpty) ...[
                        const SizedBox(height: 6),
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
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                genre,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
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
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Koleksiyonda',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.white10,
        highlightColor: Colors.white24,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 110,
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
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 60,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
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

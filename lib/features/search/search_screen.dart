import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/fire_theme.dart';
import '../../core/ui_constants.dart';
import '../library/library_controller.dart';
import '../steam_library/steam_library_provider.dart';
import 'game_detail_screen.dart';
import 'search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with TickerProviderStateMixin {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  static const _minChars = 4;
  static const _debounceDuration = Duration(milliseconds: 350);

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
    _debounce?.cancel();
    _queryController.dispose();
    _focusNode.dispose();
    _flameController.dispose();
    _emberController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    await ref
        .read(searchControllerProvider.notifier)
        .search(_queryController.text);
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
                    intensity: 0.5,
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
                    particleCount: 8,
                    intensity: 0.4,
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
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _FireSearchHeader(flameController: _flameController),
                ),

                // Search bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _FireSearchBar(
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
                        child: LinearProgressIndicator(
                          backgroundColor: UIConstants.bgSecondary,
                          valueColor: AlwaysStoppedAnimation(UIConstants.fireOrange),
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
                          gradient: LinearGradient(
                            colors: [
                              UIConstants.fireRed.withOpacity(0.15),
                              UIConstants.fireOrange.withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                          border: Border.all(
                            color: UIConstants.fireRed.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: UIConstants.fireRed,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                searchState.error.toString(),
                                style: TextStyle(color: UIConstants.fireRed),
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
                    if (results.isEmpty &&
                        _queryController.text.trim().length >= _minChars) {
                      return SliverFillRemaining(child: _FireNoResultsState());
                    }

                    if (results.isEmpty) {
                      final trendingAsync = ref.watch(trendingGamesProvider);
                      return trendingAsync.when(
                        data: (trendingGames) {
                          if (trendingGames.isEmpty) {
                            return SliverFillRemaining(child: _FireEmptySearchState());
                          }
                          return _FireTrendingGamesSection(games: trendingGames);
                        },
                        loading: () => const SliverFillRemaining(
                          child: Center(child: FireLoadingIndicator()),
                        ),
                        error: (error, _) => SliverFillRemaining(
                          child: _FireErrorState(message: error.toString()),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final game = results[index];
                          final inLibraryById = ref.watch(isGameInAnyLibraryProvider(game.id));
                          final inLibraryByName = ref.watch(isGameInAnyLibraryByNameProvider(game.name));
                          final inLibrary = inLibraryById || inLibraryByName;
                          return _FireGameCard(
                            game: game,
                            inLibrary: inLibrary,
                            index: index,
                          );
                        }, childCount: results.length),
                      ),
                    );
                  },
                  loading: () => SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const _FireShimmerGameCard(),
                        childCount: 5,
                      ),
                    ),
                  ),
                  error: (error, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FireSearchHeader extends StatelessWidget {
  const _FireSearchHeader({required this.flameController});

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
              'OYUN ARA',
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

class _FireSearchBar extends StatelessWidget {
  const _FireSearchBar({
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            UIConstants.fireOrange.withOpacity(0.18),
            UIConstants.fireRed.withOpacity(0.12),
            UIConstants.fireDarkBg.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: UIConstants.fireOrange.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: UIConstants.fireOrange.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: UIConstants.fireRed.withOpacity(0.08),
            blurRadius: 40,
            spreadRadius: -8,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: UIConstants.fireOrange,
        decoration: InputDecoration(
          hintText: 'Oyun ara (min. 4 karakter)',
          hintStyle: TextStyle(
            color: UIConstants.fireYellow.withOpacity(0.4),
            fontSize: 15,
          ),
          prefixIcon: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [UIConstants.fireYellow, UIConstants.fireOrange],
            ).createShader(bounds),
            child: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: UIConstants.fireOrange.withOpacity(0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }
}

class _FireTrendingGamesSection extends ConsumerWidget {
  const _FireTrendingGamesSection({required this.games});

  final List<dynamic> games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: UIConstants.fireOrange.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                    ).createShader(bounds),
                    child: const Text(
                      'Trend Oyunlar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: UIConstants.fireOrange.withOpacity(0.6),
                    size: 18,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
          }

          final game = games[index - 1];
          final inLibraryById = ref.watch(isGameInAnyLibraryProvider(game.id));
          final inLibraryByName = ref.watch(isGameInAnyLibraryByNameProvider(game.name));
          final inLibrary = inLibraryById || inLibraryByName;
          return _FireGameCard(game: game, inLibrary: inLibrary, index: index - 1);
        }, childCount: games.length + 1),
      ),
    );
  }
}

class _FireGameCard extends StatelessWidget {
  const _FireGameCard({
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: inLibrary
                ? [
                    UIConstants.fireYellow.withOpacity(0.12),
                    UIConstants.fireYellow.withOpacity(0.06),
                  ]
                : [
                    UIConstants.fireOrange.withOpacity(0.1),
                    UIConstants.fireRed.withOpacity(0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          border: Border.all(
            color: inLibrary
                ? UIConstants.fireYellow.withOpacity(0.3)
                : UIConstants.fireOrange.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: (inLibrary ? UIConstants.fireYellow : UIConstants.fireOrange)
                  .withOpacity(0.1),
              blurRadius: 15,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover image with fire glow
              Hero(
                tag: 'game-cover-${game.id}',
                child: Container(
                  width: 75,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: UIConstants.fireOrange.withOpacity(0.3),
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
                                child: FireLoadingIndicator(size: 20, strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => _FireGamePlaceholder(),
                          )
                        : _FireGamePlaceholder(),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  UIConstants.fireOrange.withOpacity(0.2),
                                  UIConstants.fireYellow.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: UIConstants.fireOrange.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              genre,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: UIConstants.fireOrange,
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  UIConstants.fireYellow.withOpacity(0.2),
                                  UIConstants.fireYellow.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: UIConstants.fireYellow.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 12,
                                  color: UIConstants.fireYellow,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Kütüphanede',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: UIConstants.fireYellow,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow with fire style
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
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 400.ms)
        .slideX(begin: 0.1, end: 0);
  }
}

class _FireGamePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: UIConstants.fireGradient),
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

class _FireEmptySearchState extends StatelessWidget {
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
              Icons.sports_esports_rounded,
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
              'Oyun Ara',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
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

class _FireNoResultsState extends StatelessWidget {
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
                  UIConstants.fireYellow.withOpacity(0.2),
                  UIConstants.fireOrange.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: UIConstants.fireYellow.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 56,
              color: UIConstants.fireYellow,
            ),
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [UIConstants.fireYellow, UIConstants.fireOrange],
            ).createShader(bounds),
            child: const Text(
              'Sonuç Bulunamadı',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
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

class _FireErrorState extends StatelessWidget {
  const _FireErrorState({required this.message});

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
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: UIConstants.fireRed,
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

class _FireShimmerGameCard extends StatelessWidget {
  const _FireShimmerGameCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            UIConstants.fireOrange.withOpacity(0.08),
            UIConstants.fireRed.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: UIConstants.fireOrange.withOpacity(0.15)),
      ),
      child: Shimmer.fromColors(
        baseColor: UIConstants.fireOrange.withOpacity(0.1),
        highlightColor: UIConstants.fireYellow.withOpacity(0.05),
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

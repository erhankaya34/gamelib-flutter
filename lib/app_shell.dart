import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/fire_theme.dart';
import 'core/ui_constants.dart';
import 'data/profile_repository.dart';
import 'data/supabase_client.dart';
import 'features/auth/login_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/library/library_screen.dart';
import 'features/onboarding/genre_onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/search/search_screen.dart';
import 'features/steam_library/steam_library_screen.dart';

/// Determines whether to show auth flow, onboarding, or the signed-in shell
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      loading: () => Scaffold(
        backgroundColor: UIConstants.bgPrimary,
        body: const Center(
          child: FireLoadingIndicator(),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: UIConstants.bgPrimary,
        body: Center(
          child: Text(
            'Auth error: $error',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      data: (session) {
        if (session == null) return const LoginScreen();

        final profileAsync = ref.watch(currentProfileProvider);

        return profileAsync.when(
          loading: () => Scaffold(
            backgroundColor: UIConstants.bgPrimary,
            body: const Center(
              child: FireLoadingIndicator(),
            ),
          ),
          error: (e, _) {
            Future.microtask(() async {
              final supabase = ref.read(supabaseProvider);
              await supabase.auth.signOut();
              ref.invalidate(authProvider);
            });
            return Scaffold(
              backgroundColor: UIConstants.bgPrimary,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FireLoadingIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Profil bulunamadı. Çıkış yapılıyor...',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (profile) {
            if (profile == null) {
              Future.microtask(() async {
                final supabase = ref.read(supabaseProvider);
                await supabase.auth.signOut();
                ref.invalidate(authProvider);
              });
              return Scaffold(
                backgroundColor: UIConstants.bgPrimary,
                body: const Center(
                  child: FireLoadingIndicator(),
                ),
              );
            }

            if (profile['onboarding_completed'] != true) {
              return const GenreOnboardingScreen();
            }

            return const AppShell();
          },
        );
      },
    );
  }
}

/// Signed-in scaffold with fire-themed bottom navigation
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  int _index = 0;
  late AnimationController _glowController;

  final _pages = const [
    SearchScreen(),
    FeedScreen(),
    LibraryScreen(),
    SteamLibraryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _onTap(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.bgPrimary,
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  UIConstants.fireOrange.withOpacity(0.05 + _glowController.value * 0.03),
                  UIConstants.bgSecondary,
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: UIConstants.fireOrange.withOpacity(0.15 + _glowController.value * 0.1),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: UIConstants.fireOrange.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _FireNavItem(
                      icon: Icons.search_rounded,
                      label: 'Ara',
                      isSelected: _index == 0,
                      onTap: () => _onTap(0),
                      glowController: _glowController,
                    ),
                    _FireNavItem(
                      icon: Icons.dynamic_feed_rounded,
                      label: 'Akış',
                      isSelected: _index == 1,
                      onTap: () => _onTap(1),
                      glowController: _glowController,
                    ),
                    _FireNavItem(
                      icon: Icons.bookmark_rounded,
                      label: 'Kayıtlarım',
                      isSelected: _index == 2,
                      onTap: () => _onTap(2),
                      glowController: _glowController,
                    ),
                    _FireNavItem(
                      icon: Icons.library_books_rounded,
                      label: 'Kütüphane',
                      isSelected: _index == 3,
                      onTap: () => _onTap(3),
                      glowController: _glowController,
                    ),
                    _FireNavItem(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Profil',
                      isSelected: _index == 4,
                      onTap: () => _onTap(4),
                      glowController: _glowController,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FireNavItem extends StatelessWidget {
  const _FireNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.glowController,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final AnimationController glowController;

  @override
  Widget build(BuildContext context) {
    final baseColor = isSelected ? UIConstants.fireOrange : Colors.white.withOpacity(0.4);
    final glowIntensity = isSelected ? 0.3 + glowController.value * 0.2 : 0.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    UIConstants.fireOrange.withOpacity(0.2),
                    UIConstants.fireRed.withOpacity(0.1),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: UIConstants.fireOrange.withOpacity(0.3),
                  width: 1,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: UIConstants.fireOrange.withOpacity(glowIntensity),
                    blurRadius: 12 + glowController.value * 8,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: isSelected
                  ? (bounds) => LinearGradient(
                        colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                      ).createShader(bounds)
                  : (bounds) => LinearGradient(
                        colors: [baseColor, baseColor],
                      ).createShader(bounds),
              child: Icon(
                icon,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? UIConstants.fireOrange : Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

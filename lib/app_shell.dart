import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ui_constants.dart';
import 'data/profile_repository.dart';
import 'data/supabase_client.dart';
import 'features/auth/login_screen.dart';
import 'features/discover/discover_screen.dart';
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
          child: CircularProgressIndicator(color: UIConstants.accentPurple),
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
              child: CircularProgressIndicator(color: UIConstants.accentPurple),
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
                    const CircularProgressIndicator(color: UIConstants.accentPurple),
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
                  child: CircularProgressIndicator(color: UIConstants.accentPurple),
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

/// Signed-in scaffold with modern bottom navigation
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final _pages = const [
    SearchScreen(),
    FeedScreen(),
    LibraryScreen(),
    SteamLibraryScreen(),
    DiscoverScreen(),
    ProfileScreen(),
  ];

  void _onTap(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.bgPrimary,
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: UIConstants.bgSecondary,
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.search_rounded,
                  label: 'Ara',
                  isSelected: _index == 0,
                  onTap: () => _onTap(0),
                ),
                _NavItem(
                  icon: Icons.dynamic_feed_rounded,
                  label: 'Akış',
                  isSelected: _index == 1,
                  onTap: () => _onTap(1),
                ),
                _NavItem(
                  icon: Icons.bookmark_rounded,
                  label: 'Kayıtlarım',
                  isSelected: _index == 2,
                  onTap: () => _onTap(2),
                ),
                _NavItem(
                  icon: Icons.library_books_rounded,
                  label: 'Kütüphane',
                  isSelected: _index == 3,
                  onTap: () => _onTap(3),
                ),
                _NavItem(
                  icon: Icons.explore_rounded,
                  label: 'Keşfet',
                  isSelected: _index == 4,
                  onTap: () => _onTap(4),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profil',
                  isSelected: _index == 5,
                  onTap: () => _onTap(5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? UIConstants.accentPurple;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? color : Colors.white.withOpacity(0.4),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

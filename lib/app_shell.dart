import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/profile_repository.dart';
import 'data/supabase_client.dart';
import 'features/auth/login_screen.dart';
import 'features/discover/discover_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/library/library_screen.dart';
import 'features/onboarding/genre_onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/search/search_screen.dart';

/// Determines whether to show auth flow, onboarding, or the signed-in shell
/// Flow: Login/Register (with username) → Genre Onboarding → App Shell
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Text('Auth error: $error'),
        ),
      ),
      data: (session) {
        // Not logged in → Show login screen
        if (session == null) return const LoginScreen();

        // Logged in → Check onboarding status
        final profileAsync = ref.watch(currentProfileProvider);

        return profileAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Profile error: $e'),
                ],
              ),
            ),
          ),
          data: (profile) {
            // Onboarding not completed → Show genre onboarding
            // (Username is now collected during registration)
            if (profile?['onboarding_completed'] != true) {
              return const GenreOnboardingScreen();
            }

            // All done → Show main app
            return const AppShell();
          },
        );
      },
    );
  }
}

/// Signed-in scaffold with bottom navigation tabs.
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
    DiscoverScreen(),
    ProfileScreen(),
  ];

  void _onTap(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: _pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Ara',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feed),
            label: 'Akış',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Koleksiyon',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Keşfet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_shell.dart';
import '../../core/theme.dart';
import '../../data/igdb_client.dart';
import '../../data/profile_repository.dart';
import '../../data/supabase_client.dart';

/// Provider for fetching genres from IGDB
final genresProvider = FutureProvider<List<String>>((ref) async {
  final client = ref.read(igdbClientProvider);
  return client.fetchGenres();
});

/// Provider for tracking selected genres
final selectedGenresProvider = StateProvider<Set<String>>((ref) => {});

/// Genre onboarding screen
/// Shown after username selection, before main app
/// Users must select at least 3 favorite genres
class GenreOnboardingScreen extends ConsumerWidget {
  const GenreOnboardingScreen({super.key});

  Future<void> _saveAndContinue(BuildContext context, WidgetRef ref) async {
    final selected = ref.read(selectedGenresProvider);

    // Validate minimum 3 genres
    if (selected.length < 3) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('En az 3 tür seçmelisin'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Save genres to database
      final supabase = ref.read(supabaseProvider);
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Insert selected genres
      for (final genre in selected) {
        await supabase.from('user_genres').insert({
          'user_id': userId,
          'genre_name': genre,
        });
      }

      // Mark onboarding as completed
      final profileRepo = ref.read(profileRepositoryProvider);
      await profileRepo.completeOnboarding();

      // Navigate to main app
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresAsync = ref.watch(genresProvider);
    final selected = ref.watch(selectedGenresProvider);

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.rose.withOpacity(0.2),
                    AppTheme.peach.withOpacity(0.2),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.category,
                    size: 48,
                    color: AppTheme.rose,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Favori Türlerin',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.rose,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En az 3 tür seç (sana özel öneriler alacaksın)',
                    style: const TextStyle(
                      color: AppTheme.lavenderGray,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Progress indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (selected.length / 3).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.rose),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${selected.length}/3 seçildi',
                    style: TextStyle(
                      color: selected.length >= 3 ? AppTheme.rose : AppTheme.lavenderGray,
                      fontSize: 12,
                      fontWeight:
                          selected.length >= 3 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Genre grid
            Expanded(
              child: genresAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Türler yüklenemedi',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$e',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.lavenderGray, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (genres) {
                  if (genres.isEmpty) {
                    return Center(
                      child: Text(
                        'Tür bulunamadı',
                        style: const TextStyle(color: AppTheme.lavenderGray),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: genres.length,
                    itemBuilder: (context, index) {
                      final genre = genres[index];
                      final isSelected = selected.contains(genre);

                      return InkWell(
                        onTap: () {
                          ref.read(selectedGenresProvider.notifier).update((state) {
                            final newSet = Set<String>.from(state);
                            if (isSelected) {
                              newSet.remove(genre);
                            } else {
                              newSet.add(genre);
                            }
                            return newSet;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.rose.withOpacity(0.2) : AppTheme.slate,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.rose : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isSelected)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: AppTheme.rose,
                                      size: 18,
                                    ),
                                  ),
                                Flexible(
                                  child: Text(
                                    genre,
                                    style: TextStyle(
                                      color: isSelected ? AppTheme.rose : AppTheme.cream,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Continue button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selected.length >= 3
                      ? () => _saveAndContinue(context, ref)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.rose,
                    disabledBackgroundColor: AppTheme.lavenderGray.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Tamamla (${selected.length}/3)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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

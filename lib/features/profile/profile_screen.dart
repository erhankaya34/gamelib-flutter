import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../data/supabase_client.dart';
import '../auth/auth_controller.dart';
import '../library/library_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final email = session?.user.email ?? 'Guest';
    // AsyncValue olduğu için valueOrNull ile veriyi al
    final collection = ref.watch(libraryControllerProvider).valueOrNull ?? [];
    final initials = email.isNotEmpty ? email.characters.first.toUpperCase() : '?';
    final avgRating = collection.isEmpty
        ? null
        : collection
            .where((log) => log.rating != null)
            .map((log) => log.rating!)
            .fold<double>(0, (sum, r) => sum + r) /
        (collection.where((log) => log.rating != null).length);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session != null ? 'Gamelib üyesi' : 'Misafir',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (avgRating != null)
                      Text(
                        'Ortalama puanın: ${avgRating.toStringAsFixed(1)}/10',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Koleksiyon (${collection.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (collection.isEmpty)
              const Text('Henüz koleksiyon boş.')
            else
              ...collection.map((log) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: log.game.coverUrl != null
                        ? Image.network(
                            log.game.coverUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox(width: 48, height: 48),
                    title: Text(log.game.name),
                    subtitle: Text(
                      log.rating != null
                          ? 'Puan: ${log.rating}/10'
                          : 'Puan yok',
                    ),
                  ),
                );
              }),
            const Spacer(),
            FilledButton.icon(
              onPressed: session == null
                  ? null
                  : () => ref.read(authControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Çıkış yap'),
            ),
          ],
        ),
      ),
    );
  }
}

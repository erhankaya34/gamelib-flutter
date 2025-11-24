import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../library/library_controller.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(libraryControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Padding(
        padding: const EdgeInsets.all(pagePadding),
        child: logs.isEmpty
            ? const Center(child: Text('Henüz koleksiyon boş.'))
            : ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return ListTile(
                    leading: log.game.coverUrl != null
                        ? Image.network(
                            log.game.coverUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox(width: 48, height: 48),
                    title: Text(log.game.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (log.notes != null && log.notes!.isNotEmpty)
                          Text(
                            log.notes!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (log.rating != null)
                          Text('Kendi puanın: ${log.rating}/10'),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

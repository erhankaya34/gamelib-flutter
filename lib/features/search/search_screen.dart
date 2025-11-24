import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
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
      appBar: AppBar(title: const Text('Search')),
      body: Padding(
        padding: const EdgeInsets.all(pagePadding),
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                labelText: 'Search games',
                hintText: 'Enter a title',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _runSearch,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (searchState.isLoading) ...[
              const LinearProgressIndicator(),
            ],
            if (searchState.hasError) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  searchState.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            Expanded(
              child: searchState.when(
                data: (results) {
                  if (results.isEmpty) {
                    return const Center(child: Text('No results yet.'));
                  }
                  return ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final game = results[index];
                      return ListTile(
                        leading: game.coverUrl != null
                            ? Image.network(
                                game.coverUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              )
                            : const SizedBox(width: 48, height: 48),
                        title: Text(game.name),
                        subtitle: game.summary != null
                            ? Text(
                                game.summary!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                      );
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/friend_repository.dart';

/// State provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for search results
final searchResultsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(searchQueryProvider);

  if (query.trim().isEmpty || query.trim().length < 2) {
    return [];
  }

  final repo = ref.read(friendRepositoryProvider);
  return repo.searchUsers(query);
});

/// Friend search dialog
/// Allows users to search for other users by username and send friend requests
class FriendSearchDialog extends ConsumerStatefulWidget {
  const FriendSearchDialog({super.key});

  @override
  ConsumerState<FriendSearchDialog> createState() =>
      _FriendSearchDialogState();
}

class _FriendSearchDialogState extends ConsumerState<FriendSearchDialog> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendFriendRequest(String friendId, String username) async {
    try {
      final repo = ref.read(friendRepositoryProvider);
      await repo.sendFriendRequest(friendId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$username\'e arkadaşlık isteği gönderildi'),
            backgroundColor: AppTheme.mint,
          ),
        );

        // Refresh friends list
        ref.invalidate(friendsListProvider);
        ref.invalidate(pendingRequestsProvider);
      }
    } catch (e) {
      if (mounted) {
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
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);

    return Dialog(
      backgroundColor: AppTheme.slate,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.person_search,
                  color: AppTheme.lavender,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Arkadaş Ara',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cream,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppTheme.lavenderGray,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Search input
            TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.cream),
              decoration: InputDecoration(
                hintText: 'Kullanıcı adı...',
                hintStyle: TextStyle(color: AppTheme.lavenderGray.withOpacity(0.5)),
                filled: true,
                fillColor: AppTheme.darkSlate,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.lavender, width: 2),
                ),
                prefixIcon: const Icon(Icons.search, color: AppTheme.lavender),
              ),
              onChanged: (value) {
                // Debounce search
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchController.text == value) {
                    ref.read(searchQueryProvider.notifier).state = value;
                  }
                });
              },
            ),

            const SizedBox(height: 20),

            // Results
            Flexible(
              child: searchResults.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Hata: $e',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (results) {
                  if (_searchController.text.trim().isEmpty) {
                    return Center(
                      child: Text(
                        'Aramaya başlamak için kullanıcı adı gir',
                        style: TextStyle(color: AppTheme.lavenderGray),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  if (results.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 48,
                            color: AppTheme.lavenderGray.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Kullanıcı bulunamadı',
                            style: TextStyle(color: AppTheme.lavenderGray),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final user = results[index];
                      return _UserSearchResult(
                        user: user,
                        onSendRequest: _sendFriendRequest,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual user search result card
class _UserSearchResult extends ConsumerWidget {
  const _UserSearchResult({
    required this.user,
    required this.onSendRequest,
  });

  final Map<String, dynamic> user;
  final Future<void> Function(String friendId, String username) onSendRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = user['id'] as String;
    final username = user['username'] as String;

    // Check friendship status
    final repo = ref.read(friendRepositoryProvider);
    final friendshipStatusFuture = repo.getFriendshipStatus(userId);

    return FutureBuilder<String?>(
      future: friendshipStatusFuture,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkSlate,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.lavender.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.lavender.withOpacity(0.3),
                      AppTheme.sky.withOpacity(0.3),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person,
                    color: AppTheme.lavender,
                    size: 24,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Username
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: AppTheme.cream,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (user['email'] != null)
                      Text(
                        user['email'] as String,
                        style: TextStyle(
                          color: AppTheme.lavenderGray,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),

              // Action button
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (status == null)
                FilledButton.icon(
                  onPressed: () => onSendRequest(userId, username),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Ekle'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.lavender,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                )
              else if (status == 'pending')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.peach.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.peach),
                  ),
                  child: const Text(
                    'Bekliyor',
                    style: TextStyle(
                      color: AppTheme.peach,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (status == 'accepted')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.mint.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.mint),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.mint, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Arkadaş',
                        style: TextStyle(
                          color: AppTheme.mint,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile_assets.dart';
import '../../core/theme.dart';
import '../../data/profile_repository.dart';
import '../../data/steam_service.dart';
import '../steam_library/steam_library_provider.dart';
import '../steam_link/steam_link_dialog.dart';

/// Profile edit screen
/// Allows users to customize their profile: bio, avatar, background, Steam
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _bioController = TextEditingController();
  String _selectedAvatar = 'avatar_1';
  String _selectedBackground = 'bg_1';
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    setState(() => _isLoading = true);

    try {
      final profile = await ref.read(currentProfileProvider.future);

      if (profile != null && mounted) {
        setState(() {
          _bioController.text = profile['bio'] as String? ?? '';
          _selectedAvatar = profile['avatar'] as String? ?? 'avatar_1';
          _selectedBackground = profile['background_image'] as String? ?? 'bg_1';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil yüklenemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(profileRepositoryProvider);

      await repo.updateProfileCustomization(
        bio: _bioController.text.trim(),
        avatar: _selectedAvatar,
        backgroundImage: _selectedBackground,
      );

      if (mounted) {
        // Refresh profile
        ref.invalidate(currentProfileProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil güncellendi!'),
            backgroundColor: AppTheme.mint,
          ),
        );

        Navigator.of(context).pop();
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.deepNavy,
      builder: (context) => _AvatarPicker(
        selected: _selectedAvatar,
        onSelect: (avatar) {
          setState(() => _selectedAvatar = avatar);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showBackgroundPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.deepNavy,
      builder: (context) => _BackgroundPicker(
        selected: _selectedBackground,
        onSelect: (bg) {
          setState(() => _selectedBackground = bg);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSteamDialog() {
    showSteamLinkDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.deepNavy,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
        backgroundColor: AppTheme.deepNavy,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppTheme.cream),
                    ),
                  )
                : const Text(
                    'Kaydet',
                    style: TextStyle(
                      color: AppTheme.mint,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar section
            const Text(
              'Avatar',
              style: TextStyle(
                color: AppTheme.cream,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showAvatarPicker,
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.lavender, width: 2),
                      image: DecorationImage(
                        image: NetworkImage(
                          ProfileAssets.getAvatarUrl(_selectedAvatar),
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ProfileAssets.getAvatarName(_selectedAvatar),
                          style: const TextStyle(
                            color: AppTheme.cream,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Değiştirmek için tıkla',
                          style: TextStyle(
                            color: AppTheme.lavenderGray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.lavenderGray),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(color: AppTheme.lavenderGray),
            const SizedBox(height: 24),

            // Background section
            const Text(
              'Arkaplan',
              style: TextStyle(
                color: AppTheme.cream,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showBackgroundPicker,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.lavender, width: 2),
                  image: DecorationImage(
                    image: NetworkImage(
                      ProfileAssets.getBackgroundImageUrl(_selectedBackground),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      ProfileAssets.getBackgroundName(_selectedBackground),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(color: AppTheme.lavenderGray),
            const SizedBox(height: 24),

            // Bio section
            const Text(
              'Hakkında',
              style: TextStyle(
                color: AppTheme.cream,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              maxLines: 4,
              maxLength: 200,
              style: const TextStyle(color: AppTheme.cream),
              decoration: InputDecoration(
                hintText: 'Kendini tanıt...',
                hintStyle: TextStyle(color: AppTheme.lavenderGray.withOpacity(0.5)),
                filled: true,
                fillColor: AppTheme.slate,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.lavender, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(color: AppTheme.lavenderGray),
            const SizedBox(height: 24),

            // Steam section
            const Text(
              'Steam Hesabı',
              style: TextStyle(
                color: AppTheme.cream,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _SteamSection(onLinkTap: _showSteamDialog),
          ],
        ),
      ),
    );
  }
}

/// Avatar picker bottom sheet
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Avatar Seç',
            style: TextStyle(
              color: AppTheme.cream,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: ProfileAssets.avatars.length,
            itemBuilder: (context, index) {
              final avatar = ProfileAssets.avatars[index];
              final isSelected = avatar == selected;

              return GestureDetector(
                onTap: () => onSelect(avatar),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppTheme.mint : AppTheme.lavenderGray,
                      width: isSelected ? 3 : 1,
                    ),
                    image: DecorationImage(
                      image: NetworkImage(ProfileAssets.getAvatarUrl(avatar)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Background picker bottom sheet
class _BackgroundPicker extends StatelessWidget {
  const _BackgroundPicker({
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Arkaplan Seç',
            style: TextStyle(
              color: AppTheme.cream,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 16 / 9,
            ),
            itemCount: ProfileAssets.backgrounds.length,
            itemBuilder: (context, index) {
              final bg = ProfileAssets.backgrounds[index];
              final isSelected = bg == selected;

              return GestureDetector(
                onTap: () => onSelect(bg),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppTheme.mint : AppTheme.lavenderGray,
                      width: isSelected ? 3 : 1,
                    ),
                    image: DecorationImage(
                      image: NetworkImage(
                        ProfileAssets.getBackgroundImageUrl(bg),
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        ProfileAssets.getBackgroundName(bg),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Steam section widget
class _SteamSection extends ConsumerWidget {
  const _SteamSection({required this.onLinkTap});

  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Hata: $e'),
      data: (profile) {
        final steamId = profile?['steam_id'] as String?;
        final hasSteam = steamId != null;

        if (hasSteam) {
          return _SteamLinkedCard(
            steamId: steamId,
            steamData: profile?['steam_data'] as Map<String, dynamic>?,
          );
        }

        return _SteamUnlinkedCard(onLinkTap: onLinkTap);
      },
    );
  }
}

/// Steam linked card
class _SteamLinkedCard extends ConsumerStatefulWidget {
  const _SteamLinkedCard({
    required this.steamId,
    this.steamData,
  });

  final String steamId;
  final Map<String, dynamic>? steamData;

  @override
  ConsumerState<_SteamLinkedCard> createState() => _SteamLinkedCardState();
}

class _SteamLinkedCardState extends ConsumerState<_SteamLinkedCard> {
  bool _isSyncing = false;

  Future<void> _unlinkSteam(BuildContext context) async {
    // Confirm unlink
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.slate,
        title: const Text(
          'Steam Bağlantısını Kaldır?',
          style: TextStyle(color: AppTheme.cream),
        ),
        content: const Text(
          'Steam hesabı bağlantısı kaldırılacak. Profil istatistiklerin kaybolacak.',
          style: TextStyle(color: AppTheme.lavenderGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      await profileRepo.unlinkSteamAccount();

      // Refresh profile
      ref.invalidate(currentProfileProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Steam bağlantısı kaldırıldı'),
            backgroundColor: AppTheme.lavenderGray,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _syncSteamLibrary() async {
    setState(() => _isSyncing = true);

    try {
      // Trigger full library sync
      final result = await ref.read(steamLibrarySyncProvider(widget.steamId).future);

      // Refresh Steam library provider
      ref.invalidate(steamLibraryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Steam kütüphanesi senkronize edildi!\n'
              '${result.imported + result.updated} oyun güncellendi',
            ),
            backgroundColor: AppTheme.mint,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Senkronizasyon hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.slate,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.mint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.mint, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Steam Bağlı',
                style: TextStyle(
                  color: AppTheme.cream,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _unlinkSteam(context),
                child: const Text(
                  'Bağlantıyı Kaldır',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Steam ID: ${widget.steamId}',
            style: const TextStyle(
              color: AppTheme.lavenderGray,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.lavenderGray, height: 1),
          const SizedBox(height: 16),

          // Sync button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSyncing ? null : _syncSteamLibrary,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF66C0F4),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.sync, size: 20),
              label: Text(
                _isSyncing ? 'Senkronize Ediliyor...' : 'Kütüphaneyi Senkronize Et',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Steam kütüphanenizi ve oyun sürelerinizi GameLib\'e aktarır',
            style: TextStyle(
              color: AppTheme.lavenderGray,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Steam unlinked card
class _SteamUnlinkedCard extends StatelessWidget {
  const _SteamUnlinkedCard({required this.onLinkTap});

  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.slate,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lavenderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Steam hesabını bağla',
            style: TextStyle(
              color: AppTheme.cream,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Profil resmini, oyun sayını, başarımlarını ve oyun saatini göster',
            style: TextStyle(
              color: AppTheme.lavenderGray,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onLinkTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.lavender,
            ),
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Steam Bağla'),
          ),
        ],
      ),
    );
  }
}


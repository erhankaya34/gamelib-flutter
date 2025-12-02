/// PLAYBACK Screen
///
/// Spotify Wrapped tarzı paylaşılabilir oyuncu kartı ekranı.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/ui_constants.dart';
import '../../data/profile_repository.dart';
import 'playback_card.dart';
import 'playback_provider.dart';
import 'playback_stats.dart';

class PlaybackScreen extends ConsumerStatefulWidget {
  const PlaybackScreen({super.key});

  @override
  ConsumerState<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends ConsumerState<PlaybackScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isExporting = false;

  Future<void> _shareCard() async {
    setState(() => _isExporting = true);

    try {
      // Capture the card
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _showError('Kart yakalanamadı');
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showError('Görsel oluşturulamadı');
        return;
      }

      final bytes = byteData.buffer.asUint8List();

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/playback_card.png');
      await file.writeAsBytes(bytes);

      // Share
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'PLAYBACK - Oyuncu Kartım 🎮',
      );
    } catch (e) {
      _showError('Paylaşım hatası: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _isExporting = true);

    try {
      // Capture the card
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _showError('Kart yakalanamadı');
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showError('Görsel oluşturulamadı');
        return;
      }

      final bytes = byteData.buffer.asUint8List();

      // Save to documents (cross-platform)
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/playback_$timestamp.png');
      await file.writeAsBytes(bytes);

      _showSuccess('Kart kaydedildi: ${file.path}');
    } catch (e) {
      _showError('Kaydetme hatası: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: UIConstants.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: UIConstants.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always use allTime period - no selector needed
    final statsAsync = ref.watch(playbackStatsProvider(PlaybackPeriod.allTime));
    final profileAsync = ref.watch(currentProfileProvider);

    final profile = profileAsync.valueOrNull;
    final username = profile?['username'] as String? ?? 'Oyuncu';
    final steamData = profile?['steam_data'] as Map<String, dynamic>?;
    final avatarUrl = steamData?['profile_image_url'] as String?;

    return Scaffold(
      backgroundColor: UIConstants.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: UIConstants.fireGradient),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'PLAYBACK',
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
            ),

            // Card Preview
            Expanded(
              child: statsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: UIConstants.accentPurple),
                ),
                error: (e, st) => Center(
                  child: Text(
                    'Hata: $e',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                data: (stats) => SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // The actual card (wrapped in RepaintBoundary for capture)
                      RepaintBoundary(
                        key: _cardKey,
                        child: PlaybackCard(
                          stats: stats,
                          username: username,
                          avatarUrl: avatarUrl,
                        ),
                      ).animate().fadeIn(duration: 600.ms).scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1, 1),
                        duration: 600.ms,
                        curve: Curves.easeOutBack,
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      _ActionButtons(
                        isExporting: _isExporting,
                        onShare: _shareCard,
                        onSave: _saveToGallery,
                      ),
                    ],
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

// ============================================
// ACTION BUTTONS
// ============================================

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.isExporting,
    required this.onShare,
    required this.onSave,
  });

  final bool isExporting;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Save Button
        Expanded(
          child: GestureDetector(
            onTap: isExporting ? null : onSave,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: UIConstants.bgSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isExporting)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    )
                  else
                    Icon(
                      Icons.download_rounded,
                      color: Colors.white.withOpacity(0.7),
                      size: 20,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    'Kaydet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Share Button
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: isExporting ? null : onShare,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [UIConstants.fireOrange, UIConstants.fireRed]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: UIConstants.fireOrange.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isExporting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      Icons.share_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  const SizedBox(width: 8),
                  const Text(
                    'Paylaş',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

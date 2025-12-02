import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/logger.dart';
import '../../core/theme.dart';
import '../../data/playstation_auth_service.dart';
import '../../data/playstation_library_sync_service.dart';
import '../../data/profile_repository.dart';
import '../library/library_controller.dart';

/// Global function to show PlayStation link dialog from anywhere
void showPlayStationLinkDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const PlayStationLinkDialog(),
  );
}

/// PlayStation link dialog - Uses WebView for authentication
class PlayStationLinkDialog extends ConsumerStatefulWidget {
  const PlayStationLinkDialog({super.key});

  @override
  ConsumerState<PlayStationLinkDialog> createState() =>
      _PlayStationLinkDialogState();
}

class _PlayStationLinkDialogState extends ConsumerState<PlayStationLinkDialog> {
  bool _showWebView = false;
  bool _isLinking = false;
  String? _statusMessage;
  WebViewController? _webViewController;
  bool _loginCompleted = false;

  @override
  void initState() {
    super.initState();
  }

  void _initWebView() {
    _loginCompleted = false;
    _statusMessage = null;

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            appLogger.info('PSN WebView: Page started loading: $url');
          },
          onPageFinished: (String url) async {
            appLogger.info('PSN WebView: Page finished loading: $url');

            // Check if login was successful - user returned after auth
            if (_isLoginSuccessUrl(url) && !_loginCompleted) {
              setState(() {
                _loginCompleted = true;
                _statusMessage = 'Giriş başarılı! "Bağla" butonuna basın.';
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            appLogger.info('PSN WebView: Navigation request: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.playstation.com/tr-tr/'));
  }

  bool _isLoginSuccessUrl(String url) {
    // User is logged in only when they complete the auth flow and return
    // This happens when redirected back after successful login
    return url.contains('io.playstation.com/central/auth/login') ||
           url.contains('postSignInURL');
  }

  Future<void> _fetchNpssoToken() async {
    setState(() {
      _statusMessage = 'NPSSO token alınıyor...';
    });

    try {
      appLogger.info('PSN WebView: Fetching NPSSO from endpoint...');

      // Navigate to NPSSO URL and get content
      await _webViewController!.loadRequest(
        Uri.parse(PlayStationAuthService.npssoTokenUrl),
      );

      await Future.delayed(const Duration(seconds: 2));

      final content = await _webViewController!.runJavaScriptReturningResult(
        'document.body.innerText || document.body.textContent',
      );

      appLogger.info('PSN WebView: NPSSO response: $content');

      final contentStr = content.toString();
      // Remove quotes from JavaScript string
      final cleanContent = contentStr.replaceAll('"', '').replaceAll("'", '');

      // Try to parse as JSON
      if (cleanContent.contains('npsso')) {
        // Extract from JSON like {npsso:token_value} or {"npsso":"token_value"}
        final match = RegExp(r'npsso["\s:]+([A-Za-z0-9_-]+)').firstMatch(cleanContent);
        if (match != null) {
          final npsso = match.group(1);
          if (npsso != null && npsso.length > 10) {
            appLogger.info('PSN WebView: Extracted NPSSO from response');
            await _handleNpssoToken(npsso);
            return;
          }
        }
      }

      setState(() {
        _statusMessage = 'Token alınamadı. Lütfen önce giriş yapın ve tekrar deneyin.';
      });
    } catch (e, stack) {
      appLogger.error('PSN WebView: Error fetching NPSSO', e, stack);
      setState(() {
        _statusMessage = 'Token alınamadı: $e';
      });
    }
  }

  Future<void> _handleNpssoToken(String npsso) async {
    setState(() {
      _showWebView = false;
      _isLinking = true;
      _statusMessage = 'PlayStation hesabı doğrulanıyor...';
    });

    try {
      final authService = ref.read(playstationAuthServiceProvider);
      final tokens = await authService.authenticateWithNpsso(npsso);

      if (tokens == null) {
        throw Exception('Kimlik doğrulama başarısız');
      }

      setState(() {
        _statusMessage = 'PlayStation kütüphanesi senkronize ediliyor...';
      });

      // Get user profile from PSN
      final syncService = ref.read(playstationLibrarySyncServiceProvider);
      final userId = ref.read(currentProfileProvider).value?['id'] as String?;

      if (userId == null) {
        throw Exception('Kullanıcı ID bulunamadı');
      }

      // Sync library
      final result = await syncService.syncFullLibrary(
        userId,
        tokens.accessToken,
        tokens.refreshToken,
      );

      // Refresh library
      ref.invalidate(libraryControllerProvider);
      ref.invalidate(currentProfileProvider);

      if (mounted) {
        setState(() => _isLinking = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PlayStation hesabı bağlandı! ${result.imported} oyun eklendi.',
            ),
            backgroundColor: const Color(0xFF003791), // PlayStation blue
          ),
        );
      }
    } catch (e, stack) {
      appLogger.error('PSN Link: Failed to authenticate', e, stack);
      if (mounted) {
        setState(() {
          _isLinking = false;
          _showWebView = true;
          _statusMessage = 'Bağlantı hatası: $e';
        });
      }
    }
  }

  void _startLogin() {
    setState(() {
      _showWebView = true;
      _statusMessage = null;
      _loginCompleted = false;
    });
    _initWebView();
  }

  @override
  Widget build(BuildContext context) {
    if (_showWebView) {
      return _buildWebViewDialog();
    }
    return _buildInfoDialog();
  }

  Widget _buildWebViewDialog() {
    return Dialog(
      backgroundColor: AppTheme.slate,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppTheme.slate,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF003791),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF003791), Color(0xFF0072CE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.playstation,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'PlayStation Hesabına Giriş',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // WebView
            Expanded(
              child: _webViewController != null
                  ? ClipRRect(
                      child: WebViewWidget(controller: _webViewController!),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation(Color(0xFF003791)),
                      ),
                    ),
            ),
            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.deepNavy,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_statusMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _loginCompleted
                              ? const Color(0xFF10b981)
                              : AppTheme.lavenderGray,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _loginCompleted
                              ? 'Giriş tamamlandı!'
                              : '1. Sağ üstten "Oturum Aç" butonuna tıklayın\n2. PlayStation hesabınıza giriş yapın\n3. Giriş yaptıktan sonra "Bağla" butonuna basın',
                          style: TextStyle(
                            color: AppTheme.lavenderGray,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _fetchNpssoToken,
                        style: FilledButton.styleFrom(
                          backgroundColor: _loginCompleted
                              ? const Color(0xFF10b981)
                              : const Color(0xFF003791),
                        ),
                        icon: Icon(
                          _loginCompleted ? Icons.check : Icons.link,
                          size: 18,
                        ),
                        label: Text(_loginCompleted ? 'Bağla' : 'Bağla'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoDialog() {
    return AlertDialog(
      backgroundColor: AppTheme.slate,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF003791), Color(0xFF0072CE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF0072CE),
                width: 2,
              ),
            ),
            child: const FaIcon(
              FontAwesomeIcons.playstation,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: Text(
              'PlayStation ile Bağlan',
              style: TextStyle(color: AppTheme.cream),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PlayStation hesabınızla güvenli bir şekilde bağlanın.',
            style: TextStyle(
              color: AppTheme.lavenderGray,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.deepNavy,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF003791).withOpacity(0.3),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.mint, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Uygulama İçi Giriş',
                      style: TextStyle(
                        color: AppTheme.cream,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• PlayStation hesabınıza giriş yapın\n'
                  '• Kupa geçmişiniz otomatik alınır\n'
                  '• Oyun kütüphaneniz senkronize edilir',
                  style: TextStyle(
                    color: AppTheme.lavenderGray,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isLinking
                    ? AppTheme.lavender.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (_isLinking)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppTheme.lavender),
                      ),
                    )
                  else
                    Icon(
                      Icons.error_outline,
                      color: Colors.red[300],
                      size: 16,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _isLinking ? AppTheme.lavender : Colors.red[300],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLinking ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          onPressed: _isLinking ? null : _startLogin,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF003791),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          icon: const FaIcon(
            FontAwesomeIcons.playstation,
            size: 18,
          ),
          label: const Text(
            'PlayStation ile Bağlan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

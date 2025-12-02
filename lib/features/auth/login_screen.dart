import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fire_theme.dart';
import '../../core/ui_constants.dart';
import 'auth_controller.dart';
import 'register_screen.dart';

/// Fire-themed login screen
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _flameController;
  late AnimationController _emberController;

  @override
  void initState() {
    super.initState();
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _emberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _flameController.dispose();
    _emberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    final email = _emailController.text.trim();

    await controller.signIn(
      email: email,
      password: _passwordController.text,
    );

    // Check if login failed - offer to register
    if (mounted) {
      final authState = ref.read(authControllerProvider);
      if (authState.hasError) {
        final errorMessage = authState.error.toString().toLowerCase();
        // For "invalid credentials" error, offer to register
        // (could be non-existent user or wrong password, but we offer register anyway)
        if (errorMessage.contains('hatalı') ||
            errorMessage.contains('invalid')) {
          // Wait a bit so user can see the error message
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            _showRegisterDialog(email);
          }
        }
      }
    }
  }

  void _showRegisterDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UIConstants.bgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: UIConstants.fireOrange.withOpacity(0.2),
            width: 1,
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [UIConstants.fireYellow, UIConstants.fireOrange],
          ).createShader(bounds),
          child: const Text(
            'Kullanıcı Bulunamadı',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        content: Text(
          'Bu e-posta ile kayıtlı bir kullanıcı bulunamadı. Hesap oluşturmak ister misiniz?',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: UIConstants.fireGradient),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RegisterScreen(initialEmail: email),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: const Text('Hesap Oluştur'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: UIConstants.bgPrimary,
      body: Stack(
        children: [
          // Fire background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _flameController,
              builder: (context, child) {
                return CustomPaint(
                  painter: FireBackgroundPainter(
                    progress: _flameController.value,
                    intensity: 0.5,
                  ),
                );
              },
            ),
          ),

          // Ember particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _emberController,
              builder: (context, child) {
                return CustomPaint(
                  painter: EmberParticlesPainter(
                    progress: _emberController.value,
                    particleCount: 10,
                  ),
                );
              },
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo/Icon with fire gradient
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              UIConstants.fireOrange.withOpacity(0.3),
                              UIConstants.fireRed.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: UIConstants.fireOrange.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.videogame_asset,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Welcome text
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                        ).createShader(bounds),
                        child: const Text(
                          'Hoş Geldin!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Oyun koleksiyonunu yönet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Email field
                      TextFormField(
                        controller: _emailController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'E-posta',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          hintText: 'ornek@email.com',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          filled: true,
                          fillColor: UIConstants.bgSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: UIConstants.fireOrange,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: UIConstants.fireRed, width: 2),
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: UIConstants.fireOrange,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'E-posta gerekli';
                          }
                          if (!value.contains('@')) {
                            return 'Geçerli bir e-posta girin';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        enabled: !isLoading,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          filled: true,
                          fillColor: UIConstants.bgSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: UIConstants.fireOrange,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: UIConstants.fireRed, width: 2),
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: UIConstants.fireOrange,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white.withOpacity(0.5),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifre gerekli';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Error message
                      if (authState.hasError)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: UIConstants.fireRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: UIConstants.fireRed.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: UIConstants.fireRed,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authState.error.toString(),
                                  style: TextStyle(color: UIConstants.fireRed),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Login button
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: UIConstants.fireGradient),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: UIConstants.fireOrange.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FilledButton(
                          onPressed: isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Giriş Yap',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: UIConstants.fireOrange.withOpacity(0.2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'veya',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: UIConstants.fireOrange.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Register button
                      OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: UIConstants.fireOrange,
                          side: BorderSide(color: UIConstants.fireOrange, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Hesap Oluştur',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

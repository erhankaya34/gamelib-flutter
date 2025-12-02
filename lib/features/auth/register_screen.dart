import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fire_theme.dart';
import '../../core/ui_constants.dart';
import '../../data/supabase_client.dart';
import 'auth_controller.dart';
import 'username_controller.dart';

/// Fire-themed register screen with username selection
class RegisterScreen extends ConsumerStatefulWidget {
  final String? initialEmail;

  const RegisterScreen({super.key, this.initialEmail});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _usernameError;
  bool _isCheckingUsername = false;

  late AnimationController _flameController;
  late AnimationController _emberController;

  @override
  void initState() {
    super.initState();
    // Pre-fill email if provided
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }

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
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Check username availability with debouncing
  Future<void> _checkUsername(String value) async {
    if (value.length < 3) {
      setState(() {
        _usernameError = null;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() => _isCheckingUsername = true);

    // Debounce
    await Future.delayed(const Duration(milliseconds: 500));
    if (_usernameController.text != value) return;

    final controller = ref.read(usernameControllerProvider.notifier);

    // Retry mechanism for connection errors
    String? error;
    for (var i = 0; i < 3; i++) {
      error = await controller.validateUsername(value);

      // If no error or error is not connection-related, break
      if (error == null || !error.contains('Kontrol edilemedi')) {
        break;
      }

      // Wait before retry
      if (i < 2) {
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
        if (_usernameController.text != value) return;
      }
    }

    if (mounted) {
      setState(() {
        _usernameError = error;
        _isCheckingUsername = false;
      });
    }
  }

  Future<void> _submit() async {
    // Validate form
    if (!_formKey.currentState!.validate()) return;

    // Check password match
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Şifreler eşleşmiyor'),
          backgroundColor: UIConstants.fireRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Validate username one final time
    if (_usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_usernameError!),
          backgroundColor: UIConstants.fireRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Check if email is already in use by attempting to sign in
    try {
      final supabase = ref.read(supabaseProvider);
      final email = _emailController.text.trim();

      // Try to sign in with a dummy password to check if email exists
      try {
        await supabase.auth.signInWithPassword(
          email: email,
          password: '__check_email_exists_${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (!errorMsg.contains('invalid login credentials') &&
            !errorMsg.contains('invalid credentials')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Bu e-posta adresi zaten kullanılıyor.'),
                backgroundColor: UIConstants.fireRed,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      // Ignore errors in the check, proceed with registration
    }

    // Register user
    final authController = ref.read(authControllerProvider.notifier);
    await authController.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    // Check if registration was successful
    final authState = ref.read(authControllerProvider);
    if (authState.hasError) return;

    // Save username immediately after registration
    final usernameController = ref.read(usernameControllerProvider.notifier);
    await usernameController.saveUsername(_usernameController.text.trim());

    // Close register screen - AuthGate will handle navigation to onboarding
    if (mounted) {
      Navigator.of(context).pop();
    }
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
                      // Back button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: UIConstants.bgSecondary.withOpacity(0.8),
                            border: Border.all(
                              color: UIConstants.fireOrange.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            onPressed: isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                              ).createShader(bounds),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Logo/Icon with fire gradient
                      Container(
                        padding: const EdgeInsets.all(20),
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
                              blurRadius: 25,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.person_add,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [UIConstants.fireYellow, UIConstants.fireOrange],
                        ).createShader(bounds),
                        child: const Text(
                          'Hesap Oluştur',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Oyun serüvenine başla',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Email field
                      _buildTextField(
                        controller: _emailController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.emailAddress,
                        labelText: 'E-posta',
                        hintText: 'ornek@email.com',
                        prefixIcon: Icons.email_outlined,
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

                      // Username field with real-time validation
                      TextFormField(
                        controller: _usernameController,
                        enabled: !isLoading,
                        onChanged: _checkUsername,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          hintText: 'ornek_kullanici',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          helperText: '3-20 karakter • Harf, rakam ve alt çizgi (_)',
                          helperStyle: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                          ),
                          errorText: _usernameError,
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
                            Icons.person_outline,
                            color: UIConstants.fireOrange,
                          ),
                          suffixIcon: _isCheckingUsername
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(UIConstants.fireOrange),
                                    ),
                                  ),
                                )
                              : _usernameError == null &&
                                      _usernameController.text.length >= 3
                                  ? Icon(Icons.check_circle, color: UIConstants.accentGreen)
                                  : null,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Kullanıcı adı gerekli';
                          }
                          if (value.length < 3) {
                            return 'En az 3 karakter olmalı';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      _buildPasswordField(
                        controller: _passwordController,
                        enabled: !isLoading,
                        labelText: 'Şifre',
                        obscureText: _obscurePassword,
                        onToggleVisibility: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifre gerekli';
                          }
                          if (value.length < 6) {
                            return 'En az 6 karakter kullan';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Confirm password field
                      _buildPasswordField(
                        controller: _confirmController,
                        enabled: !isLoading,
                        labelText: 'Şifre Tekrar',
                        obscureText: _obscureConfirm,
                        onToggleVisibility: () {
                          setState(() => _obscureConfirm = !_obscureConfirm);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifreyi tekrar gir';
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

                      // Register button
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: (isLoading || _isCheckingUsername || _usernameError != null)
                              ? null
                              : LinearGradient(colors: UIConstants.fireGradient),
                          color: (isLoading || _isCheckingUsername || _usernameError != null)
                              ? Colors.white.withOpacity(0.1)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: (isLoading || _isCheckingUsername || _usernameError != null)
                              ? null
                              : [
                                  BoxShadow(
                                    color: UIConstants.fireOrange.withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: FilledButton(
                          onPressed: isLoading || _isCheckingUsername || _usernameError != null
                              ? null
                              : _submit,
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
                                  'Hesap Oluştur',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required bool enabled,
    required String labelText,
    required IconData prefixIcon,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
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
          prefixIcon,
          color: UIConstants.fireOrange,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool enabled,
    required String labelText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
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
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.white.withOpacity(0.5),
          ),
          onPressed: onToggleVisibility,
        ),
      ),
      validator: validator,
    );
  }
}

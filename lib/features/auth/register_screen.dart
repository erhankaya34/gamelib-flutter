import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/supabase_client.dart';
import 'auth_controller.dart';
import 'username_controller.dart';

/// Beautiful register screen with username selection
/// User selects username during registration
class RegisterScreen extends ConsumerStatefulWidget {
  final String? initialEmail;

  const RegisterScreen({super.key, this.initialEmail});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _usernameError;
  bool _isCheckingUsername = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill email if provided
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
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
        const SnackBar(
          content: Text('Şifreler eşleşmiyor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate username one final time
    if (_usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_usernameError!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if email is already in use by attempting to sign in
    try {
      final supabase = ref.read(supabaseProvider);
      final email = _emailController.text.trim();

      // Try to sign in with a dummy password to check if email exists
      // We use a random password that won't match
      try {
        await supabase.auth.signInWithPassword(
          email: email,
          password: '__check_email_exists_${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (e) {
        // If we get here, check the error message
        final errorMsg = e.toString().toLowerCase();
        // "Invalid login credentials" means email exists
        // Any error containing "user" or "password" but NOT "invalid" means email exists
        if (!errorMsg.contains('invalid login credentials') &&
            !errorMsg.contains('invalid credentials')) {
          // Email exists (we got a different error like "email not confirmed")
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bu e-posta adresi zaten kullanılıyor.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        // "Invalid login credentials" is actually good - means email not used yet
        // OR email exists but password wrong - we need better check
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
      backgroundColor: AppTheme.deepNavy,
      body: SafeArea(
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
                    child: IconButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppTheme.lavender,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Logo/Icon with gradient
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.rose.withOpacity(0.3),
                          AppTheme.peach.withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.person_add,
                      size: 48,
                      color: AppTheme.rose,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Hesap Oluştur',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cream,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Oyun serüvenine başla',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.lavenderGray,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.cream),
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      labelStyle: const TextStyle(color: AppTheme.lavenderGray),
                      hintText: 'ornek@email.com',
                      hintStyle: TextStyle(
                        color: AppTheme.lavenderGray.withOpacity(0.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.slate,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.rose,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: AppTheme.rose,
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

                  // Username field with real-time validation
                  TextFormField(
                    controller: _usernameController,
                    enabled: !isLoading,
                    onChanged: _checkUsername,
                    style: const TextStyle(color: AppTheme.cream),
                    decoration: InputDecoration(
                      labelText: 'Kullanıcı Adı',
                      labelStyle: const TextStyle(color: AppTheme.lavenderGray),
                      hintText: 'ornek_kullanici',
                      hintStyle: TextStyle(
                        color: AppTheme.lavenderGray.withOpacity(0.5),
                      ),
                      helperText: '3-20 karakter • Harf, rakam ve alt çizgi (_)',
                      helperStyle: TextStyle(
                        color: AppTheme.lavenderGray.withOpacity(0.7),
                        fontSize: 11,
                      ),
                      errorText: _usernameError,
                      filled: true,
                      fillColor: AppTheme.slate,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.rose,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: AppTheme.rose,
                      ),
                      suffixIcon: _isCheckingUsername
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(AppTheme.rose),
                                ),
                              ),
                            )
                          : _usernameError == null &&
                                  _usernameController.text.length >= 3
                              ? const Icon(Icons.check_circle, color: AppTheme.mint)
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
                  TextFormField(
                    controller: _passwordController,
                    enabled: !isLoading,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppTheme.cream),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      labelStyle: const TextStyle(color: AppTheme.lavenderGray),
                      filled: true,
                      fillColor: AppTheme.slate,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.rose,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: AppTheme.rose,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.lavenderGray,
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
                      if (value.length < 6) {
                        return 'En az 6 karakter kullan';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Confirm password field
                  TextFormField(
                    controller: _confirmController,
                    enabled: !isLoading,
                    obscureText: _obscureConfirm,
                    style: const TextStyle(color: AppTheme.cream),
                    decoration: InputDecoration(
                      labelText: 'Şifre Tekrar',
                      labelStyle: const TextStyle(color: AppTheme.lavenderGray),
                      filled: true,
                      fillColor: AppTheme.slate,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.rose,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: AppTheme.rose,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.lavenderGray,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirm = !_obscureConfirm;
                          });
                        },
                      ),
                    ),
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
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade300,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.error.toString(),
                              style: TextStyle(color: Colors.red.shade300),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Register button
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: isLoading || _isCheckingUsername || _usernameError != null
                          ? null
                          : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.rose,
                        disabledBackgroundColor:
                            AppTheme.lavenderGray.withOpacity(0.3),
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
    );
  }
}

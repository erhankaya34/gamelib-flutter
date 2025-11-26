import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../onboarding/genre_onboarding_screen.dart';
import 'username_controller.dart';

/// Username selection screen
/// Shown after registration, before genre onboarding
/// Users must select a unique username (3-20 chars, alphanumeric + underscore)
class UsernameSelectionScreen extends ConsumerStatefulWidget {
  const UsernameSelectionScreen({super.key});

  @override
  ConsumerState<UsernameSelectionScreen> createState() =>
      _UsernameSelectionScreenState();
}

class _UsernameSelectionScreenState
    extends ConsumerState<UsernameSelectionScreen> {
  final _controller = TextEditingController();
  String? _validationError;
  bool _isChecking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Check username validity with debouncing
  Future<void> _checkUsername(String value) async {
    if (value.length < 3) {
      setState(() {
        _validationError = null;
        _isChecking = false;
      });
      return;
    }

    setState(() => _isChecking = true);

    // Debounce: wait a bit for user to stop typing
    await Future.delayed(const Duration(milliseconds: 500));

    // Check if text changed during debounce
    if (_controller.text != value) return;

    final controller = ref.read(usernameControllerProvider.notifier);
    final error = await controller.validateUsername(value);

    if (mounted) {
      setState(() {
        _validationError = error;
        _isChecking = false;
      });
    }
  }

  /// Submit username and navigate to genre onboarding
  Future<void> _submit() async {
    final controller = ref.read(usernameControllerProvider.notifier);

    // Validate one final time
    final error = await controller.validateUsername(_controller.text);

    if (error != null) {
      setState(() => _validationError = error);
      return;
    }

    // Save username
    await controller.saveUsername(_controller.text);

    // Check for errors
    final state = ref.read(usernameControllerProvider);
    if (state.hasError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${state.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Navigate to genre onboarding
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const GenreOnboardingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usernameControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Header with pastel gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.lavender.withOpacity(0.2),
                      AppTheme.sky.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.person_add,
                      size: 48,
                      color: AppTheme.lavender,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Kullanıcı Adı Seç',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.lavender,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Arkadaşların seni bu adla bulacak',
                      style: TextStyle(
                        color: AppTheme.lavenderGray,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Username input with real-time validation
              TextField(
                controller: _controller,
                onChanged: _checkUsername,
                enabled: !isLoading,
                style: const TextStyle(color: AppTheme.cream),
                decoration: InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  labelStyle: const TextStyle(color: AppTheme.lavenderGray),
                  hintText: 'ornek_kullanici',
                  hintStyle: TextStyle(color: AppTheme.lavenderGray.withOpacity(0.5)),
                  errorText: _validationError,
                  errorStyle: const TextStyle(color: Colors.red),
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.person, color: AppTheme.lavender),
                  suffixIcon: _isChecking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppTheme.lavender),
                            ),
                          ),
                        )
                      : _validationError == null && _controller.text.length >= 3
                          ? const Icon(Icons.check_circle, color: AppTheme.mint)
                          : null,
                ),
              ),

              const SizedBox(height: 12),

              // Hint text
              Text(
                '3-20 karakter • Harf, rakam ve alt çizgi (_)',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.lavenderGray.withOpacity(0.7),
                ),
              ),

              const Spacer(),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      isLoading || _isChecking || _validationError != null
                          ? null
                          : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.lavender,
                    disabledBackgroundColor: AppTheme.lavenderGray.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Devam Et',
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
    );
  }
}

/// Fire Theme Components
///
/// PLAYBACK tarzı ateş teması için paylaşımlı bileşenler.
/// Tüm ekranlarda tutarlı ateş efektleri için kullanılır.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ui_constants.dart';

// ============================================
// FIRE BACKGROUND PAINTER
// ============================================

/// Animated smoke/ember background with organic wisps and soft glow
class FireBackgroundPainter extends CustomPainter {
  FireBackgroundPainter({
    required this.progress,
    this.intensity = 1.0,
    this.glowPosition = const Alignment(0, 1.5),
  });

  final double progress;
  final double intensity;
  final Alignment glowPosition;

  // Pre-computed smoke wisp configurations
  static final List<_SmokeWisp> _wisps = List.generate(8, (i) => _SmokeWisp(i));

  @override
  void paint(Canvas canvas, Size size) {
    final pulseIntensity = (0.2 + 0.08 * math.sin(progress * math.pi * 2)) * intensity;

    // Layer 1: Deep ambient warmth from bottom
    final ambientPaint = Paint()
      ..shader = RadialGradient(
        center: glowPosition,
        radius: 1.4,
        colors: [
          UIConstants.fireRed.withOpacity(pulseIntensity * 0.35),
          UIConstants.fireOrange.withOpacity(pulseIntensity * 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), ambientPaint);

    // Layer 2: Soft core glow
    final corePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(glowPosition.x, glowPosition.y + 0.3),
        radius: 0.6,
        colors: [
          UIConstants.fireYellow.withOpacity(pulseIntensity * 0.25),
          UIConstants.fireOrange.withOpacity(pulseIntensity * 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), corePaint);

    // Layer 3: Organic smoke wisps rising
    for (final wisp in _wisps) {
      _drawSmokeWisp(canvas, size, wisp, progress);
    }

    // Layer 4: Subtle edge vignette
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          Colors.transparent,
          Colors.transparent,
          UIConstants.fireDarkBg.withOpacity(0.3 * intensity),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
  }

  void _drawSmokeWisp(Canvas canvas, Size size, _SmokeWisp wisp, double time) {
    final wispProgress = (time * wisp.speed + wisp.delay) % 1.0;

    // Smooth easing for natural rise
    final easedProgress = _smoothstep(0.0, 1.0, wispProgress);

    // Start from bottom, rise with organic curve
    final startY = size.height * 1.1;
    final endY = size.height * -0.2;
    final currentY = startY + (endY - startY) * easedProgress;

    // Organic horizontal drift using multiple sine waves
    final drift1 = math.sin(wispProgress * math.pi * 2 + wisp.phase) * wisp.driftAmount;
    final drift2 = math.sin(wispProgress * math.pi * 4 + wisp.phase * 1.5) * wisp.driftAmount * 0.3;
    final totalDrift = (drift1 + drift2) * size.width * 0.15;
    final currentX = wisp.startX * size.width + totalDrift;

    // Opacity: fade in, sustain, fade out naturally
    double opacity = wisp.baseOpacity * intensity;
    if (wispProgress < 0.15) {
      opacity *= _smoothstep(0.0, 0.15, wispProgress);
    } else if (wispProgress > 0.6) {
      opacity *= 1.0 - _smoothstep(0.6, 1.0, wispProgress);
    }

    // Size varies during rise - expands then dissipates
    final sizeMultiplier = 1.0 + math.sin(wispProgress * math.pi) * 0.5;
    final currentWidth = wisp.width * sizeMultiplier * size.width;
    final currentHeight = wisp.height * sizeMultiplier * size.height;

    if (opacity > 0.005) {
      // Draw soft, blurred elliptical wisp
      final wispPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.5,
          colors: [
            wisp.color.withOpacity((opacity * 0.6).clamp(0.0, 1.0)),
            wisp.color.withOpacity((opacity * 0.3).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(
          Rect.fromCenter(
            center: Offset(currentX, currentY),
            width: currentWidth,
            height: currentHeight,
          ),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentWidth * 0.3);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(currentX, currentY),
          width: currentWidth,
          height: currentHeight,
        ),
        wispPaint,
      );
    }
  }

  // Attempt to define smoothstep function
  double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  @override
  bool shouldRepaint(covariant FireBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.intensity != intensity;
  }
}

/// Configuration for organic smoke wisp
class _SmokeWisp {
  _SmokeWisp(int seed) {
    final random = math.Random(seed * 7919);
    startX = 0.15 + random.nextDouble() * 0.7;
    delay = random.nextDouble();
    width = 0.15 + random.nextDouble() * 0.2;
    height = 0.08 + random.nextDouble() * 0.12;
    baseOpacity = 0.04 + random.nextDouble() * 0.06;
    driftAmount = 0.3 + random.nextDouble() * 0.5;
    speed = 0.15 + random.nextDouble() * 0.2;
    phase = random.nextDouble() * math.pi * 2;
    color = [
      UIConstants.fireOrange,
      UIConstants.fireRed,
      const Color(0xFF8B4513), // Warm brown smoke
    ][random.nextInt(3)];
  }

  late final double startX;
  late final double delay;
  late final double width;
  late final double height;
  late final double baseOpacity;
  late final double driftAmount;
  late final double speed;
  late final double phase;
  late final Color color;
}

// ============================================
// EMBER PARTICLES PAINTER
// ============================================

/// Rising ember/spark particles
class EmberParticlesPainter extends CustomPainter {
  EmberParticlesPainter({
    required this.progress,
    this.particleCount = 15,
    this.intensity = 1.0,
  }) {
    if (_embers.length != particleCount) {
      _embers = List.generate(particleCount, (i) => _Ember(i));
    }
  }

  final double progress;
  final int particleCount;
  final double intensity;
  static List<_Ember> _embers = [];

  @override
  void paint(Canvas canvas, Size size) {
    for (final ember in _embers) {
      final lifeProgress = (progress * ember.speed + ember.delay) % 1.0;
      final easedProgress = 1.0 - math.pow(1.0 - lifeProgress, 2);

      final startY = size.height + 20;
      final endY = -30.0;
      final currentY = startY + (endY - startY) * easedProgress;

      final drift = math.sin(lifeProgress * math.pi * 3 + ember.phase) * ember.driftAmount * 25;
      final currentX = ember.startX * size.width + drift;

      double opacity = ember.baseOpacity * intensity;
      if (lifeProgress < 0.1) {
        opacity *= lifeProgress / 0.1;
      } else if (lifeProgress > 0.7) {
        opacity *= (1.0 - lifeProgress) / 0.3;
      }

      final currentSize = ember.size * (1.0 - easedProgress * 0.5);

      if (opacity > 0.01 && currentSize > 0.5) {
        // Outer glow
        final glowPaint = Paint()
          ..color = ember.color.withOpacity((opacity * 0.4).clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentSize * 2);
        canvas.drawCircle(Offset(currentX, currentY), currentSize * 1.5, glowPaint);

        // Main ember body
        final bodyPaint = Paint()
          ..color = ember.color.withOpacity(opacity.clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentSize * 0.3);
        canvas.drawCircle(Offset(currentX, currentY), currentSize, bodyPaint);

        // Hot bright core
        final corePaint = Paint()
          ..color = UIConstants.fireYellow.withOpacity((opacity * 0.9).clamp(0.0, 1.0));
        canvas.drawCircle(Offset(currentX, currentY), currentSize * 0.4, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EmberParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.intensity != intensity;
  }
}

class _Ember {
  _Ember(int seed) {
    final random = math.Random(seed * 31337);
    startX = 0.1 + random.nextDouble() * 0.8;
    delay = random.nextDouble();
    size = 2.0 + random.nextDouble() * 2.5;
    baseOpacity = 0.3 + random.nextDouble() * 0.4;
    driftAmount = 0.3 + random.nextDouble() * 0.7;
    speed = 0.4 + random.nextDouble() * 0.4;
    phase = random.nextDouble() * math.pi * 2;
    color = [
      UIConstants.fireOrange,
      UIConstants.fireYellow,
      UIConstants.fireGlow,
    ][random.nextInt(3)];
  }

  late final double startX;
  late final double delay;
  late final double size;
  late final double baseOpacity;
  late final double driftAmount;
  late final double speed;
  late final double phase;
  late final Color color;
}

// ============================================
// FIRE BACKGROUND WIDGET
// ============================================

/// Animated fire background with embers - easy to use widget
class FireBackground extends StatefulWidget {
  const FireBackground({
    super.key,
    this.intensity = 1.0,
    this.showEmbers = true,
    this.emberCount = 15,
    this.glowPosition = const Alignment(0, 1.5),
    this.child,
  });

  final double intensity;
  final bool showEmbers;
  final int emberCount;
  final Alignment glowPosition;
  final Widget? child;

  @override
  State<FireBackground> createState() => _FireBackgroundState();
}

class _FireBackgroundState extends State<FireBackground>
    with TickerProviderStateMixin {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Flame background
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _flameController,
            builder: (context, child) {
              return CustomPaint(
                painter: FireBackgroundPainter(
                  progress: _flameController.value,
                  intensity: widget.intensity,
                  glowPosition: widget.glowPosition,
                ),
              );
            },
          ),
        ),

        // Ember particles
        if (widget.showEmbers)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _emberController,
              builder: (context, child) {
                return CustomPaint(
                  painter: EmberParticlesPainter(
                    progress: _emberController.value,
                    particleCount: widget.emberCount,
                    intensity: widget.intensity,
                  ),
                );
              },
            ),
          ),

        // Gradient overlay
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0D0D0D).withOpacity(0.5),
                    const Color(0xFF0D0D0D).withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),

        // Child content
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

// ============================================
// FIRE SECTION HEADER
// ============================================

/// Fire-themed section header with gradient bar and text
class FireSectionHeader extends StatelessWidget {
  const FireSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.gradientColors,
  });

  final String title;
  final Widget? trailing;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? [UIConstants.fireYellow, UIConstants.fireOrange];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: [
                  BoxShadow(
                    color: colors[0].withOpacity(0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(colors: colors).createShader(bounds),
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ============================================
// FIRE CARD
// ============================================

/// Fire-themed card with gradient background and glow
class FireCard extends StatelessWidget {
  const FireCard({
    super.key,
    required this.child,
    this.gradientColors,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16.0,
    this.onTap,
  });

  final Widget child;
  final List<Color>? gradientColors;
  final EdgeInsets padding;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? [UIConstants.fireOrange, UIConstants.fireRed];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors[0].withOpacity(0.15),
              colors[1].withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: colors[0].withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// ============================================
// FIRE BUTTON
// ============================================

/// Fire-themed button with gradient and glow
class FireButton extends StatelessWidget {
  const FireButton({
    super.key,
    required this.onTap,
    required this.child,
    this.gradientColors,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.borderRadius = 12.0,
    this.isOutlined = false,
  });

  final VoidCallback? onTap;
  final Widget child;
  final List<Color>? gradientColors;
  final EdgeInsets padding;
  final double borderRadius;
  final bool isOutlined;

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? [UIConstants.fireOrange, UIConstants.fireRed];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: isOutlined ? null : LinearGradient(colors: colors),
          color: isOutlined ? colors[0].withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(borderRadius),
          border: isOutlined ? Border.all(color: colors[0].withOpacity(0.3)) : null,
          boxShadow: isOutlined
              ? null
              : [
                  BoxShadow(
                    color: colors[0].withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
        ),
        child: child,
      ),
    );
  }
}

// ============================================
// FIRE CHIP/BADGE
// ============================================

/// Fire-themed chip/badge
class FireChip extends StatelessWidget {
  const FireChip({
    super.key,
    required this.label,
    this.icon,
    this.gradientColors,
    this.fontSize = 10,
  });

  final String label;
  final IconData? icon;
  final List<Color>? gradientColors;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? [UIConstants.fireYellow, UIConstants.fireOrange];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: fontSize + 2),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// FIRE TEXT FIELD
// ============================================

/// Fire-themed text field
class FireTextField extends StatelessWidget {
  const FireTextField({
    super.key,
    this.controller,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            UIConstants.fireOrange.withOpacity(0.1),
            UIConstants.fireRed.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: UIConstants.fireOrange.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: UIConstants.fireOrange,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 15,
          ),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}

// ============================================
// FIRE LOADING INDICATOR
// ============================================

/// Fire-themed loading indicator
class FireLoadingIndicator extends StatelessWidget {
  const FireLoadingIndicator({
    super.key,
    this.size = 40,
    this.strokeWidth = 3,
  });

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(UIConstants.fireOrange),
      ),
    );
  }
}

// ============================================
// FIRE GRADIENT TEXT
// ============================================

/// Text with fire gradient shader
class FireGradientText extends StatelessWidget {
  const FireGradientText(
    this.text, {
    super.key,
    this.style,
    this.gradientColors,
  });

  final String text;
  final TextStyle? style;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? [UIConstants.fireYellow, UIConstants.fireOrange];

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(colors: colors).createShader(bounds),
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}

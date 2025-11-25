import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Modern pastel color palette - Soft, aesthetic, and harmonious
  // Base colors - soft dark blues/purples instead of harsh black
  static const Color deepNavy = Color(0xFF1a1b26); // Soft dark background
  static const Color richNavy = Color(0xFF1f2335); // Slightly lighter
  static const Color slate = Color(0xFF24283b); // Surface color
  static const Color darkSlate = Color(0xFF2a2f4a); // Elevated surface
  static const Color mediumSlate = Color(0xFF3b4261); // Interactive elements

  // Pastel accent colors - soft and pleasing to the eye
  static const Color lavender = Color(0xFFc0a7f5); // Primary - soft purple
  static const Color rose = Color(0xFFf5a7c0); // Secondary - soft pink
  static const Color mint = Color(0xFFa7f5c0); // Tertiary - soft mint
  static const Color peach = Color(0xFFf5c0a7); // Warm accent - soft peach
  static const Color sky = Color(0xFFa7c0f5); // Cool accent - soft blue

  // Text colors - soft and readable
  static const Color cream = Color(0xFFe5e9f0); // Primary text
  static const Color lavenderGray = Color(0xFF8891b0); // Secondary text
  static const Color softWhite = Color(0xFFf5f5f5); // Brightest text

  // Legacy support (will be phased out)
  @Deprecated('Use lavender instead')
  static const Color accentGold = lavender;
  @Deprecated('Use peach instead')
  static const Color accentAmber = peach;
  @Deprecated('Use deepNavy instead')
  static const Color deepBlack = deepNavy;
  @Deprecated('Use richNavy instead')
  static const Color richBlack = richNavy;
  @Deprecated('Use slate instead')
  static const Color charcoal = slate;
  @Deprecated('Use darkSlate instead')
  static const Color darkGray = darkSlate;
  @Deprecated('Use mediumSlate instead')
  static const Color mediumGray = mediumSlate;

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: lavender,
      onPrimary: deepNavy,
      secondary: rose,
      onSecondary: deepNavy,
      tertiary: mint,
      onTertiary: deepNavy,
      error: const Color(0xFFf5a7a7), // Soft pastel red
      onError: deepNavy,
      surface: slate,
      onSurface: cream,
      surfaceContainerHighest: darkSlate,
      onSurfaceVariant: lavenderGray,
      outline: mediumSlate,
      shadow: deepNavy,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    ),
    scaffoldBackgroundColor: richNavy,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: const TextStyle(
        color: cream,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: slate,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: mediumSlate.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: mediumSlate.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: lavender, width: 2),
      ),
      labelStyle: const TextStyle(
        color: lavenderGray,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: lavenderGray.withOpacity(0.6),
        fontSize: 14,
      ),
    ),
    cardTheme: CardThemeData(
      color: slate,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.zero,
    ),
    cardColor: slate,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: lavender,
        foregroundColor: deepNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        elevation: 0,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.2,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkSlate,
      labelStyle: const TextStyle(
        color: lavenderGray,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: mediumSlate.withOpacity(0.3),
      thickness: 1,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: cream,
      iconColor: lavenderGray,
    ),
  );
}

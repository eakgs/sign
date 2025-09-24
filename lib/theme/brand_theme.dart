// lib/theme/brand_theme.dart
import 'package:flutter/material.dart';

class Brand {
  static const primary = Color(0xFF2F6DF6); // Blue
  static const primaryDark = Color(0xFF1B4ACB);
  static const mint = Color(0xFF26D7AE); // Accent
  static const ink = Color(0xFF0E1C2B); // Text
  static const slate = Color(0xFF6B7A90); // Secondary text
  static const surface = Color(0xFFF6F8FC); // Cards/surfaces
  static const outline = Color(0xFFE2E7F0); // Strokes
  static const danger = Color(0xFFE53935);
}

ThemeData eviaTheme(BuildContext ctx) {
  final base = ThemeData(useMaterial3: true);

  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.primary,
    primary: Brand.primary,
    onPrimary: Colors.white,
    secondary: Brand.mint,
    onSecondary: Colors.black,
    surface: Brand.surface,
    // background: Colors.white,  // ← remove this line
    brightness: Brightness.light,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,

    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      foregroundColor: Brand.ink,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),

    // ✅ Use CardThemeData (not CardTheme)
    cardTheme: CardThemeData(
      color: Brand.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent, // avoid M3 tint
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Brand.outline),
      ),
      margin: const EdgeInsets.all(0),
      clipBehavior: Clip.antiAlias,
    ),

    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 1,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Brand.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: Brand.mint,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: Brand.ink,
        backgroundColor: Brand.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: Brand.outline,
      thickness: 1,
      space: 1,
    ),
  );
}

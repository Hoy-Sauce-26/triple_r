import 'package:flutter/material.dart';

/// Shared with Roamfree (`../step_counter`). The two apps are siblings and are
/// meant to read as one family, so the seed is deliberately identical.
const seedColor = Color(0xFF67FF7B);

ThemeData _theme(Brightness brightness) {
  final colors = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  return ThemeData(
    colorScheme: colors,
    useMaterial3: true,
    // Flat surfaces throughout — the design language leans on spacing and
    // type for hierarchy rather than elevation.
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: colors.surface,
      scrolledUnderElevation: 0,
    ),
  );
}

ThemeData get lightTheme => _theme(Brightness.light);
ThemeData get darkTheme => _theme(Brightness.dark);

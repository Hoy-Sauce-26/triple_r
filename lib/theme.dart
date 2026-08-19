import 'package:flutter/material.dart';

/// Triple R's seed colour.
///
/// Roamfree (`../step_counter`) seeds from amber; this one is its own. The two
/// stay siblings through *structure* — Material 3, flat surfaces, hierarchy
/// from spacing and type rather than elevation — not through sharing a hue.
const seedColor = Color(0xFFA6FF67);

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
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    // Matches the cards, so a bottom sheet reads as the same surface family.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    // A workout is a two-handed, sweaty, glance-at-it context; the default
    // 48dp targets are the floor, not the goal.
    listTileTheme: const ListTileThemeData(minVerticalPadding: 10),
  );
}

ThemeData get lightTheme => _theme(Brightness.light);
ThemeData get darkTheme => _theme(Brightness.dark);

/// Numeric styling for anything that changes in place.
extension NumericTextStyle on TextStyle {
  /// Fixed-width digits.
  ///
  /// Without this, a counting timer visibly jitters as glyph widths change —
  /// 1 is narrower than 8 in the default proportional figures, so "1:11"
  /// occupies less space than "8:88" and the whole line shifts every second.
  /// Applied per-use rather than to the text theme, because tabular figures
  /// make ordinary prose look subtly mechanical.
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

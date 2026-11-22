import 'package:material_ui/material_ui.dart';

import 'app_palette.dart';

class AppTheme {
  /// The light theme for [palette].
  ///
  /// The accent seeds the Material colour scheme, and the palette itself is
  /// registered as an extension so screens can reach the background gradient
  /// and card surface without any widget needing to know which scheme is on.
  static ThemeData light([AppPalette palette = AppPalette.fallback]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: colorScheme,
      switchTheme: _switchTheme(colorScheme),
      extensions: [palette],
      useMaterial3: true,
    );
  }

  /// Retained for the platform dark theme. UnderCroft currently ships light
  /// schemes only; this keeps following the palette accent so the two stay in
  /// step if a dark scheme is offered later.
  static ThemeData dark([AppPalette palette = AppPalette.fallback]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: colorScheme,
      switchTheme: _switchTheme(colorScheme),
      extensions: [palette],
      useMaterial3: true,
    );
  }

  static SwitchThemeData _switchTheme(ColorScheme colorScheme) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.38);
        }
        return states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colorScheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
        }
        return states.contains(WidgetState.selected)
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? Colors.transparent
            : colorScheme.outline;
      }),
    );
  }
}

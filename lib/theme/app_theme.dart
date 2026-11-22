import 'package:material_ui/material_ui.dart';

import 'app_palette.dart';

class AppTheme {
  /// The app theme for [palette].
  ///
  /// The accent seeds the Material colour scheme, and the palette itself is
  /// registered as an extension so screens can reach the background gradient
  /// and card surface without any widget needing to know which scheme is on.
  /// The palette's [AppPalette.brightness] decides light vs dark text, so a
  /// dark scheme gets light-on-dark automatically.
  static ThemeData light([AppPalette palette = AppPalette.fallback]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: palette.brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      switchTheme: _switchTheme(colorScheme),
      extensions: [palette],
      useMaterial3: true,
    );
  }

  /// The theme used if the platform is set to follow system dark mode.
  ///
  /// UnderCroft ships its own dark schemes (e.g. Obsidian) through the palette
  /// rather than via system dark mode, so this keeps the accent in step if
  /// `themeMode` is ever switched from [ThemeMode.light].
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

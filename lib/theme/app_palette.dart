import 'package:material_ui/material_ui.dart';

/// A selectable colour scheme.
///
/// Every scheme keeps the app's existing structure — a soft vertical
/// background gradient, a single accent for icons, links and buttons, and a
/// near-white surface for the content cards — and differs only in its colours.
///
/// The [sage] scheme carries the original literal values, so a device that
/// never touches the setting keeps looking exactly as it did before.
class AppPalette extends ThemeExtension<AppPalette> {
  /// Stable identifier, stored on the device.
  final String id;

  /// Label shown in Settings.
  final String name;

  /// Icons, links, buttons and the seed for the Material colour scheme.
  final Color accent;

  /// Top of the screen background gradient.
  final Color backgroundTop;

  /// Bottom of the screen background gradient.
  final Color backgroundBottom;

  /// Fill for the content cards — the "text boxes" the paler schemes tint.
  final Color cardSurface;

  const AppPalette({
    required this.id,
    required this.name,
    required this.accent,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.cardSurface,
  });

  /// The original look, and the fallback whenever a stored id is unknown.
  static const AppPalette sage = AppPalette(
    id: 'sage',
    name: 'Sage',
    accent: Color(0xFF5B7C6A),
    backgroundTop: Color(0xFFF5F1E8),
    backgroundBottom: Color(0xFFEDE6D6),
    cardSurface: Color(0xFFFFFFFF),
  );

  static const AppPalette slate = AppPalette(
    id: 'slate',
    name: 'Slate',
    accent: Color(0xFF4A6C8C),
    backgroundTop: Color(0xFFEDF2F7),
    backgroundBottom: Color(0xFFDCE4EE),
    cardSurface: Color(0xFFFCFDFF),
  );

  static const AppPalette clay = AppPalette(
    id: 'clay',
    name: 'Clay',
    accent: Color(0xFFA45B3A),
    backgroundTop: Color(0xFFFAF1E8),
    backgroundBottom: Color(0xFFF2E0D1),
    cardSurface: Color(0xFFFFFCF8),
  );

  static const AppPalette plum = AppPalette(
    id: 'plum',
    name: 'Plum',
    accent: Color(0xFF6E4A73),
    backgroundTop: Color(0xFFF7F1F7),
    backgroundBottom: Color(0xFFEBE0EC),
    cardSurface: Color(0xFFFDFAFE),
  );

  /// The schemes offered in Settings, in menu order.
  static const List<AppPalette> choices = [sage, slate, clay, plum];

  static const AppPalette fallback = sage;

  /// Resolves a stored id, falling back to [fallback] for anything unknown.
  static AppPalette byId(String? id) {
    for (final palette in choices) {
      if (palette.id == id) return palette;
    }
    return fallback;
  }

  /// The background gradient shared by every screen that has one.
  LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [backgroundTop, backgroundBottom],
      );

  /// The scheme in force for [context].
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? fallback;

  @override
  AppPalette copyWith({
    String? id,
    String? name,
    Color? accent,
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? cardSurface,
  }) {
    return AppPalette(
      id: id ?? this.id,
      name: name ?? this.name,
      accent: accent ?? this.accent,
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      cardSurface: cardSurface ?? this.cardSurface,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    // Schemes are swapped, never blended, so the nearer end wins. Colours are
    // mid-animation for at most a frame, which nobody sees.
    return t < 0.5 ? this : other;
  }
}

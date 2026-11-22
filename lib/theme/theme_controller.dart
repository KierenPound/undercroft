import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_palette.dart';

/// Holds the chosen colour scheme and remembers it on the device.
///
/// Appearance is a per-device preference rather than estate data: it has to be
/// known before the first frame and it should not follow the user onto another
/// phone, so it lives in SharedPreferences instead of the database.
class ThemeController extends Notifier<AppPalette> {
  static const String _preferenceKey = 'app_colour_scheme';

  @override
  AppPalette build() {
    // Start on the default so the first frame can paint, then adopt whatever
    // was stored last time. The swap is a single frame at most.
    _restore();
    return AppPalette.fallback;
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(_preferenceKey);
      if (stored == null) return;
      state = AppPalette.byId(stored);
    } catch (_) {
      // A preference read must never stop the app from starting.
    }
  }

  /// Switches schemes and stores the choice.
  Future<void> select(AppPalette palette) async {
    if (state.id == palette.id) return;
    state = palette;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_preferenceKey, palette.id);
    } catch (_) {
      // Keep the choice for this session even if it could not be stored.
    }
  }
}

final appPaletteProvider =
    NotifierProvider<ThemeController, AppPalette>(ThemeController.new);

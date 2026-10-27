import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps the device biometric prompt and the "app lock enabled" preference.
///
/// This is a local convenience gate: it hides the UI until the owner
/// authenticates, but it does not encrypt the stored Supabase session.
class BiometricLockService {
  BiometricLockService._();

  static const String _enabledKey = 'biometric_lock_enabled';

  static final LocalAuthentication _auth = LocalAuthentication();

  /// True when the device has biometric hardware AND the user has enrolled
  /// at least one fingerprint or face. Unsupported platforms (web, desktop)
  /// return false so the lock silently never engages there.
  static Future<bool> isSupported() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      return canCheck && deviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// The user's stored preference, forced to false on devices that cannot
  /// honour it.
  static Future<bool> isEnabled() async {
    if (!await isSupported()) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// Presents the system prompt. Returns true only on a successful match.
  ///
  /// Device-passcode fallback is deliberately allowed: biometrics lock out
  /// after repeated failures, and without the fallback the user would be
  /// permanently shut out of their own estate records.
  static Future<bool> authenticate() async {
    if (!await isSupported()) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock UnderCroft to view your estate records',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

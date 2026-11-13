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

  /// Whether the device can authenticate using biometrics or its passcode.
  ///
  /// This is used to decide whether Settings can enable the lock. It does not
  /// control whether an already-enabled lock remains active.
  static Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// The stored preference remains authoritative if authentication is
  /// temporarily unavailable, so the app stays covered rather than opening.
  static Future<bool> isEnabled() async {
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

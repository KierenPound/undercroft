import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists Supabase sessions in platform secure storage and migrates sessions
/// written by supabase_flutter's previous SharedPreferences implementation.
class SecureSessionLocalStorage extends LocalStorage {
  SecureSessionLocalStorage({
    required this.persistSessionKey,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? _secureStorage;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Records that this install has already been through [_prepareSessionStorage].
  ///
  /// Held in SharedPreferences rather than secure storage because it has to be
  /// deleted along with the app — it is precisely what distinguishes a fresh
  /// install from a resumed one.
  static const String _installMarkerKey = 'install_marker';

  final String persistSessionKey;
  final FlutterSecureStorage _storage;
  Future<void>? _initialization;

  @override
  Future<void> initialize() => _initialization ??= _prepareSessionStorage();

  Future<void> _prepareSessionStorage() async {
    final preferences = await SharedPreferences.getInstance();

    // A previous run of this build already settled the install state, so there
    // is nothing left to check or clean up.
    if (preferences.getBool(_installMarkerKey) ?? false) return;

    final legacySession = preferences.getString(persistSessionKey);

    if (legacySession == null) {
      // Fresh install. iOS keeps Keychain items after the app is uninstalled,
      // so a session left behind by a previous install would otherwise sign
      // the new install straight in as the old user. Nothing legitimate can
      // exist before the first sign-in here, so clear it before anything
      // reads it.
      await _storage.delete(key: persistSessionKey);
    } else {
      // An install from the SharedPreferences era. Keep an existing secure
      // session if one is present, and remove the plaintext copy only after
      // the secure write has succeeded.
      final secureSession = await _storage.read(key: persistSessionKey);
      if (secureSession == null) {
        await _storage.write(key: persistSessionKey, value: legacySession);
      }
      await preferences.remove(persistSessionKey);
    }

    // Written last on purpose: if the work above throws, the marker stays
    // unset and the next launch retries instead of treating this install as
    // already handled.
    await preferences.setBool(_installMarkerKey, true);
  }

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: persistSessionKey);

  @override
  Future<String?> accessToken() => _storage.read(key: persistSessionKey);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: persistSessionKey, value: persistSessionString);
}

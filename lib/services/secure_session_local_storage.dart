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

  final String persistSessionKey;
  final FlutterSecureStorage _storage;
  Future<void>? _initialization;

  @override
  Future<void> initialize() =>
      _initialization ??= _migrateSharedPreferencesSession();

  Future<void> _migrateSharedPreferencesSession() async {
    final preferences = await SharedPreferences.getInstance();
    final legacySession = preferences.getString(persistSessionKey);
    if (legacySession == null) return;

    // Keep an existing secure session if one is present. Remove the old copy
    // only after the secure write has succeeded.
    final secureSession = await _storage.read(key: persistSessionKey);
    if (secureSession == null) {
      await _storage.write(key: persistSessionKey, value: legacySession);
    }
    await preferences.remove(persistSessionKey);
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

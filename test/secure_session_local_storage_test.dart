import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercroft/services/secure_session_local_storage.dart';

const _persistSessionKey = 'sb-test-project-auth-token';
const _installMarkerKey = 'install_marker';

class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage([Map<String, String>? initialValues])
      : values = initialValues ?? {};

  final Map<String, String> values;
  bool failWrites = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values.containsKey(key);

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrites) throw StateError('secure write failed');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  test('migrates the legacy session and removes its plaintext copy', () async {
    SharedPreferences.setMockInitialValues({
      _persistSessionKey: 'legacy-session',
    });
    final secureStorage = _MemorySecureStorage();
    final localStorage = SecureSessionLocalStorage(
      persistSessionKey: _persistSessionKey,
      storage: secureStorage,
    );

    await localStorage.initialize();

    final preferences = await SharedPreferences.getInstance();
    expect(secureStorage.values[_persistSessionKey], 'legacy-session');
    expect(preferences.getString(_persistSessionKey), isNull);
    // The marker stops the install check running again on the next launch.
    expect(preferences.getBool(_installMarkerKey), isTrue);
  });

  test('preserves a secure session and removes the legacy copy', () async {
    SharedPreferences.setMockInitialValues({
      _persistSessionKey: 'legacy-session',
    });
    final secureStorage =
        _MemorySecureStorage({_persistSessionKey: 'secure-session'});
    final localStorage = SecureSessionLocalStorage(
      persistSessionKey: _persistSessionKey,
      storage: secureStorage,
    );

    await localStorage.initialize();

    final preferences = await SharedPreferences.getInstance();
    expect(await localStorage.accessToken(), 'secure-session');
    expect(preferences.getString(_persistSessionKey), isNull);
  });

  test('keeps the legacy copy if writing to secure storage fails', () async {
    SharedPreferences.setMockInitialValues({
      _persistSessionKey: 'legacy-session',
    });
    final secureStorage = _MemorySecureStorage()..failWrites = true;
    final localStorage = SecureSessionLocalStorage(
      persistSessionKey: _persistSessionKey,
      storage: secureStorage,
    );

    await expectLater(localStorage.initialize(), throwsStateError);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(_persistSessionKey), 'legacy-session');
    // Left unset so the migration is retried on the next launch.
    expect(preferences.getBool(_installMarkerKey), isNull);
  });

  test('clears a stale secure session on a fresh install', () async {
    // No marker and no legacy session: the app was deleted and reinstalled,
    // but the iOS Keychain entry outlived the uninstall.
    SharedPreferences.setMockInitialValues({});
    final secureStorage = _MemorySecureStorage({
      _persistSessionKey: 'session-from-previous-install',
    });
    final localStorage = SecureSessionLocalStorage(
      persistSessionKey: _persistSessionKey,
      storage: secureStorage,
    );

    await localStorage.initialize();

    final preferences = await SharedPreferences.getInstance();
    expect(await localStorage.accessToken(), isNull);
    expect(secureStorage.values, isEmpty);
    expect(preferences.getBool(_installMarkerKey), isTrue);
  });

  test('keeps a stale secure session once the install is marked', () async {
    // Same Keychain contents as above, but this install has already signed in
    // before, so the session is a real one and must be left alone.
    SharedPreferences.setMockInitialValues({_installMarkerKey: true});
    final secureStorage =
        _MemorySecureStorage({_persistSessionKey: 'secure-session'});
    final localStorage = SecureSessionLocalStorage(
      persistSessionKey: _persistSessionKey,
      storage: secureStorage,
    );

    await localStorage.initialize();

    expect(await localStorage.accessToken(), 'secure-session');
  });
}

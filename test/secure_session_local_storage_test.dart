import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercroft/services/secure_session_local_storage.dart';

const _persistSessionKey = 'sb-test-project-auth-token';

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
  setUp(() {
    SharedPreferences.setMockInitialValues({
      _persistSessionKey: 'legacy-session',
    });
  });

  test('migrates the legacy session and removes its plaintext copy', () async {
    final secureStorage = _MemorySecureStorage();
    final localStorage = SecureSessionLocalStorage(
      persistSessionKey: _persistSessionKey,
      storage: secureStorage,
    );

    await localStorage.initialize();

    final preferences = await SharedPreferences.getInstance();
    expect(secureStorage.values[_persistSessionKey], 'legacy-session');
    expect(preferences.getString(_persistSessionKey), isNull);
  });

  test('preserves a secure session and removes the legacy copy', () async {
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
    final secureStorage = _MemorySecureStorage()..failWrites = true;
    final localStorage = SecureSessionLocalStorage(
      persistSessionKey: _persistSessionKey,
      storage: secureStorage,
    );

    await expectLater(localStorage.initialize(), throwsStateError);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(_persistSessionKey), 'legacy-session');
  });
}

import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_session_local_storage.dart';

class SupabaseService {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Where Supabase sends the user back to after an emailed link.
  ///
  /// The reset and confirmation emails both carry this, so there is one value
  /// to keep in step with three other places: the scheme registered under
  /// CFBundleURLTypes in ios/Runner/Info.plist, the App Links / URL Types entry
  /// in android/app/src/main/AndroidManifest.xml, and the Redirect URLs
  /// allow-list in the Supabase dashboard.
  static const String authRedirectUrl =
      'com.kierenpound.undercroft://login-callback/';

  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be configured.',
      );
    }

    // Keep this key in sync with supabase_flutter's default storage key so
    // existing SharedPreferences sessions can be migrated on first launch.
    final projectRef = Uri.parse(supabaseUrl).host.split('.').first;
    final persistSessionKey = 'sb-$projectRef-auth-token';

    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionLocalStorage(
          persistSessionKey: persistSessionKey,
        ),
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

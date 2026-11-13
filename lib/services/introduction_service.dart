import 'package:supabase_flutter/supabase_flutter.dart';

/// Remembers whether someone has already read the introduction.
///
/// The flag lives in the account's own metadata rather than on the device, so
/// the introduction does not reappear after a reinstall or when the same
/// person signs in on another device. It is a presentation flag, not a
/// permission, so client-side storage in user metadata is enough — nothing
/// depends on it for security.
class IntroductionService {
  const IntroductionService._();

  static const String _seenKey = 'introduction_seen';

  /// Whether [user] has read the introduction.
  static bool hasSeen(User? user) => user?.userMetadata?[_seenKey] == true;

  /// Convenience read against the live session.
  ///
  /// Reads the client rather than a cached user object, so the answer is
  /// correct immediately after [markSeen] rather than only once the next auth
  /// event has been delivered.
  static bool hasSeenIntroduction() =>
      hasSeen(Supabase.instance.client.auth.currentUser);

  /// Records that the introduction has been read.
  ///
  /// Failure is swallowed: the worst outcome is that it is shown once more,
  /// which is a far better failure than blocking someone out of the app.
  static Future<void> markSeen() async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {_seenKey: true}),
      );
    } catch (_) {
      // Left unset deliberately — see the doc comment above.
    }
  }
}

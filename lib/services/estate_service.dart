import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Emits the current signed-in user whenever the auth state changes.
///
/// Other providers watch this so they re-evaluate on sign-in/sign-out
/// instead of serving a cached value from a previous session.
final currentUserProvider = StreamProvider<User?>((ref) async* {
  final client = Supabase.instance.client;
  // Emit the current user immediately so dependents don't wait for the
  // first auth-state-change event.
  yield client.auth.currentUser;
  // Then re-emit on every subsequent change.
  await for (final state in client.auth.onAuthStateChange) {
    yield state.session?.user;
  }
});

/// The role actually recorded in the database for the current user.
///
/// Distinct from the *effective* role used by the UI: a developer can
/// simulate the executor role via [simulatedRoleProvider] to test the
/// read-only UI without changing the database.
final estateRoleProvider = FutureProvider<String>((ref) async {
  // Depend on the auth stream so the role is re-fetched whenever the
  // signed-in user changes (sign out → sign in as someone else).
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return '';

  final client = Supabase.instance.client;

  try {
    // A user should only ever have one accepted row per estate, but if a
    // duplicate ever slips through (e.g. testing invite flow on the owner's
    // own account), prefer 'owner' so the UI reflects the highest privilege.
    final rows = await client
        .from('estate_access')
        .select('role')
        .eq('user_id', user.id)
        .eq('status', 'accepted')
        .order('role', ascending: false);

    if (rows.isEmpty) return '';
    return rows.first['role'] as String? ?? '';
  } catch (_) {
    return '';
  }
});

/// Developer-only role override. When non-null, the UI treats the user as
/// having this role (so read-only states can be tested) without writing
/// anything to the database. Set to `null` to resume the real role.
final simulatedRoleProvider = StateProvider<String?>((ref) => null);

/// Whether the current user should be treated as an estate owner.
///
/// Respects [simulatedRoleProvider] first so developers can toggle into the
/// executor view for testing; otherwise reads the real role from Supabase.
final isOwnerProvider = FutureProvider<bool>((ref) async {
  final simulated = ref.watch(simulatedRoleProvider);
  if (simulated != null) {
    return simulated == 'owner';
  }
  final role = await ref.watch(estateRoleProvider.future);
  return role == 'owner';
});

final estateIdProvider = FutureProvider<String>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return '';

  final client = Supabase.instance.client;

  try {
    final rows = await client
        .from('estate_access')
        .select('estate_id')
        .eq('user_id', user.id)
        .eq('status', 'accepted')
        .limit(1);

    if (rows.isEmpty) return '';
    return rows.first['estate_id'] as String;
  } catch (_) {
    return '';
  }
});

final hasEstateProvider = FutureProvider<bool>((ref) async {
  final estateId = await ref.watch(estateIdProvider.future);
  return estateId.isNotEmpty;
});

/// The display name of the estate the current user belongs to.
final estateNameProvider = FutureProvider<String>((ref) async {
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return '';

  final client = Supabase.instance.client;
  try {
    final rows = await client
        .from('estates')
        .select('name')
        .eq('id', estateId)
        .limit(1);
    if (rows.isEmpty) return '';
    return rows.first['name'] as String? ?? '';
  } catch (_) {
    return '';
  }
});

/// Characters used when generating invite codes. Ambiguous glyphs
/// (0/O, 1/I) are excluded to avoid confusion when reading the code.
const String _inviteCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Generates a random 6-character invite code.
String generateInviteCode() {
  final random = Random.secure();
  return List.generate(
    6,
    (_) => _inviteCodeChars[random.nextInt(_inviteCodeChars.length)],
  ).join();
}

/// Creates a pending executor invite for the given estate.
///
/// Inserts an `estate_access` row with `role = 'executor'`,
/// `status = 'pending'`, a freshly generated 6-char [invite_code], and
/// optionally the [invitedEmail]. Returns the invite code.
///
/// Only the estate owner can do this (enforced by RLS on the server).
Future<String> inviteExecutor({
  required String estateId,
  String? invitedEmail,
}) async {
  final client = Supabase.instance.client;
  final code = generateInviteCode();

  await client.from('estate_access').insert({
    'estate_id': estateId,
    'role': 'executor',
    'status': 'pending',
    'invite_code': code,
    if (invitedEmail != null && invitedEmail.isNotEmpty)
      'invited_email': invitedEmail,
  });

  return code;
}

/// Creates a pending co-owner invite for the given estate.
///
/// Inserts an `estate_access` row with `role = 'owner'`,
/// `status = 'pending'`, a freshly generated 6-char [invite_code], and
/// optionally the [invitedEmail]. Returns the invite code.
///
/// The person who claims this code becomes a co-owner of the estate with
/// the same privileges as the original owner.
///
/// Only the estate owner can do this (enforced by RLS on the server).
Future<String> inviteOwner({
  required String estateId,
  String? invitedEmail,
}) async {
  final client = Supabase.instance.client;
  final code = generateInviteCode();

  await client.from('estate_access').insert({
    'estate_id': estateId,
    'role': 'owner',
    'status': 'pending',
    'invite_code': code,
    if (invitedEmail != null && invitedEmail.isNotEmpty)
      'invited_email': invitedEmail,
  });

  return code;
}

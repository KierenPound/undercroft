import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EstateContext {
  final String estateId;
  final String role;

  const EstateContext({
    required this.estateId,
    required this.role,
  });
}

Future<EstateContext?> fetchCurrentEstateContext() async {
  final client = Supabase.instance.client;
  final result = await client.rpc('get_or_create_current_estate_context');
  if (result is! List || result.isEmpty) return null;

  final row = result.first;
  if (row is! Map) return null;

  final estateId = row['estate_id'] as String?;
  final role = row['role'] as String?;
  if (estateId == null || estateId.isEmpty) return null;

  return EstateContext(
    estateId: estateId,
    role: role ?? '',
  );
}

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

  try {
    final context = await fetchCurrentEstateContext();
    return context?.role ?? '';
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

  try {
    final context = await fetchCurrentEstateContext();
    return context?.estateId ?? '';
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

/// Renames the estate. Read/write for estate owners only; executors get a
/// rejection from RLS on the server, so the UI hides the control for them.
///
/// The `estates` UPDATE policy permits any accepted member with the `owner`
/// role, so co-owners can rename as well as the original owner.
Future<void> updateEstateName({
  required String estateId,
  required String name,
}) async {
  final client = Supabase.instance.client;
  await client.from('estates').update({'name': name}).eq('id', estateId);
}

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

const _inviteMonthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// One row from `estate_access`: somebody invited to, or already sharing,
/// this estate.
class EstateInvite {
  final String id;
  final String? invitedEmail;
  final String role;
  final String status;
  final DateTime? createdAt;

  /// The 6-character code for a pending invite, so it can be re-read and
  /// re-sent after the generation screen has been left. Null once claimed.
  final String? inviteCode;

  /// True when this row belongs to the signed-in user, so the UI can avoid
  /// offering them the means to remove their own access.
  final bool isSelf;

  const EstateInvite({
    required this.id,
    required this.invitedEmail,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.isSelf,
    this.inviteCode,
  });

  bool get isPending => status == 'pending';
  bool get isRevoked => status == 'revoked';

  String get roleLabel => role == 'owner' ? 'Estate Owner' : 'Executor';

  String get statusLabel {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'revoked':
        return 'Revoked';
      default:
        return 'Pending';
    }
  }

  String get formattedDate {
    final created = createdAt;
    if (created == null) return '';
    final local = created.toLocal();
    final month = _inviteMonthAbbreviations[local.month - 1];
    return '${local.day} $month ${local.year}';
  }
}

/// Lists everyone who has been invited to, or already shares, [estateId].
///
/// Owners can read every row for their estate (`estate_access_select_linked`).
/// Revoked rows are included on purpose: because revocation keeps the row,
/// the estate retains a record of who previously had access.
Future<List<EstateInvite>> fetchEstateInvites({
  required String estateId,
  required String currentUserId,
}) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from('estate_access')
      .select(
        'id, invited_email, role, status, created_at, user_id, invite_code',
      )
      .eq('estate_id', estateId)
      .order('created_at', ascending: false);

  return rows.map((row) {
    final userId = row['user_id'] as String?;
    final status = row['status'] as String? ?? 'pending';
    return EstateInvite(
      id: row['id'] as String,
      invitedEmail: row['invited_email'] as String?,
      role: row['role'] as String? ?? 'executor',
      status: status,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      isSelf: userId != null && userId == currentUserId,
      // Only a pending code is worth showing: once claimed or revoked it can
      // no longer be redeemed.
      inviteCode: status == 'pending' ? row['invite_code'] as String? : null,
    );
  }).toList();
}

/// Revokes an invitation or an existing member's access.
///
/// The row is kept and marked `revoked` rather than deleted, so the estate
/// keeps a record of who was removed. Access ends as soon as this lands:
/// both `get_allowed_estate_ids` and `get_or_create_current_estate_context`
/// only honour rows whose status is 'accepted'.
///
/// This also cancels an unused invite, because claiming one requires
/// `status = 'pending'`, so the code stops working.
///
/// Note: this cannot remove the estate's original owner. Their row is
/// recreated on next launch by `get_or_create_current_estate_context`, which
/// matches on `estates.owner_id`.
Future<void> revokeEstateAccess(String accessId) async {
  final client = Supabase.instance.client;
  await client
      .from('estate_access')
      .update({'status': 'revoked'}).eq('id', accessId);
}

/// Everybody invited to the current estate, most recent first.
final estateInvitesProvider = FutureProvider<List<EstateInvite>>((ref) async {
  final userId = ref.watch(currentUserProvider).valueOrNull?.id ?? '';
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return [];

  try {
    return await fetchEstateInvites(
      estateId: estateId,
      currentUserId: userId,
    );
  } catch (_) {
    return [];
  }
});

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

/// Deletes the signed-in user's account and everything held against it.
///
/// The database side is a single delete of the auth user: every public table
/// cascades from it, so an estate owner's estate and all of its content go with
/// it, while an executor merely loses their access.
///
/// If the caller owns an estate, its storage folder is emptied first, through
/// the Storage API. That order matters: the delete policy authorises via
/// `get_allowed_estate_ids()`, which stops matching once the estate rows are
/// gone. Anything missed here would be billed for and permanently unreachable.
Future<void> deleteMyAccount() async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw StateError('deleteMyAccount: not signed in');
  }

  final owned = await client.from('estates').select('id').eq('owner_id', userId);
  for (final row in owned) {
    await _deleteEstateFiles(row['id'] as String);
  }

  await client.rpc('delete_my_account');

  // The auth user no longer exists, so clear the dead session locally and let
  // the router send the user back to sign-in.
  try {
    await client.auth.signOut();
  } catch (_) {}
}

/// Empties `estate-documents/<estateId>/`, including nested utility folders.
Future<void> _deleteEstateFiles(String estateId) async {
  final storage = Supabase.instance.client.storage.from('estate-documents');

  // A Storage "folder" is just a path prefix with no object behind it, so the
  // tree has to be walked by hand to find the real files.
  Future<List<String>> walk(String prefix) async {
    final entries = await storage.list(path: prefix);
    final paths = <String>[];
    for (final entry in entries) {
      final child = '$prefix/${entry.name}';
      if (entry.id == null) {
        paths.addAll(await walk(child));
      } else {
        paths.add(child);
      }
    }
    return paths;
  }

  final paths = await walk(estateId);
  const chunkSize = 100;
  for (var i = 0; i < paths.length; i += chunkSize) {
    final end = i + chunkSize > paths.length ? paths.length : i + chunkSize;
    await storage.remove(paths.sublist(i, end));
  }
}

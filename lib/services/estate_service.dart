import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/build_flags.dart';
import 'photo_cache_service.dart';

class EstateContext {
  final String estateId;
  final String role;

  const EstateContext({
    required this.estateId,
    required this.role,
  });
}

class EstateOwnerReviewStatus {
  final DateTime? lastReviewedAt;
  final DateTime nextReminderAt;
  final bool remindersEnabled;

  const EstateOwnerReviewStatus({
    required this.lastReviewedAt,
    required this.nextReminderAt,
    required this.remindersEnabled,
  });

  factory EstateOwnerReviewStatus.fromRow(Map<String, dynamic> row) {
    return EstateOwnerReviewStatus(
      lastReviewedAt:
          DateTime.tryParse(row['last_reviewed_at'] as String? ?? ''),
      nextReminderAt: DateTime.parse(row['next_reminder_at'] as String),
      remindersEnabled: row['reminders_enabled'] as bool? ?? true,
    );
  }
}

enum EstateProcessRegion {
  scotland,
  ewni;

  String get dbValue {
    switch (this) {
      case EstateProcessRegion.scotland:
        return 'scotland';
      case EstateProcessRegion.ewni:
        return 'ewni';
    }
  }

  String get label {
    switch (this) {
      case EstateProcessRegion.scotland:
        return 'Scotland';
      case EstateProcessRegion.ewni:
        return 'England, Wales & Northern Ireland';
    }
  }

  static EstateProcessRegion fromDbValue(String? value) {
    switch (value) {
      case 'ewni':
        return EstateProcessRegion.ewni;
      case 'scotland':
      default:
        return EstateProcessRegion.scotland;
    }
  }
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

/// Developer-only switch that puts invitations behind the paid handover
/// unlock, so the purchase flow can be rehearsed without waiting for billing
/// to ship. Off by default, and never written anywhere: turning it back off
/// leaves the estate exactly as it was.
final testPaymentGateProvider = StateProvider<bool>((ref) => false);

/// Whether the current estate has a durable handover entitlement.
///
/// Clients can read only the estate ID from this table. Grants and store
/// transaction details are written by trusted backend/admin code.
///
/// Before inserting into `estate_handover_entitlements`, backend code must
/// verify the signed Apple transaction or Google Play purchase token with the
/// respective store; match the app/package and handover product IDs; confirm
/// the transaction is paid, valid for the expected store environment, and not
/// refunded or revoked; enforce transaction-ID uniqueness and idempotency; and
/// associate the grant with an estate the authenticated purchaser may manage.
/// Client-reported purchase status or receipt data alone must never grant it.
final estateHandoverEntitlementProvider = FutureProvider<bool>((ref) async {
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return false;

  try {
    final row = await Supabase.instance.client
        .from('estate_handover_entitlements')
        .select('estate_id')
        .eq('estate_id', estateId)
        .maybeSingle();
    return row != null;
  } catch (_) {
    // Fail closed if the entitlement table is unavailable or the request fails.
    return false;
  }
});

/// Temporary in-memory unlock after a successful store transaction.
///
/// A verified store transaction must be granted through trusted backend code
/// before this becomes durable.
final sessionInvitesUnlockedProvider = StateProvider<bool>((ref) => false);

/// Whether invitations are unlocked by either a persisted entitlement or a
/// successful purchase in the current session.
final invitesUnlockedProvider = Provider<bool>((ref) {
  final sessionUnlock = ref.watch(sessionInvitesUnlockedProvider);
  final durableUnlock =
      ref.watch(estateHandoverEntitlementProvider).valueOrNull ?? false;
  return sessionUnlock || durableUnlock;
});

/// Whether invitations are currently withheld pending payment.
///
/// False whenever the test gate is off, so the app behaves exactly as it does
/// today unless a developer has deliberately switched the gate on. A build
/// without the developer tools cannot be put into the paywalled state at all,
/// so in a release build this is always false.
final invitesLockedProvider = Provider<bool>((ref) {
  if (!devToolsEnabled) return false;
  final gating = ref.watch(testPaymentGateProvider);
  final unlocked = ref.watch(invitesUnlockedProvider);
  return gating && !unlocked;
});

/// Whether the current user should be treated as an estate owner.
///
/// Respects [simulatedRoleProvider] first so developers can toggle into the
/// executor view for testing; otherwise reads the real role from Supabase.
/// The simulation is only consulted when the developer tools are present, so
/// a release build always reports the role recorded in the database.
final isOwnerProvider = FutureProvider<bool>((ref) async {
  if (devToolsEnabled) {
    final simulated = ref.watch(simulatedRoleProvider);
    if (simulated != null) {
      return simulated == 'owner';
    }
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

/// The private annual-review schedule for the signed-in estate owner.
final estateOwnerReviewStatusProvider =
    FutureProvider<EstateOwnerReviewStatus?>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return null;

  final role = await ref.watch(estateRoleProvider.future);
  if (role != 'owner') return null;

  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return null;

  final row = await Supabase.instance.client
      .from('estate_owner_review_status')
      .select(
        'last_reviewed_at, next_reminder_at, reminders_enabled',
      )
      .eq('estate_id', estateId)
      .eq('owner_user_id', user.id)
      .maybeSingle();

  if (row == null) return null;
  return EstateOwnerReviewStatus.fromRow(row);
});

Future<void> confirmEstateDetailsReviewed({
  required String estateId,
}) async {
  await Supabase.instance.client.rpc(
    'confirm_estate_details_reviewed',
    params: {'requested_estate_id': estateId},
  );
}

Future<void> setEstateReviewRemindersEnabled({
  required String estateId,
  required bool enabled,
}) async {
  await Supabase.instance.client.rpc(
    'set_estate_review_reminders_enabled',
    params: {
      'requested_estate_id': estateId,
      'enabled': enabled,
    },
  );
}

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
    final rows =
        await client.from('estates').select('name').eq('id', estateId).limit(1);
    if (rows.isEmpty) return '';
    return rows.first['name'] as String? ?? '';
  } catch (_) {
    return '';
  }
});

/// The legal process variant the estate follows.
///
/// Stored on the estate itself so owners and executors see the same
/// jurisdiction-specific guidance after signing back in on any device.
final estateProcessRegionProvider = FutureProvider<EstateProcessRegion>((
  ref,
) async {
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return EstateProcessRegion.scotland;

  final client = Supabase.instance.client;
  try {
    final rows = await client
        .from('estates')
        .select('process_region')
        .eq('id', estateId)
        .limit(1);
    if (rows.isEmpty) return EstateProcessRegion.scotland;
    return EstateProcessRegion.fromDbValue(
      rows.first['process_region'] as String?,
    );
  } catch (_) {
    return EstateProcessRegion.scotland;
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

/// Updates the estate-wide process region used for jurisdiction-specific copy.
///
/// Owners can change this in Settings. Because it lives on `estates`, the
/// choice survives sign-out and is shared by everyone with access.
Future<void> updateEstateProcessRegion({
  required String estateId,
  required EstateProcessRegion processRegion,
}) async {
  final client = Supabase.instance.client;
  await client.from('estates').update({
    'process_region': processRegion.dbValue,
  }).eq('id', estateId);
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

/// How well the estate is set up for a handover, judged only by who has
/// actually been invited and who has accepted.
///
/// Deliberately says nothing about payment. A paid invite that was never
/// sent, or never redeemed, leaves the estate exactly as exposed as a free
/// one — so the money spent is not a measure of preparedness.
enum HandoverReadiness {
  /// Nobody else has been invited. If the owner cannot sign in, nobody can.
  atRisk,

  /// Invites are out, but nobody has accepted yet.
  awaitingAcceptance,

  /// Another owner has accepted, but no executor has. Someone can reach the
  /// estate, though not necessarily the person who will have to act.
  sharedWithOwner,

  /// At least one executor has accepted. The handover can actually happen.
  prepared,
}

/// A snapshot of [HandoverReadiness] plus the counts behind it.
class EstateReadiness {
  final HandoverReadiness state;
  final int pendingCount;
  final int acceptedOwnerCount;
  final int acceptedExecutorCount;

  const EstateReadiness({
    required this.state,
    required this.pendingCount,
    required this.acceptedOwnerCount,
    required this.acceptedExecutorCount,
  });

  /// Counts only live rows, and never the owner's own row — their access is
  /// always present and would otherwise read as "another owner".
  factory EstateReadiness.fromInvites(List<EstateInvite> invites) {
    var pending = 0;
    var acceptedOwners = 0;
    var acceptedExecutors = 0;

    for (final invite in invites) {
      if (invite.isSelf || invite.isRevoked) continue;
      if (invite.isPending) {
        pending++;
      } else if (invite.status == 'accepted') {
        if (invite.role == 'owner') {
          acceptedOwners++;
        } else {
          acceptedExecutors++;
        }
      }
    }

    final HandoverReadiness state;
    if (acceptedExecutors > 0) {
      state = HandoverReadiness.prepared;
    } else if (acceptedOwners > 0) {
      state = HandoverReadiness.sharedWithOwner;
    } else if (pending > 0) {
      state = HandoverReadiness.awaitingAcceptance;
    } else {
      state = HandoverReadiness.atRisk;
    }

    return EstateReadiness(
      state: state,
      pendingCount: pending,
      acceptedOwnerCount: acceptedOwners,
      acceptedExecutorCount: acceptedExecutors,
    );
  }
}

/// Lists everyone who has been invited to, or already shares, [estateId].
///
/// Accepted owners can read every row for their estate
/// (`estate_access_select_linked`). Revoked rows are included on purpose:
/// because revocation keeps the row, the estate retains a record of who
/// previously had access.
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

  return fetchEstateInvites(
    estateId: estateId,
    currentUserId: userId,
  );
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

/// Thrown when an account's storage files were removed but the account itself
/// was not, leaving the deletion unfinished.
///
/// Retrying is safe and is simply another call to [deleteMyAccount]: the
/// storage step walks the folder again and finds nothing to remove, so the
/// second attempt proceeds straight to the database delete.
class AccountDeletionIncompleteException implements Exception {
  const AccountDeletionIncompleteException(this.message);

  /// User-facing explanation, safe to show directly in the UI.
  final String message;

  @override
  String toString() => 'AccountDeletionIncompleteException: $message';
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
///
/// Because the files go first, a failure between the two steps leaves the
/// account half-deleted. That case raises
/// [AccountDeletionIncompleteException] instead of the raw error, so the UI
/// can tell the user the deletion did not finish and that a retry will
/// complete it.
Future<void> deleteMyAccount() async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw StateError('deleteMyAccount: not signed in');
  }

  final owned =
      await client.from('estates').select('id').eq('owner_id', userId);

  // Counted across every owned estate, so a partial failure is reported even
  // when only some of the folders had anything left in them.
  var removedFiles = 0;
  for (final row in owned) {
    removedFiles += await _deleteEstateFiles(row['id'] as String);
  }

  try {
    await client.rpc('delete_my_account');
  } catch (error) {
    if (removedFiles > 0) {
      // Files are gone but the account is not, so say so plainly rather than
      // reporting a bare failure the user cannot act on.
      throw const AccountDeletionIncompleteException(
        'Your files were removed, but your account could not be deleted, so '
        'the deletion did not finish. Please try again to complete it.',
      );
    }
    rethrow;
  }

  // The auth user no longer exists, so clear the dead session locally and let
  // the router send the user back to sign-in.
  try {
    await clearEstatePhotoCache();
    await client.auth.signOut();
  } catch (_) {}
}

/// Empties `estate-documents/<estateId>/`, including nested utility folders.
///
/// Returns how many objects were removed. A folder that is already empty
/// returns 0 without error, so a retry after a partial deletion is safe.
Future<int> _deleteEstateFiles(String estateId) async {
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
  return paths.length;
}

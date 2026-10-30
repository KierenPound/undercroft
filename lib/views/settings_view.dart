import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/biometric_lock_service.dart';
import '../services/estate_service.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _ownerEmailController = TextEditingController();
  String? _generatedCode;
  String _generatedEmail = '';
  String? _ownerGeneratedCode;
  String _ownerGeneratedEmail = '';
  bool _inviting = false;
  bool _invitingOwner = false;
  bool _lockLoading = true;
  bool _lockSupported = false;
  bool _lockEnabled = false;
  bool _deletingAccount = false;

  /// Read once and reused, so the footer doesn't refetch on every rebuild.
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  Future<void> _loadLockState() async {
    final supported = await BiometricLockService.isSupported();
    final enabled = await BiometricLockService.isEnabled();
    if (!mounted) return;
    setState(() {
      _lockSupported = supported;
      _lockEnabled = enabled;
      _lockLoading = false;
    });
  }

  /// Enabling the lock authenticates first, so the user proves it works on
  /// this device before it can shut them out.
  Future<void> _toggleLock(bool value) async {
    if (value && !await BiometricLockService.authenticate()) return;
    await BiometricLockService.setEnabled(value);
    if (!mounted) return;
    setState(() => _lockEnabled = value);
  }

  /// Renames the estate. Owner-only: the caller hides the control for
  /// executors, and RLS rejects the write server-side regardless.
  Future<void> _renameEstate(String currentName) async {
    final controller = TextEditingController(text: currentName);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Estate name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. The Pound Estate',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    final newName = result?.trim() ?? '';
    if (newName.isEmpty || newName == currentName) return;

    final estateId = ref.read(estateIdProvider).valueOrNull ?? '';
    if (estateId.isEmpty) return;

    try {
      await updateEstateName(estateId: estateId, name: newName);
      ref.invalidate(estateNameProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estate name updated')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the estate name')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _ownerEmailController.dispose();
    super.dispose();
  }

  Future<void> _generateInvite(String estateId) async {
    setState(() => _inviting = true);
    try {
      final email = _emailController.text.trim();
      final code = await inviteExecutor(
        estateId: estateId,
        invitedEmail: email,
      );
      if (!mounted) return;
      // The code is revealed with Copy / Email / Share rather than emailed
      // automatically, so the owner picks how to hand it over. The email is
      // snapshotted here so later edits to the field can't misdirect it.
      setState(() {
        _generatedCode = code;
        _generatedEmail = email;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create invite: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Future<void> _generateOwnerInvite(String estateId) async {
    setState(() => _invitingOwner = true);
    try {
      final email = _ownerEmailController.text.trim();
      final code = await inviteOwner(
        estateId: estateId,
        invitedEmail: email,
      );
      if (!mounted) return;
      setState(() {
        _ownerGeneratedCode = code;
        _ownerGeneratedEmail = email;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create invite: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _invitingOwner = false);
    }
  }

  /// Opens a support or legal page in the device browser.
  Future<void> _openExternal(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the page in your browser')),
    );
  }

  /// Revoking keeps the row but ends any access it granted. Unused invites are
  /// worded as a cancellation because that is what the owner is actually doing.
  Future<void> _confirmRevoke(EstateInvite invite) async {
    final who = invite.invitedEmail ?? 'This person';
    final cancelling = invite.isPending;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(cancelling ? 'Cancel this invite?' : 'Remove access?'),
        content: Text(
          cancelling
              ? 'The invite code for $who will stop working. You can invite '
                  'them again at any time.'
              : '$who will lose access to this estate straight away.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(cancelling ? 'Cancel invite' : 'Remove access'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await revokeEstateAccess(invite.id);
      ref.invalidate(estateInvitesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cancelling ? 'Invite cancelled' : 'Access removed'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this invitation')),
      );
    }
  }

  /// Irreversible, so it is confirmed before anything is touched. What the
  /// user is told depends on whether they own the estate: an owner's deletion
  /// takes the whole estate and everyone's access with it.
  Future<void> _confirmDeleteAccount({required bool ownsEstate}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Text(
          ownsEstate
              ? 'This permanently deletes your estate and everything in it — '
                  'sections, documents, photos, contacts, tradespeople and '
                  'meter readings.\n\nAnyone you have invited will lose access '
                  'as well.\n\nThis cannot be undone.'
              : 'This permanently deletes your account and removes your access '
                  'to this estate. The estate itself is not affected, and '
                  'nothing you can see now will be lost.\n\n'
                  'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep my account'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await deleteMyAccount();
      // The session is now dead, so the router's redirect takes over and
      // returns to sign-in without any navigation from here.
    } catch (_) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete your account. Please try again.'),
        ),
      );
    }
  }

  Widget _buildInvites(
    AsyncValue<List<EstateInvite>> asyncInvites,
    String currentUserEmail,
  ) {
    return asyncInvites.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const Text(
        'Could not load invitations.',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      ),
      data: (invites) {
        if (invites.isEmpty) {
          return const Text(
            'Nobody has been invited yet.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < invites.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              _InviteRow(
                invite: invites[i],
                currentUserEmail: currentUserEmail,
                onRevoke: () => _confirmRevoke(invites[i]),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncRole = ref.watch(estateRoleProvider);
    final simulatedRole = ref.watch(simulatedRoleProvider);
    final asyncEstateId = ref.watch(estateIdProvider);
    final asyncUser = ref.watch(currentUserProvider);
    final asyncEstateName = ref.watch(estateNameProvider);

    final actualRole = asyncRole.valueOrNull ?? '';
    final effectiveRole = simulatedRole ?? actualRole;
    final isOwner = effectiveRole == 'owner';
    final isSimulating = simulatedRole != null;

    // Deliberately the real role, not the simulated one: deletes must reflect
    // what would actually be destroyed, never the previewed role.
    final isActualOwner = actualRole == 'owner';
    final userEmail = asyncUser.valueOrNull?.email ?? 'Not signed in';
    final estateName = asyncEstateName.valueOrNull ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F1E8),
              Color(0xFFEDE6D6),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Your ID
            _SectionCard(
              title: 'Your ID',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You are signed in with',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.alternate_email,
                        color: Color(0xFF5B7C6A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          userEmail,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Estate name
            _SectionCard(
              title: 'Estate',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You are managing',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.home_outlined,
                        color: Color(0xFF5B7C6A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          estateName.isEmpty ? '—' : estateName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isOwner)
                        IconButton(
                          onPressed: () => _renameEstate(estateName),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          color: const Color(0xFF5B7C6A),
                          tooltip: 'Rename estate',
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Current role
            _SectionCard(
              title: 'Your role',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isOwner ? Icons.shield : Icons.person,
                        color: isOwner
                            ? const Color(0xFF5B7C6A)
                            : const Color(0xFFE08A2C),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        effectiveRole == 'owner' ? 'Owner' : 'Executor',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  if (isSimulating) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE9B0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Simulating — database role is unchanged',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A5A00),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Privacy: biometric app lock
            _SectionCard(
              title: 'Privacy',
              child: _lockLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : !_lockSupported
                      ? const Text(
                          'This device has no biometrics set up. Add Face ID '
                          'or a fingerprint in your device settings, then '
                          'return here to enable the app lock.',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Require your fingerprint or face to reopen '
                              'UnderCroft after it has been in the background '
                              'for more than a minute.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Unlock with biometrics'),
                              value: _lockEnabled,
                              onChanged: _toggleLock,
                            ),
                          ],
                        ),
            ),

            const SizedBox(height: 16),

            // Developer tools: simulate role
            _SectionCard(
              title: 'Developer tools',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Simulate executor view to test the read-only UI without '
                    'changing your database role.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Act as Executor'),
                    subtitle: Text(
                      isSimulating
                          ? 'Currently simulating executor'
                          : 'Using your real role ($actualRole)',
                    ),
                    value: isSimulating,
                    onChanged: (value) {
                      ref.read(simulatedRoleProvider.notifier).state =
                          value ? 'executor' : null;
                    },
                  ),
                ],
              ),
            ),

            // Invite executor (owners only)
            if (actualRole == 'owner') ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Invite an executor',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generate a 6-character invite code. Share it with the '
                      'person you want to act as an executor of this estate. '
                      'They enter the code when they first sign in.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        hintText: 'name@example.com',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _inviting
                            ? null
                            : () {
                                final eid = asyncEstateId.valueOrNull;
                                if (eid == null || eid.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Estate not loaded yet — try again',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                _generateInvite(eid);
                              },
                        icon: _inviting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.person_add),
                        label: const Text('Generate invite code'),
                      ),
                    ),
                    if (_generatedCode != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B7C6A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Invite code',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              _generatedCode!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _CodeActions(
                              code: _generatedCode!,
                              roleLabel: 'Executor',
                              email: _generatedEmail,
                              foreground: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Invite estate owner (owners only)
              _SectionCard(
                title: 'Invite an estate owner',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generate a 6-character invite code. The person who '
                      'uses this code will become a co-owner of this estate, '
                      'with the same full privileges as you. They enter the '
                      'code when they first sign in.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ownerEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        hintText: 'name@example.com',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _invitingOwner
                            ? null
                            : () {
                                final eid = asyncEstateId.valueOrNull;
                                if (eid == null || eid.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Estate not loaded yet — try again',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                _generateOwnerInvite(eid);
                              },
                        icon: _invitingOwner
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.shield),
                        label: const Text('Generate owner invite code'),
                      ),
                    ),
                    if (_ownerGeneratedCode != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5E3C),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Owner invite code',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              _ownerGeneratedCode!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _CodeActions(
                              code: _ownerGeneratedCode!,
                              roleLabel: 'Estate Owner',
                              email: _ownerGeneratedEmail,
                              foreground: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Who has been invited, and whether they accepted.
              _SectionCard(
                title: 'Invitations',
                child: _buildInvites(
                  ref.watch(estateInvitesProvider),
                  userEmail,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Both app stores expect the support and privacy pages to be
            // reachable from inside the app, so they live here rather than
            // only on the website.
            _SectionCard(
              title: 'Support & legal',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openExternal(
                        'https://crabkingslair.com/support',
                      ),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('Support'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openExternal(
                        'https://crabkingslair.com/privacy',
                      ),
                      icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                      label: const Text('Privacy policy'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Required by both app stores: a signed-in user must be able to
            // delete their own account and data from inside the app.
            _SectionCard(
              title: 'Delete my account',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActualOwner
                        ? 'Deletes your estate and everything in it, and ends '
                            'any access you have granted to others.'
                        : 'Deletes your account and removes your access to this '
                            'estate.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _deletingAccount
                          ? null
                          : () => _confirmDeleteAccount(
                                ownsEstate: isActualOwner,
                              ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      icon: _deletingAccount
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_forever_outlined, size: 18),
                      label: Text(
                        _deletingAccount ? 'Deleting…' : 'Delete my account',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Version, so a problem can be reported against a known build.
            const SizedBox(height: 24),
            Center(
              child: FutureBuilder<PackageInfo>(
                future: _packageInfo,
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  if (info == null) return const SizedBox.shrink();
                  return Text(
                    'UnderCroft ${info.version}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black38,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single invitation or existing member: who it is, whether it has been
/// accepted, and an action to revoke it.
class _InviteRow extends StatelessWidget {
  final EstateInvite invite;
  final String currentUserEmail;
  final VoidCallback onRevoke;

  const _InviteRow({
    required this.invite,
    required this.currentUserEmail,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final canRevoke = !invite.isRevoked && !invite.isSelf;
    final code = invite.inviteCode;
    final displayEmail = invite.invitedEmail ??
        (invite.isSelf ? currentUserEmail : 'No email recorded');
    final subtitle = [
      invite.roleLabel,
      if (invite.formattedDate.isNotEmpty) invite.formattedDate,
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayEmail,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: invite.isRevoked ? Colors.black45 : Colors.black87,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _StatusPill(status: invite.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              // Pending codes are re-readable here, so an invite generated and
              // then forgotten can still be sent without making a new one.
              if (code != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Code',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    SelectableText(
                      code,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                _CodeActions(
                  code: code,
                  roleLabel: invite.roleLabel,
                  email: invite.invitedEmail ?? '',
                  foreground: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
        if (canRevoke)
          TextButton(
            onPressed: onRevoke,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: Text(invite.isPending ? 'Cancel' : 'Remove'),
          ),
      ],
    );
  }
}

/// Small coloured label showing whether an invite is pending, accepted, or
/// revoked. Pending reuses the amber used by the role-simulation badge.
class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    late final String label;

    switch (status) {
      case 'accepted':
        background = const Color(0xFFE4EDE7);
        foreground = const Color(0xFF3D5C4A);
        label = 'Accepted';
      case 'revoked':
        background = const Color(0xFFEDEDED);
        foreground = Colors.black45;
        label = 'Revoked';
      default:
        background = const Color(0xFFFFE9B0);
        foreground = const Color(0xFF7A5A00);
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Copy / Email / Share for a generated invite code.
///
/// Used under the code in the generation panels and again on pending invites
/// in the list, so a code stays sendable after its panel has been left.
class _CodeActions extends StatelessWidget {
  final String code;
  final String roleLabel;
  final String email;
  final Color foreground;

  const _CodeActions({
    required this.code,
    required this.roleLabel,
    required this.foreground,
    this.email = '',
  });

  static final ButtonStyle _style = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    minimumSize: const Size(0, 32),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        TextButton.icon(
          onPressed: () => _copyInviteCode(context, code),
          style: _style,
          icon: Icon(Icons.copy, size: 16, color: foreground),
          label: Text('Copy', style: TextStyle(color: foreground)),
        ),
        TextButton.icon(
          onPressed: () => _emailInviteCode(
            context: context,
            to: email,
            roleLabel: roleLabel,
            pinCode: code,
          ),
          style: _style,
          icon: Icon(Icons.mail_outline, size: 16, color: foreground),
          label: Text('Email', style: TextStyle(color: foreground)),
        ),
        // iPad presents the share sheet as a popover anchored to the control
        // that triggered it, so the button's own rect is handed to share_plus.
        Builder(
          builder: (buttonContext) => TextButton.icon(
            onPressed: () {
              final box = buttonContext.findRenderObject() as RenderBox?;
              _shareInviteCode(
                code: code,
                roleLabel: roleLabel,
                origin: box == null
                    ? null
                    : box.localToGlobal(Offset.zero) & box.size,
              );
            },
            style: _style,
            icon: Icon(Icons.ios_share, size: 16, color: foreground),
            label: Text('Share', style: TextStyle(color: foreground)),
          ),
        ),
      ],
    );
  }
}

void _copyInviteCode(BuildContext context, String code) {
  Clipboard.setData(ClipboardData(text: code));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Invite code copied to clipboard')),
  );
}

String _inviteEmailBody({
  required String roleLabel,
  required String pinCode,
}) {
  return '''Hello,

You have been designated as an $roleLabel in my Family Estate plan.

To accept this invitation and connect to my estate records:
1. Download the UnderCroft App from the App/Play Store.
2. Select "Sign Up" with your email and what password you want.
3. Select $roleLabel and use this PIN code: $pinCode

Best regards,
Estate Owner''';
}

String _inviteShareText({
  required String roleLabel,
  required String pinCode,
}) {
  return '''You have been designated as an $roleLabel in my Family Estate plan.

To accept this invitation and connect to my estate records:
1. Download the UnderCroft app.
2. Select "Sign Up" with your email and a password of your choice.
3. Select $roleLabel and use this invite code: $pinCode''';
}

/// Opens the device email client with a pre-filled invitation. The [to]
/// address may be empty; in that case the sender fills in the recipient.
Future<void> _emailInviteCode({
  required BuildContext context,
  required String to,
  required String roleLabel,
  required String pinCode,
}) async {
  final subject = 'You have been appointed as an $roleLabel';
  final body = _inviteEmailBody(roleLabel: roleLabel, pinCode: pinCode);

  final params = <String, String>{
    if (subject.isNotEmpty) 'subject': subject,
    if (body.isNotEmpty) 'body': body,
  };
  final mailto = Uri(
    scheme: 'mailto',
    path: to,
    query: params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&'),
  );

  try {
    await launchUrl(mailto);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Could not open your email app. Copy the code and send it manually.'),
      ),
    );
  }
}

/// Hands the invite to the platform share sheet, so the owner can send it by
/// Messages, WhatsApp or anything else installed.
Future<void> _shareInviteCode({
  required String code,
  required String roleLabel,
  Rect? origin,
}) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: _inviteShareText(roleLabel: roleLabel, pinCode: code),
        subject: 'You have been appointed as an $roleLabel',
        sharePositionOrigin: origin,
      ),
    );
  } catch (_) {
    // Nothing to recover from: the code is still on screen to copy or email.
  }
}

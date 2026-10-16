import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/sections_repository.dart';
import '../services/estate_service.dart';

class OnboardingView extends ConsumerStatefulWidget {
  final ValueChanged<String> onComplete;

  const OnboardingView({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  bool _isOwner = true;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _hasPendingInvite = false;
  String? _pendingEstateName;

  @override
  void initState() {
    super.initState();
    _checkPendingInvite();
  }

  /// If the signed-in user's email matches a pending invite, they were
  /// invited to an estate — disable the "create new estate" path so they
  /// can only join via their invite code.
  Future<void> _checkPendingInvite() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user?.email == null) return;
    try {
      final rows = await client
          .from('estate_access')
          .select('estate_id')
          .eq('invited_email', user!.email!)
          .eq('status', 'pending')
          .isFilter('user_id', null)
          .limit(1);
      if (mounted && rows.isNotEmpty) {
        final estateId = rows.first['estate_id'] as String?;
        String estateName = '';
        if (estateId != null && estateId.isNotEmpty) {
          final estateRows = await client
              .from('estates')
              .select('name')
              .eq('id', estateId)
              .limit(1);
          if (estateRows.isNotEmpty) {
            estateName = estateRows.first['name'] as String? ?? '';
          }
        }

        setState(() {
          _hasPendingInvite = true;
          _pendingEstateName = estateName;
          if (estateName.isNotEmpty) {
            _nameController.text = estateName;
          }
        });
      }
    } catch (_) {
      // Ignore — fall back to the normal create-or-join flow.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      setState(() => _error = 'No signed-in user.');
      return;
    }

    if (user.emailConfirmedAt == null) {
      setState(() => _error =
          'Please confirm your email first. Check your inbox for the confirmation link, or disable email confirmation in Supabase → Authentication → Providers → Email.');
      return;
    }

    try {
      String? completedEstateId;

      // Helper: claim a pending invite by code. Returns the estate id or
      // null if the code is invalid/expired. Sets _error on failure.
      Future<String?> claimInvite(String code) async {
        // Don't let a user who already has accepted access claim another
        // invite — they already have a role on an estate.
        final existing = await client
            .from('estate_access')
            .select('estate_id, role')
            .eq('user_id', user.id)
            .eq('status', 'accepted')
            .limit(1);

        if (existing.isNotEmpty) {
          setState(() => _error =
              'You already have access to an estate. Sign out and use a different account to join with this invite code.');
          return null;
        }

        final invite = await client
            .from('estate_access')
            .select('id, estate_id, role')
            .eq('invite_code', code)
            .eq('status', 'pending')
            .isFilter('user_id', null)
            .maybeSingle();

        if (invite == null) {
          setState(() => _error = 'Invalid or expired invite code.');
          return null;
        }

        await client.from('estate_access').update({
          'user_id': user.id,
          'status': 'accepted',
        }).eq('id', invite['id'] as String);

        return invite['estate_id'] as String?;
      }

      if (_isOwner) {
        final ownerCode = _codeController.text.trim().toUpperCase();

        // If an owner invite code was provided (or the user was invited —
        // i.e. they have a pending invite for their email), claim it
        // (join as co-owner of an existing estate) instead of creating.
        if (ownerCode.isNotEmpty || _hasPendingInvite) {
          if (ownerCode.isEmpty) {
            setState(() =>
                _error = 'Please enter the invite code you were sent.');
            return;
          }
          completedEstateId = await claimInvite(ownerCode);
          if (completedEstateId == null) return;
        } else {
          final estateName = _nameController.text.trim();
          if (estateName.isEmpty) {
            setState(() => _error =
                'Please enter an estate name to create a new estate, or an invite code to join an existing one.');
            return;
          }

          // create_estate is a SECURITY DEFINER function that deletes any
          // existing estate owned by this user, creates a fresh one, and
          // guarantees the owner access row — all while bypassing RLS so
          // the insert never fails on policy checks.
          final estateId = await client.rpc('create_estate', params: {
            'estate_name': estateName,
          });

          completedEstateId = estateId as String?;

          // Seed the new estate with default sections and starter checklist
          // items. This runs only for owners creating a new estate;
          // co-owners joining via invite inherit whatever is already set up.
          if (completedEstateId != null) {
            final repo = ref.read(sectionsRepositoryProvider);
            await repo.seedDefaults(completedEstateId);
          }
        }
      } else {
        final code = _codeController.text.trim().toUpperCase();
        if (code.isEmpty) {
          setState(() => _error = 'Please enter the invite code.');
          return;
        }

        completedEstateId = await claimInvite(code);
        if (completedEstateId == null) return;
      }

      if (mounted) {
        // The estate_access row was just created/claimed, but the providers
        // that derive role/estate-id from it are cached off currentUserProvider,
        // which doesn't re-emit when the user's database row changes (only
        // when auth state changes). Invalidate them so downstream screens
        // fetch fresh values, but don't block navigation on that refresh.
        ref.invalidate(estateIdProvider);
        ref.invalidate(estateRoleProvider);
        ref.invalidate(estateNameProvider);
        ref.invalidate(hasEstateProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All set!')),
        );
        if (completedEstateId != null) {
          widget.onComplete(completedEstateId);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Something went wrong: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F1E8), Color(0xFFEDE6D6)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    await Supabase.instance.client.auth
                                        .signOut();
                                  },
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Sign out'),
                          ),
                        ],
                      ),
                      const Icon(Icons.account_balance_wallet_outlined,
                          size: 56, color: Color(0xFF3A8D5A)),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome to UnderCroft',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C2C2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tell us your role to get started.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleCard(
                              label: 'Estate Owner',
                              icon: Icons.person,
                              selected: _isOwner,
                              onTap: () => setState(() => _isOwner = true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RoleCard(
                              label: 'Executor',
                              icon: Icons.gavel,
                              selected: !_isOwner,
                              onTap: () => setState(() => _isOwner = false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_isOwner) ...[
                        TextField(
                          controller: _nameController,
                          enabled: !_hasPendingInvite,
                          decoration: InputDecoration(
                            labelText: 'Estate name',
                            hintText: _hasPendingInvite
                                ? 'Loading invited estate...'
                                : 'e.g. My Estate',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.home_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!_hasPendingInvite)
                          const Text(
                            'or',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black45),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          autofocus: _hasPendingInvite,
                          decoration: InputDecoration(
                            labelText: _hasPendingInvite
                                ? 'Invite code'
                                : 'Owner invite code',
                            hintText: '6-character code',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.vpn_key_outlined),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hasPendingInvite
                              ? (_pendingEstateName?.isNotEmpty ?? false)
                                  ? 'You were invited to join "${_pendingEstateName!}". Enter your invite code to join.'
                                  : 'You were invited to an estate. Enter your invite code to join.'
                              : 'Enter a name to create a new estate, or an invite '
                                  'code to join an existing estate as a co-owner.',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45),
                        ),
                      ] else
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Invite code',
                            hintText: '6-character code',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.vpn_key_outlined),
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF3A8D5A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Proceed',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF3A8D5A).withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF3A8D5A) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color:
                    selected ? const Color(0xFF3A8D5A) : Colors.grey.shade600,
                size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color:
                    selected ? const Color(0xFF3A8D5A) : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

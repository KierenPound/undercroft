import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/sections_repository.dart';
import '../services/estate_service.dart';
import '../services/photo_cache_service.dart';

class OnboardingView extends ConsumerStatefulWidget {
  final ValueChanged<String> onComplete;

  const OnboardingView({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

enum _JoiningPath {
  createEstate,
  inviteCode,
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _hasPendingInvite = false;
  String? _pendingEstateName;
  _JoiningPath? _joiningPath;

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
          _joiningPath = _JoiningPath.inviteCode;
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
      setState(() {
        _error = 'No signed-in user.';
        _isLoading = false;
      });
      return;
    }

    if (user.emailConfirmedAt == null) {
      setState(() {
        _error =
            'Please confirm your email first. Check your inbox for the confirmation link, or disable email confirmation in Supabase → Authentication → Providers → Email.';
        _isLoading = false;
      });
      return;
    }

    try {
      String? completedEstateId;
      final joiningPath =
          _joiningPath ?? (_hasPendingInvite ? _JoiningPath.inviteCode : null);

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
          setState(() => _error = 'Invalid invite code.');
          return null;
        }

        await client.from('estate_access').update({
          'user_id': user.id,
          'status': 'accepted',
        }).eq('id', invite['id'] as String);

        return invite['estate_id'] as String?;
      }

      if (joiningPath == _JoiningPath.inviteCode) {
        final code = _codeController.text.trim().toUpperCase();
        if (code.isEmpty) {
          setState(() => _error = _hasPendingInvite
              ? 'Please enter the invite code you were sent.'
              : 'Please enter the invite code.');
          return;
        }

        completedEstateId = await claimInvite(code);
        if (completedEstateId == null) return;
      } else if (joiningPath == _JoiningPath.createEstate) {
        final estateName = _nameController.text.trim();
        if (estateName.isEmpty) {
          setState(() => _error = 'Please enter an estate name.');
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
        // items. This runs only when the user is creating their own estate.
        if (completedEstateId != null) {
          final repo = ref.read(sectionsRepositoryProvider);
          await repo.seedDefaults(completedEstateId);
        }
      } else {
        setState(() => _error = 'Choose how you are joining first.');
        return;
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
    final joiningPath =
        _joiningPath ?? (_hasPendingInvite ? _JoiningPath.inviteCode : null);
    final showChoiceStep = joiningPath == null;
    final showCreateEstate = joiningPath == _JoiningPath.createEstate;
    final showInviteCode = joiningPath == _JoiningPath.inviteCode;

    final title = showChoiceStep
        ? 'How are you joining?'
        : showCreateEstate
            ? 'Set up your estate'
            : 'Enter your invite code';
    final body = showChoiceStep
        ? 'Are you setting up your own estate, or joining one that someone '
            'has already shared with you?'
        : showCreateEstate
            ? 'Give your estate a name. You can change this later.'
            : (_pendingEstateName?.isNotEmpty ?? false)
                ? 'You were invited to join "${_pendingEstateName!}". Enter '
                    'the 6-character code you were given. We will use it to '
                    'join the correct estate and set up your access.'
                : 'Enter the 6-character code you were given. We will use it '
                    'to join the correct estate and set up your access.';

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
                                    await clearEstatePhotoCache();
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
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C2C2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      if (showChoiceStep) ...[
                        _OptionCard(
                          label: 'Set up my own estate',
                          icon: Icons.home_outlined,
                          onTap: () => setState(() {
                            _joiningPath = _JoiningPath.createEstate;
                            _error = null;
                          }),
                        ),
                        const SizedBox(height: 12),
                        _OptionCard(
                          label: 'I have an invite code',
                          icon: Icons.vpn_key_outlined,
                          onTap: () => setState(() {
                            _joiningPath = _JoiningPath.inviteCode;
                            _error = null;
                          }),
                        ),
                      ] else ...[
                        if (!_hasPendingInvite)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(() {
                                        _joiningPath = null;
                                        _error = null;
                                      }),
                              icon: const Icon(Icons.arrow_back, size: 18),
                              label: const Text('Back'),
                            ),
                          ),
                        if (showCreateEstate) ...[
                          TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Estate name',
                              hintText: 'e.g. The Pound Estate',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.home_outlined),
                            ),
                          ),
                        ] else if (showInviteCode) ...[
                          TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Invite code',
                              hintText: '6-character code',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.vpn_key_outlined),
                            ),
                          ),
                          if (_hasPendingInvite) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'This account has a pending invite waiting for '
                              'it, so you can only join with that code.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3A8D5A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  showCreateEstate
                                      ? 'Create estate'
                                      : 'Join estate',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ],
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

class _OptionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.icon,
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
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF3A8D5A).withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF3A8D5A), size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF3A8D5A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

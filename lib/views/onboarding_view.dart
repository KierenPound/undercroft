import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingView extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingView({super.key, required this.onComplete});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  bool _isOwner = true;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

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
      if (_isOwner) {
        final estateName = _nameController.text.trim();
        if (estateName.isEmpty) {
          setState(() => _error = 'Please enter a name for your estate.');
          return;
        }

        await client.rpc('create_estate', params: {
          'estate_name': estateName,
        });
      } else {
        final code = _codeController.text.trim().toUpperCase();
        if (code.isEmpty) {
          setState(() => _error = 'Please enter the invite code.');
          return;
        }

        final invite = await client
            .from('estate_access')
            .select('id, estate_id')
            .eq('invite_code', code)
            .eq('status', 'pending')
            .eq('role', 'executor')
            .isFilter('user_id', null)
            .maybeSingle();

        if (invite == null) {
          setState(() => _error = 'Invalid or expired invite code.');
          return;
        }

        await client.from('estate_access').update({
          'user_id': user.id,
          'status': 'accepted',
        }).eq('id', invite['id'] as String);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All set!')),
        );
        widget.onComplete();
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
                      if (_isOwner)
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Estate name',
                            hintText: 'e.g. My Estate',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                        )
                      else
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
                            : Text(
                                _isOwner ? 'Create estate' : 'Join estate',
                                style: const TextStyle(fontSize: 16),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String? _ownerGeneratedCode;
  bool _inviting = false;
  bool _invitingOwner = false;

  @override
  void dispose() {
    _emailController.dispose();
    _ownerEmailController.dispose();
    super.dispose();
  }

  Future<void> _generateInvite(String estateId) async {
    setState(() => _inviting = true);
    try {
      final code = await inviteExecutor(
        estateId: estateId,
        invitedEmail: _emailController.text.trim(),
      );
      setState(() => _generatedCode = code);
      _launchInviteEmail(
        to: _emailController.text.trim(),
        roleLabel: 'Executor',
        pinCode: code,
      );
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
      final code = await inviteOwner(
        estateId: estateId,
        invitedEmail: _ownerEmailController.text.trim(),
      );
      setState(() => _ownerGeneratedCode = code);
      _launchInviteEmail(
        to: _ownerEmailController.text.trim(),
        roleLabel: 'Estate Owner',
        pinCode: code,
      );
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

  /// Opens the device email client with a pre-filled invitation email for the
  /// given role and PIN code. The [to] address may be empty; in that case the
  /// user fills in the recipient manually.
  Future<void> _launchInviteEmail({
    required String to,
    required String roleLabel,
    required String pinCode,
  }) async {
    final subject = 'You have been appointed as an $roleLabel';
    final body = '''Hello,

You have been designated as an $roleLabel in my Family Estate plan.

To accept this invitation and connect to my estate records:
1. Download the UnderCroft App from the App/Play Store.
2. Select "Sign Up" with your email and what password you want.
3. Select $roleLabel and use this PIN code: $pinCode

Best regards,
Estate Owner''';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not open your email app. The invite code has been generated — copy it and send it manually.'),
          ),
        );
      }
    }
  }

  void _copyCode(String? code) {
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied to clipboard')),
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
                            TextButton.icon(
                              onPressed: () => _copyCode(_generatedCode),
                              icon: const Icon(
                                Icons.copy,
                                color: Colors.white,
                                size: 16,
                              ),
                              label: const Text(
                                'Copy code',
                                style: TextStyle(color: Colors.white),
                              ),
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
                            TextButton.icon(
                              onPressed: () => _copyCode(_ownerGeneratedCode),
                              icon: const Icon(
                                Icons.copy,
                                color: Colors.white,
                                size: 16,
                              ),
                              label: const Text(
                                'Copy code',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
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

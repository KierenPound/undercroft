import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Password reset screen.
///
/// Two modes:
///   - Request mode: the user enters their email and we send a reset link.
///   - Recovery mode: triggered automatically when the user taps the link in
///     the reset email (Supabase fires a `passwordRecovery` auth event).
///     They enter a new password and we update it.
class PasswordResetView extends StatefulWidget {
  const PasswordResetView({super.key});

  @override
  State<PasswordResetView> createState() => _PasswordResetViewState();
}

class _PasswordResetViewState extends State<PasswordResetView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  String? _info;

  /// True when the recovery session is active (user clicked the email link).
  bool _inRecovery = false;

  @override
  void initState() {
    super.initState();
    // If we arrive here because of a password-recovery event, the user is
    // already in a recovery session and ready to set a new password.
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _inRecovery = true;
    }

    // Listen for the recovery event in case it fires after this screen mounts.
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery && mounted) {
        setState(() => _inRecovery = true);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = 'Please enter your email address.';
        _isLoading = false;
      });
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.undercroft.undercroft://login-callback/',
      );
      if (mounted) {
        setState(() => _info =
            'A password reset link has been sent to $email. Check your inbox and tap the link to set a new password.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });

    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.isEmpty || confirm.isEmpty) {
      setState(() {
        _error = 'Please enter and confirm your new password.';
        _isLoading = false;
      });
      return;
    }
    if (password != confirm) {
      setState(() {
        _error = 'Passwords do not match.';
        _isLoading = false;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _error = 'Password must be at least 6 characters.';
        _isLoading = false;
      });
      return;
    }

    try {
      await Supabase.instance.client
          .auth
          .updateUser(UserAttributes(password: password));
      // Sign out so the user signs in fresh with their new password. This also
      // clears the recovery-session flag via the signedOut auth event.
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        setState(() => _info =
            'Password updated successfully. Sign in with your new password.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
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
                      const Icon(Icons.lock_reset_outlined,
                          size: 56, color: Color(0xFF3A8D5A)),
                      const SizedBox(height: 16),
                      Text(
                        _inRecovery ? 'Set new password' : 'Reset password',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C2C2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _inRecovery
                            ? 'Enter your new password below.'
                            : 'Enter your email and we\'ll send you a link to reset your password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      if (!_inRecovery)
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        )
                      else ...[
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm new password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_info!,
                                    style: const TextStyle(
                                        color: Colors.blueAccent)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isLoading
                            ? null
                            : (_inRecovery ? _updatePassword : _sendResetLink),
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
                                _inRecovery ? 'Update password' : 'Send reset link',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).canPop()
                            ? Navigator.of(context).pop()
                            : context.go('/login'),
                        child: const Text(
                          'Back to sign in',
                          style: TextStyle(color: Color(0xFF3A8D5A)),
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

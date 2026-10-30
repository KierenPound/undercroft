import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  /// Key recording that the app has been opened at least once.
  ///
  /// This lives in shared preferences, which iOS clears when an app is
  /// deleted, so a deleted and reinstalled app correctly counts as a fresh
  /// install.
  static const String _hasOpenedAppKey = 'has_opened_app';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  /// Null until the first-run check has finished.
  ///
  /// A fresh install opens on "Create account"; every later launch opens on
  /// sign in. Reading the preference is asynchronous, so the form is held
  /// back until it resolves rather than briefly flashing the wrong tab.
  bool? _isSignUp;

  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    debugPrint('[auth_view] mounted key=${widget.key}');
    _resolveInitialMode();
  }

  Future<void> _resolveInitialMode() async {
    final prefs = await SharedPreferences.getInstance();
    final hasOpenedBefore = prefs.getBool(_hasOpenedAppKey) ?? false;

    if (!hasOpenedBefore) {
      await prefs.setBool(_hasOpenedAppKey, true);
    }

    if (mounted) {
      setState(() => _isSignUp = !hasOpenedBefore);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    debugPrint('[auth_view] submit mode=${_isSignUp == true ? 'sign_up' : 'sign_in'} '
        'email=$email');

    try {
      final client = Supabase.instance.client;
      if (_isSignUp == true) {
        final response =
            await client.auth.signUp(email: email, password: password);
        debugPrint('[auth_view] sign_up complete '
            'sessionUser=${response.session?.user.id} '
            'currentUser=${client.auth.currentUser?.id}');
        if (response.user?.emailConfirmedAt == null) {
          if (mounted) {
            setState(() => _info =
                'A confirmation email has been sent to $email. Click the link to activate your account, then sign in.');
          }
        }
        // Tells iOS the credential flow has finished, which is what prompts
        // it to offer saving the password to the keychain.
        if (response.session != null) TextInput.finishAutofillContext();
      } else {
        await client.auth.signInWithPassword(email: email, password: password);
        debugPrint('[auth_view] sign_in complete '
            'currentSessionUser=${client.auth.currentSession?.user.id} '
            'currentUser=${client.auth.currentUser?.id}');
        TextInput.finishAutofillContext();
      }
    } on AuthException catch (e) {
      debugPrint('[auth_view] auth error=${e.message}');
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      debugPrint('[auth_view] unexpected error=$e');
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _isSignUp;

    // The first-run check is still in flight. Hold the form back for that
    // moment so the tab never flashes the wrong way round.
    if (isSignUp == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F1E8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3A8D5A)),
        ),
      );
    }

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
                      const Icon(Icons.shield_outlined,
                          size: 56, color: Color(0xFF3A8D5A)),
                      const SizedBox(height: 16),
                      Text(
                        isSignUp
                            ? 'Welcome to UnderCroft'
                            : 'Welcome back to UnderCroft',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C2C2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isSignUp
                            ? 'Create an account to get started.'
                            : 'Sign in to your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      // The group is what makes the hints below take effect:
                      // without it iOS ignores them and never offers to fill or
                      // save the credentials.
                      AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              // Sign-up asks iOS for its strong password
                              // generator; signing in asks for the saved one.
                              autofillHints: isSignUp
                                  ? const [AutofillHints.newPassword]
                                  : const [AutofillHints.password],
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              onSubmitted: (_) => _isLoading ? null : _submit(),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
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
                                child: Text(
                                  _info!,
                                  style:
                                      const TextStyle(color: Colors.blueAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                isSignUp ? 'Sign up' : 'Sign in',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/password-reset'),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(color: Color(0xFF3A8D5A)),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _isSignUp = !isSignUp),
                        child: Text(
                          isSignUp
                              ? 'Already have an account? Sign in'
                              : "Don't have an account? Sign up",
                          style: const TextStyle(color: Color(0xFF3A8D5A)),
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

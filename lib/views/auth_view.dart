import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';
import '../utils/log.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

enum _AuthScreenMode {
  intro,
  signUp,
  signIn,
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

  /// Password is hidden by default; the eye icon reveals it so a mistyped
  /// character can be spotted before submitting.
  bool _obscurePassword = true;

  /// Null until the first-run check has finished.
  ///
  /// A fresh install opens on a guided first-run screen; every later launch
  /// opens on sign in. Reading the preference is asynchronous, so the UI is
  /// held back until it resolves rather than briefly flashing the wrong state.
  _AuthScreenMode? _screenMode;

  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    logDebug('[auth_view] mounted');
    _resolveInitialMode();
  }

  Future<void> _resolveInitialMode() async {
    final prefs = await SharedPreferences.getInstance();
    final hasOpenedBefore = prefs.getBool(_hasOpenedAppKey) ?? false;

    if (!hasOpenedBefore) {
      await prefs.setBool(_hasOpenedAppKey, true);
    }

    if (mounted) {
      setState(
        () => _screenMode =
            hasOpenedBefore ? _AuthScreenMode.signIn : _AuthScreenMode.intro,
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Opens the page-by-page demo guide in the device browser, so someone can
  /// see what the app does before committing to an account.
  Future<void> _openDemoGuide() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('https://crabkingslair.com/undercroft_demo'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the demo guide')),
    );
  }

  String _friendlyAuthError(String message, {required bool isSignUp}) {
    final normalized = message.toLowerCase();

    if (normalized.contains('invalid login credentials')) {
      return 'The email or password does not match our records. Check them and try again.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Please confirm your email address before signing in. Check your inbox for the confirmation link.';
    }
    if (normalized.contains('already registered') ||
        normalized.contains('already exists')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (normalized.contains('invalid email') ||
        normalized.contains('email address is invalid') ||
        normalized.contains('unable to validate email')) {
      return 'Please enter a valid email address.';
    }
    if (normalized.contains('password') &&
        (normalized.contains('at least') ||
            normalized.contains('too short') ||
            normalized.contains('weak'))) {
      return 'Your password does not meet the requirements. Choose a stronger password and try again.';
    }
    if (normalized.contains('rate limit') ||
        normalized.contains('too many requests')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }

    return isSignUp
        ? 'We could not create your account. Please check your details and try again.'
        : 'We could not sign you in. Please check your details and try again.';
  }

  Future<void> _submit() async {
    final isSignUp = _screenMode == _AuthScreenMode.signUp;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final missingFields = <String>[
      if (email.isEmpty) 'email',
      if (password.isEmpty) 'password',
    ];

    if (missingFields.isNotEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Please enter your ${missingFields.join(' and ')}.';
        _info = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });

    logDebug('[auth_view] submit mode=${isSignUp ? 'sign_up' : 'sign_in'}');
    try {
      final client = Supabase.instance.client;
      if (isSignUp) {
        final response = await client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: SupabaseService.authRedirectUrl,
        );
        logDebug('[auth_view] sign_up complete '
            'hasSession=${response.session != null} '
            'hasCurrentUser=${client.auth.currentUser != null}');
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
        logDebug('[auth_view] sign_in complete '
            'hasCurrentSession=${client.auth.currentSession != null} '
            'hasCurrentUser=${client.auth.currentUser != null}');
        TextInput.finishAutofillContext();
      }
    } on AuthException catch (e) {
      logDebug('[auth_view] auth error');
      if (mounted) {
        setState(
          () => _error = _friendlyAuthError(e.message, isSignUp: isSignUp),
        );
      }
    } catch (e) {
      logDebug('[auth_view] unexpected error type=${e.runtimeType}');
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenMode = _screenMode;

    // The first-run check is still in flight. Hold the form back for that
    // moment so the tab never flashes the wrong way round.
    if (screenMode == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F1E8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3A8D5A)),
        ),
      );
    }

    if (screenMode == _AuthScreenMode.intro) {
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 56,
                          color: Color(0xFF3A8D5A),
                        ),
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
                          'I see this is your first time using UnderCroft. '
                          'Let me guide you through getting set up.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => setState(() {
                            _screenMode = _AuthScreenMode.signUp;
                            _error = null;
                            _info = null;
                          }),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3A8D5A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Get started',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => setState(() {
                            _screenMode = _AuthScreenMode.signIn;
                            _error = null;
                            _info = null;
                          }),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('I already have an account'),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _screenMode = _AuthScreenMode.signUp;
                            _error = null;
                            _info = 'Create your account first. You will enter '
                                'your invite code on the next step.';
                          }),
                          child: const Text(
                            'I already have an invite code',
                            style: TextStyle(color: Color(0xFF3A8D5A)),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openDemoGuide,
                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          label: const Text('See how UnderCroft works'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF3A8D5A),
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

    final isSignUp = screenMode == _AuthScreenMode.signUp;

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
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              // Sign-up asks iOS for its strong password
                              // generator; signing in asks for the saved one.
                              autofillHints: isSignUp
                                  ? const [AutofillHints.newPassword]
                                  : const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
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
                        onPressed: () => setState(() {
                          _screenMode = isSignUp
                              ? _AuthScreenMode.signIn
                              : _AuthScreenMode.signUp;
                          _error = null;
                          _info = null;
                        }),
                        child: Text(
                          isSignUp
                              ? 'Already have an account? Sign in'
                              : "Don't have an account? Sign up",
                          style: const TextStyle(color: Color(0xFF3A8D5A)),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openDemoGuide,
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        label: const Text('See how UnderCroft works'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF3A8D5A),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/biometric_lock_service.dart';

/// Covers the whole app with a lock screen when it has been in the background
/// for longer than [gracePeriod].
///
/// Wrap this around the router output via `MaterialApp.router(builder: ...)`.
/// The child stays mounted underneath the lock screen, so the navigation stack
/// and in-progress form state survive an unlock.
class BiometricLockGate extends StatefulWidget {
  const BiometricLockGate({super.key, required this.child});

  final Widget child;

  /// How long the app may sit in the background before re-authentication is
  /// required. Cold starts always lock, regardless of this value.
  static const Duration gracePeriod = Duration(seconds: 60);

  /// How many system hand-offs — a camera, photo library, or file picker we
  /// opened — are currently in flight.
  static int _handOffs = 0;

  /// Runs [action], a call that hands control to system UI such as
  /// `ImagePicker.pickVideo`, with the privacy cover held back until it
  /// returns.
  ///
  /// Without this the lock screen flashes over the app as the picker takes
  /// focus, because the cover is painted the moment we stop being the
  /// foreground app — before the picker has actually covered us.
  static Future<T> suppressCoverWhile<T>(Future<T> Function() action) async {
    _handOffs++;
    try {
      return await action();
    } finally {
      _handOffs--;
    }
  }

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate>
    with WidgetsBindingObserver {
  bool _ready = false;
  bool _locked = true;
  bool _privacyCover = false;
  bool _prompting = false;
  bool _signingOut = false;
  bool _confirmingSignOut = false;
  bool _handlingResume = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Cold start: lock immediately if the user has the feature switched on.
  Future<void> _bootstrap() async {
    final enabled = await BiometricLockService.isEnabled();
    if (!mounted) return;
    setState(() {
      _locked = enabled;
      _ready = true;
    });
    if (enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_prompting) return;

    if (state == AppLifecycleState.inactive) {
      _coverIfNeeded();
      return;
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      // Keep the earliest timestamp if the platform reports a sequence of
      // backgrounding states.
      _backgroundedAt ??= DateTime.now();
      _coverIfNeeded();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResumed());
    }
  }

  /// Paints the cover that keeps estate records out of the OS app-switcher.
  ///
  /// Held back while one of our own pickers is on top: that system UI hides the
  /// app anyway, so covering here would only flash the lock screen during the
  /// activity transition. The timestamp above is recorded either way, so the
  /// grace period and the lock on return still behave as before.
  void _coverIfNeeded() {
    if (_privacyCover || BiometricLockGate._handOffs > 0) return;
    setState(() => _privacyCover = true);
  }

  Future<void> _onResumed() async {
    if (_handlingResume) return;
    _handlingResume = true;
    try {
      await _resumeAfterLifecycleChange();
    } finally {
      _handlingResume = false;
    }
  }

  Future<void> _resumeAfterLifecycleChange() async {
    final backgroundedAt = _backgroundedAt;

    // Ignore plain resume events that did not come from a real background
    // transition. Without this, the local_auth sheet can cause an unlock loop
    // on iPhone by generating extra lifecycle churn around the prompt.
    if (backgroundedAt == null) {
      if (_privacyCover) setState(() => _privacyCover = false);
      return;
    }

    // Re-read the preference so toggling it in Settings takes effect without
    // an app restart.
    final enabled = await BiometricLockService.isEnabled();
    if (!mounted) return;
    _backgroundedAt = null;

    if (!enabled) {
      setState(() {
        _locked = false;
        _privacyCover = false;
      });
      return;
    }

    // Skip the prompt only when we know the app was backgrounded briefly.
    final withinGrace = DateTime.now().difference(backgroundedAt) <
        BiometricLockGate.gracePeriod;
    if (withinGrace) {
      if (_privacyCover) setState(() => _privacyCover = false);
      return;
    }

    setState(() {
      _locked = true;
      _privacyCover = false;
    });
    await _prompt();
  }

  Future<void> _prompt() async {
    if (_prompting || !mounted) return;
    _prompting = true;
    try {
      final ok = await BiometricLockService.authenticate();
      if (!mounted) return;
      if (ok) setState(() => _locked = false);
    } finally {
      _prompting = false;
    }
  }

  /// Escape hatch for a device whose prompt can never succeed — for example
  /// once the passcode has been removed, which makes [authenticate] fail
  /// forever. Signs the user out, turns the lock off, and opens the gate, so
  /// the lock screen is not a dead end. The session is rebuilt by signing in
  /// again, so no records are lost.
  ///
  /// Confirmation is drawn inside the overlay rather than with [showDialog]:
  /// this gate sits above the router's Navigator, so it has no Navigator in
  /// scope to show a route on.
  Future<void> _signOut() async {
    setState(() {
      _confirmingSignOut = false;
      _signingOut = true;
    });

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // The gate is still covering the app, so there is nowhere to report
      // this. Carrying on is deliberate: the lock is turned off below either
      // way, leaving the user able to sign in again rather than stuck.
    }
    await BiometricLockService.setEnabled(false);
    if (!mounted) return;
    setState(() {
      _signingOut = false;
      _locked = false;
      _privacyCover = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Until the preference has loaded, show a blank cover rather than the
    // dashboard, so records are never briefly visible on a cold start.
    if (!_ready) {
      return const ColoredBox(color: Color(0xFFF5F1E8));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_locked || _privacyCover)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: _LockOverlay(
                prompting: _prompting,
                signingOut: _signingOut,
                confirmingSignOut: _confirmingSignOut,
                onUnlock: _prompt,
                onRequestSignOut: () =>
                    setState(() => _confirmingSignOut = true),
                onCancelSignOut: () =>
                    setState(() => _confirmingSignOut = false),
                onConfirmSignOut: _signOut,
              ),
            ),
          ),
      ],
    );
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({
    required this.prompting,
    required this.signingOut,
    required this.confirmingSignOut,
    required this.onUnlock,
    required this.onRequestSignOut,
    required this.onCancelSignOut,
    required this.onConfirmSignOut,
  });

  final bool prompting;
  final bool signingOut;
  final bool confirmingSignOut;
  final VoidCallback onUnlock;
  final VoidCallback onRequestSignOut;
  final VoidCallback onCancelSignOut;
  final VoidCallback onConfirmSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 44,
            color: Color(0xFF5B7C6A),
          ),
          const SizedBox(height: 20),
          const Text(
            'UnderCroft is locked',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2F3330),
            ),
          ),
          const SizedBox(height: 8),
          if (confirmingSignOut) ...[
            const Text(
              'You will need your email and password to sign back in. The app '
              'lock will also be turned off on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: signingOut ? null : onCancelSignOut,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5B7C6A),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: signingOut ? null : onConfirmSignOut,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5B7C6A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  child: signingOut
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign out'),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Unlock to view your estate records.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: prompting ? null : onUnlock,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5B7C6A),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              icon: prompting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.fingerprint),
              label: const Text('Unlock'),
            ),
            const SizedBox(height: 12),
            // A way out if the prompt can never succeed, such as when the
            // device passcode has been removed.
            TextButton(
              onPressed: (prompting || signingOut) ? null : onRequestSignOut,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF5B7C6A),
              ),
              child: const Text('Sign out'),
            ),
          ],
        ],
      ),
    );
  }
}

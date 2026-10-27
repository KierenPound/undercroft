import 'dart:async';

import 'package:flutter/material.dart';

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

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate>
    with WidgetsBindingObserver {
  bool _ready = false;
  bool _locked = true;
  bool _prompting = false;
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

    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      // Keep the earliest timestamp if the platform reports a sequence of
      // backgrounding states.
      _backgroundedAt ??= DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResumed());
    }
    // `inactive` is ignored on purpose: on iOS it fires for transient things
    // like the Control Centre or an incoming call banner, which should not
    // force a re-authentication.
  }

  Future<void> _onResumed() async {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;

    // Ignore plain resume events that did not come from a real background
    // transition. Without this, the local_auth sheet can cause an unlock loop
    // on iPhone by generating extra lifecycle churn around the prompt.
    if (backgroundedAt == null) return;

    // Re-read the preference so toggling it in Settings takes effect without
    // an app restart.
    final enabled = await BiometricLockService.isEnabled();
    if (!mounted) return;

    if (!enabled) {
      if (_locked) setState(() => _locked = false);
      return;
    }

    // Skip the prompt only when we know the app was backgrounded briefly.
    final withinGrace = DateTime.now().difference(backgroundedAt) <
        BiometricLockGate.gracePeriod;
    if (withinGrace) return;

    setState(() => _locked = true);
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
        if (_locked)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: _LockOverlay(
                prompting: _prompting,
                onUnlock: _prompt,
              ),
            ),
          ),
      ],
    );
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.prompting, required this.onUnlock});

  final bool prompting;
  final VoidCallback onUnlock;

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
        ],
      ),
    );
  }
}

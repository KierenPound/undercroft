import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/build_flags.dart';
import 'repositories/sections_repository.dart';
import 'services/crash_reporting_service.dart';
import 'services/estate_service.dart';
import 'services/introduction_service.dart';
import 'services/payment_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'utils/log.dart';
import 'views/ad_hoc_data_view.dart';
import 'views/auth_view.dart';
import 'views/biometric_lock_gate.dart';
import 'views/home_dashboard_view.dart';
import 'views/introduction_view.dart';
import 'views/my_songs_view.dart';
import 'views/onboarding_view.dart';
import 'views/password_reset_view.dart';
import 'views/section_detail_view.dart';
import 'views/settings_view.dart';
import 'views/who_to_notify_detail_view.dart';
import 'views/who_to_notify_list_view.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Initialise crash reporting before anything that can fail, so startup
      // problems are captured too. A missing DSN leaves it inert.
      await CrashReportingService.initialize();
      _installErrorHandlers();

      if (!SupabaseService.isConfigured) {
        runApp(const StartupFallbackApp());
        return;
      }

      try {
        await SupabaseService.initialize();
      } catch (error, stackTrace) {
        _debugReportError('startup', error, stackTrace);
        runApp(const StartupFallbackApp());
        return;
      }

      runApp(
        const ProviderScope(
          child: _PurchaseStreamHost(
            child: UnderCroftApp(),
          ),
        ),
      );
    },
    (error, stackTrace) => _debugReportError('uncaught', error, stackTrace),
  );
}

void _installErrorHandlers() {
  FlutterError.onError = (details) {
    _debugReportError('flutter', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _debugReportError('platform', error, stackTrace);
    return true;
  };
}

/// The single sink for every error channel. The console line stays terse
/// (type only) so debug logs never carry user text; the full error and stack
/// trace go to Sentry, where CrashReportingService redacts them first.
void _debugReportError(String source, Object error, [StackTrace? stackTrace]) {
  logDebug('[$source] errorType=${error.runtimeType}');
  unawaited(CrashReportingService.reportError(source, error, stackTrace));
}

class StartupFallbackApp extends StatelessWidget {
  const StartupFallbackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'UnderCroft',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'App is misconfigured',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class AppRouter extends ChangeNotifier {
  AppRouter() {
    _init();
  }

  String? _estateId;
  bool _checked = false;
  bool _estateLookupFailed = false;
  User? _user;
  bool _needsPasswordReset = false;

  void _init() {
    _user = Supabase.instance.client.auth.currentUser;
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      logDebug(
        '[auth] event=${state.event.name} '
        'hasSession=${state.session != null}',
      );
      // When the user taps the reset link in their email, Supabase fires a
      // passwordRecovery event. We set a flag so the router redirects them to
      // the password reset screen to choose a new password.
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _needsPasswordReset = true;
      } else if (state.event == AuthChangeEvent.signedOut) {
        _needsPasswordReset = false;
      }

      final nextUser = state.session?.user;
      final userIdChanged = _user?.id != nextUser?.id;
      final shouldRefreshEstate = state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.signedOut ||
          state.event == AuthChangeEvent.userUpdated ||
          userIdChanged;

      if (shouldRefreshEstate) {
        _user = nextUser;
        _checked = false;
        _estateId = null;
        _estateLookupFailed = false;
        notifyListeners();
        if (_user != null) _checkEstate();
      } else if (state.event == AuthChangeEvent.passwordRecovery) {
        notifyListeners();
      }
    });
    if (_user != null) _checkEstate();
  }

  Future<void> _checkEstate() async {
    final user = _user;
    if (user == null) {
      _estateId = null;
      _estateLookupFailed = false;
      _checked = true;
      notifyListeners();
      return;
    }

    try {
      final context = await fetchCurrentEstateContext();
      if (_user?.id != user.id) return;

      _estateId = context?.estateId;
      logDebug('[estate] role=${context?.role} hasEstate=${_estateId != null}');
    } catch (e) {
      if (_user?.id != user.id) return;
      logDebug('[estate] lookup failed errorType=${e.runtimeType}');
      _estateId = null;
      _estateLookupFailed = true;
    } finally {
      if (_user?.id == user.id) {
        _checked = true;
        notifyListeners();
      }
    }
  }

  void refresh() {
    _checked = false;
    _estateId = null;
    _estateLookupFailed = false;
    notifyListeners();
    if (_user != null) _checkEstate();
  }

  /// Called by onboarding after successfully creating/joining an estate.
  /// Avoids relying on the async _checkEstate() query (which may be gated
  /// by RLS) to detect the estate.
  void setEstateId(String id) {
    _estateId = id;
    _estateLookupFailed = false;
    _checked = true;
    notifyListeners();
  }
}

final _router = GoRouter(
  initialLocation: '/',
  refreshListenable: _appRouter,
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: state.pageKey,
        child: AuthView(key: state.pageKey),
      ),
    ),
    // Supabase sends the user here after they tap a link in a password reset or
    // confirmation email (see SupabaseService.authRedirectUrl). Incoming URLs
    // for that scheme carry the callback as the URL host, so this route is a
    // safety net rather than the usual path taken; either way the landing place
    // is the dashboard, and Supabase's own listener drives what happens next.
    GoRoute(
      path: '/login-callback',
      redirect: (context, state) => '/',
    ),
    GoRoute(
      path: '/password-reset',
      builder: (context, state) => const PasswordResetView(),
    ),
    GoRoute(
      path: '/retry',
      builder: (context, state) => const RetryView(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingView(
        onComplete: (estateId) => _appRouter.setEstateId(estateId),
      ),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeDashboardView(),
    ),
    GoRoute(
      path: '/section/:title',
      builder: (context, state) {
        final title = Uri.decodeComponent(state.pathParameters['title'] ?? '');
        final config = sectionConfigByTitle(title);
        if (config == null) {
          // Unknown section — redirect to the home dashboard.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        return SectionDetailView(config: config);
      },
    ),
    GoRoute(
      path: '/who-to-notify',
      builder: (context, state) => const WhoToNotifyListView(),
    ),
    GoRoute(
      path: '/my-songs',
      builder: (context, state) => const MySongsView(),
    ),
    GoRoute(
      path: '/ad-hoc-data',
      builder: (context, state) => const AdHocDataView(),
    ),
    GoRoute(
      path: '/who-to-notify/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return WhoToNotifyDetailView(whoToNotifyId: id);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsView(),
    ),
    GoRoute(
      path: '/introduction',
      builder: (context, state) => IntroductionView(
        // The gate below passes first=1, because there is nothing behind the
        // screen to go back to. Opening it from Settings does not, so that
        // route keeps its ordinary back button instead.
        isFirstRun: state.uri.queryParameters['first'] == '1',
      ),
    ),
  ],
  redirect: (context, state) {
    final user = _appRouter._user;
    final location = state.matchedLocation;

    String? decision;

    // If a password-recovery event fired, route the user to the reset screen
    // so they can set a new password.
    if (_appRouter._needsPasswordReset) {
      decision = location == '/password-reset' ? null : '/password-reset';
      logDebug('[router] authenticated=${user != null} '
          'checked=${_appRouter._checked} '
          'hasEstate=${_appRouter._estateId != null} '
          'decision=${decision ?? 'stay'} reason=password_recovery');
      return decision;
    }

    if (user == null) {
      decision = location == '/login' || location == '/password-reset'
          ? null
          : '/login';
      logDebug('[router] authenticated=false '
          'checked=${_appRouter._checked} '
          'hasEstate=${_appRouter._estateId != null} '
          'decision=${decision ?? 'stay'} reason=no_user');
      return decision;
    }

    if (_appRouter._estateLookupFailed) {
      decision = location == '/retry' ? null : '/retry';
      logDebug('[router] authenticated=true '
          'checked=${_appRouter._checked} '
          'hasEstate=${_appRouter._estateId != null} '
          'decision=${decision ?? 'stay'} reason=estate_lookup_failed');
      return decision;
    }

    if (location == '/retry') {
      if (!_appRouter._checked) return null;
      decision = '/';
      logDebug('[router] authenticated=true '
          'checked=${_appRouter._checked} '
          'hasEstate=${_appRouter._estateId != null} '
          'decision=$decision reason=estate_lookup_recovered');
      return decision;
    }

    if (location == '/login' || location == '/password-reset') {
      decision = '/';
      logDebug('[router] authenticated=true '
          'checked=${_appRouter._checked} '
          'hasEstate=${_appRouter._estateId != null} '
          'decision=$decision reason=authed_on_auth_screen');
      return decision;
    }

    if (!_appRouter._checked) {
      logDebug('[router] authenticated=true '
          'checked=${_appRouter._checked} '
          'hasEstate=${_appRouter._estateId != null} '
          'decision=stay reason=awaiting_estate_check');
      return null;
    }

    final hasEstate = _appRouter._estateId != null;
    if (!hasEstate) {
      decision = location == '/onboarding' ? null : '/onboarding';
      logDebug('[router] authenticated=true '
          'checked=${_appRouter._checked} '
          'hasEstate=false '
          'decision=${decision ?? 'stay'} reason=no_estate');
      return decision;
    }
    if (location == '/onboarding') {
      decision = '/';
      logDebug('[router] authenticated=true '
          'checked=${_appRouter._checked} hasEstate=true '
          'decision=$decision reason=has_estate');
      return decision;
    }

    // The introduction is shown once, to everyone, the first time they sign in
    // with an estate. Reading it marks a flag on their account, so this stops
    // firing afterwards. Checked against the live client rather than the
    // cached user, so that the flag set when they leave the screen takes
    // effect straight away.
    if (!IntroductionService.hasSeenIntroduction()) {
      // Compared against the path alone: the redirect target carries a query
      // parameter, and matching on the full location would bounce forever.
      decision =
          state.uri.path == '/introduction' ? null : '/introduction?first=1';
      logDebug('[router] authenticated=true '
          'checked=${_appRouter._checked} hasEstate=true '
          'decision=${decision ?? 'stay'} reason=introduction_not_seen');
      return decision;
    }

    logDebug('[router] authenticated=true '
        'checked=${_appRouter._checked} '
        'hasEstate=${_appRouter._estateId != null} '
        'decision=stay reason=allowed');
    return null;
  },
  // A location that matches no route — an unexpected deep link, say — would
  // otherwise show go_router's "page not found" screen. Send it home instead.
  errorBuilder: (context, state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/');
    });
    return const Scaffold(body: SizedBox.shrink());
  },
);

final _appRouter = AppRouter();

class RetryView extends StatelessWidget {
  const RetryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Couldn't connect. Check your connection and try again.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _appRouter.refresh,
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseStreamHost extends ConsumerStatefulWidget {
  const _PurchaseStreamHost({required this.child});

  final Widget child;

  @override
  ConsumerState<_PurchaseStreamHost> createState() =>
      _PurchaseStreamHostState();
}

class _PurchaseStreamHostState extends ConsumerState<_PurchaseStreamHost> {
  @override
  void initState() {
    super.initState();
    unawaited(
      PaymentService.startPurchaseListener(
        verifyHandoverPurchase: (purchase) async {
          final source = purchase.verificationData.source;

          // In dev builds, non-store purchases are treated as a temporary
          // session unlock. Production Android/iOS go through the server.
          if (source != 'app_store' && source != 'google_play') {
            if (!devToolsEnabled || !mounted) return false;
            ref.read(sessionInvitesUnlockedProvider.notifier).state = true;
            return true;
          }

          try {
            if (source == 'app_store') {
              final transactionId = purchase.purchaseID;
              if (transactionId == null || transactionId.isEmpty) return false;

              final response =
                  await Supabase.instance.client.functions.invoke(
                'verify-app-store-handover',
                body: {'transactionId': transactionId},
              );
              final data = response.data;
              if (response.status < 200 ||
                  response.status >= 300 ||
                  data is! Map ||
                  data['granted'] != true) {
                return false;
              }
            } else {
              // google_play: the purchase token lives in serverVerificationData.
              final purchaseToken =
                  purchase.verificationData.serverVerificationData;
              if (purchaseToken.isEmpty) return false;

              final response =
                  await Supabase.instance.client.functions.invoke(
                'verify-google-play-handover',
                body: {'purchaseToken': purchaseToken},
              );
              final data = response.data;
              if (response.status < 200 ||
                  response.status >= 300 ||
                  data is! Map ||
                  data['granted'] != true) {
                return false;
              }
            }

            if (!mounted) return true;
            ref.invalidate(estateHandoverEntitlementProvider);
            ref.read(sessionInvitesUnlockedProvider.notifier).state = true;
            return true;
          } catch (error) {
            logDebug('IAP server verification errorType=${error.runtimeType}');
            return false;
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    unawaited(PaymentService.stopPurchaseListener());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class UnderCroftApp extends StatelessWidget {
  const UnderCroftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'UnderCroft',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: _router,
      // Sits above the router so the lock screen covers every route without
      // disturbing the navigation stack.
      builder: (context, child) => BiometricLockGate(
        child: child ?? const SizedBox.shrink(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

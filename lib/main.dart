import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories/sections_repository.dart';
import 'services/estate_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'views/ad_hoc_data_view.dart';
import 'views/auth_view.dart';
import 'views/biometric_lock_gate.dart';
import 'views/home_dashboard_view.dart';
import 'views/my_songs_view.dart';
import 'views/onboarding_view.dart';
import 'views/password_reset_view.dart';
import 'views/section_detail_view.dart';
import 'views/settings_view.dart';
import 'views/who_to_notify_detail_view.dart';
import 'views/who_to_notify_list_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(
    const ProviderScope(
      child: UnderCroftApp(),
    ),
  );
}

class AppRouter extends ChangeNotifier {
  AppRouter() {
    _init();
  }

  String? _estateId;
  bool _checked = false;
  User? _user;
  bool _needsPasswordReset = false;

  void _init() {
    _user = Supabase.instance.client.auth.currentUser;
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      debugPrint(
        '[auth] event=${state.event.name} '
        'sessionUser=${state.session?.user.id} '
        'currentUser=${Supabase.instance.client.auth.currentUser?.id}',
      );
      // When the user taps the reset link in their email, Supabase fires a
      // passwordRecovery event. We set a flag so the router redirects them to
      // the password reset screen to choose a new password.
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _needsPasswordReset = true;
      } else {
        _needsPasswordReset = false;
      }
      _user = state.session?.user;
      _checked = false;
      _estateId = null;
      notifyListeners();
      if (_user != null) _checkEstate();
    });
    if (_user != null) _checkEstate();
  }

  Future<void> _checkEstate() async {
    final user = _user;
    if (user == null) {
      _estateId = null;
      _checked = true;
      notifyListeners();
      return;
    }

    try {
      final context = await fetchCurrentEstateContext();
      if (_user?.id != user.id) return;

      _estateId = context?.estateId;
      debugPrint('[estate] uid=${user.id} email=${user.email} '
          'role=${context?.role} estateId=$_estateId');
    } catch (e) {
      if (_user?.id != user.id) return;
      debugPrint('[estate] lookup threw: $e');
      _estateId = null;
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
    notifyListeners();
    if (_user != null) _checkEstate();
  }

  /// Called by onboarding after successfully creating/joining an estate.
  /// Avoids relying on the async _checkEstate() query (which may be gated
  /// by RLS) to detect the estate.
  void setEstateId(String id) {
    _estateId = id;
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
    GoRoute(
      path: '/password-reset',
      builder: (context, state) => const PasswordResetView(),
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
  ],
  redirect: (context, state) {
    final user = _appRouter._user;
    final location = state.matchedLocation;

    String? decision;

    // If a password-recovery event fired, route the user to the reset screen
    // so they can set a new password.
    if (_appRouter._needsPasswordReset) {
      decision = location == '/password-reset' ? null : '/password-reset';
      debugPrint('[router] location=$location user=${user?.id} '
          'checked=${_appRouter._checked} estateId=${_appRouter._estateId} '
          'decision=${decision ?? 'stay'} reason=password_recovery');
      return decision;
    }

    if (user == null) {
      decision = location == '/login' || location == '/password-reset'
          ? null
          : '/login';
      debugPrint('[router] location=$location user=null '
          'checked=${_appRouter._checked} estateId=${_appRouter._estateId} '
          'decision=${decision ?? 'stay'} reason=no_user');
      return decision;
    }

    if (location == '/login' || location == '/password-reset') {
      decision = '/';
      debugPrint('[router] location=$location user=${user.id} '
          'checked=${_appRouter._checked} estateId=${_appRouter._estateId} '
          'decision=$decision reason=authed_on_auth_screen');
      return decision;
    }

    if (!_appRouter._checked) {
      debugPrint('[router] location=$location user=${user.id} '
          'checked=${_appRouter._checked} estateId=${_appRouter._estateId} '
          'decision=stay reason=awaiting_estate_check');
      return null;
    }

    final hasEstate = _appRouter._estateId != null;
    if (!hasEstate) {
      decision = location == '/onboarding' ? null : '/onboarding';
      debugPrint('[router] location=$location user=${user.id} '
          'checked=${_appRouter._checked} estateId=${_appRouter._estateId} '
          'decision=${decision ?? 'stay'} reason=no_estate');
      return decision;
    }
    if (location == '/onboarding') {
      decision = '/';
      debugPrint('[router] location=$location user=${user.id} '
          'checked=${_appRouter._checked} estateId=${_appRouter._estateId} '
          'decision=$decision reason=has_estate');
      return decision;
    }
    debugPrint('[router] location=$location user=${user.id} '
        'checked=${_appRouter._checked} estateId=${_appRouter._estateId} '
        'decision=stay reason=allowed');
    return null;
  },
);

final _appRouter = AppRouter();

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

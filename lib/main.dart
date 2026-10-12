import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories/sections_repository.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'views/auth_view.dart';
import 'views/home_dashboard_view.dart';
import 'views/onboarding_view.dart';
import 'views/section_detail_view.dart';
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

  void _init() {
    _user = Supabase.instance.client.auth.currentUser;
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      _user = state.session?.user;
      _checked = false;
      _estateId = null;
      notifyListeners();
      if (_user != null) _checkEstate();
    });
    if (_user != null) _checkEstate();
  }

  Future<void> _checkEstate() async {
    try {
      final row = await Supabase.instance.client
          .from('estate_access')
          .select('estate_id')
          .eq('user_id', _user!.id)
          .eq('status', 'accepted')
          .maybeSingle();
      _estateId = row != null ? row['estate_id'] as String : null;
    } catch (_) {
      _estateId = null;
    } finally {
      _checked = true;
      notifyListeners();
    }
  }

  void refresh() {
    _checked = false;
    _estateId = null;
    notifyListeners();
    if (_user != null) _checkEstate();
  }
}

final _router = GoRouter(
  initialLocation: '/',
  refreshListenable: _appRouter,
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const AuthView(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingView(
        onComplete: () => _appRouter.refresh(),
      ),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeDashboardView(),
    ),
    GoRoute(
      path: '/section',
      builder: (context, state) {
        final config = state.extra as SectionConfig;
        return SectionDetailView(config: config);
      },
    ),
    GoRoute(
      path: '/who-to-notify',
      builder: (context, state) => const WhoToNotifyListView(),
    ),
    GoRoute(
      path: '/who-to-notify/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return WhoToNotifyDetailView(whoToNotifyId: id);
      },
    ),
  ],
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;
    final location = state.matchedLocation;

    if (user == null) {
      return location == '/login' ? null : '/login';
    }

    if (location == '/login') return '/';

    if (!_appRouter._checked) return null;

    final hasEstate = _appRouter._estateId != null;
    if (!hasEstate) {
      return location == '/onboarding' ? null : '/onboarding';
    }
    if (location == '/onboarding') return '/';
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
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

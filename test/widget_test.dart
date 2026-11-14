import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:undercroft/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // The platform plugin channels do not exist under `flutter test`, so the
    // in-memory SharedPreferences store stands in for them. Every startup path
    // in this test goes through it: Supabase restores its persisted session
    // from SharedPreferences, BiometricLockService reads the lock preference
    // from it, and AuthView reads its first-run flag from it. Without this the
    // first call throws MissingPluginException.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: UnderCroftApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

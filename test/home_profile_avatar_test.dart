import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_harness.dart';

/// The round initial at the top of Home is the way to the account page.
/// It used to be a plain circle that did nothing when tapped.
void main() {
  Future<void> pumpHome(WidgetTester tester, {required String locale}) async {
    tester.view.physicalSize = const Size(402 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = await createTestContainer();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('profile page')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: Locale(locale),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final locale in ['ar', 'en']) {
    testWidgets('tapping the avatar opens the profile page ($locale)',
        (tester) async {
      await pumpHome(tester, locale: locale);
      expect(find.text('profile page'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('home-profile-avatar')));
      await tester.pumpAndSettle();

      expect(find.text('profile page'), findsOneWidget);
    });
  }

  testWidgets('the avatar is announced as a button to screen readers',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHome(tester, locale: 'en');

    expect(
      tester.getSemantics(find.byKey(const ValueKey('home-profile-avatar'))),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(find.bySemanticsLabel(RegExp('My account')), findsOneWidget);
    semantics.dispose();
  });
}

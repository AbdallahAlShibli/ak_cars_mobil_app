import 'dart:convert';

import 'package:ak_cars_mobil_app/core/constants/app_constants.dart';
import 'package:ak_cars_mobil_app/data/models/user_profile.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/auth/login_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_harness.dart';

/// Phone login: the API texts a 4-digit code to a registered number, and the
/// code starts the session. Driven through the real screen and a real router.
void main() {
  const owner = UserProfile(
    name: 'Phone Owner',
    phone: '+968 9200 0001',
    email: '',
    region: 'Muscat',
    address: '',
  );

  Future<ProviderContainer> pumpLogin(
    WidgetTester tester, {
    bool registered = true,
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = await createTestContainer();
    if (registered) {
      // An account that already exists "on the server" (the mock keeps it in
      // prefs), with nobody signed in to it.
      await container
          .read(sharedPrefsProvider)
          .setString(AppConstants.prefsProfile, jsonEncode(owner.toJson()));
    }

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('profile page')),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const Scaffold(body: Text('register page')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('en'),
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
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> sendCodeTo(WidgetTester tester, String localPhone) async {
    await tester.enterText(find.byType(TextField).first, localPhone);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send the code'));
    await tester.pumpAndSettle();
  }

  testWidgets('a registered phone logs in with the 4-digit SMS code',
      (tester) async {
    final container = await pumpLogin(tester);

    await sendCodeTo(tester, '92000001');

    expect(find.text('Enter the 4-digit code we just sent you.'), findsOneWidget);
    expect(find.text('+968 9200 0001'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '4821');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify and log in'));
    await tester.pumpAndSettle();

    expect(container.read(authProvider).isRegistered, isTrue);
    expect(container.read(authProvider).profile?.phone, owner.phone);
    expect(find.text('profile page'), findsOneWidget);
  });

  testWidgets('an unregistered number is told so, and stays on the number',
      (tester) async {
    final container = await pumpLogin(tester, registered: false);

    await sendCodeTo(tester, '92000001');

    expect(find.text('No account with that number'), findsOneWidget);
    expect(find.text('Verify and log in'), findsNothing);
    expect(container.read(authProvider).isRegistered, isFalse);
  });

  testWidgets('a landline is refused before anything is sent', (tester) async {
    await pumpLogin(tester);

    await sendCodeTo(tester, '24478120');

    expect(find.text('An Oman mobile number starting with 7 or 9'),
        findsOneWidget);
    expect(find.text('Verify and log in'), findsNothing);
  });

  testWidgets('a short code is caught before the API is asked', (tester) async {
    final container = await pumpLogin(tester);

    await sendCodeTo(tester, '92000001');
    await tester.enterText(find.byType(TextField).last, '12');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify and log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the 4-digit code'), findsOneWidget);
    expect(container.read(authProvider).isRegistered, isFalse);
  });

  // Email sign-in is switched off for now: the API has no e-mail sender.
  testWidgets('there is no email option', (tester) async {
    await pumpLogin(tester);

    expect(find.text('Email'), findsNothing);
    expect(find.text('Phone number'), findsOneWidget);
  });
}

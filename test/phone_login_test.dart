import 'dart:convert';

import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/constants/app_constants.dart';
import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/data/models/user_profile.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/auth/login_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fakes/fake_phone_verification_service.dart';
import 'helpers/test_harness.dart';

/// Phone login: Firebase proves the number by SMS, then the API trades that
/// proof for a session. Driven through the real screen and a real router.
void main() {
  const owner = UserProfile(
    name: 'Phone Owner',
    phone: '+968 9200 0001',
    email: 'owner@akcars.om',
    region: 'Muscat',
    address: '',
  );

  /// What Firebase answers while the project cannot text this number —
  /// the Spark plan, in the case that prompted the fallback.
  const firebaseNotSetUp = PhoneVerificationException(
    'billing-not-enabled: BILLING_NOT_ENABLED',
    reason: PhoneVerificationFailure.notConfigured,
  );

  Future<(ProviderContainer, FakePhoneVerificationService)> pumpLogin(
    WidgetTester tester, {
    bool registered = true,
    bool instantVerification = false,
    AppConfig? config,
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final phones = FakePhoneVerificationService()
      ..verifyInstantly = instantVerification;
    final container = await createTestContainer(overrides: [
      phoneVerificationServiceProvider.overrideWithValue(phones),
      if (config != null) appConfigProvider.overrideWithValue(config),
    ]);
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
    return (container, phones);
  }

  Future<void> sendCodeTo(WidgetTester tester, String localPhone) async {
    await tester.enterText(find.byType(TextField).first, localPhone);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send the code'));
    await tester.pumpAndSettle();
  }

  testWidgets('a registered phone logs in with the 6-digit SMS code',
      (tester) async {
    final (container, phones) = await pumpLogin(tester);

    await sendCodeTo(tester, '92000001');

    expect(phones.sentTo, ['+96892000001']);
    expect(find.text('Enter the 6-digit code we just sent you.'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField).last, FakePhoneVerificationService.validCode);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify and log in'));
    await tester.pumpAndSettle();

    expect(container.read(authProvider).isRegistered, isTrue);
    expect(container.read(authProvider).profile?.phone, owner.phone);
    expect(find.text('profile page'), findsOneWidget);
  });

  testWidgets('an unregistered number is told so, and no SMS is sent',
      (tester) async {
    final (container, phones) = await pumpLogin(tester, registered: false);

    await sendCodeTo(tester, '92000001');

    expect(find.text('No account with that number'), findsOneWidget);
    expect(phones.sentTo, isEmpty);
    expect(container.read(authProvider).isRegistered, isFalse);
  });

  testWidgets('a number the device verified by itself signs in with no code',
      (tester) async {
    final (container, _) = await pumpLogin(tester, instantVerification: true);

    await sendCodeTo(tester, '92000001');

    expect(container.read(authProvider).isRegistered, isTrue);
    expect(find.text('profile page'), findsOneWidget);
  });

  testWidgets('email login still uses the API code, not an SMS', (tester) async {
    final (_, phones) = await pumpLogin(tester);

    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    await sendCodeTo(tester, owner.email);

    expect(phones.sentTo, isEmpty);
    expect(find.text('Enter the 4-digit code we just sent you.'), findsOneWidget);
  });

  // Regression: with the Firebase project on the Spark plan every phone login
  // failed at "SMS verification is not available right now", and nobody could
  // sign in at all while the console was being set up.
  testWidgets(
      'a development build falls back to the API code when Firebase SMS is not set up',
      (tester) async {
    final (container, phones) = await pumpLogin(tester);
    phones.sendFailure = firebaseNotSetUp;

    await sendCodeTo(tester, '92000001');

    expect(phones.sentTo, isEmpty);
    expect(find.text('Enter the 4-digit code we just sent you.'), findsOneWidget);
    // The why is on the code step, not in a bar that would cover the button.
    expect(
      find.textContaining("this development build uses the API's own 4-digit code"),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).last, '4821');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify and log in'));
    await tester.pumpAndSettle();

    expect(container.read(authProvider).isRegistered, isTrue);
    expect(find.text('profile page'), findsOneWidget);
  });

  testWidgets('outside development the refusal stands and says why',
      (tester) async {
    final (container, phones) = await pumpLogin(
      tester,
      config: AppConfig.forEnvironment(AppEnvironment.production),
    );
    phones.sendFailure = firebaseNotSetUp;

    await sendCodeTo(tester, '92000001');

    expect(find.textContaining("SMS sign-in isn't set up for this app yet"),
        findsOneWidget);
    expect(find.text('Enter the 4-digit code we just sent you.'), findsNothing);
    expect(container.read(authProvider).isRegistered, isFalse);
  });
}

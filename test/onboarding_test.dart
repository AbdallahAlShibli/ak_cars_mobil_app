import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/core/widgets/app_mark.dart';
import 'package:ak_cars_mobil_app/features/garage/add_car_screen.dart';
import 'package:ak_cars_mobil_app/config/app_flags.dart';
import 'package:ak_cars_mobil_app/features/onboarding/onboarding_screen.dart';
import 'package:ak_cars_mobil_app/features/onboarding/splash_screen.dart';
import 'package:ak_cars_mobil_app/features/onboarding/start_choice_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

import 'helpers/test_harness.dart';

/// Stand-in for the shell — the flow only needs to prove it reached the app's
/// first tab, whichever tab that is (AppFlags.startLocation).
class _HomeStub extends StatelessWidget {
  const _HomeStub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('HOME')));
}

/// The three onboarding destinations behind a real router, wired the way
/// `app_router.dart` wires them (start-choice *pushes* /add-car, so the
/// question stays underneath it on the stack).
Future<ProviderContainer> pumpStartChoice(
  WidgetTester tester, {
  String locale = 'en',
}) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = await createTestContainer();

  final router = GoRouter(
    initialLocation: '/start-choice',
    routes: [
      GoRoute(
        path: '/start-choice',
        builder: (context, state) => const StartChoiceScreen(),
      ),
      GoRoute(
        path: '/add-car',
        builder: (context, state) => const AddCarScreen(),
      ),
      GoRoute(
        path: AppFlags.startLocation,
        builder: (context, state) => const _HomeStub(),
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
  await tester.pumpAndSettle();
  return container;
}

/// Fills in the three required fields on the car form through the popups.
///
/// Each field is scrolled into view first: picking a make and model reveals
/// the car preview, which pushes the year row below the fold.
Future<void> fillCarForm(WidgetTester tester, ProviderContainer container) async {
  Future<void> pick(String field, String option) async {
    await tester.ensureVisible(find.text(field));
    await tester.pumpAndSettle();
    await tester.tap(find.text(field));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  await pick('Make', 'Toyota');
  await pick('Model', 'Camry');
  // Newest-first, so the first year is at the top of the sheet.
  await pick('Made year', '${container.read(vehicleCatalogProvider).years.first}');
}

/// Splash → onboarding → start-choice, behind a real router.
Future<ProviderContainer> pumpIntro(
  WidgetTester tester, {
  String at = '/splash',
}) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = await createTestContainer();

  final router = GoRouter(
    initialLocation: at,
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(
        path: '/start-choice',
        builder: (c, s) => const StartChoiceScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
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
  // Not pumpAndSettle: the splash's ambient drift repeats forever by design,
  // so the tree never goes quiet. Pump past the entrance timeline instead.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  return container;
}

void main() {
  group('intro flow', () {
    testWidgets('splash shows the app mark and starts the tour',
        (tester) async {
      final container = await pumpIntro(tester);

      expect(find.byType(AppMark), findsOneWidget);
      expect(find.text('Start the journey'), findsOneWidget);

      await tester.tap(find.text('Start the journey'));
      await tester.pumpAndSettle();

      // Leaving the splash is what records it — a cold start mid-tour should
      // not drop the user back onto the welcome screen.
      expect(container.read(authProvider).onboardingSeen, isTrue);
      expect(find.textContaining('Trusted workshops'), findsOneWidget);
    });

    testWidgets('"Skip the tour" jumps to the car question, not past it',
        (tester) async {
      final container = await pumpIntro(tester);

      await tester.tap(find.textContaining('Skip the tour'));
      await tester.pumpAndSettle();

      expect(container.read(authProvider).onboardingSeen, isTrue);
      expect(container.read(authProvider).startChoiceMade, isFalse);
      expect(find.text('How would you like to start?'), findsOneWidget);
    });

    testWidgets('paging to the last slide swaps Next for Get started',
        (tester) async {
      final container = await pumpIntro(tester, at: '/onboarding');

      expect(find.text('Next'), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Get started'), findsOneWidget);
      expect(find.textContaining('Buy & sell cars'), findsOneWidget);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(container.read(authProvider).onboardingSeen, isTrue);
      expect(find.text('How would you like to start?'), findsOneWidget);
    });
  });

  group('start choice', () {
    testWidgets('offers both routes with the recommended one preselected',
        (tester) async {
      await pumpStartChoice(tester);

      expect(find.text('How would you like to start?'), findsOneWidget);
      expect(find.text('Add my car now'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      // Only the selected card expands, so its benefits are the ones shown.
      expect(find.textContaining('Service reminders'), findsOneWidget);
      expect(find.textContaining('Add your car later'), findsNothing);
      expect(find.text('Choose my car'), findsOneWidget);
    });

    testWidgets('picking "Not now" swaps the detail and the action label',
        (tester) async {
      await pumpStartChoice(tester);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Add your car later'), findsOneWidget);
      expect(find.textContaining('Service reminders'), findsNothing);
      expect(find.text('Continue to the app'), findsOneWidget);
    });

    testWidgets('"Not now" goes straight to home and records the choice',
        (tester) async {
      final container = await pumpStartChoice(tester);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to the app'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(container.read(authProvider).startChoiceMade, isTrue);
    });

    testWidgets('Skip leaves the flow without registering a car',
        (tester) async {
      final container = await pumpStartChoice(tester);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(container.read(garageProvider), isEmpty);
      expect(container.read(authProvider).startChoiceMade, isTrue);
    });

    // The bug this flow was reported for: finishing the car form popped back
    // onto the start-choice question, so the Save button looked like it did
    // nothing at all.
    testWidgets('finishing the car form lands on home, not back on the question',
        (tester) async {
      final container = await pumpStartChoice(tester);

      await tester.tap(find.text('Choose my car'));
      await tester.pumpAndSettle();
      expect(find.text('Add your car'), findsOneWidget);

      await fillCarForm(tester, container);
      await tester.tap(find.textContaining('Save Toyota Camry'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('How would you like to start?'), findsNothing);
      final saved = container.read(garageProvider).single;
      expect(saved.make, 'Toyota');
      expect(saved.model, 'Camry');
      expect(container.read(authProvider).startChoiceMade, isTrue);
    });

    testWidgets('backing out of the car form keeps the question answerable',
        (tester) async {
      final container = await pumpStartChoice(tester);

      await tester.tap(find.text('Choose my car'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // No car saved, and the user is back on the choice rather than home.
      expect(container.read(garageProvider), isEmpty);
      expect(find.text('How would you like to start?'), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
    });
  });
}

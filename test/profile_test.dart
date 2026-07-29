import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:ak_cars_mobil_app/features/cars/my_ads_screen.dart';
import 'package:ak_cars_mobil_app/features/profile/profile_screen.dart';

import 'helpers/test_harness.dart';

const _profile = UserProfile(
  name: 'Salim Al Hinai',
  phone: '+968 9200 1234',
  email: 'salim@example.om',
  // Stored as the canonical English key — must render Arabic on screen.
  region: 'North Al Batinah',
  address: 'Sohar',
);

Future<ProviderContainer> pumpProfile(
  WidgetTester tester, {
  String locale = 'ar',
  bool dark = false,
  UserProfile? profile,
  List<Car> garage = const [],
  Widget screen = const ProfileScreen(),
}) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = await createTestContainer();

  if (profile != null) {
    await container.read(authProvider.notifier).register(profile);
  }
  for (final car in garage) {
    await container.read(garageProvider.notifier).add(car);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(locale),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: screen,
      ),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

void main() {
  testWidgets('renders in Arabic and English without overflow',
      (tester) async {
    await pumpProfile(tester, profile: _profile);
    expect(find.text('Salim Al Hinai'), findsOneWidget);
    expect(find.textContaining('نشاطي'), findsOneWidget);
    expect(find.textContaining('الحساب'), findsOneWidget);

    await pumpProfile(tester, locale: 'en', profile: _profile);
    expect(find.textContaining('My activity'), findsOneWidget);
    expect(find.textContaining('Account'), findsOneWidget);
  });

  testWidgets('renders in the dark "Ink" theme', (tester) async {
    await pumpProfile(tester, profile: _profile, dark: true);
    expect(find.text('Salim Al Hinai'), findsOneWidget);
  });

  testWidgets('region is translated, not shown as the stored English key',
      (tester) async {
    await pumpProfile(tester, profile: _profile);
    expect(find.textContaining('شمال الباطنة'), findsOneWidget);
    expect(find.textContaining('North Al Batinah'), findsNothing);
  });

  testWidgets('guest sees the registration prompt; registered user does not',
      (tester) async {
    await pumpProfile(tester, locale: 'en');
    expect(find.textContaining('Complete your details'), findsWidgets);
    expect(find.text('Guest'), findsOneWidget);
    // Sign out is meaningless for a guest.
    expect(find.textContaining('Sign out'), findsNothing);

    await pumpProfile(tester, locale: 'en', profile: _profile);
    expect(find.textContaining('Complete your details to request'),
        findsNothing);
    expect(find.textContaining('Sign out'), findsWidgets);
  });

  testWidgets('sign out clears the profile and returns to guest',
      (tester) async {
    final container = await pumpProfile(
        tester, locale: 'en', profile: _profile);
    expect(container.read(authProvider).isRegistered, isTrue);

    await tester.tap(find.textContaining('Sign out').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(container.read(authProvider).isRegistered, isFalse);
    // Onboarding stays done — sign out must not replay the intro.
    expect(container.read(authProvider).onboardingSeen, isTrue);
    expect(find.text('Guest'), findsOneWidget);
  });

  // Was 'shop-orders row reports orders, not cart contents'. The parts store
  // is behind AppFlags.partsStoreEnabled for phase 1, so those rows are not
  // rendered at all and there is no route for them to push to — what this
  // now guards is that hiding the pillar hid the whole of it.
  testWidgets('hidden pillars leave no rows behind', (tester) async {
    final container = await pumpProfile(tester, locale: 'en');
    final product = container.read(filteredProductsProvider).first;
    container.read(cartProvider.notifier).toggle(product);
    await tester.pump();

    expect(find.textContaining('Shop orders'), findsNothing);
    expect(find.textContaining('Shopping cart'), findsNothing);
    expect(find.textContaining('My car ads'), findsNothing);
    // The pillar that stayed.
    expect(find.textContaining('My bookings'), findsOneWidget);
  });

  testWidgets('stat tiles count garage cars', (tester) async {
    await pumpProfile(
      tester,
      locale: 'en',
      profile: _profile,
      garage: const [
        Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2021),
        Car(id: 'c2', make: 'Nissan', model: 'Patrol', year: 2019),
      ],
    );
    expect(find.text('2'), findsWidgets);
  });

  group('My car ads', () {
    testWidgets('empty state invites posting, in both languages',
        (tester) async {
      await pumpProfile(tester, locale: 'en', screen: const MyAdsScreen());
      expect(find.textContaining('not posted any ads'), findsOneWidget);
      expect(find.textContaining('Post an ad'), findsOneWidget);

      await pumpProfile(tester, screen: const MyAdsScreen());
      expect(find.textContaining('لم تنشر أي إعلان'), findsOneWidget);
      expect(find.textContaining('أضف إعلاناً'), findsOneWidget);
    });

    testWidgets('lists only the user\'s own ads', (tester) async {
      final container =
          await pumpProfile(tester, locale: 'en', screen: const MyAdsScreen());
      final mine = container.read(galleryFeedProvider).first;
      container.read(myAdsProvider.notifier).add(mine);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(myAdsProvider), hasLength(1));
      expect(find.textContaining('not posted any ads'), findsNothing);
    });
  });
}

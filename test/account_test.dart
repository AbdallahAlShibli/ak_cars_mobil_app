import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/features/auth/register_screen.dart';
import 'package:ak_cars_mobil_app/features/profile/profile_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

import 'helpers/test_harness.dart';

const _profile = UserProfile(
  name: 'Salim Al Hinai',
  phone: '+968 92001234',
  email: 'salim@example.om',
  region: 'Muscat',
  address: 'Al Khuwair',
);

/// Profile hub + details screen behind a real router, wired as the app wires
/// them (the hub *pushes* /register).
Future<ProviderContainer> pumpAccount(
  WidgetTester tester, {
  UserProfile? profile,
  String initialLocation = '/profile',
  String locale = 'en',
}) async {
  // Tall enough that the whole form mounts at once.
  //
  // These tests assert on rows all the way down the page — the name at the top
  // and the OTP block at the bottom — and a finder only sees widgets the
  // ListView has actually built. On a phone-height surface the account-type
  // step (§9) pushes the OTP block past the fold, and the tests would be
  // failing on scroll position rather than on behaviour.
  tester.view.physicalSize = const Size(402 * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = await createTestContainer();
  if (profile != null) {
    await container.read(authProvider.notifier).register(profile);
  }

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
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

/// The text field inside the labelled row [label].
Finder fieldUnder(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(TextField),
    );

String textIn(WidgetTester tester, String label) =>
    tester.widget<TextField>(fieldUnder(label)).controller?.text ?? '';

/// Answers step zero (§9) so the submit button becomes live.
///
/// Every registration test below is about a *customer* account, which is what
/// this picks. The workshop half of the form has its own tests in
/// `workshop_registration_test.dart`; here it must stay entirely hidden, and a
/// test that never chose a kind could not tell the two apart.
Future<void> chooseCustomerAccount(WidgetTester tester) async {
  await tester.tap(find.text('Customer account'));
  await tester.pumpAndSettle();
}

Future<void> pickGovernorate(WidgetTester tester, String name) async {
  await tester.tap(find.text('Governorate'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> pickWilayat(WidgetTester tester, String name) async {
  await tester.tap(find.text('Wilayat'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  group('my details', () {
    // The reported bug: "My details" reopened the empty sign-up form.
    testWidgets('opens prefilled with the saved profile, not a blank form',
        (tester) async {
      await pumpAccount(tester, profile: _profile);

      await tester.tap(find.text('My details'));
      await tester.pumpAndSettle();

      expect(find.text('My details'), findsOneWidget,
          reason: 'the details editor must not be titled like a sign-up');
      expect(find.text('Complete your details'), findsNothing);
      expect(textIn(tester, 'Full name'), 'Salim Al Hinai');
      // Stored with the dial code; the field holds the local digits only.
      expect(textIn(tester, 'Phone number'), '9200 1234');
      expect(textIn(tester, 'Email'), 'salim@example.om');
      expect(textIn(tester, 'Address'), 'Al Khuwair');
      expect(find.text('Muscat'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('tapping the identity card opens the same editor',
        (tester) async {
      await pumpAccount(tester, profile: _profile);

      await tester.tap(find.text('Salim Al Hinai'));
      await tester.pumpAndSettle();

      expect(textIn(tester, 'Full name'), 'Salim Al Hinai');
    });

    testWidgets('editing an address saves without demanding a new code',
        (tester) async {
      final container = await pumpAccount(tester, profile: _profile);

      await tester.tap(find.text('My details'));
      await tester.pumpAndSettle();
      // Nothing to re-verify, so the whole OTP block stays away.
      expect(find.text('Verify with'), findsNothing);

      await tester.enterText(fieldUnder('Address'), 'Qurum');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final saved = container.read(authProvider).profile!;
      expect(saved.address, 'Qurum');
      // An edit must not wipe the fields it did not touch.
      expect(saved.name, 'Salim Al Hinai');
      expect(saved.email, 'salim@example.om');
      expect(saved.region, 'Muscat');
      // Back on the hub.
      expect(find.text('My activity'), findsOneWidget);
    });

    // This screen used to demand an OTP when the phone or email changed, and
    // compared it against a constant compiled into the app. `PUT
    // /user/profile` saves whatever it is sent with no OTP step, so that gate
    // could only ever have been satisfied by a code the real server never
    // issued — it went with the rest of the demo plumbing on 2026-08-10.
    // Login still verifies a real, server-issued code.
    testWidgets('changing the phone saves it, with nothing to re-verify',
        (tester) async {
      final container = await pumpAccount(tester, profile: _profile);

      await tester.tap(find.text('My details'));
      await tester.pumpAndSettle();
      await tester.enterText(fieldUnder('Phone number'), '95550000');
      await tester.pumpAndSettle();

      expect(find.text('Verify with'), findsNothing);
      expect(find.textContaining('Enter the code sent to'), findsNothing);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(container.read(authProvider).profile!.phone, '+968 9555 0000');
    });
  });

  group('registration', () {
    testWidgets('refuses a malformed phone and an unset governorate',
        (tester) async {
      final container =
          await pumpAccount(tester, initialLocation: '/register');
      await chooseCustomerAccount(tester);

      await tester.enterText(fieldUnder('Full name'), 'Aisha Al Balushi');
      await tester.enterText(fieldUnder('Phone number'), '123');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('An 8-digit Oman number'), findsOneWidget);
      expect(find.text('Choose your governorate'), findsOneWidget);
      expect(container.read(authProvider).isRegistered, isFalse);
    });

    // The wilayat used to be free text inside "Address" (hint: "Wilayat,
    // area"), so it could be spelled any way at all.
    testWidgets('wilayat is a list of the chosen governorate, not free text',
        (tester) async {
      final container =
          await pumpAccount(tester, initialLocation: '/register');
      await chooseCustomerAccount(tester);

      // Nothing to choose from until the governorate narrows it.
      expect(find.text('Choose a governorate first'), findsOneWidget);
      await tester.tap(find.text('Wilayat'));
      await tester.pumpAndSettle();
      expect(find.text('Seeb'), findsNothing,
          reason: 'the disabled row must not open a picker');

      await pickGovernorate(tester, 'Muscat');
      await tester.tap(find.text('Wilayat'));
      await tester.pumpAndSettle();
      // Muscat's own wilayats, and nobody else's.
      expect(find.text('Seeb'), findsOneWidget);
      expect(find.text('Salalah'), findsNothing);
      await tester.tap(find.text('Seeb').last);
      await tester.pumpAndSettle();

      await tester.enterText(fieldUnder('Full name'), 'Aisha Al Balushi');
      await tester.enterText(fieldUnder('Phone number'), '99887766');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(container.read(authProvider).profile!.wilayat, 'Seeb');
    });

    testWidgets('changing the governorate clears a wilayat from the old one',
        (tester) async {
      await pumpAccount(tester, initialLocation: '/register');

      await pickGovernorate(tester, 'Muscat');
      await pickWilayat(tester, 'Seeb');
      expect(find.text('Seeb'), findsOneWidget);

      await pickGovernorate(tester, 'Dhofar');
      expect(find.text('Seeb'), findsNothing,
          reason: 'Seeb is not in Dhofar — it must not stay on screen');
      expect(find.text('Choose from the list'), findsOneWidget);
    });

    testWidgets('rejects a landline, which cannot receive an SMS code',
        (tester) async {
      final container =
          await pumpAccount(tester, initialLocation: '/register');
      await chooseCustomerAccount(tester);

      await tester.enterText(fieldUnder('Full name'), 'Aisha Al Balushi');
      await tester.enterText(fieldUnder('Phone number'), '24478120');
      await tester.pumpAndSettle();
      await pickGovernorate(tester, 'Muscat');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('An Oman mobile number starting with 7 or 9'),
          findsOneWidget);
      expect(container.read(authProvider).isRegistered, isFalse);
    });

    // People paste from contacts, not just type eight bare digits.
    testWidgets('normalises a pasted international number to the local digits',
        (tester) async {
      await pumpAccount(tester, initialLocation: '/register');

      for (final pasted in ['+968 9988 7766', '0096899887766', '968-99887766']) {
        await tester.enterText(fieldUnder('Phone number'), pasted);
        await tester.pumpAndSettle();
        expect(textIn(tester, 'Phone number'), '9988 7766',
            reason: '"$pasted" should reduce to the 8 local digits');
      }

      // And nothing beyond the eighth digit is accepted.
      await tester.enterText(fieldUnder('Phone number'), '998877665544');
      await tester.pumpAndSettle();
      expect(textIn(tester, 'Phone number'), '9988 7766');
    });

    // Under Arabic the row used to render as "98765432 968+".
    testWidgets('renders the dial code and digits left-to-right in Arabic',
        (tester) async {
      await pumpAccount(tester, initialLocation: '/register', locale: 'ar');

      final field = fieldUnder('رقم الهاتف');
      expect(tester.widget<TextField>(field).textDirection, TextDirection.ltr);
      expect(
        find.ancestor(of: field, matching: find.byType(Directionality)).evaluate()
            .map((e) => (e.widget as Directionality).textDirection)
            .first,
        TextDirection.ltr,
        reason: 'the nearest Directionality above the field must be LTR',
      );
    });

    testWidgets('registers in one step, with no code to wait for',
        (tester) async {
      final container =
          await pumpAccount(tester, initialLocation: '/register');
      await chooseCustomerAccount(tester);

      await tester.enterText(fieldUnder('Full name'), 'Aisha Al Balushi');
      await tester.enterText(fieldUnder('Phone number'), '99887766');
      await tester.pumpAndSettle();
      await pickGovernorate(tester, 'Muscat');

      // `POST /auth/register` has no OTP step, so neither does this screen.
      expect(find.textContaining('Enter the code sent to'), findsNothing);
      expect(find.text('Verify with'), findsNothing);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final saved = container.read(authProvider).profile!;
      expect(saved.name, 'Aisha Al Balushi');
      expect(saved.phone, '+968 9988 7766');
      // The governorate the user actually picked, not the first in the list.
      expect(saved.region, 'Muscat');
      expect(container.read(regionProvider), 'Muscat');
    });

    // Email used to be a *verification channel* the user picked, and became
    // required once they picked it. With no OTP anywhere on this screen it is
    // simply an optional contact detail — but a typo in one is still worth
    // catching, since it is where a receipt would be sent.
    testWidgets('email is optional, but a malformed one is refused',
        (tester) async {
      final container =
          await pumpAccount(tester, initialLocation: '/register');
      await chooseCustomerAccount(tester);

      await tester.enterText(fieldUnder('Full name'), 'Aisha Al Balushi');
      await tester.enterText(fieldUnder('Phone number'), '99887766');
      await tester.pumpAndSettle();
      await pickGovernorate(tester, 'Muscat');

      await tester.enterText(fieldUnder('Email'), 'not-an-email');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('That does not look like an email'), findsOneWidget);
      expect(container.read(authProvider).isRegistered, isFalse);

      // Cleared rather than corrected: an account with only a phone number is
      // complete.
      await tester.enterText(fieldUnder('Email'), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(container.read(authProvider).isRegistered, isTrue);
    });
  });
}

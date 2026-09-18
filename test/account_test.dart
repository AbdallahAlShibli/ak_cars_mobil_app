import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ak_cars_mobil_app/core/constants/app_constants.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/auth/phone_code_sheet.dart';
import 'package:ak_cars_mobil_app/features/auth/register_screen.dart';
import 'package:ak_cars_mobil_app/features/profile/profile_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

import 'fakes/mock_auth_service.dart';
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
  UserProfile? existingAccount,
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
  if (existingAccount != null) {
    // An account on the "server" (the mock keeps it in prefs), with nobody
    // signed in to it.
    await container.read(sharedPrefsProvider).setString(
      AppConstants.prefsProfile,
      jsonEncode(existingAccount.toJson()),
    );
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

/// Registration proves the phone first: types [localDigits], asks for the
/// code, and enters the one code `MockAuthService` accepts into the sheet.
Future<void> verifyPhone(WidgetTester tester, String localDigits) async {
  await tester.enterText(fieldUnder('Phone number'), localDigits);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Send verification code'));
  await tester.pumpAndSettle();
  expect(find.byType(PhoneCodeSheet), findsOneWidget,
      reason: 'sending the code must open the code sheet');
  await tester.enterText(
    find.descendant(
      of: find.byType(PhoneCodeSheet),
      matching: find.byType(TextField),
    ),
    MockAuthService.validRegistrationCode,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm number'));
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

    // The phone is the login. Saving a new one with no proof let a signed-in
    // user move their account to a number they do not hold; `PUT
    // /user/profile` now refuses that, and the screen asks for the SMS code
    // for the *new* number first — the same step registration uses.
    testWidgets('changing the phone needs an SMS code for the new number',
        (tester) async {
      final container = await pumpAccount(tester, profile: _profile);
      final auth = container.read(authServiceProvider) as MockAuthService;

      await tester.tap(find.text('My details'));
      await tester.pumpAndSettle();
      // An unchanged number has nothing to prove.
      expect(find.text('Send verification code'), findsNothing);

      await tester.enterText(fieldUnder('Phone number'), '95550000');
      await tester.pumpAndSettle();
      expect(find.text('Send verification code'), findsOneWidget);

      // Saving before proving it is refused on the screen, and nothing moves.
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Verify the new number with an SMS code before saving'),
          findsOneWidget);
      expect(container.read(authProvider).profile!.phone, _profile.phone);

      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(PhoneCodeSheet),
          matching: find.byType(TextField),
        ),
        MockAuthService.validRegistrationCode,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm number'));
      await tester.pumpAndSettle();
      expect(find.text('Number verified'), findsOneWidget);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(container.read(authProvider).profile!.phone, '+968 9555 0000');
      expect(auth.lastProfileUpdateToken,
          MockAuthService.tokenFor('+968 9555 0000'));
    });

    testWidgets('the same number written differently is not a change',
        (tester) async {
      final container = await pumpAccount(tester, profile: _profile);
      final auth = container.read(authServiceProvider) as MockAuthService;

      await tester.tap(find.text('My details'));
      await tester.pumpAndSettle();
      await tester.enterText(fieldUnder('Phone number'), '+968 9200 1234');
      await tester.pumpAndSettle();

      expect(find.text('Send verification code'), findsNothing);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(container.read(authProvider).profile!.phone, '+968 9200 1234');
      expect(auth.lastProfileUpdateToken, isNull);
      expect(auth.registrationCodesSentTo, isEmpty);
    });
  });

  group('registration', () {
    testWidgets('refuses a malformed phone before sending a code',
        (tester) async {
      final container =
          await pumpAccount(tester, initialLocation: '/register');
      final auth = container.read(authServiceProvider) as MockAuthService;
      await chooseCustomerAccount(tester);

      await tester.enterText(fieldUnder('Phone number'), '123');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();

      expect(find.text('An 8-digit Oman number'), findsOneWidget);
      expect(auth.registrationCodesSentTo, isEmpty);
      expect(find.byType(PhoneCodeSheet), findsNothing);
    });

    testWidgets('refuses an unset governorate once the phone is proved',
        (tester) async {
      final container =
          await pumpAccount(tester, initialLocation: '/register');
      await chooseCustomerAccount(tester);
      await verifyPhone(tester, '99887766');

      await tester.enterText(fieldUnder('Full name'), 'Aisha Al Balushi');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

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
      await verifyPhone(tester, '99887766');

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
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(container.read(authProvider).profile!.wilayat, 'Seeb');
    });

    testWidgets('changing the governorate clears a wilayat from the old one',
        (tester) async {
      await pumpAccount(tester, initialLocation: '/register');
      await chooseCustomerAccount(tester);
      await verifyPhone(tester, '99887766');

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
      final auth = container.read(authServiceProvider) as MockAuthService;
      await chooseCustomerAccount(tester);

      await tester.enterText(fieldUnder('Phone number'), '24478120');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();

      expect(find.text('An Oman mobile number starting with 7 or 9'),
          findsOneWidget);
      expect(auth.registrationCodesSentTo, isEmpty);
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

    testWidgets('registers once the phone is proved by SMS', (tester) async {
      final container =
          await pumpAccount(tester, initialLocation: '/register');
      final auth = container.read(authServiceProvider) as MockAuthService;
      await chooseCustomerAccount(tester);

      // The rest of the form stays closed until the number is proved.
      expect(find.text('Full name'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed,
        isNull,
      );

      await verifyPhone(tester, '99887766');

      // The code went to the number on the form, and nothing exists yet.
      expect(auth.registrationCodesSentTo, ['+968 9988 7766']);
      expect(container.read(authProvider).isRegistered, isFalse);
      expect(find.text('Number verified'), findsOneWidget);

      await tester.enterText(fieldUnder('Full name'), 'Aisha Al Balushi');
      await tester.pumpAndSettle();
      await pickGovernorate(tester, 'Muscat');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final saved = container.read(authProvider).profile!;
      expect(saved.name, 'Aisha Al Balushi');
      expect(saved.phone, '+968 9988 7766');
      expect(saved.email, isEmpty);
      // The governorate the user actually picked, not the first in the list.
      expect(saved.region, 'Muscat');
      expect(container.read(regionProvider), 'Muscat');
      // The proof the API checks rode along with the registration.
      expect(
        auth.lastPhoneVerificationToken,
        MockAuthService.tokenFor('+968 9988 7766'),
      );
    });

    testWidgets('a phone that already has an account is refused before any SMS',
        (tester) async {
      final container = await pumpAccount(
        tester,
        initialLocation: '/register',
        existingAccount: _profile,
      );
      final auth = container.read(authServiceProvider) as MockAuthService;
      await chooseCustomerAccount(tester);

      await tester.enterText(fieldUnder('Phone number'), '92001234');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();

      expect(
        find.text('This number already has an account — log in instead'),
        findsOneWidget,
      );
      expect(auth.registrationCodesSentTo, isEmpty);
      expect(find.byType(PhoneCodeSheet), findsNothing);
      expect(find.text('Full name'), findsNothing);
      expect(container.read(authProvider).isRegistered, isFalse);
    });

    testWidgets('closing the code sheet leaves the number unverified',
        (tester) async {
      final container =
          await pumpAccount(tester, initialLocation: '/register');
      await chooseCustomerAccount(tester);

      await tester.enterText(fieldUnder('Phone number'), '99887766');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byType(PhoneCodeSheet), findsNothing);
      expect(find.text('Number verified'), findsNothing);
      expect(find.text('Full name'), findsNothing);
      expect(textIn(tester, 'Phone number'), '9988 7766');
      expect(container.read(authProvider).isRegistered, isFalse);
    });

    testWidgets('a wrong code keeps the sheet open and the form closed',
        (tester) async {
      await pumpAccount(tester, initialLocation: '/register');
      await chooseCustomerAccount(tester);

      await tester.enterText(fieldUnder('Phone number'), '99887766');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(PhoneCodeSheet),
          matching: find.byType(TextField),
        ),
        '9999',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm number'));
      await tester.pumpAndSettle();

      expect(find.byType(PhoneCodeSheet), findsOneWidget);
      expect(
        find.text('That code is wrong or has expired — request a new one'),
        findsOneWidget,
      );
    });

    testWidgets('changing a verified number drops the proof', (tester) async {
      await pumpAccount(tester, initialLocation: '/register');
      await chooseCustomerAccount(tester);
      await verifyPhone(tester, '99887766');
      expect(find.text('Full name'), findsOneWidget);

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      expect(find.text('Number verified'), findsNothing);
      expect(find.text('Send verification code'), findsOneWidget);
      expect(find.text('Full name'), findsNothing);
    });

    // Registration is phone only for now.
    testWidgets('registration does not ask for an email', (tester) async {
      await pumpAccount(tester, initialLocation: '/register');
      await chooseCustomerAccount(tester);
      await verifyPhone(tester, '99887766');

      expect(find.text('Email'), findsNothing);
    });
  });


}

import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/auth/phone_code_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/mock_auth_service.dart';
import 'helpers/test_harness.dart';

/// The SMS code sheet the register screen opens once the API has texted a
/// registration code.
void main() {
  const phone = '+968 9200 0009';

  Future<({MockAuthService auth, String? Function() result})> openSheet(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = await createTestContainer();
    final auth = container.read(authServiceProvider) as MockAuthService;
    String? token = 'not returned yet';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    token = await showPhoneCodeSheet(context, phone: phone),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (auth: auth, result: () => token);
  }

  testWidgets('the right code closes the sheet with the verification token',
      (tester) async {
    final sheet = await openSheet(tester);

    expect(find.text(phone), findsOneWidget);
    await tester.enterText(
        find.byType(TextField), MockAuthService.validRegistrationCode);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm number'));
    await tester.pumpAndSettle();

    expect(sheet.result(), MockAuthService.tokenFor(phone));
    expect(find.text('Confirm number'), findsNothing);
  });

  testWidgets('a wrong code stays open and says to ask for a new one',
      (tester) async {
    final sheet = await openSheet(tester);

    await tester.enterText(find.byType(TextField), '9999');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm number'));
    await tester.pumpAndSettle();

    expect(
      find.text('That code is wrong or has expired — request a new one'),
      findsOneWidget,
    );
    expect(sheet.result(), 'not returned yet');
  });

  testWidgets('a short code is caught before the API is asked', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), '12');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm number'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the 4-digit code'), findsOneWidget);
  });

  testWidgets('resend is held back 30 seconds, then sends again', (tester) async {
    final sheet = await openSheet(tester);

    expect(find.text("Didn't get it? Resend"), findsNothing);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Didn't get it? Resend"));
    await tester.pumpAndSettle();

    expect(sheet.auth.registrationCodesSentTo, [phone]);
  });

  testWidgets('closing the sheet returns no token', (tester) async {
    final sheet = await openSheet(tester);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(sheet.result(), isNull);
  });
}

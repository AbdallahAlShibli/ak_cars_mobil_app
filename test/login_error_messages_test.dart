import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/data/models/user_profile.dart';
import 'package:ak_cars_mobil_app/data/services/auth_service.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_phone_verification_service.dart';
import 'helpers/test_harness.dart';

/// The login screen has to say *which* thing went wrong.
///
/// It used to answer every failure with "Could not log in — try again", so a
/// person who mistyped one digit, a person whose code had expired, a person
/// who had burned all five attempts and a person who was simply offline all
/// read the same sentence. Only one of those is helped by trying again.
///
/// Two senders, two sets of rules. The API's own code (email) deliberately
/// collapses wrong/expired/too-many into `otp_invalid_or_expired`, so that copy
/// names what the user can *do*. Firebase's SMS code (phone) does tell a
/// mistyped code from an expired one, and that copy says which.
void main() {
  Future<void> pumpLogin(
    WidgetTester tester, {
    required AuthService auth,
    FakePhoneVerificationService? phones,
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = await createTestContainer(overrides: [
      authServiceProvider.overrideWithValue(auth),
      if (phones != null)
        phoneVerificationServiceProvider.overrideWithValue(phones),
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('ar'), Locale('en')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the API code, sent by email', () {
    Future<void> failVerifyWith(
      WidgetTester tester,
      AppException failure,
    ) async {
      await pumpLogin(tester, auth: _ScriptedAuthService(failure));

      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'owner@akcars.om');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send the code'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '1234');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify and log in'));
      await tester.pumpAndSettle();
    }

    testWidgets('a wrong or expired code says so, and says to ask for a new one',
        (tester) async {
      await failVerifyWith(
        tester,
        const UnauthorizedException('Wrong or expired code.',
            code: 'otp_invalid_or_expired'),
      );

      expect(
        find.text('That code is wrong or has expired — request a new one'),
        findsOneWidget,
      );
      expect(find.text('Could not log in — try again'), findsNothing);
    });

    testWidgets('being rate-limited says to wait, not to try again',
        (tester) async {
      await failVerifyWith(tester, const RateLimitedException('Rate limited'));

      expect(
        find.text('Too many attempts — wait a minute and try again'),
        findsOneWidget,
      );
    });

    testWidgets('an unreachable server blames the connection, not the code',
        (tester) async {
      await failVerifyWith(
        tester,
        const NetworkException('Could not reach the host'),
      );

      expect(
        find.text('Could not reach the server — check your connection'),
        findsOneWidget,
      );
    });

    testWidgets('anything unclassified still falls back to the generic message',
        (tester) async {
      await failVerifyWith(
        tester,
        const UnknownException('something else entirely'),
      );

      expect(find.text('Could not log in — try again'), findsOneWidget);
    });
  });

  group('the Firebase code, sent by SMS', () {
    Future<void> sendAndEnter(WidgetTester tester, String code) async {
      await tester.enterText(find.byType(TextField).first, '92220002');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send the code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, code);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify and log in'));
      await tester.pumpAndSettle();
    }

    testWidgets('a mistyped code says to check it, and never reaches the API',
        (tester) async {
      final auth = _ScriptedAuthService(const UnknownException('unused'));
      await pumpLogin(tester, auth: auth);

      await sendAndEnter(tester, '000000');

      expect(
        find.text('That code is not right — check it and try again'),
        findsOneWidget,
      );
      expect(auth.phoneLoginAttempts, 0);
    });

    testWidgets('a verification the API no longer accepts asks for a new code',
        (tester) async {
      await pumpLogin(
        tester,
        auth: _ScriptedAuthService(const UnauthorizedException(
          'The phone verification is not valid or has expired.',
          code: 'phone_token_invalid',
        )),
      );

      await sendAndEnter(tester, FakePhoneVerificationService.validCode);

      expect(
        find.text('The verification has expired — ask for a new code'),
        findsOneWidget,
      );
    });

    testWidgets('SMS verification that cannot run says so under the number',
        (tester) async {
      final phones = FakePhoneVerificationService()
        ..sendFailure = const PhoneVerificationException(
          'operation-not-allowed',
          reason: PhoneVerificationFailure.unavailable,
        );
      await pumpLogin(
        tester,
        auth: _ScriptedAuthService(const UnknownException('unused')),
        phones: phones,
      );

      await tester.enterText(find.byType(TextField).first, '92220002');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send the code'));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'SMS verification is not available right now — try again later'),
        findsOneWidget,
      );
      expect(find.text('Verify and log in'), findsNothing);
    });
  });
}

/// Finds the account, then fails whichever login is attempted with [_failure].
class _ScriptedAuthService extends MockAuthServiceBase {
  _ScriptedAuthService(this._failure);

  final AppException _failure;

  int phoneLoginAttempts = 0;

  @override
  Future<bool> requestOtp(String identifier) async => true;

  @override
  Future<bool> accountExists(String identifier) async => true;

  @override
  Future<UserProfile> login(String identifier, String code) async =>
      throw _failure;

  @override
  Future<UserProfile> loginWithVerifiedPhone(String firebaseIdToken) async {
    phoneLoginAttempts++;
    throw _failure;
  }
}

/// The parts of [AuthService] this test does not exercise.
class MockAuthServiceBase implements AuthService {
  @override
  Future<UserProfile?> fetchCurrentUser() async => null;

  @override
  Future<bool> requestOtp(String identifier) async => false;

  @override
  Future<bool> accountExists(String identifier) async => false;

  @override
  Future<UserProfile> login(String identifier, String code) async =>
      throw UnimplementedError();

  @override
  Future<UserProfile> loginWithVerifiedPhone(String firebaseIdToken) async =>
      throw UnimplementedError();

  @override
  Future<UserProfile> register(
    UserProfile profile, {
    String? phoneVerificationToken,
  }) async => throw UnimplementedError();

  @override
  Future<void> validateRegistration(UserProfile profile) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async =>
      throw UnimplementedError();
}
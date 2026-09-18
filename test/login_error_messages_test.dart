import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/data/models/user_profile.dart';
import 'package:ak_cars_mobil_app/data/services/auth_service.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

/// The login screen has to say *which* thing went wrong.
///
/// It used to answer every failure with "Could not log in — try again", so a
/// person who mistyped one digit, a person whose code had expired, a person
/// who had burned all five attempts and a person who was simply offline all
/// read the same sentence. Only one of those is helped by trying again.
///
/// The API deliberately collapses wrong/expired/too-many into
/// `otp_invalid_or_expired`, so that copy names what the user can *do*.
void main() {
  Future<void> pumpLogin(WidgetTester tester, {required AuthService auth}) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = await createTestContainer(overrides: [
      authServiceProvider.overrideWithValue(auth),
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

  Future<void> sendCode(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '92220002');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send the code'));
    await tester.pumpAndSettle();
  }

  group('verifying the code', () {
    Future<void> failVerifyWith(
      WidgetTester tester,
      AppException failure,
    ) async {
      await pumpLogin(tester, auth: _ScriptedAuthService(verifyFailure: failure));
      await sendCode(tester);

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

  group('sending the code', () {
    testWidgets('being rate-limited says to wait, under the number',
        (tester) async {
      await pumpLogin(
        tester,
        auth: _ScriptedAuthService(
          sendFailure: const RateLimitedException('Rate limited'),
        ),
      );

      await sendCode(tester);

      expect(
        find.text('Too many requests — wait a minute and try again'),
        findsOneWidget,
      );
      expect(find.text('Verify and log in'), findsNothing);
    });

    testWidgets('the per-phone hourly cap says an hour, not a minute',
        (tester) async {
      await pumpLogin(
        tester,
        auth: _ScriptedAuthService(
          sendFailure: const RateLimitedException(
            'Rate limited',
            code: 'otp_too_many_requests',
          ),
        ),
      );

      await sendCode(tester);

      expect(
        find.text('Too many codes sent to this number — try again in an hour'),
        findsOneWidget,
      );
    });

    testWidgets('an unreachable server says so, under the number',
        (tester) async {
      await pumpLogin(
        tester,
        auth: _ScriptedAuthService(
          sendFailure: const NetworkException('Could not reach the host'),
        ),
      );

      await sendCode(tester);

      expect(
        find.text('Could not reach the server — check your connection'),
        findsOneWidget,
      );
    });

    // The SMS gateway refusing the message (a Twilio sender that is not on the
    // account, a country that is not enabled, no credit) is neither the user's
    // connection nor anything they typed. It read as "Could not send the code
    // — try again" until the API started answering `503 sms_send_failed`,
    // which sent people round the same loop with no idea why.
    testWidgets('a gateway that refuses the message says so', (tester) async {
      await pumpLogin(
        tester,
        auth: _ScriptedAuthService(
          sendFailure: const ApiException(
            'The verification code could not be sent. Try again shortly.',
            statusCode: 503,
            errorCode: 'sms_send_failed',
          ),
        ),
      );

      await sendCode(tester);

      expect(
        find.text("Our SMS provider wouldn't send the message — try again shortly"),
        findsOneWidget,
      );
      expect(find.text('Could not send the code — try again'), findsNothing);
    });

    testWidgets('a server fault is told apart from the send', (tester) async {
      await pumpLogin(
        tester,
        auth: _ScriptedAuthService(
          sendFailure: const ApiException('Bad gateway', statusCode: 502),
        ),
      );

      await sendCode(tester);

      expect(
        find.text("Our server isn't responding — try again shortly"),
        findsOneWidget,
      );
    });
  });
}

/// Finds the account, then fails the send or the login as scripted.
class _ScriptedAuthService extends MockAuthServiceBase {
  _ScriptedAuthService({this.sendFailure, this.verifyFailure});

  final AppException? sendFailure;
  final AppException? verifyFailure;

  @override
  Future<bool> requestOtp(String identifier) async {
    final failure = sendFailure;
    if (failure != null) throw failure;
    return true;
  }

  @override
  Future<UserProfile> login(String identifier, String code) async =>
      throw verifyFailure ?? const UnknownException('unscripted');
}

/// The parts of [AuthService] this test does not exercise.
class MockAuthServiceBase implements AuthService {
  @override
  Future<UserProfile?> fetchCurrentUser() async => null;

  @override
  Future<bool> requestOtp(String identifier) async => false;

  @override
  Future<UserProfile> login(String identifier, String code) async =>
      throw UnimplementedError();

  @override
  Future<UserProfile> register(
    UserProfile profile, {
    String? phoneVerificationToken,
  }) async => throw UnimplementedError();

  @override
  Future<void> requestRegistrationOtp(String phone) async {}

  @override
  Future<String> verifyRegistrationOtp(String phone, String code) async =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<UserProfile> updateProfile(
    UserProfile profile, {
    String? phoneVerificationToken,
  }) async =>
      throw UnimplementedError();
}

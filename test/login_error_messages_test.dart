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
/// The server deliberately collapses wrong/expired/too-many into one code
/// (`otp_invalid_or_expired`) so the message cannot be used to learn whether a
/// code was ever right — so the copy names what the user can *do*, not which
/// of the three happened.
void main() {
  const account = UserProfile(
    name: 'Abdullah',
    phone: '+968 9222 0002',
    email: 'abdullah@example.om',
    region: 'Muscat',
    wilayat: 'Seeb',
    address: 'Qurum',
  );

  /// Opens the login screen, gets as far as the code field, then makes the
  /// next `login()` fail with [failure].
  Future<void> pumpToCodeField(
    WidgetTester tester, {
    required AppException failure,
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = await createTestContainer(overrides: [
      authServiceProvider
          .overrideWithValue(_ScriptedAuthService(account, failure)),
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

    await tester.enterText(find.byType(TextField).first, '92220002');
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
    await pumpToCodeField(
      tester,
      failure: const UnauthorizedException('Wrong or expired code.',
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
    await pumpToCodeField(
      tester,
      failure: const RateLimitedException('Rate limited'),
    );

    expect(
      find.text('Too many attempts — wait a minute and try again'),
      findsOneWidget,
    );
  });

  testWidgets('an unreachable server blames the connection, not the code',
      (tester) async {
    await pumpToCodeField(
      tester,
      failure: const NetworkException('Could not reach the host'),
    );

    expect(
      find.text('Could not reach the server — check your connection'),
      findsOneWidget,
    );
  });

  testWidgets('anything unclassified still falls back to the generic message',
      (tester) async {
    await pumpToCodeField(
      tester,
      failure: const UnknownException('something else entirely'),
    );

    expect(find.text('Could not log in — try again'), findsOneWidget);
  });
}

/// Finds the account, then fails [login] with a chosen exception.
class _ScriptedAuthService extends MockAuthServiceBase {
  _ScriptedAuthService(this._account, this._failure);

  final UserProfile _account;
  final AppException _failure;

  @override
  Future<UserProfile?> findAccount(String identifier) async => _account;

  @override
  Future<UserProfile> login(String identifier, String code) async =>
      throw _failure;
}

/// The parts of [AuthService] this test does not exercise.
class MockAuthServiceBase implements AuthService {
  @override
  Future<UserProfile?> fetchCurrentUser() async => null;

  @override
  Future<UserProfile?> findAccount(String identifier) async => null;

  @override
  Future<UserProfile> login(String identifier, String code) async =>
      throw UnimplementedError();

  @override
  Future<UserProfile> register(UserProfile profile) async =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async =>
      throw UnimplementedError();
}

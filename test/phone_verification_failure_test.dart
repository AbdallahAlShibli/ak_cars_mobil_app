import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/data/services/firebase/firebase_phone_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// How a Firebase phone-auth refusal is classified, and when a development
/// build may fall back to the API's own code because of it.
void main() {
  PhoneVerificationFailure reasonFor(String code, [String? message]) =>
      FirebasePhoneVerificationService.reasonFor(code, message);

  group('Firebase phone-auth refusals', () {
    test('project-setup problems are notConfigured, by code', () {
      for (final code in [
        'billing-not-enabled',
        'operation-not-allowed',
        'app-not-authorized',
        'missing-client-identifier',
        'invalid-app-credential',
        'unauthorized-domain',
      ]) {
        expect(reasonFor(code), PhoneVerificationFailure.notConfigured,
            reason: code);
      }
    });

    test('or by the server status a native SDK leaves only in the message', () {
      // What Firebase answered this project on 2026-09-14, for an Omani
      // number and for a region outside the SMS policy.
      expect(
        reasonFor('internal-error',
            'An internal error has occurred. [ BILLING_NOT_ENABLED ]'),
        PhoneVerificationFailure.notConfigured,
      );
      expect(
        reasonFor('unknown',
            'OPERATION_NOT_ALLOWED : SMS unable to be sent until this region enabled by the app developer.'),
        PhoneVerificationFailure.notConfigured,
      );
    });

    test('what the user typed, and passing trouble, are not setup problems', () {
      expect(reasonFor('invalid-verification-code'),
          PhoneVerificationFailure.invalidCode);
      expect(reasonFor('session-expired'), PhoneVerificationFailure.codeExpired);
      expect(reasonFor('invalid-phone-number'),
          PhoneVerificationFailure.invalidPhoneNumber);
      expect(reasonFor('too-many-requests'),
          PhoneVerificationFailure.tooManyRequests);
      expect(reasonFor('network-request-failed'),
          PhoneVerificationFailure.network);
      expect(reasonFor('captcha-check-failed'),
          PhoneVerificationFailure.unavailable);
      expect(reasonFor('web-context-cancelled'),
          PhoneVerificationFailure.cancelled);
      expect(reasonFor('something-new', 'no status here'),
          PhoneVerificationFailure.unknown);
    });
  });

  group('falling back to the API code', () {
    test('only a development debug build may', () {
      expect(
        AppConfig.apiOtpFallbackAllowedFor(AppEnvironment.development,
            releaseBuild: false),
        isTrue,
      );
      expect(
        AppConfig.apiOtpFallbackAllowedFor(AppEnvironment.development,
            releaseBuild: true),
        isFalse,
      );
      for (final environment in [
        AppEnvironment.staging,
        AppEnvironment.production,
      ]) {
        expect(
          AppConfig.apiOtpFallbackAllowedFor(environment, releaseBuild: false),
          isFalse,
          reason: environment.key,
        );
      }
    });
  });
}

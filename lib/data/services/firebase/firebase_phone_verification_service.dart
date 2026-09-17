import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/firebase/firebase_init.dart';
import '../phone_verification_service.dart';

/// [PhoneVerificationService] on Firebase Authentication.
///
/// Firebase is used for the SMS round-trip and nothing else: as soon as it
/// hands over an ID token, this signs back out of Firebase. The app's session
/// is the AK Cars API's own access/refresh tokens, and a second session left
/// signed in on the Firebase side would outlive the app's sign-out.
///
/// [disableAppVerificationForTesting] replaces Firebase's app check (reCAPTCHA
/// on web, Play Integrity / APNs on mobile) with a mock. Firebase then accepts
/// only the console's test phone numbers — see `AppConfig.phoneAuthTestMode`.
class FirebasePhoneVerificationService implements PhoneVerificationService {
  FirebasePhoneVerificationService({
    this.disableAppVerificationForTesting = false,
  });

  final bool disableAppVerificationForTesting;

  bool _testSettingsApplied = false;

  static const _timeout = Duration(seconds: 60);

  /// Android's "send again" token per number. Without it, a resend inside
  /// the same verification window can be refused.
  final _resendTokens = <String, int>{};

  @override
  bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<PhoneVerificationSession> sendCode(String e164Phone) async {
    if (!isSupported) {
      throw const PhoneVerificationException(
        'Phone sign-in is not available on this platform',
        reason: PhoneVerificationFailure.unavailable,
      );
    }
    final auth = await _auth();
    try {
      if (kIsWeb) {
        // Web runs an invisible reCAPTCHA itself before sending.
        final confirmation = await auth.signInWithPhoneNumber(e164Phone);
        return PhoneVerificationSession(phone: e164Phone, handle: confirmation);
      }
      return await _sendNative(auth, e164Phone);
    } on FirebaseAuthException catch (error, stack) {
      throw _translate(error, stack);
    }
  }

  Future<PhoneVerificationSession> _sendNative(FirebaseAuth auth, String phone) {
    final completer = Completer<PhoneVerificationSession>();

    void fail(Object error, StackTrace stack) {
      if (completer.isCompleted) return;
      completer.completeError(
        error is FirebaseAuthException
            ? _translate(error, stack)
            : PhoneVerificationException(
                '$error',
                reason: PhoneVerificationFailure.unknown,
                cause: error,
                stackTrace: stack,
              ),
      );
    }

    unawaited(
      auth
          .verifyPhoneNumber(
            phoneNumber: phone,
            timeout: _timeout,
            forceResendingToken: _resendTokens[phone],
            verificationCompleted: (credential) async {
              // Android verified the number itself before a code was even
              // shown. Only useful while nothing else has answered yet.
              if (completer.isCompleted) return;
              try {
                final token = await _signInAndTakeToken(auth, credential);
                if (!completer.isCompleted) {
                  completer.complete(PhoneVerificationSession(
                    phone: phone,
                    handle: credential,
                    idToken: token,
                  ));
                }
              } catch (error, stack) {
                fail(error, stack);
              }
            },
            verificationFailed: (error) => fail(error, StackTrace.current),
            codeSent: (verificationId, resendToken) {
              if (resendToken != null) _resendTokens[phone] = resendToken;
              if (!completer.isCompleted) {
                completer.complete(
                  PhoneVerificationSession(phone: phone, handle: verificationId),
                );
              }
            },
            codeAutoRetrievalTimeout: (_) {},
          )
          .catchError(fail),
    );

    return completer.future;
  }

  @override
  Future<String> confirmCode(
    PhoneVerificationSession session,
    String smsCode,
  ) async {
    final alreadyVerified = session.idToken;
    if (alreadyVerified != null) return alreadyVerified;

    final auth = await _auth();
    try {
      final handle = session.handle;
      final UserCredential credential;
      if (handle is ConfirmationResult) {
        credential = await handle.confirm(smsCode);
      } else if (handle is String) {
        credential = await auth.signInWithCredential(
          PhoneAuthProvider.credential(verificationId: handle, smsCode: smsCode),
        );
      } else {
        throw const PhoneVerificationException(
          'Unknown verification session',
          reason: PhoneVerificationFailure.unknown,
        );
      }
      return await _takeToken(auth, credential.user);
    } on FirebaseAuthException catch (error, stack) {
      throw _translate(error, stack);
    }
  }

  Future<String> _signInAndTakeToken(
    FirebaseAuth auth,
    PhoneAuthCredential credential,
  ) async {
    final result = await auth.signInWithCredential(credential);
    return _takeToken(auth, result.user);
  }

  /// The ID token, then straight back out of Firebase (see the class comment).
  Future<String> _takeToken(FirebaseAuth auth, User? user) async {
    try {
      final token = await user?.getIdToken();
      if (token == null || token.isEmpty) {
        throw const PhoneVerificationException(
          'Firebase returned no ID token',
          reason: PhoneVerificationFailure.unknown,
        );
      }
      return token;
    } finally {
      await auth.signOut();
    }
  }

  Future<FirebaseAuth> _auth() async {
    try {
      await ensureFirebaseInitialized();
      final auth = FirebaseAuth.instance;
      if (disableAppVerificationForTesting && !_testSettingsApplied) {
        await auth.setSettings(appVerificationDisabledForTesting: true);
        _testSettingsApplied = true;
      }
      return auth;
    } catch (error, stack) {
      throw PhoneVerificationException(
        'Firebase could not start',
        reason: PhoneVerificationFailure.unavailable,
        cause: error,
        stackTrace: stack,
      );
    }
  }

  static PhoneVerificationException _translate(
    FirebaseAuthException error,
    StackTrace stack,
  ) {
    final reason = reasonFor(error.code, error.message);
    // The screens show one friendly sentence for a whole family of causes
    // (billing off, region blocked, provider disabled, app not registered).
    // The console gets Firebase's own code, which is what actually says which.
    developer.log(
      'Firebase phone auth failed: ${error.code} — ${error.message}',
      name: 'PhoneVerification',
      error: error,
      stackTrace: stack,
    );
    return PhoneVerificationException(
      '${error.code}: ${error.message}',
      reason: reason,
      cause: error,
      stackTrace: stack,
    );
  }

  /// Firebase's error [code] — and its [message], where a platform reports
  /// the server's status only there — as a [PhoneVerificationFailure].
  ///
  /// Project-setup refusals are [PhoneVerificationFailure.notConfigured], not
  /// [PhoneVerificationFailure.unavailable]: no amount of retrying fixes
  /// billing being off, and development builds fall back to the API's own
  /// code on exactly this reason (see `AppConfig.apiOtpFallbackAllowed`).
  @visibleForTesting
  static PhoneVerificationFailure reasonFor(String code, String? message) {
    // The native SDKs can surface the server's refusal under a generic code
    // ('internal-error', 'unknown') with the status only in the message —
    // BILLING_NOT_ENABLED and the SMS region policy arrive that way.
    final server = (message ?? '').toUpperCase();
    if (server.contains('BILLING_NOT_ENABLED') ||
        server.contains('OPERATION_NOT_ALLOWED') ||
        server.contains('REGION ENABLED')) {
      return PhoneVerificationFailure.notConfigured;
    }
    return switch (code) {
      'invalid-verification-code' => PhoneVerificationFailure.invalidCode,
      'session-expired' ||
      'code-expired' ||
      'invalid-verification-id' => PhoneVerificationFailure.codeExpired,
      'invalid-phone-number' ||
      'missing-phone-number' => PhoneVerificationFailure.invalidPhoneNumber,
      'too-many-requests' ||
      'quota-exceeded' => PhoneVerificationFailure.tooManyRequests,
      'network-request-failed' => PhoneVerificationFailure.network,
      'billing-not-enabled' ||
      'operation-not-allowed' ||
      'app-not-authorized' ||
      'missing-client-identifier' ||
      'invalid-app-credential' ||
      'unauthorized-domain' => PhoneVerificationFailure.notConfigured,
      'captcha-check-failed' => PhoneVerificationFailure.unavailable,
      'web-context-cancelled' ||
      'user-cancelled' => PhoneVerificationFailure.cancelled,
      _ => PhoneVerificationFailure.unknown,
    };
  }
}
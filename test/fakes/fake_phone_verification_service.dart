import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/data/services/phone_verification_service.dart';

/// Stands in for Firebase phone sign-in.
///
/// [validCode] is the only code it accepts, and the "ID token" it hands back
/// names the phone it verified (`firebase-token:+96892000001`) so
/// `MockAuthService.loginWithVerifiedPhone` can find the account the same way
/// the real API reads the number out of a real token.
class FakePhoneVerificationService implements PhoneVerificationService {
  FakePhoneVerificationService({this.isSupported = true});

  static const validCode = '123456';

  static String tokenFor(String phone) => 'firebase-token:$phone';

  @override
  final bool isSupported;

  /// Every number a code was "texted" to, in order.
  final sentTo = <String>[];

  /// When set, [sendCode] throws this instead of sending.
  PhoneVerificationException? sendFailure;

  /// Android instant verification: the session arrives already verified.
  bool verifyInstantly = false;

  @override
  Future<PhoneVerificationSession> sendCode(String e164Phone) async {
    final failure = sendFailure;
    if (failure != null) throw failure;
    sentTo.add(e164Phone);
    return PhoneVerificationSession(
      phone: e164Phone,
      handle: 'fake-verification-${sentTo.length}',
      idToken: verifyInstantly ? tokenFor(e164Phone) : null,
    );
  }

  @override
  Future<String> confirmCode(
    PhoneVerificationSession session,
    String smsCode,
  ) async {
    final alreadyVerified = session.idToken;
    if (alreadyVerified != null) return alreadyVerified;
    if (smsCode != validCode) {
      throw const PhoneVerificationException(
        'wrong code',
        reason: PhoneVerificationFailure.invalidCode,
      );
    }
    return tokenFor(session.phone);
  }
}
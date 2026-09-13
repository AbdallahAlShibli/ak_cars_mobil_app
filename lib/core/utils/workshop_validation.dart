import '../../data/models/models.dart';
import '../i18n/strings.dart';

/// The rules a workshop record has to satisfy, in one place.
///
/// Two screens now edit the same record — "My details"
/// (`register_screen.dart`, where the owner keeps the filed application up to
/// date) and the dashboard's workshop profile
/// (`workshop_profile_screen.dart`) — and the founder edits it from a third.
/// Rules written separately in each drift: one screen accepts a five-digit CR
/// number, the next refuses it, and the owner finds out which of the two was
/// lying only after a rejected review.
///
/// Every rule returns a **localized message** or null, so a call site reads as
/// `errors['crNumber'] = WorkshopRules.crNumber(text, s)`.
///
/// What is deliberately *not* checked: nothing here contacts a registry. A CR
/// number is shape-checked, never verified — the founder reads the
/// certificate, and a client-side check pretending otherwise would be false
/// assurance. These catch typos before they waste a review.
abstract final class WorkshopRules {
  /// The legal name on the certificate. Required — it is what the founder
  /// matches the document against.
  static String? businessNameAr(String value, S s) => value.trim().isEmpty
      ? s.t(
          'اسم السجل التجاري مطلوب',
          'The commercial registration name is required',
        )
      : null;

  /// Commercial Registration number: 6–10 digits.
  static String? crNumber(String value, S s, {bool required = true}) {
    final cr = value.trim();
    if (cr.isEmpty) {
      return required
          ? s.t('رقم السجل التجاري مطلوب', 'The CR number is required')
          : null;
    }
    if (!RegExp(r'^\d{6,10}$').hasMatch(cr)) {
      return s.t(
        'رقم السجل التجاري من 6 إلى 10 أرقام',
        'A CR number is 6–10 digits',
      );
    }
    return null;
  }

  /// Oman VATIN — **optional**, and it stays optional.
  ///
  /// VAT registration in Oman is turnover-based, so a small garage genuinely
  /// has none; requiring one only produces invented numbers. When a number
  /// *is* given it is shape-checked: an Omani VATIN is `OM` followed by
  /// digits, and the bare digits are accepted too, since that is how plenty of
  /// certificates print it.
  static String? vatNumber(String value, S s) {
    final vat = value.trim().replaceAll(' ', '').toUpperCase();
    if (vat.isEmpty) return null;
    if (!RegExp(r'^(OM)?\d{8,15}$').hasMatch(vat)) {
      return s.t(
        'الرقم الضريبي مثل OM1100059183',
        'A VAT number looks like OM1100059183',
      );
    }
    return null;
  }

  /// An Oman phone number: 8 digits after the +968.
  ///
  /// [mobileOnly] refuses a landline. Use it where an SMS has to arrive (the
  /// account's own number); leave it off for a workshop's contact line, where
  /// a `24…` landline is the normal case and refusing it would be wrong.
  static String? omanPhone(
    String value,
    S s, {
    required bool required,
    bool mobileOnly = false,
  }) {
    final local = _digits(value).replaceFirst(RegExp(r'^968'), '');
    if (local.isEmpty) {
      return required
          ? s.t('رقم الهاتف مطلوب', 'Phone number is required')
          : null;
    }
    if (local.length != 8) {
      return s.t('رقم عُماني من 8 أرقام', 'An 8-digit Oman number');
    }
    if (mobileOnly && !RegExp(r'^[79]').hasMatch(local)) {
      return s.t(
        'رقم هاتف نقّال عُماني يبدأ بـ 7 أو 9',
        'An Oman mobile number starting with 7 or 9',
      );
    }
    if (!mobileOnly && !RegExp(r'^[2379]').hasMatch(local)) {
      return s.t(
        'رقم عُماني يبدأ بـ 2 أو 7 أو 9',
        'An Oman number starting with 2, 7 or 9',
      );
    }
    return null;
  }

  /// WhatsApp has to be a mobile — there is no WhatsApp on a landline.
  static String? whatsapp(String value, S s, {bool required = false}) =>
      omanPhone(value, s, required: required, mobileOnly: true);

  static String? area(String? value, S s) => (value ?? '').trim().isEmpty
      ? s.t('اختر منطقة الورشة', "Choose the workshop's area")
      : null;

  static String? region(String? value, S s) => (value ?? '').trim().isEmpty
      ? s.t('اختر المحافظة', 'Choose your governorate')
      : null;

  /// At least one way of taking a car in, or the workshop cannot be booked at
  /// all — an empty set is not a preference, it is a listing nobody can use.
  static String? fulfillments(Set<Fulfillment> value, S s) => value.isEmpty
      ? s.t(
          'اختر طريقة استقبال واحدة على الأقل',
          'Choose at least one way of taking cars in',
        )
      : null;

  /// The pickup/callout fee. Empty reads as zero; anything else has to be a
  /// non-negative number.
  static String? pickupFee(String value, S s) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final fee = double.tryParse(text);
    if (fee == null) return s.t('أدخل رقماً', 'Enter a number');
    if (fee < 0) {
      return s.t('لا يمكن أن تكون الرسوم بالسالب', 'A fee cannot be negative');
    }
    return null;
  }

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');
}

import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/utils/workshop_validation.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';

/// The rules "My details", the dashboard's workshop profile and the founder's
/// screen all check the same record against.
///
/// Asserted here as plain functions rather than only through the three
/// screens: the point of sharing the rules is that they cannot drift, and a
/// screen test proves one screen at a time.
void main() {
  const s = S(false);

  group('CR number', () {
    test('accepts 6 to 10 digits', () {
      expect(WorkshopRules.crNumber('1234567', s), isNull);
      expect(WorkshopRules.crNumber('123456', s), isNull);
      expect(WorkshopRules.crNumber('1234567890', s), isNull);
    });

    test('refuses anything else, with the reason', () {
      expect(WorkshopRules.crNumber('123', s), 'A CR number is 6–10 digits');
      expect(
        WorkshopRules.crNumber('12345678901', s),
        'A CR number is 6–10 digits',
      );
      expect(WorkshopRules.crNumber('CR-123456', s), isNotNull);
    });

    test('required at registration, optional on an existing record', () {
      expect(WorkshopRules.crNumber('', s), 'The CR number is required');
      expect(WorkshopRules.crNumber('', s, required: false), isNull);
    });
  });

  group('VAT number', () {
    // Oman registers VAT by turnover, so a small garage genuinely has none. A
    // required field here would only be answered with an invented number.
    test('stays optional', () {
      expect(WorkshopRules.vatNumber('', s), isNull);
      expect(WorkshopRules.vatNumber('   ', s), isNull);
    });

    test('accepts a VATIN with or without the OM prefix', () {
      expect(WorkshopRules.vatNumber('OM1100059183', s), isNull);
      expect(WorkshopRules.vatNumber('om1100059183', s), isNull);
      expect(WorkshopRules.vatNumber('1100059183', s), isNull);
    });

    test('refuses a shape no certificate carries', () {
      expect(WorkshopRules.vatNumber('not-a-vat', s), isNotNull);
      expect(WorkshopRules.vatNumber('OM12', s), isNotNull);
    });
  });

  group('Phone', () {
    test('a workshop line may be a landline', () {
      expect(
        WorkshopRules.omanPhone('+968 2400 0000', s, required: false),
        isNull,
      );
      expect(WorkshopRules.omanPhone('99887766', s, required: false), isNull);
    });

    test('an account number must be able to receive an SMS', () {
      expect(
        WorkshopRules.omanPhone(
          '24000000',
          s,
          required: true,
          mobileOnly: true,
        ),
        'An Oman mobile number starting with 7 or 9',
      );
    });

    test('length is checked before anything else', () {
      expect(
        WorkshopRules.omanPhone('123', s, required: false),
        'An 8-digit Oman number',
      );
    });

    test('empty is allowed only where the field is optional', () {
      expect(WorkshopRules.omanPhone('', s, required: false), isNull);
      expect(
        WorkshopRules.omanPhone('', s, required: true),
        'Phone number is required',
      );
    });

    test('WhatsApp refuses a landline — there is no WhatsApp on one', () {
      expect(WorkshopRules.whatsapp('24000000', s), isNotNull);
      expect(WorkshopRules.whatsapp('91650430', s), isNull);
      expect(WorkshopRules.whatsapp('', s), isNull);
    });
  });

  group('The rest of the record', () {
    test('a workshop must say how it takes cars in', () {
      expect(WorkshopRules.fulfillments(const {}, s), isNotNull);
      expect(
        WorkshopRules.fulfillments(const {Fulfillment.workshop}, s),
        isNull,
      );
    });

    test('area and region are required', () {
      expect(WorkshopRules.area('', s), isNotNull);
      expect(WorkshopRules.area('Seeb', s), isNull);
      expect(WorkshopRules.region(null, s), isNotNull);
      expect(WorkshopRules.region('Muscat', s), isNull);
    });

    test('the pickup fee is a non-negative number, or nothing at all', () {
      expect(WorkshopRules.pickupFee('', s), isNull);
      expect(WorkshopRules.pickupFee('3', s), isNull);
      expect(WorkshopRules.pickupFee('3.500', s), isNull);
      expect(WorkshopRules.pickupFee('free', s), 'Enter a number');
      expect(WorkshopRules.pickupFee('-1', s), 'A fee cannot be negative');
    });

    test('the legal name is required', () {
      expect(WorkshopRules.businessNameAr('  ', s), isNotNull);
      expect(WorkshopRules.businessNameAr('نزوى للعناية بالسيارات', s), isNull);
    });
  });

  group('Arabic', () {
    const ar = S(true);

    test('every message is localized, not an English string in a red box', () {
      expect(WorkshopRules.crNumber('123', ar), isNot(contains('digits')));
      expect(WorkshopRules.pickupFee('free', ar), 'أدخل رقماً');
      expect(
        WorkshopRules.fulfillments(const {}, ar),
        'اختر طريقة استقبال واحدة على الأقل',
      );
    });
  });
}

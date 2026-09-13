import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/home/home_widgets.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/core/widgets/promotion_card_face.dart';
import 'package:ak_cars_mobil_app/data/models/promotion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'helpers/test_harness.dart';

/// The home page's announcement card, after a founder published one whose
/// badge, title and body were all the same five words — which painted a card
/// that looked broken and empty rather than one saying a thing three times.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget face, {
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: PromotionCardFace.railHeight,
                child: face,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a body that only repeats the title is not printed twice', (
    tester,
  ) async {
    await pump(
      tester,
      const PromotionCardFace(
        icon: LucideIcons.wrench,
        title: 'Pre-purchase inspection',
        body: 'pre-purchase inspection ',
        badge: 'Pre-purchase inspection',
      ),
    );

    // Once for the title, and not again for the body or the badge.
    expect(find.textContaining('purchase inspection'), findsOneWidget);
  });

  testWidgets('a body that says something new is kept', (tester) async {
    await pump(
      tester,
      const PromotionCardFace(
        icon: LucideIcons.wrench,
        title: 'Pre-purchase inspection',
        body: 'A mechanic checks the car before you pay for it.',
      ),
    );

    expect(find.text('Pre-purchase inspection'), findsOneWidget);
    expect(
      find.text('A mechanic checks the car before you pay for it.'),
      findsOneWidget,
    );
  });

  testWidgets("the founder's background image is painted, text on top of it", (
    tester,
  ) async {
    await pump(
      tester,
      PromotionCardFace(
        icon: LucideIcons.wrench,
        title: 'Free pickup this week',
        body: 'We collect the car from your office.',
        image: testAttachment('promo-1'),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    // White title, which is only legible because of the scrim over the photo.
    final title = tester.widget<Text>(find.text('Free pickup this week'));
    expect(title.style?.color, Colors.white);
  });

  testWidgets('without an image the card keeps its sand gradient', (
    tester,
  ) async {
    await pump(
      tester,
      const PromotionCardFace(
        icon: LucideIcons.wrench,
        title: 'Free pickup this week',
        body: 'We collect the car from your office.',
      ),
    );

    expect(find.byType(Image), findsNothing);
    final title = tester.widget<Text>(find.text('Free pickup this week'));
    expect(title.style?.color, isNot(Colors.white));
  });

  testWidgets('the forward arrow follows the reading direction', (
    tester,
  ) async {
    const face = PromotionCardFace(
      icon: LucideIcons.wrench,
      title: 'عنوان',
      body: 'نص مختلف عن العنوان',
    );

    await pump(tester, face, direction: TextDirection.rtl);
    expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);

    await pump(tester, face);
    expect(find.byIcon(LucideIcons.arrowRight), findsOneWidget);
  });

  testWidgets('an image off the wire reaches the card', (tester) async {
    // The exact shape `GET /service-marketplace/promotions` returns, keys and
    // all — a card that renders from a hand-built `Promotion` but not from the
    // server's own JSON is the failure this pins down.
    final wire = {
      'id': '0b65c6c7-5107-43bf-a8fa-a4e67a47c811',
      'title': {'ar': 'خدمات فحص الشراء', 'en': 'Pre-purchase inspection'},
      'body': {'ar': 'فحص قبل الشراء', 'en': 'Checked before you pay'},
      'icon': 'wrench',
      'badge': null,
      'providerId': null,
      'offeringId': null,
      'query': null,
      'regions': <String>[],
      'endsAt': null,
      'image': {
        'id': '2196c359-597c-40fd-a39f-a6a3526054b7',
        'base64Data': testPngBase64,
        'mimeType': 'image/jpeg',
        'fileName': 'promotion.jpg',
        'caption': '',
      },
    };

    final promotion = Promotion.fromJson(wire);
    expect(promotion.image, isNotNull);

    await pump(
      tester,
      PromotionCardFace(
        icon: promotion.icon,
        title: promotion.title.en,
        body: promotion.body.en,
        image: promotion.image,
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });

  test('a promotion carries its image through JSON', () {
    final promotion = Promotion(
      id: 'promo-1',
      title: const L('عنوان', 'Title'),
      body: const L('نص', 'Body'),
      icon: LucideIcons.wrench,
      image: testAttachment('promo-image-1'),
    );

    final decoded = Promotion.fromJson(promotion.toJson());
    expect(decoded, promotion);
    expect(decoded.image?.id, 'promo-image-1');
    expect(decoded.image?.base64Data, testPngBase64);

    // Clearing it is expressible — an edit that removes the picture has to be
    // able to say so, not merely fail to mention it.
    final cleared = promotion.copyWith(clearImage: true);
    expect(cleared.image, isNull);
    expect(Promotion.fromJson(cleared.toJson()).image, isNull);
  });

  // ------------------------------------------------- where a tap actually goes

  /// A card is tapped because of what it said. Landing on the unfiltered
  /// Services tab makes the customer search again for the thing they just
  /// tapped, so the tab is the last resort and not the default.
  group('promotionTarget', () {
    const s = S(false);

    test('a card naming a service opens that service', () async {
      final container = await createTestContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final offering = marketplace.offerings.first;

      final target = promotionTarget(
        Promotion(
          id: 'p',
          title: const L('a', 'a'),
          body: const L('b', 'b'),
          icon: LucideIcons.wrench,
          offeringId: offering.id,
        ),
        marketplace,
        s,
      );

      expect(target.route, '/service/${offering.id}');
      expect(target.push, isTrue);
    });

    test("a workshop-only card opens that workshop's services", () async {
      final container = await createTestContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final provider = marketplace.visibleProviders.first;

      final target = promotionTarget(
        Promotion(
          id: 'p',
          title: const L('a', 'a'),
          body: const L('b', 'b'),
          icon: LucideIcons.wrench,
          providerId: provider.id,
        ),
        marketplace,
        s,
      );

      expect(
        target.route,
        '/services?q=${Uri.encodeQueryComponent(provider.name.en)}',
      );
      expect(target.push, isFalse);
    });

    test('a search wins over the workshop that narrowed it', () async {
      final container = await createTestContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      final target = promotionTarget(
        Promotion(
          id: 'p',
          title: const L('a', 'a'),
          body: const L('b', 'b'),
          icon: LucideIcons.wrench,
          providerId: marketplace.visibleProviders.first.id,
          query: 'تكييف',
        ),
        marketplace,
        s,
      );

      expect(target.route, '/services?q=${Uri.encodeQueryComponent('تكييف')}');
    });

    test('only a card with no destination at all opens the whole tab', () async {
      final container = await createTestContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      final target = promotionTarget(
        Promotion(
          id: 'p',
          title: const L('a', 'a'),
          body: const L('b', 'b'),
          icon: LucideIcons.wrench,
        ),
        marketplace,
        s,
      );

      expect(target.route, '/services');
    });

    test('a service that has left the catalogue does not open a dead page',
        () async {
      final container = await createTestContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      final target = promotionTarget(
        Promotion(
          id: 'p',
          title: const L('a', 'a'),
          body: const L('b', 'b'),
          icon: LucideIcons.wrench,
          offeringId: 'deleted-offering',
          query: 'تكييف',
        ),
        marketplace,
        s,
      );

      expect(target.route, '/services?q=${Uri.encodeQueryComponent('تكييف')}');
    });
  });
}

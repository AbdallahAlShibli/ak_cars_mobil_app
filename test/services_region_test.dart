import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/services/service_widgets.dart';
import 'package:ak_cars_mobil_app/features/services/services_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

import 'helpers/test_harness.dart';

/// The region chip used to only *sort* results, so workshops from other
/// governorates were listed under "Popular near you" whenever the selected
/// region had fewer than six offerings. Now the chip filters, and the only
/// way past it is the explicit "Look beyond {region}" button.
Future<ProviderContainer> pumpServices(
  WidgetTester tester,
  String region,
) async {
  final container = await createTestContainer(
    overrides: [regionProvider.overrideWith((ref) => region)],
  );
  // Tall surface so the whole list mounts — the assertions compare the
  // on-screen position of cards against the section header.
  tester.view.physicalSize = const Size(402 * 3, 2600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ServicesScreen(),
      ),
    ),
  );
  await settleEntrances(tester);
  return container;
}

/// The screen's skeleton and the staggered `Entrance()` animations both use
/// `Future.delayed`, which schedules no frame — so `pumpAndSettle` returns
/// while they are still pending. Pump real time past all of them instead.
Future<void> settleEntrances(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Every provider the marketplace knows that is not in [region].
Set<String> outsidersOf(ProviderContainer container, String region) =>
    container
        .read(serviceMarketplaceRepositoryProvider)
        .providers
        .where((p) => p.region != region)
        .map((p) => p.name.en)
        .toSet();

void main() {
  testWidgets('List holds only workshops in the selected governorate',
      (tester) async {
    final container = await pumpServices(tester, 'Dhofar');

    expect(find.text('Popular in Dhofar'), findsOneWidget);
    for (final name in outsidersOf(container, 'Dhofar')) {
      expect(find.textContaining(name), findsNothing,
          reason: '$name is not in Dhofar and was never asked for');
    }
  });

  testWidgets('Looking beyond the region is opt-in, and reversible',
      (tester) async {
    final container = await pumpServices(tester, 'Dhofar');
    final outsiders = outsidersOf(container, 'Dhofar');

    final widen = find.textContaining('Look beyond Dhofar');
    expect(widen, findsOneWidget);

    await tester.tap(widen);
    await settleEntrances(tester);
    expect(
      outsiders.where((n) => find.textContaining(n).evaluate().isNotEmpty),
      isNotEmpty,
      reason: 'widening should bring in workshops from other governorates',
    );
    expect(find.text('Popular in & around Dhofar'), findsOneWidget);

    await tester.tap(find.text('Show only Dhofar'));
    await settleEntrances(tester);
    for (final name in outsiders) {
      expect(find.textContaining(name), findsNothing);
    }
  });

  testWidgets('A governorate with no workshops explains itself',
      (tester) async {
    await pumpServices(tester, 'Musandam');

    expect(
      find.textContaining('No workshops in Musandam yet'),
      findsOneWidget,
      reason: 'the wider list must say why it is wider',
    );
    // Nothing to narrow back down to, so no toggle is offered.
    expect(find.textContaining('Look beyond'), findsNothing);
  });

  testWidgets('Chip and region picker count the same thing', (tester) async {
    // Muscat has 3 workshops but 14 offers between them. The chip used to
    // show the offer count under a "workshops" label, so it read "14" while
    // the picker right below it read "3".
    final container = await pumpServices(tester, 'Muscat');
    final marketplace = container.read(serviceMarketplaceRepositoryProvider);
    final workshops =
        marketplace.providers.where((p) => p.region == 'Muscat').length;
    expect(workshops, 3);

    expect(find.textContaining('Muscat · 3 workshops'), findsOneWidget);
    expect(find.textContaining('14 workshops'), findsNothing,
        reason: '14 is the offer count, not the workshop count');

    await tester.tap(find.textContaining('Muscat · 3 workshops'));
    await tester.pumpAndSettle();
    expect(find.text('Where do you need service?'), findsOneWidget);
    expect(find.text('3 workshops'), findsWidgets);
  });

  testWidgets('Package cards count and price the selected region only',
      (tester) async {
    final container = await pumpServices(tester, 'Muscat');
    final marketplace = container.read(serviceMarketplaceRepositoryProvider);

    // "Full Service": sold in every governorate, but the card above a Muscat
    // list must quote the cheapest *Muscat* price, not the national one.
    expect(marketplace.providerCountFor('full', region: 'Muscat'), 2);
    // Liwa, at 27. Sohar publishes 26 and is cheaper, but it is an unapproved
    // application — so it is not bookable, and a "from" price has to quote
    // something the tap can actually reach.
    expect(marketplace.fromPriceFor('full'), 27);
    expect(marketplace.fromPriceFor('full', region: 'Muscat'), 30);
    expect(find.textContaining('from OMR 30 · 2 workshops'), findsOneWidget);

    // Tyres used to exist only in Sohar and Salalah, so a Muscat user tapping
    // the tile got a sheet of out-of-region workshops. It is now sold locally.
    expect(marketplace.providerCountFor('tyres', region: 'Muscat'), 2);
    // Qurum publishes 6 and is running a validated offer at 4.5, so "from" is
    // 4.5: the card must quote the price the tap actually leads to, not the
    // pre-discount one. The struck-through 6 is on the offer record.
    expect(marketplace.fromPriceFor('tyres', region: 'Muscat'), 4.5);
    expect(marketplace.offeringById('o-p4-tyres')!.price, 6);
    expect(marketplace.offerFor('o-p4-tyres')!.referencePrice, 6);
  });

  test('Arabic counted nouns inflect by the number in front of them', () {
    const ar = S(true);
    expect(ar.workshops(0), 'لا توجد ورش');
    expect(ar.workshops(1), 'ورشة واحدة');
    expect(ar.workshops(2), 'ورشتان');
    expect(ar.workshops(3), '3 ورش');
    expect(ar.workshops(10), '10 ورش');
    expect(ar.workshops(14), '14 ورشة');

    const en = S(false);
    expect(en.workshops(0), 'No workshops');
    expect(en.workshops(1), '1 workshop');
    expect(en.workshops(3), '3 workshops');
  });

  test('splitByRegion filters strictly and orders each group', () async {
    final container = await createDataContainer();
    final marketplace = container.read(serviceMarketplaceRepositoryProvider);
    final split = splitByRegion(marketplace.offerings, 'Muscat');

    expect(split.local, isNotEmpty);
    expect(split.local.every((o) => o.provider.region == 'Muscat'), isTrue);
    expect(split.nearby.any((o) => o.provider.region == 'Muscat'), isFalse);

    // In-region: cheapest first. Beyond it: closest first.
    final prices = [for (final o in split.local) o.price ?? 999];
    expect(prices, orderedEquals([...prices]..sort()));
    final distances = [for (final o in split.nearby) o.provider.distanceKm];
    expect(distances, orderedEquals([...distances]..sort()));
  });

  test('Every served governorate covers every category', () async {
    final container = await createDataContainer();
    final marketplace = container.read(serviceMarketplaceRepositoryProvider);

    // The filter only widens on its own when the selected governorate has
    // nothing to show. A category with no local workshop is therefore a
    // filter that silently ignores itself — the user picks Muscat, taps
    // "Tyres", and gets Sohar. Demo data must not create that hole.
    for (final region in marketplace.providerRegions) {
      expect(
        marketplace.providers.where((p) => p.region == region).length,
        greaterThanOrEqualTo(2),
        reason: '$region needs enough workshops to compare',
      );
      for (final category in marketplace.categories) {
        expect(
          marketplace.providerCountFor(category.id, region: region),
          greaterThan(0),
          reason: 'no workshop sells ${category.id} in $region, so the '
              'region filter would widen without being asked',
        );
      }
    }
  });

  test('Selectable service regions are the ones workshops actually serve',
      () async {
    final container = await createDataContainer();
    // Settings, the shop filter and the default region all read the catalogue
    // list; the services page reads the providers. A governorate in only one
    // of them is either unreachable or a guaranteed empty state.
    expect(
      container.read(catalogRepositoryProvider).serviceRegions.toSet(),
      container.read(serviceMarketplaceRepositoryProvider).providerRegions
          .toSet(),
    );
  });
}

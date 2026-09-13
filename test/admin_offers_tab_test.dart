import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/data/models/offer.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/operations/admin_offers_tab.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/data/mock_service_data.dart';
import 'fakes/fakes.dart';
import 'helpers/test_harness.dart';

/// A marketplace service that behaves like the deployed API rather than like
/// the fixture.
///
/// The real `GET /service-marketplace/offers` returns only offers that are
/// already founder-approved and inside their window — that is what makes it
/// the *public* feed. The plain mock returns every fixture row from it, which
/// hid a real bug: a founder screen reading the warm cache filled by that feed
/// can never show an offer that is not live yet, which is every offer at the
/// moment it is created.
class _PublicFeedMarketplaceService extends MockServiceMarketplaceService {
  _PublicFeedMarketplaceService() : super(seeded: false);

  @override
  Future<List<Offer>> fetchOffers() async {
    final all = await super.fetchOffers();
    final now = DateTime.now();
    return [
      for (final offer in all)
        if (offer.activeByFounder && offer.isWithin(now)) offer,
    ];
  }
}

Future<ProviderContainer> _container() => createTestContainer(
  overrides: [
    appConfigProvider.overrideWithValue(
      AppConfig.forEnvironment(AppEnvironment.development),
    ),
    serviceMarketplaceServiceProvider.overrideWith(
      (ref) => _PublicFeedMarketplaceService(),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  String locale = 'en',
}) async {
  tester.view.physicalSize = const Size(402 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: Locale(locale),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: AdminOffersTab()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  // `MockServiceData.offers` is a static, mutable fixture and the tab writes to
  // it for real (enable, delete). Snapshotting it keeps a test that stops an
  // offer from changing what the next test sees.
  late List<Offer> savedOffers;

  setUp(() => savedOffers = [...MockServiceData.offers]);
  tearDown(() {
    MockServiceData.offers
      ..clear()
      ..addAll(savedOffers);
  });

  testWidgets('lists every offer the platform holds, not just the live ones', (
    tester,
  ) async {
    final container = await _container();
    // Stop one of the valid offers so it is absent from the public feed the
    // warm cache is filled from — the exact case the old screen could not
    // render.
    final stopped = MockServiceData.offers.first;
    await container
        .read(serviceMarketplaceRepositoryProvider)
        .setOfferActive(stopped.id, active: false);

    await _pump(tester, container);
    await tester.pump(const Duration(milliseconds: 500));

    // Every fixture row is on screen, live or not.
    expect(find.text('All · ${MockServiceData.offers.length}'), findsOneWidget);
    // And the stopped one says which rule is keeping it off the home page.
    expect(find.textContaining('Not enabled by the founder'), findsWidgets);
  });

  testWidgets('offers the founder create, edit, enable and delete', (
    tester,
  ) async {
    final container = await _container();
    await _pump(tester, container);
    await tester.pump(const Duration(milliseconds: 500));

    // Create.
    expect(find.text('New offer'), findsOneWidget);
    // Enable/stop, edit and delete, on every row.
    expect(find.byType(Switch), findsWidgets);
    expect(find.byTooltip('Edit'), findsWidgets);
    expect(find.byTooltip('Delete'), findsWidgets);

    // The editor opens and is the create form, not a placeholder.
    await tester.tap(find.text('New offer'));
    await tester.pumpAndSettle();
    expect(find.text('Publish offer'), findsOneWidget);
    expect(find.text('Workshop'), findsOneWidget);
    expect(find.text('Discounted price'), findsOneWidget);
  });

  testWidgets('deleting an offer removes it from the list', (tester) async {
    final container = await _container();
    await _pump(tester, container);
    await tester.pump(const Duration(milliseconds: 500));

    final before = MockServiceData.offers.length;
    expect(find.text('All · $before'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    expect(find.text('Delete this offer?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(MockServiceData.offers, hasLength(before - 1));
    expect(find.text('All · ${before - 1}'), findsOneWidget);
  });

  testWidgets('stopping an offer flips its row without a refetch', (
    tester,
  ) async {
    final container = await _container();
    await _pump(tester, container);
    await tester.pump(const Duration(milliseconds: 500));

    int enabled() => container
        .read(adminOfferAuditProvider)
        .requireValue
        .where((row) => row.offer.activeByFounder)
        .length;

    final before = enabled();
    expect(before, greaterThan(0));

    // Deliberately not asserting on the *live* count: the list is ordered
    // decision-first, so the top card is usually one blocked by a rule the
    // switch cannot clear, and stopping it changes nothing about what is
    // showing. What the switch must do is write through to this list.
    final onSwitch = find.byWidgetPredicate(
      (w) => w is Switch && w.value == true,
    );
    expect(onSwitch, findsWidgets);
    await tester.tap(onSwitch.first);
    await tester.pumpAndSettle();

    expect(enabled(), before - 1);
  });
}

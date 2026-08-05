import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/core/utils/provider_contact.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_ids.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/services/booking_screen.dart';
import 'package:ak_cars_mobil_app/features/services/service_detail_screen.dart';
import 'package:ak_cars_mobil_app/features/services/tracking_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

/// Platform leakage: a workshop's phone number shown before the booking is
/// protected lets both sides agree the job off-platform, where there is no
/// escrow, no proof of work and no service record — and where the commission
/// the pilot runs on does not exist either.
///
/// The rule these tests pin: **direct contact appears only from `fundsHeld`
/// onwards**, and the state that *is* deliberately open, `disputed`, stays
/// open — a customer with a problem needs the workshop more than anyone.

const _car = Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2019);

Future<ProviderContainer> _container() => createTestContainer(
      overrides: [
        // Otherwise the demo lifecycle advances the booking underneath the
        // test and the state under assertion is gone by the first pump.
        appConfigProvider.overrideWithValue(
          AppConfig.forEnvironment(AppEnvironment.development)
              .copyWith(simulateProviderLifecycle: false),
        ),
      ],
    );

Future<ServiceRequest> _book(ProviderContainer container) =>
    container.read(requestsProvider.notifier).place(
          CreateServiceRequestDraft(
            offering: MockServiceData.offerings.first,
            car: _car,
            plate: '1234 AB',
            fulfillment: Fulfillment.workshop,
            slot: 'Mon 3 Aug · 10:30',
            addOnIds: const {},
          ),
        );

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen, {
  String locale = 'en',
  double height = 874,
}) async {
  tester.view.physicalSize = Size(402 * 3, height * 3);
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
        home: screen,
      ),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('canContactProviderDirectly', () {
    test('nothing before the money is held', () {
      expect(canContactProviderDirectly(null), isFalse);
      for (final state in [
        EscrowState.requested,
        EscrowState.quoted,
        EscrowState.quoteAccepted,
        EscrowState.createdPendingPayment,
      ]) {
        expect(canContactProviderDirectly(state), isFalse, reason: state.name);
      }
    });

    test('open from fundsHeld through release', () {
      for (final state in [
        EscrowState.fundsHeld,
        EscrowState.acceptedByWorkshop,
        EscrowState.inProgress,
        EscrowState.proofSubmitted,
        EscrowState.awaitingApproval,
        EscrowState.releasedToWorkshop,
      ]) {
        expect(canContactProviderDirectly(state), isTrue, reason: state.name);
      }
    });

    test('a dispute keeps contact open, deliberately', () {
      expect(canContactProviderDirectly(EscrowState.disputed), isTrue);
    });

    test('a booking that ended without work closes again', () {
      expect(canContactProviderDirectly(EscrowState.cancelled), isFalse);
      expect(canContactProviderDirectly(EscrowState.refunded), isFalse);
    });
  });

  testWidgets('service page hides the workshop number before any booking',
      (tester) async {
    final container = await _container();
    await _pump(
      tester,
      container,
      ServiceDetailScreen(
          offeringId: mockOfferingId(mockIdP1, mockIdExpress)),
      height: 3200,
    );

    // The workshop's own record is still there — only the contact channel
    // moved.
    expect(find.text('Workshop details'), findsOneWidget);
    expect(find.text('OM1100047382'), findsOneWidget);

    // …and none of it is a way to ring them.
    expect(find.text('Call'), findsNothing);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Phone'), findsNothing);
    expect(find.textContaining('+968'), findsNothing);

    // What stands in its place explains why and opens the thread.
    expect(
        find.textContaining('Direct contact opens'), findsOneWidget);
    expect(find.text('Message the workshop'), findsOneWidget);

    container.dispose();
  });

  testWidgets('tracking offers the thread until the funds are held',
      (tester) async {
    final container = await _container();
    final request = await _book(container);

    await _pump(tester, container, TrackingScreen(requestId: request.id));
    expect(find.text('Call'), findsNothing);
    expect(find.textContaining('Direct contact opens'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);

    // The founder confirms the transfer landed — the money is now held, and
    // the two parties are in a protected transaction.
    await container.read(requestsProvider.notifier).fire(
          request.id,
          EscrowEvent.confirmFundsHeld,
          actor: EscrowActor.founder,
        );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Call'), findsOneWidget);
    expect(find.textContaining('Direct contact opens'), findsNothing);

    container.dispose();
  });

  testWidgets('the booking screen says what booking in the app is worth',
      (tester) async {
    final container = await _container();
    await _pump(
      tester,
      container,
      BookingScreen(offeringId: mockOfferingId(mockIdP1, mockIdExpress)),
      height: 1800,
    );

    expect(find.text('Why book through the app?'), findsOneWidget);
    expect(find.textContaining('held until you are happy'), findsOneWidget);
    expect(find.textContaining('Photo proof'), findsOneWidget);

    container.dispose();
  });

  testWidgets('the value card is worded positively, in both languages',
      (tester) async {
    final container = await _container();
    await _pump(
      tester,
      container,
      BookingScreen(offeringId: mockOfferingId(mockIdP1, mockIdExpress)),
      locale: 'ar',
      height: 1800,
    );

    expect(find.text('لماذا تحجز عبر التطبيق؟'), findsOneWidget);
    // Never the warning-shaped version of the same idea.
    expect(find.textContaining('خارج المنصة'), findsNothing);

    container.dispose();
  });
}

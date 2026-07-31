import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/operations/admin_screen.dart';
import 'package:ak_cars_mobil_app/features/operations/workshop_screen.dart';
import 'package:ak_cars_mobil_app/features/services/approval_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

const _car = Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2019);

Future<ProviderContainer> _container() => createTestContainer(
  overrides: [
    appConfigProvider.overrideWithValue(
      AppConfig.forEnvironment(
        AppEnvironment.development,
      ).copyWith(simulateProviderLifecycle: false),
    ),
  ],
);

Future<ServiceRequest> _book(ProviderContainer container) => container
    .read(requestsProvider.notifier)
    .place(
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
}) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
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
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('the founder panel offers only the founder’s transitions', (
    tester,
  ) async {
    final container = await _container();
    await _book(container);
    await _pump(tester, container, const AdminScreen());

    // A new booking is waiting on the founder to confirm the transfer landed.
    expect(find.text('Confirm funds received'), findsOneWidget);
    // The workshop's buttons belong on the workshop's panel.
    expect(find.text('Accept job'), findsNothing);
    expect(find.textContaining('Held in escrow'), findsOneWidget);
    // Nothing is held until it is confirmed.
    expect(find.text('OMR 0.00'), findsOneWidget);
  });

  testWidgets('the workshop panel picks up a job once the funds are held', (
    tester,
  ) async {
    final container = await _container();
    final request = await _book(container);
    await container
        .read(requestsProvider.notifier)
        .fire(
          request.id,
          EscrowEvent.confirmFundsHeld,
          actor: EscrowActor.founder,
        );

    await _pump(tester, container, const WorkshopScreen());

    expect(find.text('Accept job'), findsOneWidget);
    expect(find.text('Reject job'), findsOneWidget);
    expect(find.text('Start work'), findsNothing);
  });

  testWidgets('the approval screen shows the real proof, never a placeholder', (
    tester,
  ) async {
    final container = await _container();
    final request = await _book(container);
    final notifier = container.read(requestsProvider.notifier);

    for (final (event, actor) in const [
      (EscrowEvent.confirmFundsHeld, EscrowActor.founder),
      (EscrowEvent.acceptJob, EscrowActor.workshop),
      (EscrowEvent.startWork, EscrowActor.workshop),
    ]) {
      await notifier.fire(
        request.id,
        event,
        actor: actor,
        proof: event == EscrowEvent.submitProof ? testProof(request.id) : null,
      );
    }
    await notifier.fire(
      request.id,
      EscrowEvent.submitProof,
      actor: EscrowActor.workshop,
      proof: testProof(
        request.id,
        notes: 'New oil and genuine filter fitted.',
      ),
    );

    await _pump(tester, container, ApprovalScreen(requestId: request.id));

    expect(find.text('New oil and genuine filter fitted.'), findsOneWidget);
    // The photos are the proof (spec §3) — a notes-only submission can no
    // longer reach this screen, so the gallery is always drawn.
    expect(find.byType(Image), findsWidgets);
    expect(find.textContaining('written notes only'), findsNothing);
    expect(find.text('Approve & release payment'), findsOneWidget);
    expect(find.textContaining('Auto-releases in 3 day'), findsOneWidget);

    // The approval window arms a real 72-hour timer (and its 24-hour warning).
    // The widget tester fails a test that ends with timers still pending, so
    // the container is torn down here rather than in the teardown queue.
    container.dispose();
  });

  testWidgets('a disputed booking still counts toward the escrow total', (
    tester,
  ) async {
    final container = await _container();
    final request = await _book(container);
    final notifier = container.read(requestsProvider.notifier);

    for (final (event, actor) in const [
      (EscrowEvent.confirmFundsHeld, EscrowActor.founder),
      (EscrowEvent.acceptJob, EscrowActor.workshop),
      (EscrowEvent.startWork, EscrowActor.workshop),
      (EscrowEvent.submitProof, EscrowActor.workshop),
    ]) {
      await notifier.fire(
        request.id,
        event,
        actor: actor,
        proof: event == EscrowEvent.submitProof ? testProof(request.id) : null,
      );
    }
    await notifier.fire(
      request.id,
      EscrowEvent.raiseIssue,
      actor: EscrowActor.customer,
      disputeNote: 'The noise is still there',
    );
    final disputed = container.read(requestsProvider).single;
    expect(disputed.escrow, EscrowState.disputed);

    await _pump(tester, container, const AdminScreen());

    // A dispute moves the booking out of "in flight" and into its own
    // section, but not out of escrow — the customer was told the funds stay
    // held, so the founder's total has to say the same.
    expect(find.text('OMR ${disputed.total.toStringAsFixed(2)}'), findsWidgets);
    expect(find.text('OMR 0.00'), findsNothing);

    container.dispose();
  });
}

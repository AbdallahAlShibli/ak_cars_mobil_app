import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/data/mock_service_data.dart';
import 'helpers/test_harness.dart';

/// Regression for "BusinessRuleException: 'System' may not fire
/// 'cancelBooking' from 'Cancelled'" — a cancel sent for a booking the server
/// had already cancelled escaped as an unhandled exception.
void main() {
  const car = Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2019);

  Future<(ProviderContainer, ServiceRequest)> placed() async {
    final container = await createDataContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.forEnvironment(AppEnvironment.development),
        ),
      ],
    );
    final request = await container.read(requestsProvider.notifier).place(
          CreateServiceRequestDraft(
            offering: MockServiceData.offerings.first,
            car: car,
            plate: '1234 AB',
            fulfillment: Fulfillment.workshop,
            slot: 'Mon 3 Aug · 10:30',
            addOnIds: const {},
          ),
        );
    return (container, request);
  }

  EscrowState stateOf(ProviderContainer container, String id) =>
      container.read(requestsProvider).firstWhere((r) => r.id == id).escrow;

  test('a cancel the server already applied is absorbed and the list catches up',
      () async {
    final (container, request) = await placed();
    // The server moves on without this list seeing it — another screen,
    // another device, a tap the list had not caught up with.
    await container.read(serviceMarketplaceServiceProvider).applyEscrowEvent(
          request.id,
          EscrowEvent.cancelBooking,
          actor: EscrowActor.customer,
        );
    expect(stateOf(container, request.id), EscrowState.createdPendingPayment);

    final result = await container
        .read(requestsProvider.notifier)
        .fire(request.id, EscrowEvent.cancelBooking, actor: EscrowActor.customer);

    expect(result, isNull);
    expect(stateOf(container, request.id), EscrowState.cancelled);
  });

  test('a second cancel while the first is still on the wire is not sent',
      () async {
    final (container, request) = await placed();
    final notifier = container.read(requestsProvider.notifier);

    final first = notifier.fire(request.id, EscrowEvent.cancelBooking,
        actor: EscrowActor.customer);
    final second = notifier.fire(request.id, EscrowEvent.cancelBooking,
        actor: EscrowActor.customer);

    expect(await second, isNull);
    expect((await first)?.escrow, EscrowState.cancelled);
    expect(stateOf(container, request.id), EscrowState.cancelled);
  });

  test('the operator queue absorbs the same stale refusal for its own bookings',
      () async {
    final (container, request) = await placed();
    await container.read(serviceMarketplaceServiceProvider).applyEscrowEvent(
          request.id,
          EscrowEvent.cancelBooking,
          actor: EscrowActor.customer,
        );

    final result = await container
        .read(operatorQueueProvider.notifier)
        .fire(request.id, EscrowEvent.cancelBooking, actor: EscrowActor.customer);

    expect(result, isNull);
    expect(stateOf(container, request.id), EscrowState.cancelled);
  });
}

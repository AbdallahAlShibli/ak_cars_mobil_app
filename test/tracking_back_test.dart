import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/router/app_router.dart';
import 'package:ak_cars_mobil_app/core/widgets/sand_widgets.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_harness.dart';

/// The booking details page (`/track/:id`) must always offer a way out.
///
/// It is reached two ways and only one leaves a stack behind: the bookings
/// list `push`es it, but completing a booking `go`es to it so that "back"
/// cannot return to a submitted form. `go` replaces the stack, and the route
/// sits outside the tab shell — so without an explicit exit the second path
/// left the user on a page with no back button and no bottom navigation.

const _car = Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2019);

Future<ProviderContainer> _container() => createTestContainer(
      overrides: [
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

Future<void> _pumpApp(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: container.read(routerProvider),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the details page has a back button even when it was not pushed',
      (tester) async {
    final container = await _container();
    final request = await _book(container);
    await _pumpApp(tester, container);

    final router = container.read(routerProvider);
    // Exactly what booking_screen/quote_screen/part_request_screen do on
    // submit: replace the stack rather than stacking on the finished form.
    router.go('/track/${request.id}');
    await tester.pumpAndSettle();

    expect(find.textContaining('Request #'), findsOneWidget);
    // The regression: nothing to pop, and no bottom navigation on this route.
    expect(router.canPop(), isFalse);
    expect(find.byType(SandBackButton), findsOneWidget);

    await tester.tap(find.byType(SandBackButton));
    await tester.pumpAndSettle();

    // Lands on the bookings tab — where the booking now lives — rather than
    // doing nothing and leaving the user stuck.
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/bookings',
    );

    container.dispose();
  });

  testWidgets('and still pops normally when it was pushed', (tester) async {
    final container = await _container();
    final request = await _book(container);
    await _pumpApp(tester, container);

    final router = container.read(routerProvider);
    router.go('/bookings');
    await tester.pumpAndSettle();
    router.push('/track/${request.id}');
    await tester.pumpAndSettle();

    expect(router.canPop(), isTrue);
    await tester.tap(find.byType(SandBackButton));
    await tester.pumpAndSettle();

    // Back to the list it was opened from, not a hard jump to the tab root.
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/bookings',
    );

    container.dispose();
  });
}

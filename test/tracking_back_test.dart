import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/core/widgets/sand_widgets.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/services/tracking_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_harness.dart';

/// The booking details page (`/track/:id`) must always offer a way out.
///
/// It is reached two ways and only one of them leaves a stack behind: the
/// bookings list `push`es it, but finishing a booking, sending a part request,
/// accepting a quote and approving a job all `go` to it — so that "back"
/// cannot return the user to a form they have already submitted. `go` replaces
/// the stack, and the route sits outside the tab shell, so before this fix the
/// second path left the customer on a page with no back button, no bottom
/// navigation, and no way out.
///
/// Pumped against a two-route router rather than the real one: the app's own
/// router opens on an animated splash that `pumpAndSettle` can never settle,
/// and the behaviour under test belongs to the screen, not to the route table.

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

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/bookings',
      builder: (_, _) =>
          const Scaffold(body: Center(child: Text('bookings list'))),
    ),
    GoRoute(
      path: '/track/:id',
      builder: (_, state) =>
          TrackingScreen(requestId: state.pathParameters['id']!),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  GoRouter router,
) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('the details page has a back button even when it was not pushed', (
    tester,
  ) async {
    final container = await _container();
    final request = await _book(container);

    // Landing straight on the details page, exactly as a completed booking
    // does: nothing underneath it to go back to.
    final router = _router('/track/${request.id}');
    await _pump(tester, container, router);

    expect(find.textContaining('Request #'), findsOneWidget);
    expect(router.canPop(), isFalse);
    // The regression: no leading widget was drawn here at all.
    expect(find.byType(SandBackButton), findsOneWidget);

    await tester.tap(find.byType(SandBackButton));
    await tester.pump(const Duration(milliseconds: 500));

    // Falls back to the bookings tab — where this booking now lives — rather
    // than doing nothing and leaving the customer stuck.
    expect(_path(router), '/bookings');

    container.dispose();
  });

  testWidgets('and still pops back to where it was opened from', (
    tester,
  ) async {
    final container = await _container();
    final request = await _book(container);

    final router = _router('/bookings');
    await _pump(tester, container, router);
    router.push('/track/${request.id}');
    // Two pumps: one to process the push, one to run the transition out.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Request #'), findsOneWidget);
    expect(router.canPop(), isTrue);

    await tester.tap(find.byType(SandBackButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Popped back onto the list it was opened from. Asserted on what is
    // rendered rather than on `currentConfiguration`, which still reports the
    // base location while an imperatively pushed route is on top.
    expect(find.text('bookings list'), findsOneWidget);
    expect(find.textContaining('Request #'), findsNothing);

    container.dispose();
  });
}

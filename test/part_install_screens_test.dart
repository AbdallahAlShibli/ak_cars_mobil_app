import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'fakes/data/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/services/part_request_screen.dart';
import 'package:ak_cars_mobil_app/features/services/quote_screen.dart';
import 'package:ak_cars_mobil_app/features/services/review_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

import 'helpers/test_harness.dart';

/// The three screens the part-and-fit transaction and verified reviews added,
/// rendered in both languages. What is asserted is not layout but *claims*:
/// that the quote shows two prices and not one, and that a review screen
/// cannot be used on a booking that has not paid out.
const _car = Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2019);

Future<ProviderContainer> _container() => createTestContainer(overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.forEnvironment(AppEnvironment.development)
            ,
      ),
    ]);

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen, {
  String locale = 'ar',
  double height = 1600,
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
  await tester.pump(const Duration(milliseconds: 500));
}

CreatePartRequestDraft _draft() => CreatePartRequestDraft(
      providerId: MockServiceData.providers.first.id,
      carId: _car.id,
      plate: '1234 AB',
      fulfillment: Fulfillment.workshop.key,
      part: const PartRequest(description: 'Front brake pads set'),
    );

Future<ServiceRequest> _quoted(ProviderContainer container) async {
  final notifier = container.read(requestsProvider.notifier);
  final request = await notifier.placePartRequest(_draft(), car: _car);
  await notifier.submitQuote(
    request.id,
    Quote(
      id: 'q1',
      requestId: request.id,
      workshopId: MockServiceData.providers.first.id,
      partDescription: 'OEM front pad set',
      partPrice: 24,
      laborPrice: 8,
      warrantyDays: 90,
      createdAt: DateTime.now(),
    ),
  );
  return container.read(requestsProvider).firstWhere((r) => r.id == request.id);
}

void main() {
  testWidgets('the part request screen asks for a description, not a product',
      (tester) async {
    final container = await _container();
    await _pump(tester, container, const PartRequestScreen());

    expect(find.text('ما الذي تحتاجه؟'), findsOneWidget);
    expect(find.text('أي ورشة تسعّرها؟'), findsOneWidget);
    expect(find.text('أرسل الطلب للتسعير'), findsOneWidget);
  });

  testWidgets('and in English', (tester) async {
    final container = await _container();
    await _pump(tester, container, const PartRequestScreen(), locale: 'en');

    expect(find.text('What do you need?'), findsOneWidget);
    expect(find.text('Send for a quote'), findsOneWidget);
  });

  testWidgets('the quote screen itemises the part and the fitting separately',
      (tester) async {
    final container = await _container();
    final request = await _quoted(container);
    await _pump(tester, container, QuoteScreen(requestId: request.id),
        locale: 'en');

    expect(find.text('Part'), findsOneWidget);
    expect(find.text('Fitting'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.textContaining('24.00', findRichText: true), findsOneWidget);
    expect(find.textContaining('8.00', findRichText: true), findsOneWidget);
    // The total is printed twice — once on the quote card, once on the
    // action bar that pays it.
    expect(find.textContaining('32.00', findRichText: true), findsWidgets);
    expect(find.text('Accept the quote'), findsOneWidget);
  });

  testWidgets("the part's warranty is not sold as the payment escrow",
      (tester) async {
    final container = await _container();
    final request = await _quoted(container);
    await _pump(tester, container, QuoteScreen(requestId: request.id),
        locale: 'en');

    expect(
      find.textContaining('separate from the payment escrow'),
      findsOneWidget,
    );
  });

  testWidgets('a review screen on an unreleased booking offers no stars',
      (tester) async {
    final container = await _container();
    final request = await _quoted(container);
    await _pump(tester, container, ReviewScreen(requestId: request.id),
        locale: 'en');

    expect(find.textContaining('only unlocks once the booking completes'),
        findsOneWidget);
    expect(find.text('Submit review'), findsNothing);
  });
}

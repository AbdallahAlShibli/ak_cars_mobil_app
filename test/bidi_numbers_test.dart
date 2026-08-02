import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/core/utils/bidi_text.dart';
import 'package:ak_cars_mobil_app/features/shop/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_ids.dart';

const lri = '\u2066';
const pdi = '\u2069';

/// Same phone-sized surface the other screen tests use.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required String locale,
}) async {
  final container = await createTestContainer();
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
  group('isolateNumbers', () {
    test('keeps the dial code with its number', () {
      // Without the isolate, Arabic renders this as "96824478120+".
      expect(isolateNumbers('+96824478120', rtl: true),
          '$lri+96824478120$pdi');
    });

    test('keeps a time range in opening order', () {
      // Without the isolate, "8:00–20:00" renders as "20:00–8:00".
      expect(isolateNumbers('8:00–20:00', rtl: true), '${lri}8:00–20:00$pdi');
      expect(isolateNumbers('٨:٠٠–٢٠:٠٠', rtl: true), '$lri٨:٠٠–٢٠:٠٠$pdi');
    });

    test('leaves the Arabic around a number alone', () {
      expect(isolateNumbers('السبت–الخميس ٨:٠٠–٢٠:٠٠ · الجمعة مغلق',
          rtl: true), 'السبت–الخميس $lri٨:٠٠–٢٠:٠٠$pdi · الجمعة مغلق');
    });

    test('isolates each number separately', () {
      expect(isolateNumbers('OM1100047382', rtl: true),
          'OM${lri}1100047382$pdi');
      expect(isolateNumbers('2.4 كم · 5 دقائق', rtl: true),
          '${lri}2.4$pdi كم · ${lri}5$pdi دقائق');
    });

    test('does nothing in English — the data must stay untouched', () {
      for (final value in ['+96824478120', '8:00–20:00', 'OM1100047382']) {
        expect(isolateNumbers(value, rtl: false), value);
      }
    });
  });

  group('shop details card', () {
    testWidgets('prints the phone with its dial code first in Arabic',
        (tester) async {
      await pumpScreen(tester, const ProductDetailScreen(productId: mockIdPr1),
          locale: 'ar');
      await tester.scrollUntilVisible(find.text('بيانات المتجر'), 300,
          scrollable: find.byType(Scrollable).first);

      expect(find.text('$lri+96824478120$pdi'), findsOneWidget,
          reason: 'the plus must stay glued to the left of the digits');
    });

    testWidgets('leaves the numbers as data in English', (tester) async {
      await pumpScreen(tester, const ProductDetailScreen(productId: mockIdPr1),
          locale: 'en');
      await tester.scrollUntilVisible(find.text('Shop details'), 300,
          scrollable: find.byType(Scrollable).first);

      expect(find.text('+96824478120'), findsOneWidget);
      expect(find.text('OM1100047382'), findsOneWidget);
    });
  });
}

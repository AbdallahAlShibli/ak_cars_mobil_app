import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/core/widgets/oman_plate_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

/// Opens the picker and returns whatever it pops — the letters the car is
/// saved with.
Future<String?> pumpPicker(WidgetTester tester, {String initial = 'A'}) async {
  final container = await createTestContainer();
  String? result;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<String>(
                  context: context,
                  builder: (_) => PlateLettersPicker(initial: initial),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

/// The letter keys are 46x46 tiles; the live preview above them is the large
/// text. Finding by text alone is ambiguous once a letter is picked, so scope
/// the taps to the tiles.
Finder letterKey(String letter) => find.descendant(
      of: find.byType(Wrap),
      matching: find.text(letter),
    );

void main() {
  group('plate letters', () {
    testWidgets('the same letter can be picked twice — AA is a real plate',
        (tester) async {
      await pumpPicker(tester);

      await tester.tap(letterKey('A'));
      await tester.pumpAndSettle();
      await tester.tap(letterKey('A'));
      await tester.pumpAndSettle();

      expect(find.text('Use "AA"'), findsOneWidget);
    });

    testWidgets('a repeated letter is marked ×2 so the pair is unambiguous',
        (tester) async {
      await pumpPicker(tester);

      await tester.tap(letterKey('B'));
      await tester.pumpAndSettle();
      expect(find.text('×2'), findsNothing);

      await tester.tap(letterKey('B'));
      await tester.pumpAndSettle();
      expect(find.text('×2'), findsOneWidget);
    });

    testWidgets('a repeated pair is what gets saved', (tester) async {
      // Inlined rather than reusing pumpPicker: this test needs the value the
      // sheet pops, which only lands after the sheet closes.
      String? result;
      final container = await createTestContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<String>(
                      context: context,
                      builder: (_) => const PlateLettersPicker(initial: 'A'),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(letterKey('M'));
      await tester.pumpAndSettle();
      await tester.tap(letterKey('M'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use "MM"'));
      await tester.pumpAndSettle();

      expect(result, 'MM');
    });

    testWidgets('backspace undoes the last letter', (tester) async {
      await pumpPicker(tester);

      await tester.tap(letterKey('A'));
      await tester.pumpAndSettle();
      await tester.tap(letterKey('B'));
      await tester.pumpAndSettle();
      expect(find.text('Use "AB"'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Use "A"'), findsOneWidget);
    });

    testWidgets('a third tap slides the pair along', (tester) async {
      await pumpPicker(tester);

      for (final letter in ['A', 'B', 'D']) {
        await tester.tap(letterKey(letter));
        await tester.pumpAndSettle();
      }

      expect(find.text('Use "BD"'), findsOneWidget);
    });

    testWidgets('a repeated pair survives a reopen', (tester) async {
      await pumpPicker(tester, initial: 'HH');

      expect(find.text('Use "HH"'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
    });
  });

  group('stored plates', () {
    test('a repeated pair round-trips through parse', () {
      expect(OmanPlateInput.parse('12345 AA'), ('12345', 'AA'));
      expect(OmanPlateInput.parse('12345AA'), ('12345', 'AA'));
    });
  });
}

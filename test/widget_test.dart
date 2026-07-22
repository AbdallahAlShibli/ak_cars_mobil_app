import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/app/ak_cars_app.dart';

import 'helpers/test_harness.dart';

void main() {
  testWidgets('App boots to the Sand & Ink splash screen (Arabic default)',
      (tester) async {
    final container = await createTestContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AkCarsApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('AK Cars'), findsOneWidget);
    // Arabic is the first-launch default.
    expect(find.text('ابدأ الرحلة'), findsOneWidget);
    expect(find.text('كل ما تحتاجه سيارتك… في مكان واحد'), findsOneWidget);
  });
}

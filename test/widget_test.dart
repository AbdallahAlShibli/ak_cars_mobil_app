import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ak_cars_mobil_app/data/settings_state.dart';
import 'package:ak_cars_mobil_app/main.dart';

void main() {
  testWidgets('App boots to the Sand & Ink splash screen (Arabic default)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
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

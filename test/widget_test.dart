import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/main.dart';

void main() {
  testWidgets('App boots to the splash screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AkCarsApp()));
    expect(find.text('AK Cars'), findsOneWidget);
    expect(find.text('Services · Parts · Cars'), findsOneWidget);
  });
}

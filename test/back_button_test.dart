import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/core/widgets/sand_widgets.dart';

/// Pushes a plain `AppBar()` page on top of a first route, which is the exact
/// situation every detail/flow screen in the app is in.
Future<void> pumpPushedPage(
  WidgetTester tester, {
  String locale = 'ar',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: Locale(locale),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Detail')),
                    body: const SizedBox(),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a plain AppBar page gets the Sand & Ink back button',
      (tester) async {
    await pumpPushedPage(tester);

    expect(find.byType(SandBackButton), findsOneWidget);
    // The stock Material arrow must not be what the user sees.
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('the chevron points right in Arabic (RTL)', (tester) async {
    await pumpPushedPage(tester, locale: 'ar');
    expect(find.byIcon(LucideIcons.chevronRight), findsOneWidget);
  });

  testWidgets('the chevron points left in English (LTR)', (tester) async {
    await pumpPushedPage(tester, locale: 'en');
    expect(find.byIcon(LucideIcons.chevronLeft), findsOneWidget);
  });

  testWidgets('tapping it pops the page', (tester) async {
    await pumpPushedPage(tester);
    expect(find.text('Detail'), findsOneWidget);

    await tester.tap(find.byType(SandBackButton));
    await tester.pumpAndSettle();

    expect(find.text('Detail'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the standalone button pops and stays a single tap target',
      (tester) async {
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SandBackButton(onTap: () => popped = true),
        ),
      ),
    );

    await tester.tap(find.byType(SandBackButton));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(tester.getSize(find.byType(SandBackButton)).height,
        greaterThanOrEqualTo(44));
  });
}

import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/operations/admin_category_badges.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

/// The yellow ribbon on a service card ("زيت مجاني" / "FREE OIL") was seed data
/// with no owner: visible to every customer, editable by nobody. These cover the
/// founder's control over it now that one exists.
void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = await createTestContainer();
    tester.view.physicalSize = const Size(402 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(
            body: SingleChildScrollView(child: AdminCategoryBadgesSection()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    return container;
  }

  String? badgeOf(ProviderContainer container, {required String slug}) =>
      container
          .read(serviceMarketplaceRepositoryProvider)
          .categories
          .firstWhere((c) => c.slug == slug)
          .badge
          ?.en;

  testWidgets('lists every category and shows which carry a badge', (
    tester,
  ) async {
    final container = await pump(tester);
    final categories = container
        .read(serviceMarketplaceRepositoryProvider)
        .categories;
    final withBadge = categories.where((c) => c.badge != null).length;

    expect(find.text('Service types'), findsOneWidget);
    // One editor per category, and the fixture's badges rendered as the real
    // ribbon rather than as plain text.
    //
    // The corner action names which of its two jobs it will do, so the split
    // is asserted rather than a single tooltip counted across the whole list:
    // a row with nothing on it invites a badge, a row with one edits it.
    expect(find.byTooltip('Edit badge'), findsNWidgets(withBadge));
    expect(
      find.byTooltip('Add a badge'),
      findsNWidgets(categories.length - withBadge),
    );
    expect(find.byType(BadgeRibbon), findsNWidgets(withBadge));
  });

  testWidgets('editing a badge writes it through to the catalogue', (
    tester,
  ) async {
    final container = await pump(tester);
    expect(badgeOf(container, slug: 'major'), 'FREE OIL');

    await tester.tap(find.byTooltip('Edit badge').first);
    await tester.pumpAndSettle();
    expect(find.text('Arabic'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Arabic'),
      'فحص مجاني',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'English'),
      'FREE CHECK',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(badgeOf(container, slug: 'major'), 'FREE CHECK');
  });

  testWidgets('a badge cannot be set in one language only', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Edit badge').first);
    await tester.pumpAndSettle();

    // Clearing only the English half would render an empty yellow box for
    // English readers, so Save is refused until the two agree.
    await tester.enterText(find.widgetWithText(TextField, 'English'), '');
    await tester.pumpAndSettle();

    expect(find.text('Fill both languages, or clear both.'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('removing a badge takes the ribbon off the card', (tester) async {
    final container = await pump(tester);
    expect(badgeOf(container, slug: 'major'), isNotNull);
    final before = find.byType(BadgeRibbon).evaluate().length;

    await tester.tap(find.byTooltip('Edit badge').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove badge'));
    await tester.pumpAndSettle();

    expect(badgeOf(container, slug: 'major'), isNull);
    expect(find.byType(BadgeRibbon), findsNWidgets(before - 1));
  });

  testWidgets('a category with no badge says so', (tester) async {
    final container = await pump(tester);
    final none = container
        .read(serviceMarketplaceRepositoryProvider)
        .categories
        .where((c) => c.badge == null);
    expect(none, isNotEmpty, reason: 'fixture should have unbadged categories');
    // Back to a plain status: the row's own tap now opens the *type* editor,
    // so an invitation to add a badge would name the wrong destination. The
    // badge action beside it is what says "Add a badge", and that is asserted
    // by the tooltip split above.
    expect(find.text('No badge'), findsNWidgets(none.length));
  });
}

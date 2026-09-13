import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:ak_cars_mobil_app/core/constants/app_constants.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/core/utils/guid.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/auth/auth_form_widgets.dart';
import 'package:ak_cars_mobil_app/features/auth/register_screen.dart';
import 'package:ak_cars_mobil_app/features/profile/profile_screen.dart';
import 'package:ak_cars_mobil_app/features/settings/settings_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

import 'fakes/memory_token_store.dart';
import 'helpers/test_harness.dart';

/// The operator-panel entry point and the workshop's own approval status,
/// both of which now live in **My account** rather than in Settings.
///
/// Replaces `settings_business_section_test.dart`: the "My business" section
/// moved off the Settings screen entirely, so its coverage moved with it, and
/// gained the two things that section never had — a dismissible status card
/// and a permanent status row that dismissing it cannot hide.
void main() {
  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    Widget screen = const ProfileScreen(),
    List<Override> overrides = const [],
    // Reuse an existing container when the screen has to be built *after* the
    // account it reads was registered — a form that prefills in initState
    // cannot be tested by registering into a container it never saw.
    ProviderContainer? reuse,
  }) async {
    final container = reuse ?? await createTestContainer(overrides: overrides);
    tester.view.physicalSize = const Size(402 * 3, 1800 * 3);
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
          home: screen,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  MediaAttachment crAttachment() => MediaAttachment(
    id: derivedGuid('test-cr', 'account-panel-test'),
    base64Data:
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
        'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    mimeType: 'image/png',
    fileName: 'cr.png',
  );

  UserProfile workshopProfile(String id) => UserProfile(
    id: id,
    name: 'Owner',
    phone: '+968 9200 0001',
    email: 'owner@example.om',
    region: 'Muscat',
    wilayat: 'Seeb',
    address: 'Street 1',
    kind: AccountKind.workshop,
    workshop: WorkshopApplication(
      businessNameAr: 'ورشة',
      businessNameEn: 'Test Workshop',
      crNumber: '1234567',
      crDocument: crAttachment(),
      area: 'Seeb',
      fulfillments: const {Fulfillment.workshop},
      submittedAt: DateTime.now(),
    ),
  );

  /// Walks a registered workshop to `approved`, the way the founder panel
  /// would.
  Future<void> approve(ProviderContainer container, String id) async {
    final workshop = container
        .read(serviceMarketplaceRepositoryProvider)
        .providerOwnedBy(id)!;
    await container
        .read(adminActionsProvider)
        .setStage(workshop.id, ProviderOnboardingStage.approved);
  }

  testWidgets('a plain customer sees no business panel and no status row', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('My business'), findsNothing);
    expect(find.text('Workshop dashboard'), findsNothing);
    expect(find.text('Founder panel'), findsNothing);
    expect(find.text('Workshop status'), findsNothing);
  });

  testWidgets('an applicant gets the status, but no dashboard door yet', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    await container
        .read(authProvider.notifier)
        .register(workshopProfile('u-pending'));
    await tester.pump(const Duration(milliseconds: 300));

    // The explanation card...
    expect(
      find.text('Your workshop application is under review'),
      findsOneWidget,
    );
    // ...and the permanent row, carrying the real stage.
    expect(find.text('Workshop status'), findsOneWidget);
    expect(find.text('Documents submitted'), findsOneWidget);
    // No panel to open: `_guardOperatorPanels` would bounce them straight
    // back, so offering the button would be offering a dead end.
    expect(find.text('My business'), findsNothing);
    expect(find.text('Workshop dashboard'), findsNothing);
  });

  testWidgets('an approved owner gets a live dashboard card', (tester) async {
    final container = await pumpScreen(tester);
    await container
        .read(authProvider.notifier)
        .register(workshopProfile('u-approved'));
    await approve(container, 'u-approved');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('My business'), findsOneWidget);
    expect(find.text('Workshop dashboard'), findsOneWidget);
    expect(find.text('Test Workshop'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Documents submitted'), findsNothing);
    expect(find.text('Founder panel'), findsNothing);
  });

  testWidgets(
    'dismissing the status card keeps the status row, and the row brings '
    'the card back',
    (tester) async {
      final container = await pumpScreen(tester);
      await container
          .read(authProvider.notifier)
          .register(workshopProfile('u-approved'));
      await approve(container, 'u-approved');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Your workshop is approved'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pump(const Duration(milliseconds: 300));

      // Card gone, fact still on screen — that is the whole point of the row.
      expect(find.text('Your workshop is approved'), findsNothing);
      expect(find.text('Workshop status'), findsOneWidget);
      expect(find.text('Approved'), findsWidgets);
      // Written through to prefs, so it outlives this build.
      expect(container.read(workshopNoticeDismissalProvider), 'approved');

      // The row now opens a dialog rather than restoring the card outright.
      // Asserting on the status sentence alone would pass either way — the
      // dialog prints it too — so this checks the dialog is what appeared,
      // then uses its own control to bring the card back.
      await tester.tap(find.text('Workshop status'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Show the status card again'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(workshopNoticeDismissalProvider), isNull);
      expect(find.text('Your workshop is approved'), findsOneWidget);
    },
  );

  testWidgets('the status row opens a dialog with the workshop at a glance', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    await container
        .read(authProvider.notifier)
        .register(workshopProfile('u-approved'));
    await approve(container, 'u-approved');
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Workshop status'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    // Name, verdict and the record behind it — read-only, and reachable
    // without leaving My account.
    expect(
      find.descendant(of: dialog, matching: find.text('Test Workshop')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('Your workshop is approved'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Verification')),
      findsOneWidget,
    );
    // Where the application sits in the review, as the four stages the
    // backend actually has — not a spinner and not a percentage.
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('Step 4 of 4 · Approved'),
      ),
      findsOneWidget,
    );
    // An approved workshop gets a way through to the panel from here.
    expect(
      find.descendant(of: dialog, matching: find.text('Dashboard')),
      findsOneWidget,
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('My account no longer carries a settings shortcut in its '
      'header', (tester) async {
    await pumpScreen(tester);
    // Settings is still one tap away from the Account section below; what is
    // gone is the second door to it in the header.
    expect(find.byIcon(LucideIcons.settings2), findsNothing);
    expect(find.text('Language & appearance'), findsOneWidget);
  });

  testWidgets('a dismissal does not carry over to the next decision', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    await container
        .read(authProvider.notifier)
        .register(workshopProfile('u-approved'));
    await approve(container, 'u-approved');
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Your workshop is approved'), findsNothing);

    // The founder stops the workshop afterwards. Hiding "you're approved"
    // must not also hide "your workshop was stopped" — different sentence,
    // different stage, so the card comes back on its own.
    final workshop = container
        .read(serviceMarketplaceRepositoryProvider)
        .providerOwnedBy('u-approved')!;
    await container
        .read(adminActionsProvider)
        .setStage(
          workshop.id,
          ProviderOnboardingStage.suspended,
          reason: 'CR document expired.',
        );
    // The owner's own device learns about it the way it learns about every
    // other roster change — the next session refresh re-warms the caches and
    // announces, which is what makes this screen read again.
    container.read(warmCacheNoticeProvider).announce();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Your application needs a change'), findsOneWidget);
    expect(find.text('"CR document expired."'), findsOneWidget);
  });

  testWidgets('a real founder JWT gets the founder card', (tester) async {
    String segment(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final founderToken =
        '${segment({'alg': 'none'})}.'
        '${segment({'http://schemas.microsoft.com/ws/2008/06/identity/claims/role': 'founder'})}'
        '.sig';

    final container = await pumpScreen(
      tester,
      overrides: [
        tokenStoreProvider.overrideWithValue(
          MemoryTokenStore(access: founderToken, refresh: 'r'),
        ),
      ],
    );
    await container
        .read(authProvider.notifier)
        .register(
          const UserProfile(
            name: 'Founder',
            phone: '+968 9555 6666',
            email: 'founder@example.om',
            region: 'Muscat',
            address: '',
          ),
        );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('My business'), findsOneWidget);
    expect(find.text('Founder panel'), findsOneWidget);
    expect(find.text('Workshop dashboard'), findsNothing);
    expect(find.text('Workshop status'), findsNothing);
  });

  testWidgets('the Settings About row opens a dialog with the app version', (
    tester,
  ) async {
    await pumpScreen(tester, screen: const SettingsScreen());

    // Was a dead row: it printed a version and did nothing when tapped.
    await tester.tap(find.text('About the app'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('AK Cars')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Version')),
      findsOneWidget,
    );
    // One constant, so the row and the dialog can never disagree the way the
    // old hardcoded "v2.0" and "v1.0.0" strings did.
    // Twice on purpose: the row behind the dialog and the dialog's own
    // header, both reading the same constant.
    expect(find.text('v${AppConstants.appVersion}'), findsNWidgets(2));
    expect(
      find.descendant(of: dialog, matching: find.text(AppConstants.appVersion)),
      findsOneWidget,
    );
  });

  group('My details — the filed workshop record is read, then edited', () {
    /// Every workshop text field on the register form, by its label.
    const workshopFields = [
      'CR name (Arabic)',
      'CR name (English)',
      'CR number',
      'VAT number',
    ];

    /// Asks the form's own field widgets, rather than hunting for the
    /// `TextField` buried inside each one — `AuthFieldRow.readOnly` is
    /// exactly the property under test.
    bool allReadOnly(WidgetTester tester) {
      final rows = tester
          .widgetList<AuthFieldRow>(find.byType(AuthFieldRow))
          .where((r) => workshopFields.contains(r.label))
          .toList();
      expect(rows, hasLength(workshopFields.length));
      return rows.every((r) => r.readOnly);
    }

    testWidgets('an approved owner reads the filed record first, and edits it '
        'on purpose', (tester) async {
      final container = await createTestContainer();
      await container
          .read(authProvider.notifier)
          .register(workshopProfile('u-approved'));
      await approve(container, 'u-approved');
      // Pumped only now: the form prefills in initState.
      await pumpScreen(
        tester,
        screen: const RegisterScreen(),
        reuse: container,
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Opens as a reading of what is on file — a screen full of live inputs
      // over a verified business record invites a stray keystroke into a CR
      // number.
      expect(allReadOnly(tester), isTrue);
      expect(find.text('Your filed record'), findsOneWidget);

      await tester.tap(find.text('Edit workshop details'));
      await tester.pump(const Duration(milliseconds: 300));

      // ...and editing is one deliberate tap away, not a support ticket.
      expect(allReadOnly(tester), isFalse);
      // An approved workshop is told what saving does *before* it types: the
      // live record changes, and the founder does not re-review it.
      expect(
        find.textContaining('reaches customers directly', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.text('Discard changes'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(allReadOnly(tester), isTrue);
    });

    testWidgets('an account whose profile carries no application still sees '
        'what it registered', (tester) async {
      final container = await createTestContainer();
      final filed = workshopProfile('u-approved');
      await container.read(authProvider.notifier).register(filed);
      await approve(container, 'u-approved');
      // What a fresh sign-in actually looks like: `GET /me` answers with the
      // account, not with the application it filed months ago. The section
      // used to render blank here — an owner opening "My details" saw an
      // empty registration form and no sign the platform still held their
      // record.
      await container
          .read(authProvider.notifier)
          .updateProfile(
            UserProfile(
              id: filed.id,
              name: filed.name,
              phone: filed.phone,
              email: filed.email,
              region: filed.region,
              wilayat: filed.wilayat,
              address: filed.address,
              kind: AccountKind.workshop,
            ),
          );
      await pumpScreen(
        tester,
        screen: const RegisterScreen(),
        reuse: container,
      );
      await tester.pump(const Duration(milliseconds: 300));

      String fieldText(String label) => tester
          .widgetList<AuthFieldRow>(find.byType(AuthFieldRow))
          .firstWhere((r) => r.label == label)
          .controller
          .text;

      // Seeded from the roster record the founder approved.
      expect(fieldText('CR number'), '1234567');
      expect(fieldText('CR name (English)'), 'Test Workshop');
      expect(find.text('Your filed record'), findsOneWidget);
    });

    testWidgets('a rejected application stays editable — correcting it is '
        'the whole point', (tester) async {
      final container = await createTestContainer();
      await container
          .read(authProvider.notifier)
          .register(workshopProfile('u-rejected'));
      final workshop = container
          .read(serviceMarketplaceRepositoryProvider)
          .providerOwnedBy('u-rejected')!;
      await container
          .read(adminActionsProvider)
          .setStage(
            workshop.id,
            ProviderOnboardingStage.suspended,
            reason: 'CR document unreadable.',
          );
      await pumpScreen(
        tester,
        screen: const RegisterScreen(),
        reuse: container,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(allReadOnly(tester), isFalse);
    });
  });

  testWidgets('Settings no longer carries a second copy of the section', (
    tester,
  ) async {
    final container = await pumpScreen(tester, screen: const SettingsScreen());
    await container
        .read(authProvider.notifier)
        .register(workshopProfile('u-approved'));
    await approve(container, 'u-approved');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('My business'), findsNothing);
    expect(find.text('Workshop dashboard'), findsNothing);
    expect(find.text('Founder panel'), findsNothing);
  });
}

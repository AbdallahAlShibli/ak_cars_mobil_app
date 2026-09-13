import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/workshop_dashboard/dashboard_home_screen.dart';
import 'package:ak_cars_mobil_app/features/workshop_dashboard/statistics_screen.dart';
import 'package:ak_cars_mobil_app/core/widgets/working_hours_field.dart';
import 'package:ak_cars_mobil_app/features/workshop_dashboard/workshop_profile_screen.dart';
import 'package:ak_cars_mobil_app/state/provider_dashboard_state.dart';

import 'fakes/data/mock_service_data.dart';
import 'helpers/test_harness.dart';

/// Pumps a screen inside the real theme + localization stack, same shape as
/// `screens_smoke_test.dart`'s helper — kept local rather than imported
/// across test files, matching this suite's existing convention of each test
/// file owning its own copy.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  String locale = 'ar',
  double height = 1400,
}) async {
  final container = await createTestContainer();
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
  return container;
}

void main() {
  group('DashboardHomeScreen smoke', () {
    testWidgets('renders the priority ladder and quick actions in Arabic '
        '(RTL)', (tester) async {
      await pumpScreen(tester, const DashboardHomeScreen());
      expect(find.text('لوحة الورشة'), findsOneWidget);
      // An empty queue is good news and reads as such, rather than as a grey
      // zero in a grid of four equal tiles.
      expect(find.text('لا شيء ينتظرك الآن'), findsOneWidget);
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('الأموال'), findsOneWidget);
      expect(find.text('حالة الورشة'), findsOneWidget);
      expect(find.text('إجراءات سريعة'), findsOneWidget);
      expect(find.text('الخدمات'), findsWidgets);
      expect(find.byType(Directionality), findsWidgets);
      final directionality = tester.widget<Directionality>(
        find.byType(Directionality).first,
      );
      expect(directionality.textDirection, TextDirection.rtl);
    });

    testWidgets(
      'renders the same screen in English (LTR) without layout errors',
      (tester) async {
        await pumpScreen(tester, const DashboardHomeScreen(), locale: 'en');
        expect(find.text('Workshop dashboard'), findsOneWidget);
        expect(find.text('Nothing is waiting on you'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Money'), findsOneWidget);
        expect(find.text('Quick actions'), findsOneWidget);
        // 'Workshop profile', never a second thing called 'Profile' — the
        // account has one of those already, on a different screen.
        expect(find.text('Workshop profile'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('GET /my-workshop envelope', () {
    test('unwraps the provider, the completeness report and the schedule', () {
      // The exact shape `GetMyWorkshopQueryHandler` returns. The client used
      // to parse this whole object as a bare `ServiceProvider`, which has no
      // top-level `id` — so `requireString('id')` threw and the workshop
      // profile screen only ever rendered "Couldn't load the profile".
      final profile = MyWorkshopProfile.fromJson({
        'provider': {
          'id': 'p-1',
          'name': {'ar': 'ورشة', 'en': 'Workshop'},
          'area': 'Seeb',
          'region': 'Muscat',
          'stage': 'approved',
          'fulfillments': ['workshop'],
        },
        'isComplete': false,
        'missingFields': ['whatsapp', 'vatNumber'],
        'schedule': {
          'slotTemplate': ['09:00', '11:00'],
          'capacityPerSlot': 2,
          'closedDays': ['Friday'],
        },
      });

      expect(profile.provider.id, 'p-1');
      expect(profile.provider.stage, ProviderOnboardingStage.approved);
      expect(profile.isComplete, isFalse);
      expect(profile.missingFields, ['whatsapp', 'vatNumber']);
      expect(profile.schedule.slotTemplate, ['09:00', '11:00']);
      expect(profile.schedule.capacityPerSlot, 2);
      expect(profile.schedule.closedDays, ['Friday']);
    });

    test('reads a bare provider too — that is what PUT answers with', () {
      final profile = MyWorkshopProfile.fromJson({
        'id': 'p-2',
        'name': {'ar': 'ورشة', 'en': 'Workshop'},
        'area': 'Sohar',
        'region': 'North Al Batinah',
        'fulfillments': <String>[],
      });
      expect(profile.provider.id, 'p-2');
      expect(profile.missingFields, isEmpty);
    });

    test('re-derives the completeness report after a PUT', () {
      const provider = ServiceProvider(
        id: 'p-3',
        name: L('ورشة', 'Workshop'),
        area: 'Seeb',
        region: 'Muscat',
        distanceKm: 0,
        verified: true,
        fulfillments: {Fulfillment.workshop},
        phone: '+968 2400 0000',
      );
      final profile = MyWorkshopProfile.of(provider);
      // Same six checks the server runs, in the same order.
      expect(profile.missingFields, [
        'whatsapp',
        'hours',
        'vatNumber',
        'crDocument',
      ]);
      expect(profile.isComplete, isFalse);
    });
  });

  group('Schedule config', () {
    test('saved slots, capacity and closed days survive a reload', () async {
      final container = await createDataContainer();
      await container.read(workshopScheduleConfigProvider.future);

      await container
          .read(workshopScheduleConfigProvider.notifier)
          .save(
            slotTemplate: const ['08:00', '10:00', '12:00'],
            capacityPerSlot: 3,
            closedDays: const ['Friday'],
          );

      // Reload from scratch — this is what reopening the config sheet does,
      // and it used to come back empty because the notifier rebuilt the
      // config from the profile's `hours` alone and let every other field
      // fall back to its default.
      container.invalidate(workshopScheduleConfigProvider);
      final reloaded = await container.read(
        workshopScheduleConfigProvider.future,
      );

      expect(reloaded.slotTemplate, ['08:00', '10:00', '12:00']);
      expect(reloaded.capacityPerSlot, 3);
      expect(reloaded.closedDays, ['Friday']);
    });
  });

  group('Offering CRUD', () {
    test(
      'create, edit and delete round-trip through the offerings notifier',
      () async {
        final container = await createDataContainer();
        final notifier = container.read(workshopOfferingsProvider.notifier);

        // build() runs on first read — wait for the initial (empty) load.
        await container.read(workshopOfferingsProvider.future);

        final category = MockServiceData.categories.first;
        final created = await notifier.create(
          categoryId: category.id,
          name: const L('تغيير زيت', 'Oil change'),
          description: const L('وصف', 'Description'),
          price: 15,
          durationMin: 30,
        );
        expect(created.name.en, 'Oil change');
        expect(created.isActive, isTrue);
        expect(container.read(workshopOfferingsProvider).value, hasLength(1));

        final edited = await notifier.edit(
          created.id,
          categoryId: category.id,
          name: const L('تغيير زيت سريع', 'Quick oil change'),
          description: const L('وصف', 'Description'),
          price: 18,
        );
        expect(edited.name.en, 'Quick oil change');
        expect(edited.price, 18);

        final unpublished = await notifier.setActive(
          created.id,
          isActive: false,
        );
        expect(unpublished.isActive, isFalse);

        await notifier.delete(created.id);
        // The DELETE route returns no body (a soft delete server-side), so the
        // repository's optimistic cache drops the row rather than guessing its
        // new isActive value — a subsequent `loadOfferings()` would bring it
        // back showing "Hidden" once the server confirms it.
        expect(container.read(workshopOfferingsProvider).value, isEmpty);
      },
    );
  });

  group('Inventory movement math', () {
    test(
      'quantity increases and decreases correctly, and cannot go below zero',
      () async {
        final container = await createDataContainer();
        final notifier = container.read(workshopInventoryProvider.notifier);
        await container.read(workshopInventoryProvider.future);

        final item = await notifier.create(
          name: const L('فلتر زيت', 'Oil filter'),
          sku: 'SKU-1',
          unitCost: 2,
          sellPrice: 5,
          reorderLevel: 3,
          unit: InventoryUnit.piece,
        );
        expect(item.quantityOnHand, 0);
        expect(item.isLowStock, isTrue); // 0 <= reorderLevel(3)

        final afterPurchase = await notifier.recordMovement(
          item.id,
          delta: 10,
          reason: InventoryMovementReason.purchase,
        );
        expect(afterPurchase.quantityOnHand, 10);
        expect(afterPurchase.isLowStock, isFalse);

        final afterConsumption = await notifier.recordMovement(
          item.id,
          delta: -8,
          reason: InventoryMovementReason.consumed,
        );
        expect(afterConsumption.quantityOnHand, 2);
        expect(afterConsumption.isLowStock, isTrue); // 2 <= reorderLevel(3)

        await expectLater(
          notifier.recordMovement(
            item.id,
            delta: -5,
            reason: InventoryMovementReason.consumed,
          ),
          throwsA(anything),
        );
        // The rejected movement must not have changed the stored quantity.
        final unchanged = container
            .read(workshopInventoryProvider)
            .value!
            .single;
        expect(unchanged.quantityOnHand, 2);
      },
    );
  });

  group('Founder audit trail', () {
    test(
      'inventory, staff and customer-note writes append to the platform audit log',
      () async {
        final container = await createDataContainer();

        await container.read(workshopInventoryProvider.future);
        final item = await container
            .read(workshopInventoryProvider.notifier)
            .create(
              name: const L('فلتر', 'Filter'),
              sku: 'SKU-A',
              unitCost: 1,
              sellPrice: 2,
              reorderLevel: 1,
              unit: InventoryUnit.piece,
            );

        await container.read(workshopStaffProvider.future);
        final staffMember = await container
            .read(workshopStaffProvider.notifier)
            .create(name: 'Nasser', role: WorkshopStaffRole.technician);

        await container
            .read(workshopRepositoryProvider)
            .addCustomerNote('customer-1', body: 'Prefers afternoons');

        final auditLog = await container
            .read(serviceMarketplaceServiceProvider)
            .fetchAuditLog();
        final actions = auditLog.map((e) => e.action).toSet();

        expect(actions, contains('inventory.created'));
        expect(actions, contains('staff.created'));
        expect(actions, contains('customer.note_added'));
        expect(
          auditLog.firstWhere((e) => e.action == 'inventory.created').subjectId,
          item.id,
        );
        expect(
          auditLog.firstWhere((e) => e.action == 'staff.created').subjectType,
          AuditSubjectType.staff,
        );
        expect(
          auditLog.firstWhere((e) => e.action == 'staff.created').subjectId,
          staffMember.id,
        );
      },
    );
  });

  group('Staff permissions', () {
    test('only owner and manager roles can manage the workshop', () {
      expect(WorkshopStaffRole.owner.canManage, isTrue);
      expect(WorkshopStaffRole.manager.canManage, isTrue);
      expect(WorkshopStaffRole.technician.canManage, isFalse);
      expect(WorkshopStaffRole.receptionist.canManage, isFalse);
    });

    test('deactivating a staff member updates the roster in place', () async {
      final container = await createDataContainer();
      final notifier = container.read(workshopStaffProvider.notifier);
      await container.read(workshopStaffProvider.future);

      final member = await notifier.create(
        name: 'Said',
        role: WorkshopStaffRole.technician,
      );
      expect(member.isActive, isTrue);

      await notifier.deactivate(member.id);
      final roster = container.read(workshopStaffProvider).value!;
      expect(roster.single.isActive, isFalse);
    });
  });

  group('StatisticsScreen', () {
    testWidgets('renders the window selector, chart and rate cards without '
        'crashing', (tester) async {
      await pumpScreen(tester, const StatisticsScreen(), locale: 'en');
      // Both figures arrive asynchronously, and each re-runs once its
      // `workshopSummaryProvider` dependency resolves — more round trips
      // than `pumpScreen`'s single fixed pump covers, so wait for them
      // properly rather than for a fixed 500ms.
      await tester.pumpAndSettle();
      expect(find.text('7d'), findsOneWidget);
      expect(find.text('30d'), findsOneWidget);
      expect(find.text('90d'), findsOneWidget);
      // The fake's earnings/metrics both come back empty (no seeded
      // transactions), so both sections render their real empty state
      // rather than a chart with nothing to plot.
      expect(find.text('No transactions in this window yet.'), findsOneWidget);
      expect(
        find.text(
          'No performance figures yet — these appear after your '
          'first job.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Switching windows re-requests both providers for the new value
      // rather than silently keeping the 30-day figures on screen.
      await tester.tap(find.text('7d'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  });

  group('Workshop profile: read first, edit on purpose', () {
    testWidgets('opens as a reading of the registered record', (tester) async {
      await pumpScreen(tester, const WorkshopProfileScreen(), locale: 'en');

      expect(find.text('Workshop profile'), findsOneWidget);
      // Nothing editable until asked for: an owner opening this screen is
      // usually checking what is on file, not rewriting it.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.text('Your registered details'), findsOneWidget);
      expect(find.text('Contact and hours'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Edit opens the form, Cancel closes it again', (tester) async {
      // Tall viewport: the editor is a long form, and a `ListView` never
      // builds what it cannot show — a shorter one would fail on a button
      // that exists.
      await pumpScreen(
        tester,
        const WorkshopProfileScreen(),
        locale: 'en',
        height: 3200,
      );

      await tester.tap(find.text('Edit workshop details'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Save changes'), findsOneWidget);
      // Hours are picked here too — the owner gets the same control the
      // founder does, not a free-text box.
      expect(find.byType(WorkingHoursField), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('refuses a malformed CR number, VAT number and phone', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const WorkshopProfileScreen(),
        locale: 'en',
        height: 3200,
      );
      await tester.tap(find.text('Edit workshop details'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.widgetWithText(TextField, 'CR number'), '123');
      await tester.enterText(
        find.widgetWithText(TextField, 'VAT number'),
        'not-a-vat',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Phone'), '123');
      await tester.pump();

      await tester.tap(find.text('Save changes'));
      await tester.pump(const Duration(milliseconds: 300));

      // Still on the form, with all three said out loud rather than one at a
      // time.
      expect(find.text('A CR number is 6–10 digits'), findsOneWidget);
      expect(find.text('A VAT number looks like OM1100059183'), findsOneWidget);
      expect(find.text('An 8-digit Oman number'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('still names what the platform is missing', (tester) async {
      await pumpScreen(tester, const WorkshopProfileScreen(), locale: 'en');

      // Same list the founder's review reads — it is what tells the owner
      // which fields are worth opening the editor for.
      expect(
        find.text(
          'Still missing — fill these in so your profile reads as trustworthy:',
        ),
        findsOneWidget,
      );
    });
  });

  group('WorkingHours', () {
    const s = S(false);

    test('formats open days as ranges and names the closed ones', () {
      const hours = WorkingHours.standard;
      expect(hours.format().en, 'Sat–Thu 08:00–18:00 · Fri closed');
      expect(hours.format().ar, 'السبت–الخميس 08:00–18:00 · الجمعة مغلق');
    });

    test('a full week has nothing to call closed', () {
      final hours = WorkingHours.standard.copyWith(
        openDays: {...WorkingHours.week},
      );
      expect(hours.format().en, 'Sat–Fri 08:00–18:00');
    });

    test('two loose days read as a pair, not as a range', () {
      final hours = WorkingHours.standard.copyWith(
        openDays: const {DateTime.saturday, DateTime.monday},
      );
      expect(
        hours.format().en,
        'Sat, Mon 08:00–18:00 · Sun, Tue–Fri closed',
      );
    });

    test('round-trips its own output', () {
      const hours = WorkingHours.standard;
      expect(WorkingHours.parse(hours.format()), hours);
    });

    test('reads hours a human typed, Arabic-Indic digits included', () {
      // The shape actually found in the database before the picker existed.
      final parsed = WorkingHours.parse(
        const L('السبت–الخميس ٧:٣٠–١٩:٠٠ الجمعة مغلق', ''),
      );
      expect(parsed, isNotNull);
      expect(parsed!.opens, const TimeOfDay(hour: 7, minute: 30));
      expect(parsed.closes, const TimeOfDay(hour: 19, minute: 0));
      expect(parsed.openDays.contains(DateTime.friday), isFalse);
      expect(parsed.openDays.length, 6);
    });

    test('"Fri closed" alone still says the rest of the week is open', () {
      final parsed = WorkingHours.parse(
        const L('', '9:00-17:00 · Friday closed'),
      );
      expect(parsed!.openDays.contains(DateTime.friday), isFalse);
      expect(parsed.openDays.length, 6);
    });

    test('unreadable text parses to null rather than to a guess', () {
      expect(WorkingHours.parse(null), isNull);
      expect(WorkingHours.parse(const L('حسب الطلب', 'By appointment')), isNull);
      // A single time is not a range.
      expect(WorkingHours.parse(const L('', 'Opens 08:00')), isNull);
    });

    test('a closing time before the opening time is flagged, not silently '
        'accepted', () {
      final backwards = WorkingHours.standard.copyWith(
        opens: const TimeOfDay(hour: 18, minute: 0),
        closes: const TimeOfDay(hour: 8, minute: 0),
      );
      expect(backwards.closesBeforeItOpens, isTrue);
      expect(WorkingHours.standard.closesBeforeItOpens, isFalse);
    });

    test('labels every day of the Omani week', () {
      expect(
        [for (final d in WorkingHours.week) WorkingHours.dayLabel(d, s)],
        ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
      );
    });
  });

  group('WorkingHoursField', () {
    testWidgets('picks days and times instead of taking typed text', (
      tester,
    ) async {
      WorkingHours? latest;
      await pumpScreen(
        tester,
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => WorkingHoursField(
              value: latest ?? WorkingHours.standard,
              onChanged: (v) => setState(() => latest = v),
            ),
          ),
        ),
        locale: 'en',
      );

      // No text entry anywhere in the field — that is the whole change.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Opens'), findsOneWidget);
      expect(find.text('Closes'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      // The exact sentence that will be stored, in both languages.
      expect(find.text('Sat–Thu 08:00–18:00 · Fri closed'), findsOneWidget);

      // Tapping a day chip is what edits the days.
      await tester.tap(find.text('Fri'));
      await tester.pump();
      expect(latest!.openDays.contains(DateTime.friday), isTrue);
      expect(find.text('Sat–Fri 08:00–18:00'), findsOneWidget);
    });

    testWidgets('shows unreadable stored text as it is rather than replacing '
        'it', (tester) async {
      WorkingHours? taken;
      await pumpScreen(
        tester,
        Scaffold(
          body: WorkingHoursField(
            value: null,
            savedText: 'By appointment',
            onChanged: (v) => taken = v,
          ),
        ),
        locale: 'en',
      );

      expect(find.text('By appointment'), findsOneWidget);
      expect(taken, isNull);

      await tester.tap(find.text('Set them with the picker'));
      await tester.pump();
      expect(taken, WorkingHours.standard);
    });
  });
}

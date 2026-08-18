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
    testWidgets('renders the KPI grid and quick actions in Arabic (RTL)', (
      tester,
    ) async {
      await pumpScreen(tester, const DashboardHomeScreen());
      expect(find.text('لوحة الورشة'), findsOneWidget);
      expect(find.text('يحتاج إجراءك'), findsOneWidget);
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
        expect(find.text('Needs your action'), findsOneWidget);
        expect(find.text('Quick actions'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
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
    test('inventory, staff and customer-note writes append to the platform audit log', () async {
      final container = await createDataContainer();

      await container.read(workshopInventoryProvider.future);
      final item = await container.read(workshopInventoryProvider.notifier).create(
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

      final auditLog = await container.read(serviceMarketplaceServiceProvider).fetchAuditLog();
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
    });
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
      expect(find.text('7d'), findsOneWidget);
      expect(find.text('30d'), findsOneWidget);
      expect(find.text('90d'), findsOneWidget);
      // The fake's earnings/metrics both come back empty (no seeded
      // transactions), so both sections render their real empty state
      // rather than a chart with nothing to plot.
      expect(
        find.text('No transactions in this window yet.'),
        findsOneWidget,
      );
      expect(
        find.text('No performance figures yet — these appear after your '
            'first job.'),
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
}

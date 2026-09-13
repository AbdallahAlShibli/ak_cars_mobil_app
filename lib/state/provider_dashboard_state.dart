import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/strings.dart';
import '../data/models/models.dart';
import '../di/providers.dart';

// State for the Workshop (Provider) Dashboard —
// lib/features/workshop_dashboard/.
//
// Nothing here needs to decide *which* workshop is active: every
// /my-workshop/* route resolves the caller's own workshop from the JWT
// server-side (see WorkshopAccess.RequireOwnedAsync on the API), so there is
// no client-side choice to make. This dashboard's entry point is gated by
// `_guardOperatorPanels` in app_router.dart — real ownership
// (`providerOwnedBy`) plus approval, re-checked on every navigation — not by
// anything in this file.
//
// AsyncNotifier, not the plain Notifier + manual refresh()
// operator_queue_state.dart uses. That distinction is deliberate: the
// operator queue is warmed at bootstrap and always has *something* to show,
// so it has never needed a loading state. This dashboard is opened on
// demand, starts with nothing loaded, and its own spec calls for loading
// skeletons on every list — AsyncValue is what gives every screen below a
// .when(loading: error: data:) for free instead of each one inventing its
// own boolean.

// ------------------------------------------------------------- summary

class WorkshopSummaryNotifier extends AsyncNotifier<WorkshopSummary> {
  @override
  Future<WorkshopSummary> build() =>
      ref.read(workshopRepositoryProvider).fetchSummary();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(workshopRepositoryProvider).fetchSummary(),
    );
  }
}

final workshopSummaryProvider =
    AsyncNotifierProvider<WorkshopSummaryNotifier, WorkshopSummary>(
      WorkshopSummaryNotifier.new,
    );

/// After any dashboard mutation — the KPIs must reflect the write immediately,
/// not on the next time someone happens to reopen the home screen.
///
/// Guarded with [Ref.exists] for the reason `SessionRefresh._ifBuilt`'s doc
/// comment sets out at length: a bare `invalidate` on an `AsyncNotifierProvider`
/// that was never built *builds* it, firing a real `GET /my-workshop/summary`
/// for the sake of a debug-only assertion. That is not hypothetical here —
/// [MyWorkshopProfileNotifier.save] is also called from the "My details"
/// screen in `register_screen.dart`, where the dashboard has never been
/// opened and this provider therefore does not exist.
void _invalidateSummary(Ref ref) {
  if (ref.exists(workshopSummaryProvider)) {
    ref.invalidate(workshopSummaryProvider);
  }
}

// ------------------------------------------------------------- profile

class MyWorkshopProfileNotifier extends AsyncNotifier<MyWorkshopProfile> {
  @override
  Future<MyWorkshopProfile> build() =>
      ref.read(workshopRepositoryProvider).loadMyWorkshop();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(workshopRepositoryProvider).loadMyWorkshop(),
    );
  }

  /// `PUT /my-workshop` — the owner editing their own live record.
  ///
  /// Two screens call it: the dashboard's workshop profile
  /// (`workshop_profile_screen.dart`) and, for an approved workshop, the
  /// workshop half of "My details" (`register_screen.dart`). Both write here
  /// rather than re-filing the application, which is what keeps a corrected
  /// phone number from dropping an approved workshop back into the founder's
  /// review queue.
  ///
  /// The customer-facing roster is a separate cache — callers refresh it
  /// (`refreshProviders`) afterwards, so the status dialog and the services
  /// list do not keep showing the old record.
  Future<ServiceProvider> save({
    required L name,
    required String area,
    required String region,
    String? phone,
    String? whatsapp,
    L? hours,
    required Set<Fulfillment> fulfillments,
    required Set<ProviderCapability> capabilities,
    required double pickupFee,
    String? vatNumber,
    String? crNumber,
  }) async {
    final updated = await ref
        .read(workshopRepositoryProvider)
        .updateMyWorkshop(
          name: name,
          area: area,
          region: region,
          phone: phone,
          whatsapp: whatsapp,
          hours: hours,
          fulfillments: fulfillments,
          capabilities: capabilities,
          pickupFee: pickupFee,
          vatNumber: vatNumber,
          crNumber: crNumber,
        );
    // The repository re-wraps the PUT's bare provider into a fresh envelope
    // (completeness recomputed, schedule carried over); read that back rather
    // than rebuilding a second, possibly disagreeing, copy here.
    state = AsyncData(
      ref.read(workshopRepositoryProvider).cachedProfile ??
          MyWorkshopProfile.of(updated),
    );
    _invalidateSummary(ref);
    // The schedule sheet reads its hours from the same envelope, so an edit
    // that changed opening hours has to reach it too.
    if (ref.exists(workshopScheduleConfigProvider)) {
      ref.invalidate(workshopScheduleConfigProvider);
    }
    return updated;
  }
}

final myWorkshopProfileProvider =
    AsyncNotifierProvider<MyWorkshopProfileNotifier, MyWorkshopProfile>(
      MyWorkshopProfileNotifier.new,
    );

// ----------------------------------------------------------- offerings

class WorkshopOfferingsNotifier extends AsyncNotifier<List<ServiceOffering>> {
  @override
  Future<List<ServiceOffering>> build() =>
      ref.read(workshopRepositoryProvider).loadOfferings();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(workshopRepositoryProvider).loadOfferings(),
    );
  }

  Future<ServiceOffering> create({
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
    MediaAttachment? photo,
  }) async {
    final created = await ref
        .read(workshopRepositoryProvider)
        .createOffering(
          categoryId: categoryId,
          name: name,
          description: description,
          price: price,
          durationMin: durationMin,
          includes: includes,
          warrantyMonths: warrantyMonths,
          photo: photo,
        );
    _syncFromRepository();
    _invalidateSummary(ref);
    return created;
  }

  Future<ServiceOffering> edit(
    String offeringId, {
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
    MediaAttachment? photo,
  }) async {
    final updated = await ref
        .read(workshopRepositoryProvider)
        .updateOffering(
          offeringId,
          categoryId: categoryId,
          name: name,
          description: description,
          price: price,
          durationMin: durationMin,
          includes: includes,
          warrantyMonths: warrantyMonths,
          photo: photo,
        );
    _syncFromRepository();
    return updated;
  }

  Future<ServiceOffering> setActive(
    String offeringId, {
    required bool isActive,
  }) async {
    final updated = await ref
        .read(workshopRepositoryProvider)
        .setOfferingActive(offeringId, isActive: isActive);
    _syncFromRepository();
    return updated;
  }

  Future<void> delete(String offeringId) async {
    await ref.read(workshopRepositoryProvider).deleteOffering(offeringId);
    _syncFromRepository();
    _invalidateSummary(ref);
  }

  void _syncFromRepository() =>
      state = AsyncData(ref.read(workshopRepositoryProvider).offerings);
}

final workshopOfferingsProvider =
    AsyncNotifierProvider<WorkshopOfferingsNotifier, List<ServiceOffering>>(
      WorkshopOfferingsNotifier.new,
    );

// ------------------------------------------------------------- add-ons

class WorkshopAddOnsNotifier extends AsyncNotifier<List<AddOn>> {
  @override
  Future<List<AddOn>> build() =>
      ref.read(workshopRepositoryProvider).loadAddOns();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(workshopRepositoryProvider).loadAddOns(),
    );
  }

  Future<AddOn> create({
    required L name,
    required double price,
    required bool isPart,
  }) async {
    final created = await ref
        .read(workshopRepositoryProvider)
        .createAddOn(name: name, price: price, isPart: isPart);
    _syncFromRepository();
    return created;
  }

  Future<AddOn> edit(
    String addOnId, {
    required L name,
    required double price,
    required bool isPart,
  }) async {
    final updated = await ref
        .read(workshopRepositoryProvider)
        .updateAddOn(addOnId, name: name, price: price, isPart: isPart);
    _syncFromRepository();
    return updated;
  }

  Future<void> delete(String addOnId) async {
    await ref.read(workshopRepositoryProvider).deleteAddOn(addOnId);
    _syncFromRepository();
  }

  void _syncFromRepository() =>
      state = AsyncData(ref.read(workshopRepositoryProvider).addOns);
}

final workshopAddOnsProvider =
    AsyncNotifierProvider<WorkshopAddOnsNotifier, List<AddOn>>(
      WorkshopAddOnsNotifier.new,
    );

// ---------------------------------------------------------- inventory

class WorkshopInventoryNotifier extends AsyncNotifier<List<InventoryItem>> {
  @override
  Future<List<InventoryItem>> build() =>
      ref.read(workshopRepositoryProvider).loadInventory();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(workshopRepositoryProvider).loadInventory(),
    );
  }

  Future<InventoryItem> create({
    required L name,
    required String sku,
    String? partNumber,
    String? brand,
    String? categoryId,
    required double unitCost,
    required double sellPrice,
    required int reorderLevel,
    required InventoryUnit unit,
    String? location,
  }) async {
    final created = await ref
        .read(workshopRepositoryProvider)
        .createInventoryItem(
          name: name,
          sku: sku,
          partNumber: partNumber,
          brand: brand,
          categoryId: categoryId,
          unitCost: unitCost,
          sellPrice: sellPrice,
          reorderLevel: reorderLevel,
          unit: unit,
          location: location,
        );
    _syncFromRepository();
    _invalidateSummary(ref);
    return created;
  }

  Future<InventoryItem> edit(
    String itemId, {
    required L name,
    required String sku,
    String? partNumber,
    String? brand,
    String? categoryId,
    required double unitCost,
    required double sellPrice,
    required int reorderLevel,
    required InventoryUnit unit,
    String? location,
    required bool isActive,
  }) async {
    final updated = await ref
        .read(workshopRepositoryProvider)
        .updateInventoryItem(
          itemId,
          name: name,
          sku: sku,
          partNumber: partNumber,
          brand: brand,
          categoryId: categoryId,
          unitCost: unitCost,
          sellPrice: sellPrice,
          reorderLevel: reorderLevel,
          unit: unit,
          location: location,
          isActive: isActive,
        );
    _syncFromRepository();
    _invalidateSummary(ref);
    return updated;
  }

  Future<void> delete(String itemId) async {
    await ref.read(workshopRepositoryProvider).deleteInventoryItem(itemId);
    _syncFromRepository();
    _invalidateSummary(ref);
  }

  Future<InventoryItem> recordMovement(
    String itemId, {
    required int delta,
    required InventoryMovementReason reason,
    String? requestId,
    String? note,
  }) async {
    final updated = await ref
        .read(workshopRepositoryProvider)
        .recordInventoryMovement(
          itemId,
          delta: delta,
          reason: reason,
          requestId: requestId,
          note: note,
        );
    _syncFromRepository();
    _invalidateSummary(ref);
    return updated;
  }

  void _syncFromRepository() =>
      state = AsyncData(ref.read(workshopRepositoryProvider).inventory);
}

final workshopInventoryProvider =
    AsyncNotifierProvider<WorkshopInventoryNotifier, List<InventoryItem>>(
      WorkshopInventoryNotifier.new,
    );

// ------------------------------------------------------------- staff

class WorkshopStaffNotifier extends AsyncNotifier<List<WorkshopStaff>> {
  @override
  Future<List<WorkshopStaff>> build() =>
      ref.read(workshopRepositoryProvider).loadStaff();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(workshopRepositoryProvider).loadStaff(),
    );
  }

  Future<WorkshopStaff> create({
    required String name,
    String? phone,
    required WorkshopStaffRole role,
    List<String> specialties = const [],
    String? userId,
  }) async {
    final created = await ref
        .read(workshopRepositoryProvider)
        .createStaff(
          name: name,
          phone: phone,
          role: role,
          specialties: specialties,
          userId: userId,
        );
    _syncFromRepository();
    _invalidateSummary(ref);
    return created;
  }

  Future<WorkshopStaff> edit(
    String staffId, {
    required String name,
    String? phone,
    required WorkshopStaffRole role,
    List<String> specialties = const [],
  }) async {
    final updated = await ref
        .read(workshopRepositoryProvider)
        .updateStaff(
          staffId,
          name: name,
          phone: phone,
          role: role,
          specialties: specialties,
        );
    _syncFromRepository();
    return updated;
  }

  Future<void> deactivate(String staffId) async {
    await ref.read(workshopRepositoryProvider).deactivateStaff(staffId);
    _syncFromRepository();
    _invalidateSummary(ref);
  }

  void _syncFromRepository() =>
      state = AsyncData(ref.read(workshopRepositoryProvider).staff);
}

final workshopStaffProvider =
    AsyncNotifierProvider<WorkshopStaffNotifier, List<WorkshopStaff>>(
      WorkshopStaffNotifier.new,
    );

// ---------------------------------------------------------- requests

/// Filters for [WorkshopRequestsNotifier] — held as state so the orders
/// screen's filter chips and the notifier agree on what is currently applied.
class WorkshopRequestsFilter {
  const WorkshopRequestsFilter({this.status, this.from, this.to, this.query});

  final EscrowState? status;
  final DateTime? from;
  final DateTime? to;
  final String? query;

  static const none = WorkshopRequestsFilter();
}

class WorkshopRequestsNotifier extends AsyncNotifier<List<ServiceRequest>> {
  WorkshopRequestsFilter _filter = WorkshopRequestsFilter.none;

  WorkshopRequestsFilter get filter => _filter;

  @override
  Future<List<ServiceRequest>> build() => ref
      .read(workshopRepositoryProvider)
      .fetchWorkshopRequests(
        status: _filter.status,
        from: _filter.from,
        to: _filter.to,
        query: _filter.query,
      );

  Future<void> applyFilter(WorkshopRequestsFilter filter) async {
    _filter = filter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(workshopRepositoryProvider)
          .fetchWorkshopRequests(
            status: filter.status,
            from: filter.from,
            to: filter.to,
            query: filter.query,
          ),
    );
  }

  Future<void> refresh() => applyFilter(_filter);

  Future<ServiceRequest> assign(
    String requestId, {
    required String staffId,
  }) async {
    final updated = await ref
        .read(workshopRepositoryProvider)
        .assignRequest(requestId, staffId: staffId);
    state = AsyncData([
      for (final r in state.valueOrNull ?? const <ServiceRequest>[])
        if (r.id == updated.id) updated else r,
    ]);
    return updated;
  }
}

final workshopRequestsProvider =
    AsyncNotifierProvider<WorkshopRequestsNotifier, List<ServiceRequest>>(
      WorkshopRequestsNotifier.new,
    );

// --------------------------------------------------------- customers

class WorkshopCustomersFilter {
  const WorkshopCustomersFilter({this.query, this.tag});

  final String? query;
  final WorkshopCustomerTag? tag;

  static const none = WorkshopCustomersFilter();
}

class WorkshopCustomersNotifier extends AsyncNotifier<List<WorkshopCustomer>> {
  WorkshopCustomersFilter _filter = WorkshopCustomersFilter.none;

  WorkshopCustomersFilter get filter => _filter;

  @override
  Future<List<WorkshopCustomer>> build() => ref
      .read(workshopRepositoryProvider)
      .fetchCustomers(query: _filter.query, tag: _filter.tag);

  Future<void> applyFilter(WorkshopCustomersFilter filter) async {
    _filter = filter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(workshopRepositoryProvider)
          .fetchCustomers(query: filter.query, tag: filter.tag),
    );
  }

  Future<void> refresh() => applyFilter(_filter);
}

final workshopCustomersProvider =
    AsyncNotifierProvider<WorkshopCustomersNotifier, List<WorkshopCustomer>>(
      WorkshopCustomersNotifier.new,
    );

class WorkshopCustomerDetailNotifier
    extends FamilyAsyncNotifier<WorkshopCustomerDetail, String> {
  @override
  Future<WorkshopCustomerDetail> build(String userId) =>
      ref.read(workshopRepositoryProvider).fetchCustomer(userId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(workshopRepositoryProvider).fetchCustomer(arg),
    );
  }

  Future<WorkshopCustomerNote> addNote(String body) async {
    final note = await ref
        .read(workshopRepositoryProvider)
        .addCustomerNote(arg, body: body);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        WorkshopCustomerDetail(
          customer: current.customer,
          bookings: current.bookings,
          notes: [note, ...current.notes],
        ),
      );
    }
    return note;
  }
}

final workshopCustomerDetailProvider =
    AsyncNotifierProvider.family<
      WorkshopCustomerDetailNotifier,
      WorkshopCustomerDetail,
      String
    >(WorkshopCustomerDetailNotifier.new);

// ---------------------------------------------------------- schedule

class WorkshopScheduleNotifier
    extends FamilyAsyncNotifier<WorkshopDaySchedule, DateTime> {
  @override
  Future<WorkshopDaySchedule> build(DateTime date) =>
      ref.read(workshopRepositoryProvider).fetchSchedule(date);
}

final workshopScheduleProvider =
    AsyncNotifierProvider.family<
      WorkshopScheduleNotifier,
      WorkshopDaySchedule,
      DateTime
    >(WorkshopScheduleNotifier.new);

class WorkshopScheduleConfigNotifier extends AsyncNotifier<WorkshopSchedule> {
  /// Read from `GET /my-workshop`, which is the only route that serves the
  /// saved slot template, capacity and closed days back — `PUT
  /// /my-workshop/schedule` writes them and has no matching GET of its own.
  /// This used to build a `WorkshopSchedule` from the profile's `hours`
  /// alone, so every other field silently reset to its default and the
  /// config sheet reopened blank after each save.
  @override
  Future<WorkshopSchedule> build() async =>
      (await ref.read(workshopRepositoryProvider).loadMyWorkshop()).schedule;

  Future<WorkshopSchedule> save({
    L? hours,
    List<String> slotTemplate = const [],
    required int capacityPerSlot,
    List<String> closedDays = const [],
  }) async {
    final updated = await ref
        .read(workshopRepositoryProvider)
        .updateSchedule(
          hours: hours,
          slotTemplate: slotTemplate,
          capacityPerSlot: capacityPerSlot,
          closedDays: closedDays,
        );
    state = AsyncData(updated);
    // The day view generates its slots from exactly these settings, so it is
    // stale the instant they change — without this the schedule screen kept
    // showing the old grid behind the sheet that had just replaced it.
    ref.invalidate(workshopScheduleProvider);
    return updated;
  }
}

final workshopScheduleConfigProvider =
    AsyncNotifierProvider<WorkshopScheduleConfigNotifier, WorkshopSchedule>(
      WorkshopScheduleConfigNotifier.new,
    );

// ------------------------------------------------------ earnings/metrics

/// Server-computed figures for the dashboard's earnings/performance sections.
final workshopDashboardEarningsProvider =
    FutureProvider.family<WorkshopEarnings, int>((ref, windowDays) {
      ref.watch(workshopSummaryProvider);
      return ref
          .read(workshopRepositoryProvider)
          .fetchEarnings(windowDays: windowDays);
    });

final workshopDashboardMetricsProvider =
    FutureProvider.family<WorkshopMetrics, int>((ref, windowDays) {
      ref.watch(workshopSummaryProvider);
      return ref
          .read(workshopRepositoryProvider)
          .fetchMetrics(windowDays: windowDays);
    });

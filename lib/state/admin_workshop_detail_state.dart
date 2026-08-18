import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/strings.dart';
import '../data/models/models.dart';
import '../di/providers.dart';
import 'admin_state.dart';

// State for the founder's "manage this workshop" screen
// (lib/features/operations/admin_workshop_detail_screen.dart) — profile,
// offerings and add-ons for one workshop the founder picked from the roster,
// not the signed-in account's own workshop (that's provider_dashboard_state.dart).
//
// `autoDispose.family<..., String providerId>` rather than the plain
// `AsyncNotifierProvider` the rest of this app's dashboard state uses: this
// is founder-viewing-someone-else's-data, keyed by whichever workshop is
// open, and it should be torn down when the detail screen closes rather than
// live on forever. That sidesteps the SessionRefresh registration every
// non-autoDispose `ref.read`-based provider otherwise needs by hand (see
// `session_refresh.dart` and the workshop-dashboard bug it was added for) —
// there is nothing here for a sign-in/sign-out to leak.
//
// `AdminWorkshopRepository` holds no cache of its own (unlike
// `WorkshopRepository`), so every notifier below patches its own `state`
// list directly after a write rather than reading a repository-owned list
// back.

// ------------------------------------------------------------- profile

class AdminWorkshopProfileNotifier
    extends AutoDisposeFamilyAsyncNotifier<ServiceProvider, String> {
  @override
  Future<ServiceProvider> build(String providerId) =>
      ref.read(adminWorkshopRepositoryProvider).getProvider(providerId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(adminWorkshopRepositoryProvider).getProvider(arg),
    );
  }

  /// Routed through [AdminActions] rather than the repository directly — a
  /// profile edit also has to refresh the founder's roster (name/area shown
  /// in `_RosterRow`), and that side effect belongs in one place.
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
    final updated = await ref.read(adminActionsProvider).updateProviderProfile(
          arg,
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
    state = AsyncData(updated);
    return updated;
  }
}

final adminWorkshopProfileProvider = AsyncNotifierProvider.autoDispose
    .family<AdminWorkshopProfileNotifier, ServiceProvider, String>(
      AdminWorkshopProfileNotifier.new,
    );

// ----------------------------------------------------------- offerings

class AdminWorkshopOfferingsNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<ServiceOffering>, String> {
  @override
  Future<List<ServiceOffering>> build(String providerId) =>
      ref.read(adminWorkshopRepositoryProvider).getOfferings(providerId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(adminWorkshopRepositoryProvider).getOfferings(arg),
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
  }) async {
    final created = await ref.read(adminWorkshopRepositoryProvider).createOffering(
          arg,
          categoryId: categoryId,
          name: name,
          description: description,
          price: price,
          durationMin: durationMin,
          includes: includes,
          warrantyMonths: warrantyMonths,
        );
    state = AsyncData([...state.valueOrNull ?? const [], created]);
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
  }) async {
    final updated = await ref.read(adminWorkshopRepositoryProvider).updateOffering(
          arg,
          offeringId,
          categoryId: categoryId,
          name: name,
          description: description,
          price: price,
          durationMin: durationMin,
          includes: includes,
          warrantyMonths: warrantyMonths,
        );
    _replace(updated);
    return updated;
  }

  Future<ServiceOffering> setActive(
    String offeringId, {
    required bool isActive,
  }) async {
    final updated = await ref
        .read(adminWorkshopRepositoryProvider)
        .setOfferingActive(arg, offeringId, isActive: isActive);
    _replace(updated);
    return updated;
  }

  Future<void> delete(String offeringId) async {
    await ref.read(adminWorkshopRepositoryProvider).deleteOffering(arg, offeringId);
    state = AsyncData([
      for (final o in state.valueOrNull ?? const <ServiceOffering>[])
        if (o.id != offeringId) o,
    ]);
  }

  void _replace(ServiceOffering updated) => state = AsyncData([
        for (final o in state.valueOrNull ?? const <ServiceOffering>[])
          if (o.id == updated.id) updated else o,
      ]);
}

final adminWorkshopOfferingsProvider = AsyncNotifierProvider.autoDispose
    .family<AdminWorkshopOfferingsNotifier, List<ServiceOffering>, String>(
      AdminWorkshopOfferingsNotifier.new,
    );

// ------------------------------------------------------------- add-ons

class AdminWorkshopAddOnsNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<AddOn>, String> {
  @override
  Future<List<AddOn>> build(String providerId) =>
      ref.read(adminWorkshopRepositoryProvider).getAddOns(providerId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(adminWorkshopRepositoryProvider).getAddOns(arg),
    );
  }

  Future<AddOn> create({
    required L name,
    required double price,
    required bool isPart,
  }) async {
    final created = await ref
        .read(adminWorkshopRepositoryProvider)
        .createAddOn(arg, name: name, price: price, isPart: isPart);
    state = AsyncData([...state.valueOrNull ?? const [], created]);
    return created;
  }

  Future<AddOn> edit(
    String addOnId, {
    required L name,
    required double price,
    required bool isPart,
  }) async {
    final updated = await ref
        .read(adminWorkshopRepositoryProvider)
        .updateAddOn(arg, addOnId, name: name, price: price, isPart: isPart);
    state = AsyncData([
      for (final a in state.valueOrNull ?? const <AddOn>[])
        if (a.id == updated.id) updated else a,
    ]);
    return updated;
  }

  Future<void> delete(String addOnId) async {
    await ref.read(adminWorkshopRepositoryProvider).deleteAddOn(arg, addOnId);
    state = AsyncData([
      for (final a in state.valueOrNull ?? const <AddOn>[])
        if (a.id != addOnId) a,
    ]);
  }
}

final adminWorkshopAddOnsProvider = AsyncNotifierProvider.autoDispose
    .family<AdminWorkshopAddOnsNotifier, List<AddOn>, String>(
      AdminWorkshopAddOnsNotifier.new,
    );

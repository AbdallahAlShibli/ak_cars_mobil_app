import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/strings.dart';
import '../data/models/offer.dart';
import '../data/models/promotion.dart';
import '../data/models/service_category.dart';
import '../di/providers.dart';
import 'offers_state.dart';

/// The founder's content-management screen — full create/edit/delete over
/// every [Offer] and [Promotion] on the platform, the two things that show
/// up on the Home page's offers/announcements rails and (offers only) the
/// Services page.
///
/// Fetched on demand rather than warmed into the marketplace repository's
/// caches, same reasoning as `admin_workshop_detail_state.dart`: an
/// occasionally-opened founder screen, not a hot path every screen reads
/// from.

/// Bumped after any write here — the counterpart to [offersRevisionProvider]
/// for promotions, which never had one because nothing used to write them.
final promotionsRevisionProvider = StateProvider<int>((ref) => 0);

/// Bumped after a category's promo ribbon is set or cleared.
///
/// Categories live in the marketplace repository's warm cache and are read
/// synchronously by the home page, the services page and the founder's own
/// list, so a write has to announce itself the same way an offer's does —
/// otherwise the founder saves a badge and the list under the editor keeps
/// showing the old one until something else happens to rebuild it.
final categoriesRevisionProvider = StateProvider<int>((ref) => 0);

/// Every service category, for the founder's badge editor.
///
/// Read straight from the warm cache rather than fetched: unlike offers and
/// promotions, categories are already loaded at bootstrap because every
/// customer-facing screen needs them.
final adminCategoriesProvider = Provider<List<ServiceCategory>>((ref) {
  ref.watch(categoriesRevisionProvider);
  return ref.watch(serviceMarketplaceRepositoryProvider).categories;
});

/// The founder's writes on the service catalogue's *types* — the ribbon, and
/// the categories themselves.
///
/// One object rather than two because every one of these writes ends the same
/// way: bump [categoriesRevisionProvider] so the lists reading the warm cache
/// rebuild. Splitting them is how one of the four forgets to.
class CategoryBadgeAdmin {
  const CategoryBadgeAdmin(this._ref);

  final Ref _ref;

  Future<void> setBadge(String categoryId, {L? badge}) async {
    await _ref
        .read(serviceMarketplaceRepositoryProvider)
        .setCategoryBadge(categoryId, badge: badge);
    _bump();
  }

  Future<ServiceCategory> create(ServiceCategoryDraft draft) async {
    final created = await _ref
        .read(serviceMarketplaceRepositoryProvider)
        .createCategory(draft);
    _bump();
    return created;
  }

  Future<ServiceCategory> update(
    String categoryId,
    ServiceCategoryDraft draft,
  ) async {
    final updated = await _ref
        .read(serviceMarketplaceRepositoryProvider)
        .updateCategory(categoryId, draft);
    _bump();
    return updated;
  }

  Future<void> delete(String categoryId) async {
    await _ref
        .read(serviceMarketplaceRepositoryProvider)
        .deleteCategory(categoryId);
    _bump();
  }

  /// How many offerings a type still carries — what the delete confirmation
  /// needs to explain a refusal before making the call.
  int offeringCount(String categoryId) => _ref
      .read(serviceMarketplaceRepositoryProvider)
      .offeringCountFor(categoryId);

  void _bump() => _ref.read(categoriesRevisionProvider.notifier).state++;
}

final categoryBadgeAdminProvider = Provider<CategoryBadgeAdmin>(
  CategoryBadgeAdmin.new,
);

final adminOffersProvider =
    AsyncNotifierProvider<AdminOffersNotifier, List<Offer>>(
      AdminOffersNotifier.new,
    );

/// The founder panel's Offers tab: every offer the platform holds, each with
/// the reason it is not live.
///
/// Deliberately built on [adminOffersProvider] and not on `offersAuditProvider`
/// — that one reads the repository's warm cache, which is filled from the
/// public offers endpoint and so holds only offers that are already approved
/// and in-window. A management screen sourced from it could never show the row
/// it had just created, because creating an offer is exactly the moment it is
/// not yet live.
final adminOfferAuditProvider =
    Provider<AsyncValue<List<({Offer offer, OfferRejection? rejection})>>>((
      ref,
    ) {
      // Repaints when an offer is written from anywhere — the same signal the
      // customer-facing rails watch.
      ref.watch(offersRevisionProvider);
      final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
      return ref
          .watch(adminOffersProvider)
          .whenData(
            (offers) => [
              for (final offer in offers)
                (offer: offer, rejection: marketplace.rejectionFor(offer)),
            ],
          );
    });

class AdminOffersNotifier extends AsyncNotifier<List<Offer>> {
  @override
  Future<List<Offer>> build() =>
      ref.read(serviceMarketplaceRepositoryProvider).fetchAllOffersForFounder();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(serviceMarketplaceRepositoryProvider)
          .fetchAllOffersForFounder(),
    );
  }

  Future<Offer> create({
    required String workshopId,
    required String serviceOfferingId,
    required double referencePrice,
    required double discountedPrice,
    required DateTime startsAt,
    required DateTime endsAt,
    Set<String> regions = const {},
    bool activeByFounder = false,
  }) async {
    final created = await ref
        .read(serviceMarketplaceRepositoryProvider)
        .createOffer(
          workshopId: workshopId,
          serviceOfferingId: serviceOfferingId,
          referencePrice: referencePrice,
          discountedPrice: discountedPrice,
          startsAt: startsAt,
          endsAt: endsAt,
          regions: regions,
          activeByFounder: activeByFounder,
        );
    state = AsyncData([...state.valueOrNull ?? const [], created]);
    ref.read(offersRevisionProvider.notifier).state++;
    return created;
  }

  Future<Offer> edit(
    String offerId, {
    required double referencePrice,
    required double discountedPrice,
    required DateTime startsAt,
    required DateTime endsAt,
    Set<String> regions = const {},
    required bool activeByFounder,
  }) async {
    final updated = await ref
        .read(serviceMarketplaceRepositoryProvider)
        .updateOffer(
          offerId,
          referencePrice: referencePrice,
          discountedPrice: discountedPrice,
          startsAt: startsAt,
          endsAt: endsAt,
          regions: regions,
          activeByFounder: activeByFounder,
        );
    state = AsyncData([
      for (final o in state.valueOrNull ?? const [])
        if (o.id == updated.id) updated else o,
    ]);
    ref.read(offersRevisionProvider.notifier).state++;
    return updated;
  }

  Future<void> delete(String offerId) async {
    await ref.read(serviceMarketplaceRepositoryProvider).deleteOffer(offerId);
    state = AsyncData([
      for (final o in state.valueOrNull ?? const [])
        if (o.id != offerId) o,
    ]);
    ref.read(offersRevisionProvider.notifier).state++;
  }

  /// The founder's approval switch, as a write against *this* list.
  ///
  /// `OffersAdmin.setActive` does the same call, but only bumps the revision —
  /// it has no list of its own to correct, so a management screen driven by it
  /// would keep rendering the stale `activeByFounder` until its next fetch.
  Future<void> setActive(String offerId, {required bool active}) async {
    final updated = await ref
        .read(serviceMarketplaceRepositoryProvider)
        .setOfferActive(offerId, active: active);
    state = AsyncData([
      for (final o in state.valueOrNull ?? const [])
        if (o.id == updated.id) updated else o,
    ]);
    ref.read(offersRevisionProvider.notifier).state++;
  }
}

final adminPromotionsProvider =
    AsyncNotifierProvider<AdminPromotionsNotifier, List<Promotion>>(
      AdminPromotionsNotifier.new,
    );

class AdminPromotionsNotifier extends AsyncNotifier<List<Promotion>> {
  @override
  Future<List<Promotion>> build() => ref
      .read(serviceMarketplaceRepositoryProvider)
      .fetchAllPromotionsForFounder();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(serviceMarketplaceRepositoryProvider)
          .fetchAllPromotionsForFounder(),
    );
  }

  Future<Promotion> create({
    required L title,
    required L body,
    required IconData icon,
    L? badge,
    String? providerId,
    String? offeringId,
    String? query,
    Set<String> regions = const {},
    DateTime? endsAt,
  }) async {
    final created = await ref
        .read(serviceMarketplaceRepositoryProvider)
        .createPromotion(
          title: title,
          body: body,
          icon: icon,
          badge: badge,
          providerId: providerId,
          offeringId: offeringId,
          query: query,
          regions: regions,
          endsAt: endsAt,
        );
    state = AsyncData([...state.valueOrNull ?? const [], created]);
    ref.read(promotionsRevisionProvider.notifier).state++;
    return created;
  }

  Future<Promotion> edit(
    String promotionId, {
    required L title,
    required L body,
    required IconData icon,
    L? badge,
    String? providerId,
    String? offeringId,
    String? query,
    Set<String> regions = const {},
    DateTime? endsAt,
  }) async {
    final updated = await ref
        .read(serviceMarketplaceRepositoryProvider)
        .updatePromotion(
          promotionId,
          title: title,
          body: body,
          icon: icon,
          badge: badge,
          providerId: providerId,
          offeringId: offeringId,
          query: query,
          regions: regions,
          endsAt: endsAt,
        );
    state = AsyncData([
      for (final p in state.valueOrNull ?? const [])
        if (p.id == updated.id) updated else p,
    ]);
    ref.read(promotionsRevisionProvider.notifier).state++;
    return updated;
  }

  Future<void> delete(String promotionId) async {
    await ref
        .read(serviceMarketplaceRepositoryProvider)
        .deletePromotion(promotionId);
    state = AsyncData([
      for (final p in state.valueOrNull ?? const [])
        if (p.id != promotionId) p,
    ]);
    ref.read(promotionsRevisionProvider.notifier).state++;
  }
}

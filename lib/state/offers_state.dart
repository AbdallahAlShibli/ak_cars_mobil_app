import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/offer.dart';
import '../di/providers.dart';

/// Every offer the platform holds, each with the reason it is not live.
///
/// The founder panel's list, and the reason the panel can explain itself: a
/// workshop asking "why is my offer not showing?" gets an answer from the same
/// validation the home page runs, not a second opinion.
final offersAuditProvider =
    Provider<List<({Offer offer, OfferRejection? rejection})>>((ref) {
  // Depends on the revision so a founder's toggle repaints this list.
  ref.watch(offersRevisionProvider);
  return ref.watch(serviceMarketplaceRepositoryProvider).auditOffers();
});

/// Bumped after any write to an offer.
///
/// The marketplace repository holds its catalogue in warm caches rather than
/// in Riverpod state — reads are synchronous all over the app — so a write has
/// to announce itself. Everything that renders an offer watches this, which is
/// why switching one off in the founder panel empties the home rail on the
/// next frame instead of on the next cold start.
final offersRevisionProvider = StateProvider<int>((ref) => 0);

/// The founder's switch on one offer.
class OffersAdmin {
  const OffersAdmin(this._ref);

  final Ref _ref;

  Future<void> setActive(String offerId, {required bool active}) async {
    await _ref
        .read(serviceMarketplaceRepositoryProvider)
        .setOfferActive(offerId, active: active);
    _ref.read(offersRevisionProvider.notifier).state++;
  }
}

final offersAdminProvider = Provider<OffersAdmin>(OffersAdmin.new);

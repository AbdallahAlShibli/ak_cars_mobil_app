/// Barrel for the domain models.
///
/// Every model here is immutable, has a `const` constructor, and supports
/// `fromJson` / `toJson` / `copyWith` so it can be handed straight to a REST
/// client without a parallel DTO hierarchy.
library;

export 'add_on.dart';
export 'app_notification.dart';
export 'app_role.dart';
export 'car.dart';
export 'car_listing.dart';
export 'car_make.dart';
export 'cars_filter.dart';
export 'challenge.dart';
export 'chat_message.dart';
export 'escrow.dart';
export 'gallery_listing.dart';
export 'location_catalog.dart';
export 'maintenance.dart';
export 'offer.dart';
export 'order.dart';
export 'powertrain.dart';
export 'product.dart';
export 'promotion.dart';
export 'proof_of_work.dart';
export 'quote.dart';
export 'recommendation.dart';
export 'review.dart';
export 'service_category.dart';
export 'service_offering.dart';
export 'service_provider.dart';
export 'service_request.dart';
export 'service_stats.dart';
export 'shop_filter.dart';
export 'spec_catalog.dart';
export 'spec_option.dart';
export 'user_profile.dart';
export 'vehicle_catalog.dart';

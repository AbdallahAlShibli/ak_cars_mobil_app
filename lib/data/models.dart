import 'package:flutter/material.dart';

/// A car saved in the user's garage, or selected ad-hoc for a request.
class Car {
  const Car({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    this.plate,
    this.serviceDueKm,
  });

  final String id;
  final String make;
  final String model;
  final int year;
  final String? plate;
  final int? serviceDueKm;

  String get label => '$make $model $year';

  Car copyWith({String? plate}) => Car(
        id: id,
        make: make,
        model: model,
        year: year,
        plate: plate ?? this.plate,
        serviceDueKm: serviceDueKm,
      );
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.providerCount,
    this.fromPrice,
    this.note,
    this.emergency = false,
    this.badge,
    this.primary = false,
  });

  final String id;
  final String name;
  final IconData icon;
  final int providerCount;
  final double? fromPrice;
  final String? note;
  final bool emergency;

  /// Promo ribbon shown on the card (e.g. "FREE OIL").
  final String? badge;

  /// Primary = big "Car service" package card; otherwise an
  /// "Other services" tile.
  final bool primary;
}

enum Fulfillment { workshop, pickup, roadside }

extension FulfillmentX on Fulfillment {
  String get label => switch (this) {
        Fulfillment.workshop => 'Visit workshop',
        Fulfillment.pickup => 'Pickup & return',
        Fulfillment.roadside => 'Roadside (emergency)',
      };

  IconData get icon => switch (this) {
        Fulfillment.workshop => Icons.storefront_outlined,
        Fulfillment.pickup => Icons.local_shipping_outlined,
        Fulfillment.roadside => Icons.warning_amber_rounded,
      };
}

class ServiceProvider {
  const ServiceProvider({
    required this.id,
    required this.name,
    required this.area,
    required this.region,
    required this.distanceKm,
    required this.verified,
    required this.fulfillments,
    this.pickupFee = 3,
  });

  final String id;
  final String name;
  final String area;
  final String region;
  final double distanceKm;
  final bool verified;
  final Set<Fulfillment> fulfillments;
  final double pickupFee;
}

class ServiceOffering {
  const ServiceOffering({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.provider,
    required this.description,
    this.price,
    this.durationMin,
  });

  final String id;
  final String categoryId;
  final String name;
  final ServiceProvider provider;
  final String description;
  final double? price; // null => quote after inspection
  final int? durationMin;
}

class AddOn {
  const AddOn({
    required this.id,
    required this.name,
    required this.price,
    required this.isPart,
  });

  final String id;
  final String name;
  final double price;
  final bool isPart;
}

enum RequestStatus {
  requested,
  accepted,
  inProgress,
  proofSubmitted,
  completed,
  disputed,
}

extension RequestStatusX on RequestStatus {
  String get label => switch (this) {
        RequestStatus.requested => 'Waiting for provider',
        RequestStatus.accepted => 'Accepted',
        RequestStatus.inProgress => 'In progress',
        RequestStatus.proofSubmitted => 'Awaiting your approval',
        RequestStatus.completed => 'Completed',
        RequestStatus.disputed => 'Disputed',
      };
}

class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.offering,
    required this.car,
    required this.plate,
    required this.fulfillment,
    required this.slot,
    required this.addOns,
    required this.total,
    required this.status,
  });

  final String id;
  final ServiceOffering offering;
  final Car car;
  final String plate;
  final Fulfillment fulfillment;
  final String slot;
  final List<AddOn> addOns;
  final double total;
  final RequestStatus status;

  ServiceRequest copyWith({RequestStatus? status}) => ServiceRequest(
        id: id,
        offering: offering,
        car: car,
        plate: plate,
        fulfillment: fulfillment,
        slot: slot,
        addOns: addOns,
        total: total,
        status: status ?? this.status,
      );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.providerId,
    required this.region,
    required this.icon,
    required this.fits,
    this.rating = 4.5,
    this.oldPrice,
    this.description,
    this.photoCount = 3,
  });

  final String id;
  final String name;
  final double price;
  final String categoryId;
  final String providerId;
  final String region;
  final IconData icon;

  /// Buyer rating (staging data).
  final double rating;

  /// Pre-discount price — shown struck through when on offer.
  final double? oldPrice;

  final String? description;
  final int photoCount;

  bool get onOffer => oldPrice != null && oldPrice! > price;

  String get details =>
      description ??
      'Genuine quality part with 6-month warranty. Inspected and '
          'guaranteed by the selling workshop.';

  /// 'any' or 'Make Model' keys this part fits.
  final Set<String> fits;

  bool fitsCar(Car? car) {
    if (car == null || fits.contains('any')) return true;
    return fits.contains('${car.make} ${car.model}');
  }
}

class ShopFilter {
  const ShopFilter({
    this.car,
    this.categoryId,
    this.providerId,
    this.region,
    this.minPrice = 0,
    this.maxPrice = 100,
  });

  final Car? car;
  final String? categoryId;
  final String? providerId;
  final String? region;
  final double minPrice;
  final double maxPrice;

  int get activeCount {
    var n = 0;
    if (car != null) n++;
    if (categoryId != null) n++;
    if (providerId != null) n++;
    if (region != null) n++;
    if (minPrice > 0 || maxPrice < 100) n++;
    return n;
  }

  ShopFilter copyWith({
    Car? Function()? car,
    String? Function()? categoryId,
    String? Function()? providerId,
    String? Function()? region,
    double? minPrice,
    double? maxPrice,
  }) =>
      ShopFilter(
        car: car != null ? car() : this.car,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        providerId: providerId != null ? providerId() : this.providerId,
        region: region != null ? region() : this.region,
        minPrice: minPrice ?? this.minPrice,
        maxPrice: maxPrice ?? this.maxPrice,
      );
}

class CarListing {
  const CarListing({
    required this.id,
    required this.title,
    required this.year,
    required this.km,
    required this.region,
    required this.price,
    required this.spec,
    required this.icon,
    required this.photoCount,
  });

  final String id;
  final String title;
  final int year;
  final int km;
  final String region;
  final double price;
  final String spec;
  final IconData icon;
  final int photoCount;
}

enum OrderStatus { placed, processing, delivered, completed }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.placed => 'Placed',
        OrderStatus.processing => 'Being prepared',
        OrderStatus.delivered => 'Delivered — confirm receipt',
        OrderStatus.completed => 'Completed',
      };

  /// Escrow is held until the buyer confirms they received the parts.
  bool get held => this != OrderStatus.completed;
}

class OrderItem {
  const OrderItem({required this.product, required this.qty});

  final Product product;
  final int qty;

  double get total => product.price * qty;
}

class Order {
  const Order({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    required this.placedAt,
  });

  final String id;
  final List<OrderItem> items;
  final double total;
  final OrderStatus status;
  final DateTime placedAt;

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        items: items,
        total: total,
        status: status ?? this.status,
        placedAt: placedAt,
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.time,
    this.read = false,
    this.route,
  });

  final String id;
  final String title;
  final String body;
  final IconData icon;
  final DateTime time;
  final bool read;
  final String? route;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        icon: icon,
        time: time,
        read: read ?? this.read,
        route: route,
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromUser,
    required this.text,
    required this.time,
  });

  final String id;
  final bool fromUser;
  final String text;
  final DateTime time;
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.phone,
    required this.email,
    required this.region,
    required this.address,
  });

  final String name;
  final String phone;
  final String email;
  final String region;
  final String address;
}

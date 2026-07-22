import 'dart:convert';

import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/json/icon_codec.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_cars_data.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_catalog_data.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_garage_data.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_shop_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the models are genuinely wire-ready: every one survives a trip
/// through `toJson` → `jsonEncode` → `jsonDecode` → `fromJson` unchanged.
///
/// Encoding through real JSON (rather than passing the map straight back)
/// matters — it catches fields that hold a Dart object a real HTTP body could
/// never carry.
void main() {
  T roundTrip<T>(Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) =>
      parse(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);

  group('round-trips through encoded JSON', () {
    test('Car', () {
      const car = Car(
        id: 'c1',
        make: 'Toyota',
        model: 'Camry',
        year: 2021,
        plate: '1234 AB',
        serviceDueKm: 5000,
      );
      expect(roundTrip(car.toJson(), Car.fromJson), car);
    });

    test('UserProfile', () {
      const profile = UserProfile(
        name: 'Salim',
        phone: '+968 9200 1234',
        email: 'salim@example.om',
        region: 'North Al Batinah',
        address: 'Sohar',
      );
      expect(roundTrip(profile.toJson(), UserProfile.fromJson), profile);
    });

    test('ServiceProvider keeps its fulfillment set', () {
      for (final provider in MockServiceData.providers) {
        final decoded =
            roundTrip(provider.toJson(), ServiceProvider.fromJson);
        expect(decoded, provider);
        expect(decoded.fulfillments, provider.fulfillments);
      }
    });

    test('ServiceCategory keeps its icon and bilingual text', () {
      for (final category in MockServiceData.categories) {
        final decoded =
            roundTrip(category.toJson(), ServiceCategory.fromJson);
        expect(decoded, category);
        expect(decoded.icon, category.icon);
        expect(decoded.name.ar, category.name.ar);
      }
    });

    test('ServiceOffering keeps its expanded provider', () {
      for (final offering in MockServiceData.offerings) {
        expect(roundTrip(offering.toJson(), ServiceOffering.fromJson),
            offering);
      }
    });

    test('Product', () {
      for (final product in MockShopData.products) {
        expect(roundTrip(product.toJson(), Product.fromJson), product);
      }
    });

    test('GalleryListing keeps its colour swatches', () {
      for (final listing in MockCarsData.galleryListings) {
        final decoded =
            roundTrip(listing.toJson(), GalleryListing.fromJson);
        expect(decoded.id, listing.id);
        expect(decoded.exteriorSwatch, listing.exteriorSwatch);
        expect(decoded.interiorSwatch, listing.interiorSwatch);
        expect(decoded.tint, listing.tint);
        expect(decoded.icon, listing.icon);
        expect(decoded.price, listing.price);
        expect(decoded.engineLitres, listing.engineLitres);
      }
    });

    test('CarListing', () {
      for (final listing in MockCarsData.homeListings) {
        expect(roundTrip(listing.toJson(), CarListing.fromJson), listing);
      }
    });

    test('Order with nested items', () {
      final order = Order(
        id: 'A1200',
        items: [OrderItem(product: MockShopData.products.first, qty: 3)],
        total: 10.5,
        status: OrderStatus.delivered,
        placedAt: DateTime.utc(2026, 7, 21, 9, 30),
      );
      expect(roundTrip(order.toJson(), Order.fromJson), order);
    });

    test('ServiceRequest with nested offering, car and add-ons', () {
      final request = ServiceRequest(
        id: '1042',
        offering: MockServiceData.offerings.first,
        car: const Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2021),
        plate: '1234 AB',
        fulfillment: Fulfillment.pickup,
        slot: 'Mon 3 Aug · 10:30',
        addOns: MockServiceData.addOnsByProvider['p1']!,
        total: 27.5,
        status: RequestStatus.proofSubmitted,
      );
      expect(roundTrip(request.toJson(), ServiceRequest.fromJson), request);
    });

    test('AppNotification', () {
      final notification = AppNotification(
        id: 'n1',
        title: const L('عنوان', 'Title'),
        body: const L('نص', 'Body'),
        icon: Icons.fact_check_outlined,
        time: DateTime.utc(2026, 7, 21, 12),
        read: true,
        route: '/track/1042',
      );
      expect(
          roundTrip(notification.toJson(), AppNotification.fromJson),
          notification);
    });

    test('ChatMessage', () {
      final message = ChatMessage(
        id: 'm1',
        fromUser: true,
        text: 'Any update?',
        time: DateTime.utc(2026, 7, 21, 13),
      );
      expect(roundTrip(message.toJson(), ChatMessage.fromJson), message);
    });

    test('MaintenanceLog with typed interval maps', () {
      final log = MockGarageData.maintenanceLog();
      final decoded = roundTrip(log.toJson(), MaintenanceLog.fromJson);
      expect(decoded.currentOdometerKm, log.currentOdometerKm);
      expect(decoded.records, log.records);
      expect(decoded.kmIntervals, log.kmIntervals);
      expect(decoded.monthIntervals, log.monthIntervals);
    });

    test('ChallengeBoard', () {
      const board = MockGarageData.challengeBoard;
      final decoded = roundTrip(board.toJson(), ChallengeBoard.fromJson);
      expect(decoded.current, board.current);
      expect(decoded.next, board.next);
      expect(decoded.history, board.history);
      expect(decoded.points, board.points);
    });

    test('SpecCatalog', () {
      const catalog = MockCatalogData.specCatalog;
      final decoded = roundTrip(catalog.toJson(), SpecCatalog.fromJson);
      expect(decoded.bodyTypes, catalog.bodyTypes);
      expect(decoded.cylinders, catalog.cylinders);
      expect(decoded.engineSizes, catalog.engineSizes);
      expect(decoded.swatches, catalog.swatches);
    });

    test('VehicleCatalog and LocationCatalog', () {
      const vehicles = MockCatalogData.vehicleCatalog;
      final decodedVehicles =
          roundTrip(vehicles.toJson(), VehicleCatalog.fromJson);
      expect(decodedVehicles.makes, vehicles.makes);
      expect(decodedVehicles.trimsByModel, vehicles.trimsByModel);
      expect(decodedVehicles.plateLetters, vehicles.plateLetters);

      const locations = MockCatalogData.locationCatalog;
      final decodedLocations =
          roundTrip(locations.toJson(), LocationCatalog.fromJson);
      expect(decodedLocations.governorates, locations.governorates);
      expect(decodedLocations.arabicNames, locations.arabicNames);
    });
  });

  group('degrades safely on unexpected payloads', () {
    test('an unknown icon key falls back rather than throwing', () {
      final decoded = ServiceCategory.fromJson({
        'id': 'x',
        'name': {'ar': 'أ', 'en': 'A'},
        'icon': 'not_a_registered_icon',
        'providerCount': 1,
      });
      expect(decoded.icon, IconCodec.fallback);
    });

    test('an unknown enum value falls back to the default', () {
      final decoded = Order.fromJson({
        'id': 'A1',
        'items': const [],
        'total': 0,
        'status': 'refunded_by_finance',
        'placedAt': '2026-07-21T00:00:00Z',
      });
      expect(decoded.status, OrderStatus.placed);
    });

    test('a missing identity field is reported, not silently defaulted', () {
      expect(() => Car.fromJson(const {'make': 'Toyota'}), throwsA(isA<Object>()));
    });

    test('L accepts both the object form and a bare string', () {
      expect(L.fromJson({'ar': 'أ', 'en': 'A'}), const L('أ', 'A'));
      expect(L.fromJson('Solo'), const L('Solo', 'Solo'));
    });
  });
}

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

    test('Car keeps its powertrain', () {
      const ev = Car(
        id: 'ev1',
        make: 'Tesla',
        model: 'Model Y',
        year: 2024,
        powertrain: Powertrain.electric,
      );
      final decoded = roundTrip(ev.toJson(), Car.fromJson);
      expect(decoded, ev);
      expect(decoded.powertrain, Powertrain.electric);
      expect(decoded.isElectric, isTrue);

      // "Not recorded" survives as null rather than becoming a default.
      const unstated = Car(id: 'u1', make: 'Nissan', model: 'Patrol', year: 2019);
      expect(roundTrip(unstated.toJson(), Car.fromJson).powertrain, isNull);

      // The wire also accepts a marketplace fuel value, so a car saved from an
      // ad parses without a translation table at the call site.
      expect(
        Car.fromJson(const {
          'id': 'x',
          'make': 'BMW',
          'model': '330e',
          'year': 2023,
          'powertrain': 'Plug-in Hybrid',
        }).powertrain,
        Powertrain.pluginHybrid,
      );
    });

    test('UserProfile', () {
      const profile = UserProfile(
        name: 'Salim',
        phone: '+968 9200 1234',
        email: 'salim@example.om',
        region: 'North Al Batinah',
        wilayat: 'Sohar',
        address: 'Al Hambar',
      );
      expect(roundTrip(profile.toJson(), UserProfile.fromJson), profile);
    });

    test('ServiceProvider keeps its fulfillment and capability sets', () {
      for (final provider in MockServiceData.providers) {
        final decoded =
            roundTrip(provider.toJson(), ServiceProvider.fromJson);
        expect(decoded, provider);
        expect(decoded.fulfillments, provider.fulfillments);
        expect(decoded.capabilities, provider.capabilities);
      }
      // An empty capability set is the normal case, so at least one provider
      // must carry a non-empty one for this to prove anything.
      expect(
        MockServiceData.providers.any((p) => p.capabilities.isNotEmpty),
        isTrue,
      );
    });

    test('ServiceCategory keeps its icon and bilingual text', () {
      for (final category in MockServiceData.categories) {
        final decoded =
            roundTrip(category.toJson(), ServiceCategory.fromJson);
        expect(decoded, category);
        expect(decoded.icon, category.icon);
        expect(decoded.name.ar, category.name.ar);
        // The two fields that decide who may book it and who may sell it.
        expect(decoded.powertrains, category.powertrains);
        expect(decoded.requires, category.requires);
      }
      // …and at least one category actually exercises them.
      final ev = MockServiceData.categories.firstWhere((c) => c.evOnly);
      expect(ev.powertrains, isNotEmpty);
      expect(ev.requires, isNotNull);
    });

    test('ServiceOffering keeps its expanded provider', () {
      for (final offering in MockServiceData.offerings) {
        expect(roundTrip(offering.toJson(), ServiceOffering.fromJson),
            offering);
      }
    });

    test('Product keeps its powertrain restriction', () {
      for (final product in MockShopData.products) {
        final decoded = roundTrip(product.toJson(), Product.fromJson);
        expect(decoded, product);
        expect(decoded.powertrains, product.powertrains);
      }
      final cable =
          MockShopData.products.firstWhere((p) => p.id == 'pr7');
      expect(cable.powertrains, isNotEmpty);
      expect(roundTrip(cable.toJson(), Product.fromJson).evOnly, isTrue);
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
        // EV facts, including the difference between "no" and "not stated".
        expect(decoded.rangeKm, listing.rangeKm);
        expect(decoded.batteryWarrantyUntilYear,
            listing.batteryWarrantyUntilYear);
        expect(decoded.chargerIncluded, listing.chargerIncluded);
      }
      final ev = MockCarsData.galleryListings
          .firstWhere((l) => l.fuel == 'Electric');
      expect(ev.rangeKm, isNotNull);
      expect(ev.batteryWarrantyUntilYear, isNotNull);
      expect(ev.chargerIncluded, isNotNull);
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
        escrow: EscrowState.awaitingApproval,
        createdAt: DateTime.utc(2026, 7, 21, 9),
        awaitingApprovalSince: DateTime.utc(2026, 7, 21, 15),
        disputeNote: '',
        // The maintenance line this booking was raised from, carried so the
        // completed booking knows which schedule to log against.
        maintenanceItemKey: 'oil',
        proof: ProofOfWork(
          id: 'proof-1042',
          requestId: '1042',
          notes: 'Oil and filter replaced.',
          submittedAt: DateTime.utc(2026, 7, 21, 15),
          media: const [
            ProofMedia(
              id: 'm1',
              uri: 'https://cdn.example.com/proof/1042-1.jpg',
              caption: 'Old filter',
            ),
          ],
        ),
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

    test('MaintenanceBook with records, custom items and intervals', () {
      final book = MaintenanceBook(
        carId: 'c1',
        currentOdometerKm: 128450,
        odometerUpdatedAt: DateTime(2026, 7, 26),
        previousOdometerKm: 126000,
        previousOdometerAt: DateTime(2026, 6, 1),
        records: [
          ServiceRecord(
            id: 'r-oil-1',
            title: const L('تغيير زيت + فلتر', 'Oil + filter change'),
            workshop: 'Gulf Auto Care',
            odometerKm: 123000,
            date: DateTime(2026, 3, 14),
            itemKey: MaintenanceType.oil.key,
            notes: '5W-30 synthetic',
          ),
          ServiceRecord(
            id: 'booking-1042',
            title: const L('صيانة سريعة', 'Express service'),
            workshop: 'Al Noor Workshop',
            odometerKm: 127000,
            date: DateTime(2026, 6, 20),
            itemKey: 'custom-1',
            bookingId: '1042',
          ),
        ],
        customItems: const [
          CustomMaintenanceItem(
            id: 'custom-1',
            title: 'Wiper blades',
            intervalKm: 20000,
            intervalMonths: 12,
          ),
        ],
        kmIntervals: const {'oil': 7000},
        monthIntervals: const {'tyres': 6, 'custom-1': 12},
      );

      final decoded = roundTrip(book.toJson(), MaintenanceBook.fromJson);
      expect(decoded, book);
      expect(decoded.carId, 'c1');
      expect(decoded.records.first.notes, '5W-30 synthetic');
      // The booking link survives — it is what keeps a repeated completion
      // event from writing the same service twice.
      expect(decoded.hasRecordForBooking('1042'), isTrue);
      expect(decoded.customItems.single.title, 'Wiper blades');
      expect(decoded.kmIntervals, book.kmIntervals);
      expect(decoded.monthIntervals, book.monthIntervals);
    });

    test('ServiceRecord decodes the pre-per-car "type" wire name', () {
      // Books written before maintenance became per-car filed the item under
      // `type`; those rows still have to land on the right schedule line.
      final decoded = ServiceRecord.fromJson({
        'id': 'legacy-1',
        'title': {'ar': 'زيت', 'en': 'Oil'},
        'workshop': 'Gulf Auto Care',
        'odometerKm': 123000,
        'date': DateTime(2026, 3, 14).toIso8601String(),
        'type': 'oil',
      });
      expect(decoded.itemKey, 'oil');
      expect(decoded.type, MaintenanceType.oil);
    });

    test('ChallengeBoard', () {
      for (final board in const [
        MockGarageData.challengeBoard,
        MockGarageData.evChallengeBoard,
      ]) {
        final decoded = roundTrip(board.toJson(), ChallengeBoard.fromJson);
        expect(decoded.current, board.current);
        expect(decoded.next, board.next);
        expect(decoded.history, board.history);
        expect(decoded.points, board.points);
      }
      // The EV challenge names its own maintenance record, so the record it
      // writes says what the owner actually did.
      final ev = MockGarageData.evChallengeBoard.current!;
      expect(ev.recordTitle, isNotNull);
      expect(
        roundTrip(ev.toJson(), WeeklyChallenge.fromJson).recordTitle,
        ev.recordTitle,
      );
    });

    test('Promotion', () {
      for (final promotion in MockServiceData.promotions) {
        final decoded = roundTrip(promotion.toJson(), Promotion.fromJson);
        expect(decoded, promotion);
        // The icon survives as a registry key, not as a raw code point.
        expect(IconCodec.encode(promotion.icon), isNotNull,
            reason: '${promotion.id} uses an icon the registry cannot name');
      }
      // An expiry is a real DateTime on the way out and back.
      final dated =
          MockServiceData.promotions.firstWhere((p) => p.endsAt != null);
      expect(roundTrip(dated.toJson(), Promotion.fromJson).endsAt, dated.endsAt);
    });

    test('CategoryDemand and WorkshopRating', () {
      for (final demand in MockServiceData.categoryDemand) {
        expect(roundTrip(demand.toJson(), CategoryDemand.fromJson), demand);
      }
      for (final rating in MockServiceData.workshopRatings) {
        expect(roundTrip(rating.toJson(), WorkshopRating.fromJson), rating);
      }
      // A workshop the marketplace publishes no job count for keeps a null,
      // rather than gaining a zero on the way through.
      const partial =
          WorkshopRating(providerId: 'p99', rating: 4.4, reviews: 31);
      expect(roundTrip(partial.toJson(), WorkshopRating.fromJson).completedJobs,
          isNull);
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

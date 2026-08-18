import 'dart:convert';

import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/json/icon_codec.dart';
import 'fakes/data/mock_cars_data.dart';
import 'fakes/data/mock_catalog_data.dart';
import 'fakes/data/mock_garage_data.dart';
import 'fakes/data/mock_service_data.dart';
import 'fakes/data/mock_shop_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';
import 'fakes/data/mock_ids.dart';

/// Proves the models are genuinely wire-ready: every one survives a trip
/// through `toJson` → `jsonEncode` → `jsonDecode` → `fromJson` unchanged.
///
/// Encoding through real JSON (rather than passing the map straight back)
/// matters — it catches fields that hold a Dart object a real HTTP body could
/// never carry.
void main() {
  T roundTrip<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) => parse(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);

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
      const unstated = Car(
        id: 'u1',
        make: 'Nissan',
        model: 'Patrol',
        year: 2019,
      );
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
        final decoded = roundTrip(provider.toJson(), ServiceProvider.fromJson);
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
        final decoded = roundTrip(category.toJson(), ServiceCategory.fromJson);
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
        expect(
          roundTrip(offering.toJson(), ServiceOffering.fromJson),
          offering,
        );
      }
    });

    test('Product keeps its powertrain restriction', () {
      for (final product in MockShopData.products) {
        final decoded = roundTrip(product.toJson(), Product.fromJson);
        expect(decoded, product);
        expect(decoded.powertrains, product.powertrains);
      }
      final cable = MockShopData.products.firstWhere((p) => p.id == mockIdPr7);
      expect(cable.powertrains, isNotEmpty);
      expect(roundTrip(cable.toJson(), Product.fromJson).evOnly, isTrue);
    });

    test('GalleryListing keeps its colour swatches', () {
      for (final listing in MockCarsData.galleryListings) {
        final decoded = roundTrip(listing.toJson(), GalleryListing.fromJson);
        expect(decoded.id, listing.id);
        expect(decoded.exteriorSwatch, listing.exteriorSwatch);
        expect(decoded.interiorSwatch, listing.interiorSwatch);
        expect(decoded.tint, listing.tint);
        expect(decoded.icon, listing.icon);
        expect(decoded.price, listing.price);
        expect(decoded.engineLitres, listing.engineLitres);
        // EV facts, including the difference between "no" and "not stated".
        expect(decoded.rangeKm, listing.rangeKm);
        expect(
          decoded.batteryWarrantyUntilYear,
          listing.batteryWarrantyUntilYear,
        );
        expect(decoded.chargerIncluded, listing.chargerIncluded);
      }
      final ev = MockCarsData.galleryListings.firstWhere(
        (l) => l.fuel == 'Electric',
      );
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
        addOns: MockServiceData.addOnsByProvider[mockIdP1]!,
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
            MediaAttachment(
              id: 'ef0b2f2c-6c1e-4a9b-9a1e-0c5f4b2d7a10',
              base64Data: testPngBase64,
              mimeType: 'image/png',
              fileName: '1042-1.png',
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
        icon: LucideIcons.clipboardList,
        time: DateTime.utc(2026, 7, 21, 12),
        read: true,
        route: '/track/1042',
      );
      expect(
        roundTrip(notification.toJson(), AppNotification.fromJson),
        notification,
      );
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
        expect(
          IconCodec.encode(promotion.icon),
          isNotNull,
          reason: '${promotion.id} uses an icon the registry cannot name',
        );
      }
      // An expiry is a real DateTime on the way out and back.
      final dated = MockServiceData.promotions.firstWhere(
        (p) => p.endsAt != null,
      );
      expect(
        roundTrip(dated.toJson(), Promotion.fromJson).endsAt,
        dated.endsAt,
      );
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
      const partial = WorkshopRating(
        providerId: 'p99',
        rating: 4.4,
        reviews: 31,
      );
      expect(
        roundTrip(partial.toJson(), WorkshopRating.fromJson).completedJobs,
        isNull,
      );
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
      final decodedVehicles = roundTrip(
        vehicles.toJson(),
        VehicleCatalog.fromJson,
      );
      expect(decodedVehicles.makes, vehicles.makes);
      expect(decodedVehicles.trimsByModel, vehicles.trimsByModel);
      expect(decodedVehicles.plateLetters, vehicles.plateLetters);

      const locations = MockCatalogData.locationCatalog;
      final decodedLocations = roundTrip(
        locations.toJson(),
        LocationCatalog.fromJson,
      );
      expect(decodedLocations.governorates, locations.governorates);
      expect(decodedLocations.arabicNames, locations.arabicNames);
    });

    test('InventoryItem keeps its unit and low-stock derivation', () {
      final item = InventoryItem(
        id: 'i1',
        name: const L('فلتر زيت', 'Oil filter'),
        sku: 'OIL-FLT-001',
        partNumber: 'PN-99',
        brand: 'Toyota',
        categoryId: 'cat-1',
        unitCost: 2.5,
        sellPrice: 5,
        quantityOnHand: 4,
        reorderLevel: 10,
        unit: InventoryUnit.piece,
        location: 'Bay 1',
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 20),
      );
      final decoded = roundTrip(item.toJson(), InventoryItem.fromJson);
      expect(decoded, item);
      expect(decoded.isLowStock, isTrue);
      expect(decoded.isOutOfStock, isFalse);
    });

    test('InventoryMovement keeps its reason and optional requestId', () {
      final movement = InventoryMovement(
        id: 'm1',
        itemId: 'i1',
        delta: -2,
        reason: InventoryMovementReason.consumed,
        requestId: 'r1',
        note: 'Used on job',
        at: DateTime.utc(2026, 7, 21, 9),
        byUserId: 'u1',
      );
      expect(
        roundTrip(movement.toJson(), InventoryMovement.fromJson),
        movement,
      );
    });

    test('WorkshopStaff keeps its role and specialties', () {
      final staff = WorkshopStaff(
        id: 's1',
        name: 'Said Al Harthy',
        phone: '+968 9200 0002',
        role: WorkshopStaffRole.technician,
        specialties: const ['brakes', 'suspension'],
        joinedAt: DateTime.utc(2026, 1, 1),
        userId: 'u2',
        openJobCount: 3,
      );
      final decoded = roundTrip(staff.toJson(), WorkshopStaff.fromJson);
      expect(decoded, staff);
      expect(decoded.role.canManage, isFalse);

      final manager = staff.copyWith(role: WorkshopStaffRole.manager);
      expect(manager.role.canManage, isTrue);
    });

    test('WorkshopCustomer keeps its tag set and omits phone when null', () {
      final customer = WorkshopCustomer(
        userId: 'u3',
        name: 'Nasser Al Balushi',
        carCount: 2,
        bookingsCount: 5,
        lifetimeGross: 340,
        lastBookingAt: DateTime.utc(2026, 7, 20),
        avgRatingGiven: 4.5,
        tags: const {WorkshopCustomerTag.repeat},
      );
      final decoded = roundTrip(customer.toJson(), WorkshopCustomer.fromJson);
      expect(decoded, customer);
      expect(decoded.phone, isNull);
    });

    test('WorkshopCustomerDetail keeps its bookings and notes', () {
      final detail = WorkshopCustomerDetail(
        customer: WorkshopCustomer(
          userId: 'u3',
          name: 'Nasser Al Balushi',
          carCount: 1,
          bookingsCount: 1,
          lifetimeGross: 27.5,
          lastBookingAt: DateTime.utc(2026, 7, 20),
          tags: const {WorkshopCustomerTag.newCustomer},
        ),
        bookings: [
          ServiceRequest(
            id: '1042',
            offering: MockServiceData.offerings.first,
            car: const Car(
              id: 'c1',
              make: 'Toyota',
              model: 'Camry',
              year: 2021,
            ),
            plate: '1234 AB',
            fulfillment: Fulfillment.workshop,
            slot: 'Mon 3 Aug · 10:30',
            addOns: const [],
            total: 27.5,
            escrow: EscrowState.releasedToWorkshop,
            createdAt: DateTime.utc(2026, 7, 20, 9),
          ),
        ],
        notes: [
          WorkshopCustomerNote(
            id: 'n1',
            body: 'Prefers morning slots.',
            at: DateTime.utc(2026, 7, 20, 10),
          ),
        ],
      );
      final decoded = roundTrip(
        detail.toJson(),
        WorkshopCustomerDetail.fromJson,
      );
      expect(decoded.customer, detail.customer);
      expect(decoded.bookings, detail.bookings);
      expect(decoded.notes.single.body, 'Prefers morning slots.');
    });

    test('WorkshopSchedule and WorkshopDaySchedule', () {
      const schedule = WorkshopSchedule(
        hours: L('السبت–الخميس ٨:٠٠–٢٠:٠٠', 'Sat–Thu 8:00–20:00'),
        slotTemplate: ['09:00', '11:00', '13:00'],
        capacityPerSlot: 2,
        closedDays: ['Friday'],
      );
      final decodedSchedule = WorkshopSchedule.fromJson(
        jsonDecode(jsonEncode(schedule.toJson())) as Map<String, dynamic>,
      );
      expect(decodedSchedule.hours, schedule.hours);
      expect(decodedSchedule.slotTemplate, schedule.slotTemplate);
      expect(decodedSchedule.capacityPerSlot, schedule.capacityPerSlot);
      expect(decodedSchedule.closedDays, schedule.closedDays);

      final day = WorkshopDaySchedule(
        date: DateTime.utc(2026, 8, 12),
        slots: const ['09:00', '11:00'],
        bookedSlots: const ['09:00'],
        assignedJobs: const [],
      );
      expect(day.isAvailable('09:00'), isFalse);
      expect(day.isAvailable('11:00'), isTrue);
      final decodedDay = WorkshopDaySchedule.fromJson(
        jsonDecode(jsonEncode(day.toJson())) as Map<String, dynamic>,
      );
      expect(decodedDay.slots, day.slots);
      expect(decodedDay.bookedSlots, day.bookedSlots);
    });

    test('WorkshopSummary keeps every nested figure', () {
      final json = {
        'provider': MockServiceData.providers.first.toJson(),
        'jobs': {
          'needsYou': 4,
          'inProgress': 3,
          'awaitingApproval': 2,
          'overdue': 1,
          'todays': 6,
        },
        'money': {
          'heldInEscrow': 4200.0,
          'releasedGross': 18900.0,
          'totalCommission': 1890.0,
          'payoutDue': 3100.0,
        },
        'stock': {
          'items': 42,
          'lowStock': 5,
          'outOfStock': 1,
          'stockValue': 12750.0,
        },
        'people': {'activeStaff': 4, 'customers': 87, 'repeatRate': 0.34},
        'rating': {
          'avg': 4.6,
          'reviewCount': 31,
          'acceptanceRate': 0.92,
          'avgResponseMinutes': 47.0,
        },
        'alerts': [
          {'code': 'low_stock', 'count': 5},
          {'code': 'overdue_jobs', 'count': 1},
        ],
      };
      final decoded = WorkshopSummary.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );

      expect(decoded.provider, MockServiceData.providers.first);
      expect(decoded.jobs.needsYou, 4);
      expect(decoded.jobs.overdue, 1);
      expect(decoded.money.payoutDue, 3100.0);
      expect(decoded.stock.lowStock, 5);
      expect(decoded.people.repeatRate, 0.34);
      expect(decoded.rating.avg, 4.6);
      expect(decoded.alerts, hasLength(2));
      expect(decoded.alerts.first.code, 'low_stock');
    });

    test('WorkshopEarnings keeps its lines with the embedded booking', () {
      final earnings = WorkshopEarnings(
        heldInEscrow: 100,
        releasedGross: 200,
        releasedCommission: 20,
        totalCommission: 40,
        window: const Duration(days: 30),
        lines: [
          EarningsLine(
            request: ServiceRequest(
              id: '1042',
              offering: MockServiceData.offerings.first,
              car: const Car(
                id: 'c1',
                make: 'Toyota',
                model: 'Camry',
                year: 2021,
              ),
              plate: '1234 AB',
              fulfillment: Fulfillment.workshop,
              slot: 'Mon 3 Aug · 10:30',
              addOns: const [],
              total: 27.5,
              escrow: EscrowState.releasedToWorkshop,
              createdAt: DateTime.utc(2026, 7, 20, 9),
            ),
            at: DateTime.utc(2026, 7, 21, 9),
            gross: 27.5,
            commission: 2.75,
          ),
        ],
      );
      final decoded = roundTrip(earnings.toJson(), WorkshopEarnings.fromJson);
      expect(decoded.heldInEscrow, earnings.heldInEscrow);
      expect(decoded.window, earnings.window);
      expect(decoded.lines.single.request.id, '1042');
      expect(decoded.lines.single.pending, isFalse);
      expect(decoded.lines.single.net, closeTo(24.75, 0.001));
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

    // `IconCodec.encode` reverses the registry by code point, so two keys
    // pointing at the same icon would silently make one of them un-encodable
    // — a booking or promotion would round-trip through JSON and come back
    // wearing a different icon. Cheap to assert, invisible to debug.
    test('every registered icon key maps to a distinct icon', () {
      final keys = IconCodec.keys.toList();
      for (final key in keys) {
        expect(
          IconCodec.encode(IconCodec.decode(key)),
          key,
          reason:
              '"$key" does not survive a decode/encode round trip — '
              'another key almost certainly shares its icon',
        );
      }
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
      expect(
        () => Car.fromJson(const {'make': 'Toyota'}),
        throwsA(isA<Object>()),
      );
    });

    test('L accepts both the object form and a bare string', () {
      expect(L.fromJson({'ar': 'أ', 'en': 'A'}), const L('أ', 'A'));
      expect(L.fromJson('Solo'), const L('Solo', 'Solo'));
    });

    test('an unknown inventory unit falls back to piece', () {
      final decoded = InventoryItem.fromJson({
        'id': 'i1',
        'name': {'ar': 'أ', 'en': 'A'},
        'sku': 'X',
        'unit': 'gallon',
        'createdAt': '2026-07-01T00:00:00Z',
        'updatedAt': '2026-07-01T00:00:00Z',
      });
      expect(decoded.unit, InventoryUnit.piece);
    });

    test('an unknown staff role falls back to technician, not owner', () {
      final decoded = WorkshopStaff.fromJson({
        'id': 's1',
        'name': 'X',
        'role': 'ceo',
        'joinedAt': '2026-01-01T00:00:00Z',
      });
      expect(decoded.role, WorkshopStaffRole.technician);
      expect(decoded.role.canManage, isFalse);
    });

    test(
      'a customer tag the client does not recognise is dropped, not guessed',
      () {
        final decoded = WorkshopCustomer.fromJson({
          'userId': 'u1',
          'name': 'X',
          'lastBookingAt': '2026-07-20T00:00:00Z',
          'tags': ['repeat', 'vip'],
        });
        expect(decoded.tags, {WorkshopCustomerTag.repeat});
      },
    );
  });
}

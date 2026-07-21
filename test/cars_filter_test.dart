import 'package:ak_cars_mobil_app/data/car_spec_options.dart';
import 'package:ak_cars_mobil_app/data/gallery_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the cars-gallery filter facets: every spec a listing can hold must
/// be expressible in [CarsFilter], and every filter must actually narrow.
void main() {
  final feed = GalleryData.listings;

  group('spec catalog covers the feed', () {
    test('every listing value exists as a canonical option', () {
      String? missing;
      for (final l in feed) {
        bool has<T>(List<SpecOption<T>> options, T value) =>
            options.any((o) => o.value == value);
        if (!has(CarSpecs.bodyTypes, l.bodyType)) missing = l.bodyType;
        if (!has(CarSpecs.conditions, l.condition)) missing = l.condition;
        if (!has(CarSpecs.fuels, l.fuel)) missing = l.fuel;
        if (!has(CarSpecs.transmissions, l.transmission)) {
          missing = l.transmission;
        }
        if (!has(CarSpecs.drivetrains, l.drivetrain)) missing = l.drivetrain;
        if (!has(CarSpecs.cylinders, l.cylinders)) missing = '${l.cylinders}';
        if (!has(CarSpecs.doors, l.doors)) missing = '${l.doors} doors';
        if (!has(CarSpecs.sellerTypes, l.sellerType)) missing = l.sellerType;
        if (!has(CarSpecs.dealTypes, l.dealType)) missing = l.dealType;
        if (!has(CarSpecs.regionalSpecs, l.regionalSpec)) {
          missing = l.regionalSpec;
        }
        if (!has(CarSpecs.colors, l.exteriorColor)) missing = l.exteriorColor;
        if (!has(CarSpecs.colors, l.interiorColor)) missing = l.interiorColor;
        if (CarSpecs.bucketFor(l.engineLitres) == null) {
          missing = '${l.engineLitres}L';
        }
      }
      expect(missing, isNull, reason: 'no canonical option for "$missing"');
    });

    test('engine buckets do not overlap', () {
      for (final l in feed) {
        final hits = CarSpecs.engineSizes
            .where((b) => b.contains(l.engineLitres))
            .length;
        expect(hits, 1, reason: '${l.engineLitres}L matched $hits buckets');
      }
    });
  });

  group('facets filter', () {
    test('fuel type narrows to that fuel', () {
      final diesel = const CarsFilter(fuels: {'Diesel'}).apply(feed);
      expect(diesel, isNotEmpty);
      expect(diesel.every((l) => l.fuel == 'Diesel'), isTrue);
    });

    test('multiple values in one facet OR together', () {
      final f = const CarsFilter(fuels: {'Diesel', 'Hybrid'});
      expect(f.apply(feed).length,
          feed.where((l) => l.fuel == 'Diesel' || l.fuel == 'Hybrid').length);
      expect(f.apply(feed).length,
          greaterThan(const CarsFilter(fuels: {'Diesel'}).apply(feed).length));
    });

    test('separate facets AND together', () {
      final f = const CarsFilter(
          fuels: {'Petrol'}, transmissions: {'Automatic'}, conditions: {'New'});
      expect(
        f.apply(feed).every((l) =>
            l.fuel == 'Petrol' &&
            l.transmission == 'Automatic' &&
            l.condition == 'New'),
        isTrue,
      );
    });

    test('electric matches the zero-cylinder / zero-litre options', () {
      final ev = const CarsFilter(fuels: {'Electric'}).apply(feed);
      expect(ev, isNotEmpty);
      expect(const CarsFilter(cylinders: {0}).apply(feed), ev);
      expect(const CarsFilter(engineSizes: {'electric'}).apply(feed), ev);
    });

    test('engine bucket matches only its range', () {
      final big = const CarsFilter(engineSizes: {'over4.0'}).apply(feed);
      expect(big, isNotEmpty);
      expect(big.every((l) => l.engineLitres > 4.0), isTrue);
    });

    test('top seat option means "or more"', () {
      final roomy = const CarsFilter(seats: {8}).apply(feed);
      expect(roomy, isNotEmpty);
      expect(roomy.every((l) => l.seats >= 8), isTrue);
    });

    test('warranty filter keeps only covered cars', () {
      final covered = const CarsFilter(warrantyOnly: true).apply(feed);
      expect(covered, isNotEmpty);
      expect(covered.every((l) => l.hasWarranty), isTrue);
    });

    test('regional spec narrows by import market', () {
      final gcc = const CarsFilter(regionalSpecs: {'GCC'}).apply(feed);
      expect(gcc, isNotEmpty);
      expect(gcc.every((l) => l.regionalSpec == 'GCC'), isTrue);
      // Imports are a separate market — GCC and American must not overlap.
      final american =
          const CarsFilter(regionalSpecs: {'American'}).apply(feed);
      expect(american.any(gcc.contains), isFalse);
    });

    test('seller type narrows to showrooms', () {
      final showrooms =
          const CarsFilter(sellerTypes: {'Showroom'}).apply(feed);
      expect(showrooms, isNotEmpty);
      expect(showrooms.every((l) => l.sellerType == 'Showroom'), isTrue);
    });

    test('an empty filter passes everything through', () {
      expect(const CarsFilter().apply(feed).length, feed.length);
      expect(const CarsFilter().activeCount, 0);
    });
  });

  group('sorting', () {
    test('mileage low to high', () {
      final sorted =
          const CarsFilter(sort: GallerySort.mileageLowHigh).apply(feed);
      for (var i = 1; i < sorted.length; i++) {
        expect(sorted[i].mileageValue,
            greaterThanOrEqualTo(sorted[i - 1].mileageValue));
      }
    });

    test('model year newest first', () {
      final sorted =
          const CarsFilter(sort: GallerySort.yearNewOld).apply(feed);
      for (var i = 1; i < sorted.length; i++) {
        expect(sorted[i].year, lessThanOrEqualTo(sorted[i - 1].year));
      }
    });
  });
}

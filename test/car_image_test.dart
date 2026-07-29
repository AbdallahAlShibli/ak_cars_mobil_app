import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/core/media/vehicle_assets.dart';
import 'package:ak_cars_mobil_app/core/widgets/car_artwork.dart';
import 'package:ak_cars_mobil_app/core/widgets/car_media.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rendering', () {
    test('the real CDN photos and logos are the default, as on the web', () {
      expect(AppConfig.useRemoteVehicleImages, isTrue);
    });

    testWidgets('a car asks the CDN for its photo', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: CarImage(make: 'Toyota', model: 'Land Cruiser'),
        ),
      ));

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a car that cannot load is drawn instead of left blank',
        (tester) async {
      // The test HTTP client answers 400, which is what an offline phone sees.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: CarImage(make: 'Toyota', model: 'Land Cruiser'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CarArtwork), findsOneWidget);
    });

    testWidgets('a brand tile shows its monogram until the logo loads',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MakeLogo(make: CarMake('Toyota', ['Camry'])),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('TO'), findsOneWidget);
    });
  });

  group('body shape', () {
    test('is inferred from the model name', () {
      expect(carBodyType('Nissan', 'Patrol'), CarBodyType.suv);
      expect(carBodyType('Toyota', 'Hilux'), CarBodyType.pickup);
      expect(carBodyType('Toyota', 'Hiace'), CarBodyType.van);
      expect(carBodyType('Ford', 'Mustang'), CarBodyType.coupe);
      expect(carBodyType('Suzuki', 'Swift'), CarBodyType.hatchback);
    });

    test('unknown models fall back to a sedan rather than nothing', () {
      expect(carBodyType('Acme', 'Prototype X'), CarBodyType.sedan);
    });

    test('trim words do not change the shape', () {
      expect(carBodyType('Toyota', 'Land Cruiser GXR'), CarBodyType.suv);
    });
  });

  group('paint colour', () {
    test('uses the recorded exterior colour when there is one', () {
      expect(carPaintColor('Toyota', 'Camry', 'White'),
          carPaintColor('Nissan', 'Sunny', 'white'));
    });

    test('is stable per model when the colour is unknown', () {
      expect(carPaintColor('Toyota', 'Camry', null),
          carPaintColor('Toyota', 'Camry', null));
    });

    test('an unrecognised colour name still yields a colour', () {
      expect(carPaintColor('Toyota', 'Camry', 'Chameleon'),
          carPaintColor('Toyota', 'Camry', null));
    });
  });

  group('bundled asset lookup', () {
    test('keys normalise make and model', () {
      expect(vehicleKey('Mercedes-Benz', 'C 200'), 'mercedes-benz|c-200');
      expect(vehicleFamilyKey('Toyota', 'Land Cruiser GXR'), 'toyota|land');
    });

    test('nothing is bundled yet, so every car draws its silhouette', () {
      expect(carPhotoAsset('Toyota', 'Land Cruiser'), isNull);
      expect(brandLogoAsset('Toyota'), isNull);
    });
  });
}

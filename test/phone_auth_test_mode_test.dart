import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phone-auth test mode swaps Firebase's real app check for a mock. It must
/// never reach real users, however the release was built.
void main() {
  test('production ignores a requested phone-auth test mode', () {
    expect(
      AppConfig.phoneAuthTestModeAllowed(
        AppEnvironment.production,
        requested: true,
      ),
      isFalse,
    );
  });

  test('development and staging honour it only when it is requested', () {
    for (final environment in [
      AppEnvironment.development,
      AppEnvironment.staging,
    ]) {
      expect(
        AppConfig.phoneAuthTestModeAllowed(environment, requested: true),
        isTrue,
      );
      expect(
        AppConfig.phoneAuthTestModeAllowed(environment, requested: false),
        isFalse,
      );
    }
  });

  test('an unrecognised AK_ENV cannot unlock it', () {
    expect(
      AppConfig.phoneAuthTestModeAllowed(
        AppEnvironment.fromKey('prod'),
        requested: true,
      ),
      isFalse,
    );
  });
}
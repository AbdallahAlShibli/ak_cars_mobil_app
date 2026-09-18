import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/features/home/home_car_pulse.dart';
import 'package:flutter_test/flutter_test.dart';

DueItem _due(String key, DueStatus status, [double? progress]) => DueItem(
  item: MaintenanceItem(key: key, title: L(key, key), shortTitle: L(key, key)),
  status: status,
  progress: progress,
);

void main() {
  test('no measurable line means no score at all', () {
    expect(CarPulse.from(const []), isNull);
    expect(CarPulse.from([_due('oil', DueStatus.noRecord)]), isNull);
  });

  test('the score is the average share of each interval still left', () {
    final pulse = CarPulse.from([
      _due('oil', DueStatus.good, 0.4),
      _due('tyres', DueStatus.good, 0.2),
      _due('brakes', DueStatus.noRecord),
    ])!;

    expect(pulse.score, 70);
    expect(pulse.state, PulseState.ready);
    // Unlogged lines are not measured, and the most used-up comes first.
    expect(pulse.tracked.map((d) => d.key), ['oil', 'tyres']);
  });

  test('a line coming up turns the word amber without capping the score', () {
    final pulse = CarPulse.from([
      _due('oil', DueStatus.near, 0.9),
      _due('tyres', DueStatus.good, 0.1),
    ])!;

    expect(pulse.state, PulseState.soon);
    expect(pulse.score, 50);
  });

  test('an overdue line caps the score below half', () {
    final pulse = CarPulse.from([
      _due('brakes', DueStatus.due, 1.3),
      _due('oil', DueStatus.good, 0),
      _due('tyres', DueStatus.good, 0),
      _due('coolant', DueStatus.good, 0),
    ])!;

    expect(pulse.state, PulseState.overdue);
    expect(pulse.score, CarPulse.overdueCeiling);
    expect(pulse.tracked.first.key, 'brakes');
  });
}

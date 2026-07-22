import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/maintenance.dart';
import '../di/providers.dart';

/// The user's maintenance book.
///
/// Everything shown is computed from data the user enters (odometer readings,
/// manual records) plus service records created inside the app. The app never
/// reads anything from the car itself, and items with no record never show a
/// percentage — that is the whole point of the redesign that replaced the old
/// fabricated "health score".
class MaintenanceNotifier extends Notifier<MaintenanceLog> {
  @override
  MaintenanceLog build() =>
      // Warmed at bootstrap, so the first frame already has the real log.
      ref.watch(maintenanceRepositoryProvider).log;

  Future<void> updateOdometer(int km) async {
    if (km <= 0) return;
    state = await ref.read(maintenanceRepositoryProvider).updateOdometer(km);
  }

  Future<void> addRecord(ServiceRecord record) async {
    state = await ref.read(maintenanceRepositoryProvider).addRecord(record);
  }

  Future<void> setKmInterval(MaintenanceType type, int km) async {
    state =
        await ref.read(maintenanceRepositoryProvider).setKmInterval(type, km);
  }

  Future<void> setMonthInterval(MaintenanceType type, int months) async {
    state = await ref
        .read(maintenanceRepositoryProvider)
        .setMonthInterval(type, months);
  }
}

final maintenanceProvider =
    NotifierProvider<MaintenanceNotifier, MaintenanceLog>(
        MaintenanceNotifier.new);

/// Computed upcoming items — never shows a percentage without a record.
final maintenanceDueProvider = Provider<List<DueItem>>(
  (ref) => ref
      .watch(maintenanceRepositoryProvider)
      .dueItems(ref.watch(maintenanceProvider)),
);

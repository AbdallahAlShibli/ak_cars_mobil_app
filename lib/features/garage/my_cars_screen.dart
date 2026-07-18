import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';

/// Garage — saved cars: set default, delete, add another.
class MyCarsScreen extends ConsumerWidget {
  const MyCarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(garageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My cars')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-car'),
        backgroundColor: AppColors.brand,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add car',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: cars.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IconTile(Icons.directions_car_outlined,
                        size: 64,
                        radius: 22,
                        background: AppColors.field,
                        foreground: AppColors.ink3),
                    const SizedBox(height: 12),
                    const Text('No cars in your garage',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                      'Add your car to get matched services and reminders.',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.ink2),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                itemCount: cars.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final car = cars[i];
                  final primary = i == 0;
                  return Entrance(
                    delayMs: 40 * i,
                    child: AppCard(
                      gradient:
                          primary ? AppColors.brandGradient : null,
                      child: Row(
                        children: [
                          IconTile(
                            Icons.directions_car_filled_rounded,
                            background: primary
                                ? Colors.white.withValues(alpha: 0.16)
                                : AppColors.brandSoft,
                            foreground: primary
                                ? Colors.white
                                : AppColors.brand,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  car.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: primary
                                        ? Colors.white
                                        : AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  car.plate ?? 'No plate saved',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    color: primary
                                        ? const Color(0xFFB9C9F5)
                                        : AppColors.ink3,
                                  ),
                                ),
                                if (primary)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Text(
                                      'DEFAULT — used for services & shop',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: Color(0xFF9DB4F0),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!primary)
                            IconButton(
                              tooltip: 'Make default',
                              icon: const Icon(Icons.star_outline_rounded,
                                  color: AppColors.ink3),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(garageProvider.notifier)
                                    .setPrimary(car.id);
                              },
                            ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: Icon(Icons.delete_outline_rounded,
                                color: primary
                                    ? const Color(0xFFB9C9F5)
                                    : AppColors.bad),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  title: const Text('Remove car?'),
                                  content: Text(
                                      '${car.label} will be removed from your garage.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.bad,
                                        minimumSize: const Size(0, 44),
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed ?? false) {
                                ref
                                    .read(garageProvider.notifier)
                                    .remove(car.id);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

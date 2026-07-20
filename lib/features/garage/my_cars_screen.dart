import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';

/// Garage — saved cars: set default, delete, add another.
class MyCarsScreen extends ConsumerWidget {
  const MyCarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final cars = ref.watch(garageProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('سياراتي', 'My cars'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-car'),
        backgroundColor: ak.primary,
        icon: Icon(Icons.add_rounded, color: ak.onPrimary),
        label: Text(s.t('أضف سيارة', 'Add car'),
            style: TextStyle(
                color: ak.onPrimary, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: cars.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTile(Icons.directions_car_outlined,
                        size: 64,
                        radius: 22,
                        background: ak.surfaceDim,
                        foreground: ak.inkFaint),
                    const SizedBox(height: 12),
                    Text(s.t('لا سيارات في مرآبك', 'No cars in your garage'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      s.t('أضف سيارتك لتحصل على خدمات وتذكيرات مناسبة.',
                          'Add your car to get matched services and reminders.'),
                      style: TextStyle(fontSize: 12.5, color: ak.inkSub),
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
                                : ak.surfaceDim,
                            foreground: primary ? Colors.white : ak.ink,
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
                                    color: primary ? Colors.white : ak.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  car.plate ??
                                      s.t('لا لوحة محفوظة', 'No plate saved'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    color: primary
                                        ? const Color(0xFFD8D2C6)
                                        : ak.inkFaint,
                                  ),
                                ),
                                if (primary)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      s.t('الافتراضية — للخدمات والمتجر',
                                          'DEFAULT — used for services & shop'),
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: Color(0xFFE9C88A),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!primary)
                            IconButton(
                              tooltip: s.t('اجعلها افتراضية', 'Make default'),
                              icon: Icon(Icons.star_outline_rounded,
                                  color: ak.inkFaint),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(garageProvider.notifier)
                                    .setPrimary(car.id);
                              },
                            ),
                          IconButton(
                            tooltip: s.t('حذف', 'Remove'),
                            icon: Icon(Icons.delete_outline_rounded,
                                color: primary
                                    ? const Color(0xFFD8D2C6)
                                    : ak.danger),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  title: Text(s.t('حذف السيارة؟', 'Remove car?')),
                                  content: Text(s.t(
                                      'سيتم حذف ${car.label} من مرآبك.',
                                      '${car.label} will be removed from your garage.')),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(s.t('إلغاء', 'Cancel')),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: ak.danger,
                                        minimumSize: const Size(0, 44),
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(s.t('حذف', 'Remove')),
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

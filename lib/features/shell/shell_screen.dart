import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Bottom navigation shell — Home, Services, Shop, Cars, Profile.
class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.build_rounded, 'Services'),
    (Icons.shopping_bag_rounded, 'Shop'),
    (Icons.directions_car_filled_rounded, 'Cars'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(
            top: BorderSide(color: Color(0xFFEDF1F6), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (final (i, item) in _items.indexed)
                  _NavItem(
                    icon: item.$1,
                    label: item.$2,
                    selected: shell.currentIndex == i,
                    onTap: () => shell.goBranch(
                      i,
                      initialLocation: i == shell.currentIndex,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brand : AppColors.ink3;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                gradient: selected ? AppColors.brandGradient : null,
                borderRadius: BorderRadius.circular(999),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Icon(icon,
                  color: selected ? Colors.white : color, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

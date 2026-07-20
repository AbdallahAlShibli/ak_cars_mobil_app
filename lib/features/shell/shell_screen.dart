import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';

/// Bottom navigation shell — Sand & Ink: surface bar with 24px top radius,
/// active item = icon inside an ink pill (inverted cream in dark) + bold
/// label. Home, Services, Shop, Cars, Profile.
class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final items = [
      (LucideIcons.home, s.navHome),
      (LucideIcons.wrench, s.navServices),
      (LucideIcons.shoppingBag, s.navShop),
      (LucideIcons.car, s.navCars),
      (LucideIcons.user, s.navProfile),
    ];

    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ak.navBar,
          border: Border(top: BorderSide(color: ak.border)),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
            child: Row(
              children: [
                for (final (i, item) in items.indexed)
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
    final ak = AkColors.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? ak.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                icon,
                size: 16,
                color: selected ? ak.onPrimary : ak.navIdle,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? ak.ink : ak.navIdle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

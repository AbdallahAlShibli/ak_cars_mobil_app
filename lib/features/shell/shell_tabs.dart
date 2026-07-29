import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../cars/cars_screen.dart';
import '../garage/maintenance_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../services/requests_screen.dart';
import '../services/services_screen.dart';
import '../shop/shop_screen.dart';

/// One bottom-navigation destination.
class ShellTab {
  const ShellTab({
    required this.location,
    required this.icon,
    required this.label,
    required this.builder,
  });

  final String location;
  final IconData icon;
  final String Function(S) label;
  final GoRouterWidgetBuilder builder;
}

/// The bottom bar, in order — and the single source of truth for it.
///
/// The router builds one `StatefulShellBranch` per entry and `ShellScreen`
/// builds one button per entry, so the bar and the branch indices cannot drift
/// apart. Adding a tab is one entry here.
///
/// Spec §2 cuts the bar to four: `الخدمات • حجوزاتي • سيارتي • حسابي`. The
/// entries guarded by [AppFlags] are the phase-2 pillars, hidden rather than
/// deleted — flip the flag and both the tab and its branch come back.
List<ShellTab> buildShellTabs() => [
      if (AppFlags.homeTabEnabled)
        ShellTab(
          location: '/home',
          icon: LucideIcons.house,
          label: (s) => s.navHome,
          builder: (context, state) => const HomeScreen(),
        ),
      ShellTab(
        location: '/services',
        icon: LucideIcons.wrench,
        label: (s) => s.navServices,
        // `?q=` opens the tab already searching — used by the maintenance
        // reminders, which must land on real matching offerings rather than
        // on a page the user has to search again themselves.
        builder: (context, state) =>
            ServicesScreen(initialQuery: state.uri.queryParameters['q']),
      ),
      ShellTab(
        location: '/bookings',
        icon: LucideIcons.clipboardList,
        label: (s) => s.navBookings,
        builder: (context, state) => const RequestsScreen(),
      ),
      if (AppFlags.maintenanceEnabled)
        ShellTab(
          location: '/my-car',
          icon: LucideIcons.car,
          label: (s) => s.navMyCar,
          builder: (context, state) => const MaintenanceScreen(),
        ),
      if (AppFlags.partsStoreEnabled)
        ShellTab(
          location: '/shop',
          icon: LucideIcons.shoppingBag,
          label: (s) => s.navShop,
          builder: (context, state) => const ShopScreen(),
        ),
      if (AppFlags.carMarketplaceEnabled)
        ShellTab(
          location: '/cars',
          icon: LucideIcons.carFront,
          label: (s) => s.navCars,
          builder: (context, state) => const CarsScreen(),
        ),
      ShellTab(
        location: '/profile',
        icon: LucideIcons.user,
        label: (s) => s.navProfile,
        builder: (context, state) => const ProfileScreen(),
      ),
    ];

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../features/auth/register_screen.dart';
import '../../features/cars/cars_screen.dart';
import '../../features/cars/listing_detail_screen.dart';
import '../../features/cars/make_filter_screen.dart';
import '../../features/cars/post_ad_screen.dart';
import '../../features/cars/results_screen.dart';
import '../../features/challenge/challenge_screen.dart';
import '../../features/garage/add_car_screen.dart';
import '../../features/garage/maintenance_screen.dart';
import '../../features/garage/my_cars_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/notifications_screen.dart';
import '../../features/profile/payments_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/start_choice_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/services/approval_screen.dart';
import '../../features/services/booking_screen.dart';
import '../../features/services/chat_screen.dart';
import '../../features/services/requests_screen.dart';
import '../../features/services/service_detail_screen.dart';
import '../../features/services/services_screen.dart';
import '../../features/services/tracking_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/shop/cart_screen.dart';
import '../../features/shop/orders_screen.dart';
import '../../features/shop/shop_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/start-choice',
        builder: (context, state) => const StartChoiceScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/add-car',
        builder: (context, state) => const AddCarScreen(),
      ),
      GoRoute(
        path: '/cars/make/:make',
        builder: (context, state) => MakeFilterScreen(
            makeName: Uri.decodeComponent(state.pathParameters['make']!)),
      ),
      GoRoute(
        path: '/cars/results',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return ResultsScreen(
            make: q['make'],
            model: q['model'],
            fromYear: int.tryParse(q['from'] ?? ''),
            toYear: int.tryParse(q['to'] ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/cars/listing/:id',
        builder: (context, state) =>
            ListingDetailScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/post-ad',
        builder: (context, state) => const PostAdScreen(),
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/garage',
        builder: (context, state) => const MyCarsScreen(),
      ),
      GoRoute(
        path: '/maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: '/challenge',
        builder: (context, state) => const ChallengeScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/requests',
        builder: (context, state) => const RequestsScreen(),
      ),
      GoRoute(
        path: '/payments',
        builder: (context, state) => const PaymentsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) =>
            ChatScreen(requestId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/service/:id',
        builder: (context, state) =>
            ServiceDetailScreen(offeringId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/book/:id',
        builder: (context, state) =>
            BookingScreen(offeringId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/track/:id',
        builder: (context, state) =>
            TrackingScreen(requestId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/approve/:id',
        builder: (context, state) =>
            ApprovalScreen(requestId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScreen(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/services',
              builder: (context, state) => const ServicesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/shop',
              builder: (context, state) => const ShopScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cars',
              builder: (context, state) => const CarsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

/// Registration gate — rule 4/5/6: no service requests, parts orders, or
/// car ads until the user has completed their details. Browsing stays free.
bool ensureRegistered(BuildContext context, WidgetRef ref) {
  final registered = ref.read(authProvider).isRegistered;
  if (!registered) {
    context.push('/register');
  }
  return registered;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_flags.dart';
import '../../data/models/review.dart';
import '../../state/app_state.dart';
import '../../features/auth/register_screen.dart';
import '../../features/cars/listing_detail_screen.dart';
import '../../features/cars/make_filter_screen.dart';
import '../../features/cars/my_ads_screen.dart';
import '../../features/cars/post_ad_screen.dart';
import '../../features/cars/results_screen.dart';
import '../../features/challenge/challenge_screen.dart';
import '../../features/garage/add_car_screen.dart';
import '../../features/garage/my_cars_screen.dart';
import '../../features/home/notifications_screen.dart';
import '../../features/operations/admin_screen.dart';
import '../../features/operations/workshop_screen.dart';
import '../../features/profile/payments_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/start_choice_screen.dart';
import '../../features/services/approval_screen.dart';
import '../../features/services/booking_screen.dart';
import '../../features/services/chat_screen.dart';
import '../../features/services/part_request_screen.dart';
import '../../features/services/quote_screen.dart';
import '../../features/services/review_screen.dart';
import '../../features/services/service_detail_screen.dart';
import '../../features/services/tracking_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/shell/shell_tabs.dart';
import '../../features/shop/cart_screen.dart';
import '../../features/shop/orders_screen.dart';
import '../../features/shop/product_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // `read`, not `watch`: this decides where a *cold start* lands. Watching it
  // would rebuild the router — and throw away the navigation stack — the
  // moment the user finished onboarding or signed out mid-session.
  final start = ref.read(authProvider).initialRoute;
  final tabs = buildShellTabs();

  return GoRouter(
    initialLocation: start,
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
      // Same screen as /add-car, prefilled with the saved car.
      GoRoute(
        path: '/garage/edit/:id',
        builder: (context, state) =>
            AddCarScreen(carId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/garage',
        builder: (context, state) => const MyCarsScreen(),
      ),
      if (AppFlags.weekChallengeEnabled)
        GoRoute(
          path: '/challenge',
          builder: (context, state) => const ChallengeScreen(),
        ),
      GoRoute(
        path: '/search',
        builder: (context, state) =>
            SearchScreen(initialQuery: state.uri.queryParameters['q'] ?? ''),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
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

      // ------------------------------------------- part + install (spec §6)
      // A custom-quote booking rides the same escrow machine as any other, so
      // it needs no routes of its own beyond the two decision points: opening
      // the request, and answering the price it comes back with.
      if (AppFlags.requestPartInstall) ...[
        GoRoute(
          path: '/request-part',
          builder: (context, state) => PartRequestScreen(
              providerId: state.uri.queryParameters['provider']),
        ),
        GoRoute(
          path: '/quote/:id',
          builder: (context, state) =>
              QuoteScreen(requestId: state.pathParameters['id']!),
        ),
      ],

      // Verified reviews (spec §8). `?direction=workshopToCustomer` opens the
      // workshop's half of the same screen; anything else falls back to the
      // customer's, so a malformed link cannot land on the wrong side.
      if (AppFlags.verifiedReviews)
        GoRoute(
          path: '/review/:id',
          builder: (context, state) => ReviewScreen(
            requestId: state.pathParameters['id']!,
            direction: ReviewDirection.fromKey(
                state.uri.queryParameters['direction']),
          ),
        ),

      // ------------------------------------------------- operator panels
      // Spec §6. Reachable only after switching role in Settings; a customer
      // never sees a link to either.
      if (AppFlags.operatorPanelsEnabled) ...[
        GoRoute(
          path: '/workshop',
          builder: (context, state) => const WorkshopScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminScreen(),
        ),
      ],

      // ------------------------------------------------------- phase 2
      // Hidden, not deleted (spec §1). Every screen below still compiles and
      // still has its tests; what a `false` flag removes is the route, so a
      // stale deep link cannot land on a pillar the pilot does not run.
      if (AppFlags.partsStoreEnabled) ...[
        GoRoute(
          path: '/shop/product/:id',
          builder: (context, state) =>
              ProductDetailScreen(productId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/orders',
          builder: (context, state) => const OrdersScreen(),
        ),
      ],
      if (AppFlags.carMarketplaceEnabled) ...[
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
          path: '/my-ads',
          builder: (context, state) => const MyAdsScreen(),
        ),
      ],

      // The bar and its branches are generated from one list, so a tab can
      // never point at a branch index that is not there.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            ShellScreen(shell: shell, tabs: tabs),
        branches: [
          for (final tab in tabs)
            StatefulShellBranch(routes: [
              GoRoute(path: tab.location, builder: tab.builder),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_flags.dart';
import '../../data/models/app_role.dart';
import '../../data/models/review.dart';
import '../../data/models/service_provider.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../features/auth/auth_gate_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/workshop_application_received_screen.dart';
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
    redirect: (context, state) => _guardOperatorPanels(ref, state),
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
      // Presents the login/register choice — where a guest lands before
      // either form, so returning users are never funnelled straight into
      // registration (see [ensureRegistered] below).
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthGateScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // §11 step 4. A route rather than a dialog because it is where the
      // registration flow *ends* for a workshop — there is nothing behind it
      // to go back to, and the customer's flow pops to the action it came from.
      GoRoute(
        path: '/workshop-application-received',
        builder: (context, state) => const WorkshopApplicationReceivedScreen(),
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

/// Role guard for the two operator panels (spec §7).
///
/// Until phase 2.5 the panels were gated by [AppFlags.operatorPanelsEnabled]
/// alone, which is a *build* switch: with the flag on, any deep link reached
/// either panel regardless of who was holding the phone. This is the check
/// that was missing.
///
/// Two rules, and the second is the one that matters:
///
/// 1. The active role has to match the panel. A workshop operator has no
///    business in the founder's dispute queue and vice versa.
/// 2. `/workshop` additionally requires the operator's own workshop to be
///    [ProviderOnboardingStage.approved] — **re-checked on every entry, not
///    once at sign-in** (§7, §11 step 6). A workshop suspended an hour ago
///    must not still be inside its panel because its session predates the
///    suspension.
///
/// Runs as a top-level `redirect`, so it fires on every navigation to these
/// paths rather than only on the first build of the route.
///
/// **Deliberately not a check that the user owns an approved workshop.** The
/// pilot's role switcher (`activeRoleProvider`, Settings) is a device-local
/// tool for demonstrating the panels on an account that never applied to be a
/// workshop, and §7 says to build on that mechanism rather than replace it. So
/// the stage check applies to accounts that *did* apply — where a real
/// onboarding decision exists to honour — and an account with no application
/// falls through to rule 1 alone.
String? _guardOperatorPanels(Ref ref, GoRouterState state) {
  final location = state.matchedLocation;
  if (location != '/workshop' && location != '/admin') return null;

  final role = ref.read(activeRoleProvider);

  if (location == '/admin') {
    return role == AppRole.founder ? null : '/settings';
  }

  if (role != AppRole.workshop) return '/settings';

  final userId = ref.read(authProvider).profile?.id;
  if (userId == null) return null;
  final workshop =
      ref.read(serviceMarketplaceRepositoryProvider).providerOwnedBy(userId);
  // No application on file — the pilot's role switch, not a suspended
  // workshop. See the note above.
  if (workshop == null) return null;
  // An application in flight, or one that was rejected, grants nothing. The
  // profile screen is where its status and any rejection reason are shown, so
  // that is where this lands rather than on a dead end.
  return workshop.isApproved ? null : '/settings';
}

/// Registration gate — rule 4/5/6: no service requests, parts orders, or
/// car ads until the user has completed their details. Browsing stays free.
///
/// Opens [AuthGateScreen] rather than jumping straight to `/register`: a
/// guest here might be someone who signed out of an existing account, not
/// only a first-time visitor, and only they know which of the two they are.
bool ensureRegistered(BuildContext context, WidgetRef ref) {
  final registered = ref.read(authProvider).isRegistered;
  if (!registered) {
    context.push('/auth');
  }
  return registered;
}

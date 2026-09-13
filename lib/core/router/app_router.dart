import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_flags.dart';
import '../../data/models/chat_message.dart';
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
import '../../features/operations/admin_workshop_detail_screen.dart';
import '../../features/workshop_dashboard/add_ons_screen.dart';
import '../../features/workshop_dashboard/dashboard_home_screen.dart';
import '../../features/workshop_dashboard/inventory_screen.dart';
import '../../features/workshop_dashboard/offerings_screen.dart';
import '../../features/workshop_dashboard/customer_detail_screen.dart';
import '../../features/workshop_dashboard/customers_screen.dart';
import '../../features/workshop_dashboard/orders_screen.dart'
    as workshop_dashboard;
import '../../features/workshop_dashboard/schedule_screen.dart';
import '../../features/workshop_dashboard/staff_screen.dart';
import '../../features/workshop_dashboard/statistics_screen.dart';
import '../../features/workshop_dashboard/workshop_profile_screen.dart';
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
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
      // The pre-booking enquiry thread. Contact details are gated on escrow
      // (`core/utils/provider_contact.dart`), so a customer still deciding has
      // to be able to *ask* the workshop something — this is that channel, and
      // it is keyed by workshop rather than by a booking that does not exist
      // yet. Three segments, so it can never be matched by `/chat/:id`.
      GoRoute(
        path: '/chat/provider/:providerId',
        builder: (context, state) => ChatScreen(
          requestId: providerThreadId(state.pathParameters['providerId']!),
          providerId: state.pathParameters['providerId']!,
        ),
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
            providerId: state.uri.queryParameters['provider'],
          ),
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
              state.uri.queryParameters['direction'],
            ),
          ),
        ),

      // ------------------------------------------------- operator panels
      // Spec §6. Reachable only when the account itself is the role — see
      // `_guardOperatorPanels`; there is no switch a customer can flip.
      if (AppFlags.operatorPanelsEnabled) ...[
        // `/workshop` used to be its own read-only 3-tab panel. It is now
        // just the pre-dashboard deep link: every real workshop feature
        // (jobs, earnings, performance) lives at `/workshop/dashboard`, which
        // `_guardOperatorPanels` applies the real ownership+approval check
        // to either way, so redirecting here rather than duplicating that
        // check is not a weaker gate.
        GoRoute(
          path: '/workshop',
          redirect: (context, state) => '/workshop/dashboard',
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminScreen(),
        ),
        GoRoute(
          path: '/admin/workshops/:providerId',
          builder: (context, state) => AdminWorkshopDetailScreen(
            providerId: state.pathParameters['providerId']!,
          ),
        ),
        GoRoute(
          path: '/workshop/dashboard',
          builder: (context, state) => const DashboardHomeScreen(),
        ),
        GoRoute(
          path: '/workshop/dashboard/offerings',
          builder: (context, state) => const OfferingsScreen(),
        ),
        GoRoute(
          path: '/workshop/dashboard/add-ons',
          builder: (context, state) => const AddOnsScreen(),
        ),
        GoRoute(
          path: '/workshop/dashboard/inventory',
          builder: (context, state) => const InventoryScreen(),
        ),
        GoRoute(
          path: '/workshop/dashboard/orders',
          builder: (context, state) => const workshop_dashboard.OrdersScreen(),
        ),
        GoRoute(
          path: '/workshop/dashboard/staff',
          builder: (context, state) => const StaffScreen(),
        ),
        GoRoute(
          path: '/workshop/dashboard/customers',
          builder: (context, state) => const CustomersScreen(),
        ),
        GoRoute(
          path: '/workshop/dashboard/customers/:userId',
          builder: (context, state) =>
              CustomerDetailScreen(userId: state.pathParameters['userId']!),
        ),
        GoRoute(
          path: '/workshop/dashboard/schedule',
          builder: (context, state) => const ScheduleScreen(),
        ),
        GoRoute(
          path: '/workshop/dashboard/profile',
          builder: (context, state) => const WorkshopProfileScreen(),
        ),
        GoRoute(
          path: '/workshop/dashboard/statistics',
          builder: (context, state) => const StatisticsScreen(),
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
        GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
        GoRoute(
          path: '/orders',
          builder: (context, state) => const OrdersScreen(),
        ),
      ],
      if (AppFlags.carMarketplaceEnabled) ...[
        GoRoute(
          path: '/cars/make/:make',
          builder: (context, state) => MakeFilterScreen(
            makeName: Uri.decodeComponent(state.pathParameters['make']!),
          ),
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
            StatefulShellBranch(
              routes: [GoRoute(path: tab.location, builder: tab.builder)],
            ),
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
/// Both branches check a **real account fact**, re-read fresh on every
/// navigation rather than once at sign-in (§7, §11 step 6) — a workshop
/// suspended an hour ago must not still be inside its dashboard because its
/// session predates the suspension:
///
/// * `/admin` requires [AuthState.isFounder] — the JWT's own role claim.
/// * `/workshop/dashboard` (and `/workshop`, which redirects into it) requires
///   the signed-in account to own a [ServiceProvider]
///   (`providerOwnedBy`, keyed on `ownerUserId` — a staff account linked to
///   the roster does not pass this) that is
///   [ProviderOnboardingStage.approved]. An application still under review,
///   or one nobody has ever filed, both land on `/profile` — My account,
///   which is where the status card and the permanent "Workshop status" row
///   both live, so a bounced navigation ends somewhere that explains itself.
///   (This used to redirect to `/settings`, which stopped being the right
///   answer when the "My business" section moved to My account.)
///
/// Deliberately **not** routed through the cached `activeRoleProvider`: that
/// provider only recomputes when something invalidates it, and this check has
/// to see a suspension the moment it happens, not whenever that next
/// happens to fire. Calling the repository directly, the same way this guard
/// always has, keeps it exact.
///
/// Runs as a top-level `redirect`, so it fires on every navigation to these
/// paths rather than only on the first build of the route.
String? _guardOperatorPanels(Ref ref, GoRouterState state) {
  final location = state.matchedLocation;
  final isDashboard = location.startsWith('/workshop/dashboard');
  final isAdminWorkshopDetail = location.startsWith('/admin/workshops/');
  if (location != '/admin' && !isAdminWorkshopDetail && !isDashboard) {
    return null;
  }

  if (location == '/admin' || isAdminWorkshopDetail) {
    return ref.read(authProvider).isFounder ? null : '/profile';
  }

  final userId = ref.read(authProvider).profile?.id;
  if (userId == null) return '/profile';
  final workshop = ref
      .read(serviceMarketplaceRepositoryProvider)
      .providerOwnedBy(userId);
  if (workshop == null || !workshop.isApproved) return '/profile';
  return null;
}

/// Registration gate — rule 4/5/6: no service requests, parts orders, or
/// car ads until the user has completed their details. Browsing stays free.
///
/// Opens [showAuthGate] rather than jumping straight to `/register`: a guest
/// here might be someone who signed out of an existing account, not only a
/// first-time visitor, and only they know which of the two they are. It is a
/// dialog over the current screen, so declining it leaves the user exactly
/// where the gated action was.
bool ensureRegistered(BuildContext context, WidgetRef ref) {
  final registered = ref.read(authProvider).isRegistered;
  if (!registered) {
    unawaited(showAuthGate(context));
  }
  return registered;
}

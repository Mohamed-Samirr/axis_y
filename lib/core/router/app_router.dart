import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/otp_screen.dart';
import '../../features/auth/view/register_screen.dart';
import '../../features/body_scan/view/scan_camera_screen.dart';
import '../../features/body_scan/view/scan_intro_screen.dart';
import '../../features/body_scan/view/scan_result_screen.dart';
import '../../features/cart_checkout/view/cart_screen.dart';
import '../../features/cart_checkout/view/checkout_screen.dart';
import '../../features/cart_checkout/view/order_success_screen.dart';
import '../../features/compare/view/compare_screen.dart';
import '../../features/home/view/home_screen.dart';
import '../../features/home/view/main_shell.dart';
import '../../features/loyalty/view/loyalty_screen.dart';
import '../../features/notifications/view/notifications_screen.dart';
import '../../features/onboarding/view/onboarding_screen.dart';
import '../../features/orders/view/orders_screen.dart';
import '../../features/product_details/view/product_details_screen.dart';
import '../../features/profile_settings/view/profile_screen.dart';
import '../../features/profile_settings/view/settings_screen.dart';
import '../../features/search/view/explore_screen.dart';
import '../../features/splash/view/splash_screen.dart';
import '../../features/store_portal/view/register_store_screen.dart';
import '../../features/style_assistant/view/assistant_screen.dart';
import '../../features/style_preferences/view/preferences_screen.dart';
import '../../features/virtual_try_on/view/tryon_screen.dart';
import '../../features/wishlist/view/wishlist_screen.dart';
import '../models/commerce.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// App router. The 5 primary tabs live in a [StatefulShellRoute] so the bottom
/// navigation is persistent and each tab keeps its own navigation stack.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: Routes.splash,
  routes: [
    GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
    GoRoute(path: Routes.onboarding, builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
    GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),
    GoRoute(path: Routes.otp, builder: (_, __) => const OtpScreen()),

    GoRoute(path: Routes.scanIntro, builder: (_, __) => const ScanIntroScreen()),
    GoRoute(path: Routes.scanCamera, builder: (_, __) => const ScanCameraScreen()),
    GoRoute(path: Routes.scanResult, builder: (_, __) => const ScanResultScreen()),
    GoRoute(path: Routes.preferences, builder: (_, __) => const PreferencesScreen()),

    // Pushed pages (over the shell)
    GoRoute(
      path: '${Routes.product}/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => ProductDetailsScreen(productId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '${Routes.tryon}/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => TryOnScreen(productId: state.pathParameters['id']!),
    ),
    GoRoute(path: Routes.cart, parentNavigatorKey: _rootKey, builder: (_, __) => const CartScreen()),
    GoRoute(path: Routes.checkout, parentNavigatorKey: _rootKey, builder: (_, __) => const CheckoutScreen()),
    GoRoute(
      path: Routes.orderSuccess,
      parentNavigatorKey: _rootKey,
      builder: (_, state) => OrderSuccessScreen(order: state.extra as AppOrder),
    ),
    GoRoute(path: Routes.orders, parentNavigatorKey: _rootKey, builder: (_, __) => const OrdersScreen()),
    GoRoute(path: Routes.compare, parentNavigatorKey: _rootKey, builder: (_, __) => const CompareScreen()),
    GoRoute(path: Routes.loyalty, parentNavigatorKey: _rootKey, builder: (_, __) => const LoyaltyScreen()),
    GoRoute(path: Routes.settings, parentNavigatorKey: _rootKey, builder: (_, __) => const SettingsScreen()),
    GoRoute(path: Routes.notifications, parentNavigatorKey: _rootKey, builder: (_, __) => const NotificationsScreen()),
    GoRoute(path: Routes.registerStore, parentNavigatorKey: _rootKey, builder: (_, __) => const RegisterStoreScreen()),

    // Bottom-nav shell
    StatefulShellRoute.indexedStack(
      builder: (_, __, shell) => MainShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellKey,
          routes: [GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.explore,
              builder: (_, state) => ExploreScreen(initialCategoryKey: state.uri.queryParameters['cat']),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.tryonTab, builder: (_, __) => const AssistantScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.wishlist, builder: (_, __) => const WishlistScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen())],
        ),
      ],
    ),
  ],
);

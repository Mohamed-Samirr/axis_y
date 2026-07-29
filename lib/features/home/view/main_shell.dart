import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// Persistent bottom-navigation shell hosting the 5 primary tabs.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  void _goTab(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          indicatorColor: AppColors.navy.withValues(alpha: 0.1),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _goTab,
          height: 66,
          backgroundColor: AppColors.surface,
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home, color: AppColors.navy), label: context.tr('nav_home')),
            NavigationDestination(icon: const Icon(Icons.search_outlined), selectedIcon: const Icon(Icons.search, color: AppColors.navy), label: context.tr('nav_explore')),
            NavigationDestination(icon: const Icon(Icons.view_in_ar_outlined), selectedIcon: const Icon(Icons.view_in_ar, color: AppColors.navy), label: context.tr('nav_tryon')),
            // TEMPORARY: the wishlist's slot, showing the scanned 3D body model.
            // It still exists as a pushed page off the profile.
            NavigationDestination(icon: const Icon(Icons.accessibility_new_outlined), selectedIcon: const Icon(Icons.accessibility_new, color: AppColors.navy), label: context.tr('nav_avatar')),
            NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person, color: AppColors.navy), label: context.tr('nav_profile')),
          ],
        ),
      ),
    );
  }
}

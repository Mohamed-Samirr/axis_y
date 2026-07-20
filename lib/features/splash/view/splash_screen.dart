import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/local_store.dart';
import '../../../core/di/injector.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';

/// Navy splash. No network — session is read from local storage only, then
/// routes to Home (logged-in) or Onboarding (not).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final auth = sl<AuthRepository>();
    if (auth.isLoggedIn) {
      context.go(Routes.home);
    } else {
      final onboarded = sl<LocalStore>().getBool(StoreKeys.onboardingDone);
      context.go(onboarded ? Routes.login : Routes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.gold, width: 2),
              ),
              child: const Center(
                child: Text('AY', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('AXIS Y', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 8),
            Text('جرب قبل ما تشتري', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

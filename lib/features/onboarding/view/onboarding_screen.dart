import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/local_store.dart';
import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';

class _Slide {
  final IconData icon;
  final String titleKey;
  final String subKey;
  const _Slide(this.icon, this.titleKey, this.subKey);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = [
    _Slide(Icons.phone_iphone, 'onb1_title', 'onb1_sub'),
    _Slide(Icons.camera_alt_outlined, 'onb2_title', 'onb2_sub'),
    _Slide(Icons.storefront_outlined, 'onb3_title', 'onb3_sub'),
  ];

  void _finish() {
    sl<LocalStore>().setBool(StoreKeys.onboardingDone, true);
    context.go(Routes.register);
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(onPressed: _finish, child: Text(context.tr('skip'))),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), shape: BoxShape.circle),
                          child: Icon(s.icon, size: 84, color: AppColors.navy),
                        ),
                        const SizedBox(height: 40),
                        Text(context.tr(s.titleKey), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(context.tr(s.subKey), style: const TextStyle(color: AppColors.textSecondary, fontSize: 15), textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: active ? AppColors.navy : AppColors.divider, borderRadius: BorderRadius.circular(4)),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _next,
                child: Text(_index == _slides.length - 1 ? context.tr('start_shopping') : context.tr('next')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

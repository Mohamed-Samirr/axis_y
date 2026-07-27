import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../cubit/auth_cubit.dart';

/// Social sign-in buttons. Apple appears on iOS only. Actions are stubbed
/// behind [AuthCubit] for real OAuth later.
class SocialButtons extends StatelessWidget {
  const SocialButtons({super.key});

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(context.tr('or_divider'), style: const TextStyle(color: AppColors.textSecondary)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.read<AuthCubit>().google(),
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: Text(context.tr('google_login')),
        ),
        if (_isIOS) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthCubit>().apple(),
            icon: const Icon(Icons.apple, size: 22),
            label: Text(context.tr('apple_login')),
          ),
        ],
      ],
    );
  }
}

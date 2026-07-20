import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/commerce.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';

class OrderSuccessScreen extends StatelessWidget {
  final AppOrder order;
  const OrderSuccessScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.check_circle, color: AppColors.success, size: 96),
              const SizedBox(height: 20),
              Text(context.tr('order_success'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('${context.tr('order_number')}: #${order.id}', style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Text(context.tr('delivery_estimate'), style: const TextStyle(color: AppColors.textSecondary)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: () => context.go(Routes.orders), child: Text(context.tr('my_orders'))),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: () => context.go(Routes.home), child: Text(context.tr('nav_home'))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

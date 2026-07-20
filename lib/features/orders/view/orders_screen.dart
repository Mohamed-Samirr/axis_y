import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/commerce.dart';
import '../../../core/repositories/order_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/state_views.dart';
import '../cubit/orders_cubit.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrdersCubit(sl<OrderRepository>())..load(),
      child: Scaffold(
        appBar: AppBar(title: Text(context.tr('my_orders'))),
        body: BlocBuilder<OrdersCubit, OrdersState>(
          builder: (context, state) {
            return switch (state) {
              OrdersLoading() => const Center(child: CircularProgressIndicator(color: AppColors.navy)),
              OrdersError(:final message) => ErrorView(message: context.tr(message), onRetry: () => context.read<OrdersCubit>().load()),
              OrdersLoaded(:final orders) => orders.isEmpty
                  ? EmptyView(icon: Icons.receipt_long_outlined, title: context.tr('no_orders'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _OrderCard(order: orders[i]),
                    ),
            };
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final AppOrder order;
  const _OrderCard({required this.order});

  (Color, IconData) _statusStyle() => switch (order.status) {
        OrderStatus.received => (AppColors.navy, Icons.check),
        OrderStatus.preparing => (AppColors.warning, Icons.autorenew),
        OrderStatus.shipping => (AppColors.tierRegular, Icons.local_shipping),
        OrderStatus.delivered => (AppColors.success, Icons.done_all),
        OrderStatus.cancelled => (AppColors.danger, Icons.close),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _statusStyle();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(context.tr(order.status.key), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(order.date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: order.lines
                .take(4)
                .map((l) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: AppNetworkImage(url: l.image, width: 54, height: 64, radius: BorderRadius.circular(8)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatEgp(order.total), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.price)),
              Row(
                children: [
                  if (order.status == OrderStatus.delivered)
                    TextButton(onPressed: () => _snack(context, 'return_order'), child: Text(context.tr('return_order'))),
                  TextButton.icon(
                    onPressed: () => _snack(context, 'track_order'),
                    icon: const Icon(Icons.location_on_outlined, size: 16),
                    label: Text(context.tr('track_order')),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String key) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(key))));
}

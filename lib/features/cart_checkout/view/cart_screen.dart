import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/commerce.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/state_views.dart';
import '../cubit/cart_cubit.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('cart'))),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return EmptyView(
              icon: Icons.shopping_cart_outlined,
              title: context.tr('cart_empty'),
              action: ElevatedButton(onPressed: () => context.go(Routes.home), child: Text(context.tr('start_shopping'))),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _CartTile(item: state.items[i]),
                ),
              ),
              _Summary(state: state),
            ],
          );
        },
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  final CartItem item;
  const _CartTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Row(
        children: [
          AppNetworkImage(url: item.product.images.first, width: 76, height: 90, radius: BorderRadius.circular(12)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(item.product.storeName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text('${item.color.name} • ${item.size}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(formatEgp(item.product.price), style: const TextStyle(color: AppColors.price, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: () => context.read<CartCubit>().remove(item.key),
              ),
              Row(
                children: [
                  _qtyBtn(context, Icons.remove, () => context.read<CartCubit>().updateQty(item.key, item.qty - 1)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  _qtyBtn(context, Icons.add, () => context.read<CartCubit>().updateQty(item.key, item.qty + 1)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final CartState state;
  const _Summary({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(context.tr('subtotal'), formatEgp(state.subtotal)),
          const SizedBox(height: 6),
          _row(context.tr('delivery_fee'), formatEgp(state.deliveryFee)),
          const Divider(height: 20),
          _row(context.tr('total'), formatEgp(state.total), bold: true),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: () => context.push(Routes.checkout), child: Text(context.tr('checkout'))),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: bold ? 17 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: bold ? AppColors.textPrimary : AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: bold ? 18 : 14, fontWeight: FontWeight.bold, color: bold ? AppColors.price : AppColors.textPrimary)),
      ],
    );
  }
}

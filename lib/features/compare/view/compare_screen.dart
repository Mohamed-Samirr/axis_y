import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/catalog.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/state_views.dart';
import '../cubit/compare_cubit.dart';

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('compare_title'))),
      body: BlocBuilder<CompareCubit, List<Product>>(
        builder: (context, products) {
          if (products.isEmpty) {
            return EmptyView(
              icon: Icons.compare_arrows,
              title: context.tr('compare_empty'),
              action: ElevatedButton(onPressed: () => context.go(Routes.explore), child: Text(context.tr('start_shopping'))),
            );
          }
          final size = sl<AuthRepository>().currentUser?.measurements?.recommendedSize;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _ComparisonTable(products: products, userSize: size),
            ),
          );
        },
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final List<Product> products;
  final String? userSize;
  const _ComparisonTable({required this.products, required this.userSize});

  @override
  Widget build(BuildContext context) {
    const colWidth = 150.0;
    Widget cell(Widget child, {bool header = false}) => Container(
          width: colWidth,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
          child: child,
        );

    bool fits(Product p) => userSize != null && p.sizes.any((s) => s.label == userSize && s.available);

    return Column(
      children: [
        // Images + remove
        Row(
          children: products
              .map((p) => cell(Column(
                    children: [
                      Stack(
                        children: [
                          AppNetworkImage(url: p.images.first, width: colWidth - 16, height: 130, radius: BorderRadius.circular(10)),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                              onPressed: () => context.read<CompareCubit>().remove(p.id),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(p.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  )))
              .toList(),
        ),
        _dataRow(context.tr('price'), products.map((p) => formatEgp(p.price)).toList(), cell),
        _dataRow(context.tr('store'), products.map((p) => p.storeName).toList(), cell),
        _dataRow(context.tr('rating'), products.map((p) => '${p.rating.toStringAsFixed(1)} ★').toList(), cell),
        _dataRow(context.tr('material'), products.map((p) => p.material).toList(), cell),
        _dataRow(context.tr('delivery'), products.map((p) => formatEgp(p.deliveryFee)).toList(), cell),
        // Fits your size
        Row(
          children: products.map((p) {
            final ok = fits(p);
            return cell(Center(
              child: Text(ok ? '✔' : '⚠', style: TextStyle(fontSize: 20, color: ok ? AppColors.success : AppColors.warning)),
            ));
          }).toList(),
        ),
        // Buy
        Row(
          children: products
              .map((p) => cell(ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                    onPressed: () => context.push('${Routes.product}/${p.id}'),
                    child: Text(context.tr('buy')),
                  )))
              .toList(),
        ),
      ],
    );
  }

  Widget _dataRow(String label, List<String> values, Widget Function(Widget, {bool header}) cell) {
    return Row(
      children: [
        for (final v in values)
          cell(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          )),
      ],
    );
  }
}

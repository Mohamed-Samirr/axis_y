import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/wishlist/cubit/wishlist_cubit.dart';
import '../localization/app_localizations.dart';
import '../models/catalog.dart';
import '../router/routes.dart';
import '../theme/app_colors.dart';
import '../utils/money.dart';
import 'app_network_image.dart';
import 'rating_stars.dart';

/// Reusable product card: image, name, store, price, wishlist heart.
class ProductCard extends StatelessWidget {
  final Product product;
  final double width;

  const ProductCard({super.key, required this.product, this.width = 170});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${Routes.product}/${product.id}'),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AppNetworkImage(
                  url: product.images.first,
                  width: width,
                  height: width * 1.15,
                  radius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                if (product.isDiscounted)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _Badge(text: '-${(100 - product.price / product.oldPrice! * 100).round()}%', color: AppColors.danger),
                  ),
                if (product.isNew && !product.isDiscounted)
                  Positioned(top: 8, left: 8, child: _Badge(text: context.tr('cat_new'), color: AppColors.navy)),
                Positioned(top: 4, right: 4, child: _HeartButton(productId: product.id)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(product.storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  RatingStars(rating: product.rating, size: 13),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(formatEgp(product.price), style: const TextStyle(color: AppColors.price, fontWeight: FontWeight.bold, fontSize: 15)),
                      if (product.isDiscounted) ...[
                        const SizedBox(width: 6),
                        Text(
                          formatEgp(product.oldPrice!),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, decoration: TextDecoration.lineThrough),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _HeartButton extends StatelessWidget {
  final String productId;
  const _HeartButton({required this.productId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WishlistCubit, Set<String>>(
      builder: (context, ids) {
        final liked = ids.contains(productId);
        return Material(
          color: Colors.white.withValues(alpha: 0.9),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.read<WishlistCubit>().toggle(productId),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: liked ? AppColors.danger : AppColors.textSecondary,
              ),
            ),
          ),
        );
      },
    );
  }
}

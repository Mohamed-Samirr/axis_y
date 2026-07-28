import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/commerce.dart';
import '../../../core/models/fit.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/catalog_repository.dart';
import '../../../core/repositories/tryon_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/verdict_view.dart';
import '../../cart_checkout/cubit/cart_cubit.dart';
import '../../compare/cubit/compare_cubit.dart';
import '../../wishlist/cubit/wishlist_cubit.dart';
import '../cubit/product_details_cubit.dart';

class ProductDetailsScreen extends StatelessWidget {
  final String productId;
  const ProductDetailsScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductDetailsCubit(
        sl<CatalogRepository>(),
        sl<AuthRepository>(),
        sl<TryOnRepository>(),
        sl<SessionService>(),
      )..load(productId),
      child: const _ProductDetailsBody(),
    );
  }
}

class _ProductDetailsBody extends StatelessWidget {
  const _ProductDetailsBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
        builder: (context, state) {
          return switch (state) {
            ProductDetailsLoading() => const Center(child: CircularProgressIndicator(color: AppColors.navy)),
            ProductDetailsError(:final message) => Scaffold(appBar: AppBar(), body: ErrorView(message: message)),
            ProductDetailsLoaded() => _Loaded(state: state),
          };
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  final ProductDetailsLoaded state;
  const _Loaded({required this.state});

  Product get product => state.product;

  void _addToCart(BuildContext context) {
    if (state.selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('select_size'))));
      return;
    }
    context.read<CartCubit>().add(CartItem(
          product: product,
          color: state.selectedColor,
          size: state.selectedSize!,
        ));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('added_to_cart'))));
  }

  @override
  Widget build(BuildContext context) {
    final images = state.selectedColor.image.isNotEmpty
        ? [state.selectedColor.image, ...product.images]
        : product.images;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 420,
            pinned: true,
            actions: [
              BlocBuilder<WishlistCubit, Set<String>>(
                builder: (context, ids) => IconButton(
                  icon: Icon(ids.contains(product.id) ? Icons.favorite : Icons.favorite_border, color: AppColors.danger),
                  onPressed: () => context.read<WishlistCubit>().toggle(product.id),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('share')))),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(background: _ImageSlider(images: images)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => context.go('${Routes.explore}?store=${product.storeId}'),
                    child: Text(product.storeName, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      RatingStars(rating: product.rating, size: 18),
                      const SizedBox(width: 6),
                      Text(context.tr('reviews_count', args: {'n': '${product.reviewCount}'}), style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Same guard as ProductCard: two prices at 24sp overflow this
                  // row on a narrow phone once the text scale is turned up.
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatEgp(product.price), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.price)),
                          if (product.isDiscounted) ...[
                            const SizedBox(width: 10),
                            Text(formatEgp(product.oldPrice!), style: const TextStyle(color: AppColors.textSecondary, fontSize: 16, decoration: TextDecoration.lineThrough)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(product.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                  const SizedBox(height: 8),
                  Text('${context.tr('material')}: ${product.material}', style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 20),

                  // Colors
                  Text(context.tr('select_color'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(product.colors.length, (i) {
                      final c = product.colors[i];
                      final selected = i == state.colorIndex;
                      return GestureDetector(
                        onTap: () => context.read<ProductDetailsCubit>().selectColor(i),
                        child: Container(
                          margin: const EdgeInsetsDirectional.only(end: 12),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Color(c.hex),
                            shape: BoxShape.circle,
                            border: Border.all(color: selected ? AppColors.navy : AppColors.divider, width: selected ? 3 : 1),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Sizes
                  Text(context.tr('select_size'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: product.sizes.map((s) {
                      final selected = state.selectedSize == s.label;
                      final recommended = s.label == state.recommendedSize;
                      return GestureDetector(
                        onTap: s.available ? () => context.read<ProductDetailsCubit>().selectSize(s.label) : null,
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.navy : (recommended ? AppColors.navy.withValues(alpha: 0.08) : AppColors.surface),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: recommended ? AppColors.navy : AppColors.divider, width: recommended ? 1.6 : 1),
                          ),
                          child: Text(
                            s.label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: selected ? Colors.white : (s.available ? AppColors.textPrimary : AppColors.textSecondary),
                              decoration: s.available ? null : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // Backend fit verdict for the selected size. It supersedes the
                  // local "not your usual size" hint, which is only a guess.
                  if (state.fitLoading) ...[
                    const SizedBox(height: 12),
                    const _FitCheckSkeleton(),
                  ] else if (state.fit != null) ...[
                    const SizedBox(height: 12),
                    _FitCheckBanner(fit: state.fit!),
                  ] else if (state.sizeMismatch) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(context.tr('size_warning', args: {'size': state.recommendedSize!}), style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Try-on CTA
                  if (product.tryOnAvailable)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('${Routes.tryon}/${product.id}'),
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(context.tr('try_on_cta')),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('reserve_in_store')))),
                          icon: const Icon(Icons.place_outlined, size: 18),
                          label: Text(context.tr('reserve_in_store'), style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _CompareButton(product: product),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Similar
                  if (state.similar.isNotEmpty) ...[
                    Text(context.tr('you_may_like'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 300,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.similar.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => ProductCard(product: state.similar[i]),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Reviews
                  Text(context.tr('reviews'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...product.reviews.map((r) => _ReviewTile(review: r)),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _BottomBar(onAddToCart: () => _addToCart(context)),
    );
  }
}

/// `POST /fit-check` verdict: recommended size plus the tightest region, with
/// the alternatives the engine suggested.
class _FitCheckBanner extends StatelessWidget {
  final FitResult fit;
  const _FitCheckBanner({required this.fit});

  @override
  Widget build(BuildContext context) {
    final color = verdictColor(fit.overallVerdict);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(verdictIcon(fit.overallVerdict), color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(fit.overallVerdict.key),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                context.tr('fit_confidence', args: {'p': (fit.overallConfidence * 100).round().toString()}),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          if (fit.recommendation != null) ...[
            const SizedBox(height: 6),
            // Server-authored copy, shown as-is.
            Text(fit.recommendation!, style: const TextStyle(fontSize: 13)),
          ],
          if (fit.regions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: fit.regions
                  .map((r) => Text(
                        '${context.tr(r.labelKey)} ${r.easeCm >= 0 ? '+' : ''}${r.easeCm.toStringAsFixed(1)} ${context.tr('cm')}',
                        style: TextStyle(fontSize: 12, color: verdictColor(r.verdict), fontWeight: FontWeight.w600),
                      ))
                  .toList(),
            ),
          ],
          if (fit.alternativeSizes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${context.tr('fit_other_sizes')}: ${fit.alternativeSizes.map((a) => '${a.sizeLabel} (${context.tr(a.predictedVerdict.key)})').join(' · ')}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _FitCheckSkeleton extends StatelessWidget {
  const _FitCheckSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy),
          ),
          const SizedBox(width: 10),
          Text(context.tr('fit_checking'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ImageSlider extends StatefulWidget {
  final List<String> images;
  const _ImageSlider({required this.images});

  @override
  State<_ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<_ImageSlider> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        PageView.builder(
          controller: _controller,
          onPageChanged: (i) => setState(() => _index = i),
          itemCount: widget.images.length,
          itemBuilder: (_, i) => AppNetworkImage(url: widget.images[i], fit: BoxFit.cover),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(color: active ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(4)),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _CompareButton extends StatelessWidget {
  final Product product;
  const _CompareButton({required this.product});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CompareCubit, List<Product>>(
      builder: (context, list) {
        final inCompare = list.any((p) => p.id == product.id);
        return OutlinedButton.icon(
          onPressed: () {
            final ok = context.read<CompareCubit>().toggle(product);
            final messenger = ScaffoldMessenger.of(context);
            if (!ok) {
              messenger.showSnackBar(SnackBar(content: Text(context.tr('compare_max'))));
            } else if (!inCompare) {
              messenger.showSnackBar(SnackBar(
                content: Text(context.tr('add_to_compare')),
                action: SnackBarAction(label: context.tr('compare'), onPressed: () => context.push(Routes.compare)),
              ));
            }
          },
          icon: Icon(inCompare ? Icons.check : Icons.compare_arrows, size: 18),
          label: Text(context.tr('add_to_compare'), style: const TextStyle(fontSize: 13)),
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 16, backgroundColor: AppColors.navy.withValues(alpha: 0.1), child: Text(review.user[0], style: const TextStyle(color: AppColors.navy))),
              const SizedBox(width: 8),
              Text(review.user, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(review.date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          RatingStars(rating: review.rating, size: 14),
          const SizedBox(height: 4),
          Text(review.text, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onAddToCart;
  const _BottomBar({required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          _CartBadge(),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onAddToCart,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(context.tr('add_to_cart')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        return Stack(
          alignment: AlignmentDirectional.topEnd,
          children: [
            IconButton.outlined(onPressed: () => context.push(Routes.cart), icon: const Icon(Icons.shopping_cart_outlined)),
            if (state.count > 0)
              Positioned(
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                  child: Text('${state.count}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        );
      },
    );
  }
}

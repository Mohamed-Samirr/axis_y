import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/catalog.dart';
import '../../../core/repositories/catalog_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/state_views.dart';
import '../cubit/wishlist_cubit.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Product>? _all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<CatalogRepository>().getProducts();
    if (mounted) setState(() => _all = result.valueOrNull ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.tr('wishlist')),
        actions: [
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('share_wishlist')))),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: _all == null
          ? const ProductGridSkeleton()
          : BlocBuilder<WishlistCubit, Set<String>>(
              builder: (context, ids) {
                final items = _all!.where((p) => ids.contains(p.id)).toList();
                if (items.isEmpty) {
                  return EmptyView(
                    icon: Icons.favorite_border,
                    title: context.tr('wishlist_empty'),
                    action: ElevatedButton(onPressed: () => context.go(Routes.explore), child: Text(context.tr('start_shopping'))),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.6,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => ProductCard(product: items[i], width: double.infinity),
                );
              },
            ),
    );
  }
}

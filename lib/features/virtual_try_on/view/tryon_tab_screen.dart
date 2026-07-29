import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/catalog.dart';
import '../../../core/repositories/catalog_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/state_views.dart';
import 'tryon_screen.dart';

/// The try-on bottom-nav tab.
///
/// [TryOnScreen] is normally pushed from a product page and takes the product
/// with it. A tab has no product context, so this resolves one itself — the
/// first try-on-able item in the catalog — and hands it over. That is the
/// t-shirt today, and stays correct as the catalog grows.
class TryOnTabScreen extends StatefulWidget {
  const TryOnTabScreen({super.key});

  @override
  State<TryOnTabScreen> createState() => _TryOnTabScreenState();
}

class _TryOnTabScreenState extends State<TryOnTabScreen> {
  late Future<Result<List<Product>>> _products;

  @override
  void initState() {
    super.initState();
    _products = sl<CatalogRepository>().getProducts();
  }

  void _reload() {
    setState(() => _products = sl<CatalogRepository>().getProducts());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<List<Product>>>(
      future: _products,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.navy)));
        }
        final result = snapshot.data;
        if (result == null) {
          return Scaffold(body: ErrorView(message: context.tr('error_generic'), onRetry: _reload));
        }
        return result.when(
          success: (products) {
            final product = products.where((p) => p.tryOnAvailable).firstOrNull;
            if (product == null) {
              // No catalog, or nothing in it supports try-on.
              return Scaffold(
                body: ErrorView(message: context.tr('tryon_no_products'), onRetry: _reload),
              );
            }
            // Keyed on the id so a catalog change rebuilds the Cubit underneath
            // rather than leaving the previous product's mesh on screen.
            return TryOnScreen(key: ValueKey(product.id), productId: product.id);
          },
          failure: (message) =>
              Scaffold(body: ErrorView(message: context.tr(message), onRetry: _reload)),
        );
      },
    );
  }
}

import 'package:axis_y/core/di/injector.dart';
import 'package:axis_y/core/localization/app_localizations.dart';
import 'package:axis_y/core/models/catalog.dart';
import 'package:axis_y/core/repositories/catalog_repository.dart';
import 'package:axis_y/core/utils/result.dart';
import 'package:axis_y/features/virtual_try_on/view/tryon_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Only the tab's own resolution logic is exercised here. The success path
/// hands off to TryOnScreen, which needs the whole try-on dependency graph.
class _FakeCatalog implements CatalogRepository {
  final Result<List<Product>> products;
  _FakeCatalog(this.products);

  @override
  Future<Result<List<Product>>> getProducts() async => products;

  @override
  Future<Result<Product>> getProduct(String id) async => const Failure('not used');

  @override
  Future<Result<List<Product>>> search(String query) async => products;

  @override
  Future<Result<List<Store>>> getStores() async => const Success([]);

  @override
  Future<Result<List<AppBanner>>> getBanners() async => const Success([]);
}

Product _product({required bool tryOn}) => Product(
      id: 'p-1',
      name: 'Tee',
      storeId: 's1',
      storeName: 'AXIS',
      price: 499,
      images: const [''],
      colors: const [ProductColor(name: 'Black', hex: 0xFF111111, image: '')],
      sizes: const [],
      material: '',
      description: '',
      rating: 0,
      reviewCount: 0,
      category: ProductCategory.tops,
      tryOnAvailable: tryOn,
    );

void main() {
  Widget wrap() => const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ar')],
        home: TryOnTabScreen(),
      );

  // `reset` is async — registering before it completes gets wiped.
  Future<void> registerCatalog(Result<List<Product>> products) async {
    await sl.reset();
    sl.registerLazySingleton<CatalogRepository>(() => _FakeCatalog(products));
  }

  tearDown(() async => sl.reset());

  testWidgets('tells the user when nothing in the catalog supports try-on', (tester) async {
    await registerCatalog(Success([_product(tryOn: false)]));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('No products available to try on yet'), findsOneWidget);
  });

  testWidgets('shows the empty-catalog message rather than a blank tab', (tester) async {
    await registerCatalog(const Success([]));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('No products available to try on yet'), findsOneWidget);
  });

  testWidgets('surfaces a catalog failure with a retry', (tester) async {
    await registerCatalog(const Failure('scan_err_offline'));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Localized through the same key map the rest of the app uses.
    expect(find.text('Retry'), findsOneWidget);
  });
}

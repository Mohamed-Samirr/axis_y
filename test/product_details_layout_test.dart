import 'package:axis_y/core/data/local_store.dart';
import 'package:axis_y/core/di/injector.dart';
import 'package:axis_y/core/localization/app_localizations.dart';
import 'package:axis_y/core/models/catalog.dart';
import 'package:axis_y/core/models/commerce.dart';
import 'package:axis_y/core/models/fit.dart';
import 'package:axis_y/core/models/user.dart';
import 'package:axis_y/core/repositories/auth_repository.dart';
import 'package:axis_y/core/repositories/cart_repository.dart';
import 'package:axis_y/core/repositories/catalog_repository.dart';
import 'package:axis_y/core/repositories/tryon_repository.dart';
import 'package:axis_y/core/repositories/wishlist_repository.dart';
import 'package:axis_y/core/services/session_service.dart';
import 'package:axis_y/core/theme/app_theme.dart';
import 'package:axis_y/core/utils/result.dart';
import 'package:axis_y/features/cart_checkout/cubit/cart_cubit.dart';
import 'package:axis_y/features/compare/cubit/compare_cubit.dart';
import 'package:axis_y/features/product_details/view/product_details_screen.dart';
import 'package:axis_y/features/wishlist/cubit/wishlist_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCatalog implements CatalogRepository {
  final Product product;
  _FakeCatalog(this.product);

  @override
  Future<Result<Product>> getProduct(String id) async => Success(product);

  @override
  Future<Result<List<Product>>> getProducts() async => Success([product]);

  @override
  Future<Result<List<Product>>> search(String query) async => Success([product]);

  @override
  Future<Result<List<Store>>> getStores() async => const Success([]);

  @override
  Future<Result<List<AppBanner>>> getBanners() async => const Success([]);
}

class _FakeAuth implements AuthRepository {
  @override
  AppUser? get currentUser => null;
  @override
  bool get isLoggedIn => false;
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Never reached: the fake session carries no scan, so the product page skips
/// `/fit-check` entirely.
class _FakeTryOn implements TryOnRepository {
  @override
  Future<Result<FitResult>> fitCheck({
    required String scanId,
    required Product product,
    required String sizeLabel,
  }) async =>
      const Failure('err_generic');

  @override
  Future<Result<TryOnResult>> tryOn({
    required String scanId,
    required Product product,
    required String sizeLabel,
    bool autoSelectSize = false,
  }) async =>
      const Failure('err_generic');
}

class _FakeCart implements CartRepository {
  @override
  List<CartItem> get items => const [];
  @override
  void add(CartItem item) {}
  @override
  void clear() {}
  @override
  void remove(String key) {}
  @override
  void updateQty(String key, int qty) {}
}

class _FakeWishlist implements WishlistRepository {
  @override
  Set<String> get ids => const {};
  @override
  bool contains(String id) => false;
  @override
  void toggle(String id) {}
}

/// Shaped like what `ApiCatalogRepository` produces for the seeded backend
/// product: real sizes, the synthesized fallback colour, no imagery.
Product _product() => const Product(
      id: 'p-1',
      name: 'Axis Y Core T-Shirt',
      storeId: 's-1',
      storeName: 'Axis Y',
      price: 25,
      images: [''],
      colors: [ProductColor(name: '—', hex: 0xFF1B2A4A, image: '')],
      sizes: [
        ProductSize(label: 'S', chest: 0, waist: 0, length: 0),
        ProductSize(label: 'M', chest: 0, waist: 0, length: 0),
      ],
      material: '',
      description: '',
      rating: 0,
      reviewCount: 0,
      category: ProductCategory.tops,
      tryOnAvailable: true,
    );

Widget _host() => MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CartCubit(_FakeCart())),
        BlocProvider(create: (_) => WishlistCubit(_FakeWishlist())),
        BlocProvider(create: (_) => CompareCubit()),
      ],
      child: MaterialApp(
        // The bug lives in the theme's `minimumSize: Size.fromHeight(52)`, so
        // the real theme is the whole point of this test.
        theme: AppTheme.light,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const ProductDetailsScreen(productId: 'p-1'),
      ),
    );

void main() {
  setUp(() async {
    await sl.reset();
    // `formatEgp` reads the saved locale straight off the store.
    SharedPreferences.setMockInitialValues({});
    sl.registerSingleton<LocalStore>(await LocalStore.create());
    sl.registerLazySingleton<CatalogRepository>(() => _FakeCatalog(_product()));
    sl.registerLazySingleton<AuthRepository>(_FakeAuth.new);
    sl.registerLazySingleton<TryOnRepository>(_FakeTryOn.new);
    sl.registerLazySingleton<SessionService>(
      () => SessionService(const FlutterSecureStorage(), 'device-1', null),
    );
  });

  tearDown(() async => sl.reset());

  // The compare button sits bare in a Row next to an Expanded sibling, so it is
  // handed unbounded width. Every themed button carries
  // `minimumSize: Size.fromHeight(52)` — a *width* of `double.infinity` — which
  // turns that into "BoxConstraints forces an infinite width" and takes the
  // whole page down with it. The page then renders blank, so the try-on CTA
  // below it is unreachable: tapping the product looked like a crash.
  group('ProductDetailsScreen lays out', () {
    for (final size in const [Size(320, 568), Size(360, 640), Size(411, 891)]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        testWidgets('at ${size.width}px, textScale $scale', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await tester.pumpWidget(_host());
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // Not vacuous: the page really did render its content.
          expect(find.text('Axis Y Core T-Shirt'), findsOneWidget);
        });
      }
    }

    testWidgets('with the try-on CTA reachable', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.text('Try it on ✨'), findsOneWidget);
      expect(find.text('Add to compare'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

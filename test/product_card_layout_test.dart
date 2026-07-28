import 'package:axis_y/core/data/local_store.dart';
import 'package:axis_y/core/di/injector.dart';
import 'package:axis_y/core/localization/app_localizations.dart';
import 'package:axis_y/core/models/catalog.dart';
import 'package:axis_y/core/repositories/wishlist_repository.dart';
import 'package:axis_y/core/widgets/product_card.dart';
import 'package:axis_y/features/wishlist/cubit/wishlist_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWishlist implements WishlistRepository {
  final _ids = <String>{};
  @override
  Set<String> get ids => _ids;
  @override
  bool contains(String id) => _ids.contains(id);
  @override
  void toggle(String id) {}
}

/// Worst case for the price row: a long discounted price. The row is the one
/// place in the card with no width limit of its own, so it is what overflows
/// first — on a narrow phone, in a wide font, or at a large text scale.
Product _product({double price = 12999, double oldPrice = 18999}) => Product(
      id: 'p1',
      name: 'جاكيت شتوي طويل بقلنسوة',
      storeId: 's1',
      storeName: 'متجر الأزياء المصري الحديث',
      price: price,
      oldPrice: oldPrice,
      images: ['https://example.com/a.jpg'],
      colors: [],
      sizes: [],
      material: 'قطن',
      description: 'وصف',
      rating: 4.5,
      reviewCount: 12,
      category: ProductCategory.jackets,
      tryOnAvailable: true,
      isNew: true,
    );

Widget _host(Widget child, {required Size size, required double textScale}) {
  return MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Localizations(
        locale: const Locale('ar'),
        delegates: const [
          AppLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: BlocProvider(
          create: (_) => WishlistCubit(_FakeWishlist()),
          child: Material(child: child),
        ),
      ),
    ),
  );
}

/// The catalog grid, exactly as explore/wishlist configure it.
Widget _grid(Product product) => GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.6,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => ProductCard(product: product, width: double.infinity),
    );

/// The home / "you may like" horizontal rail.
Widget _rail(Product product) => SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => ProductCard(product: product),
      ),
    );

/// Pumps and then settles the async `Localizations` delegate.
///
/// Without the second pump the whole subtree is still empty, and every layout
/// assertion below would pass without a single card ever being laid out — which
/// is exactly how the price-row overflow slipped through the first time.
Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
  expect(find.byType(ProductCard), findsWidgets, reason: 'nothing rendered — vacuous test');
  expect(find.textContaining('ج.م'), findsWidgets, reason: 'price never rendered');
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    if (!sl.isRegistered<LocalStore>()) {
      sl.registerSingleton<LocalStore>(await LocalStore.create());
    }
  });

  // Smallest phone still in use through to a large one, at the text scales a
  // user can actually set in system settings.
  const sizes = [Size(320, 568), Size(360, 640), Size(411, 891)];
  const scales = [1.0, 1.3, 2.0];

  group('ProductCard never overflows', () {
    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets('in the 2-column grid at ${size.width}px, textScale $scale',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await _pump(tester, _host(_grid(_product()), size: size, textScale: scale));
          expect(tester.takeException(), isNull);
        });

        testWidgets('in the horizontal rail at ${size.width}px, textScale $scale',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await _pump(tester, _host(_rail(_product()), size: size, textScale: scale));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('with a price far longer than the card is wide', (tester) async {
      const size = Size(320, 568);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // No price this large exists in the catalog today, but the row must
      // ellipsize rather than overflow whatever the store prices things at.
      final product = _product(price: 9999999, oldPrice: 19999999);
      await _pump(tester, _host(_grid(product), size: size, textScale: 1));
      expect(tester.takeException(), isNull);
    });
  });
}

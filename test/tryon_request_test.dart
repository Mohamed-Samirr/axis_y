import 'package:axis_y/core/data/mock_seed.dart';
import 'package:axis_y/core/models/catalog.dart';
import 'package:axis_y/core/repositories/tryon_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Product productWith(List<ProductSize> sizes) => Product(
        id: 'prod-uuid',
        name: 'Tee',
        storeId: 's1',
        storeName: 'AXIS',
        price: 499,
        images: const [''],
        colors: const [ProductColor(name: 'Black', hex: 0xFF111111, image: '')],
        sizes: sizes,
        material: '',
        description: '',
        rating: 0,
        reviewCount: 0,
        category: ProductCategory.tops,
        tryOnAvailable: true,
      );

  group('tryOnRequestBody', () {
    test('never sends size_label — the endpoint has no such field', () {
      final body = tryOnRequestBody(
        scanId: 'scan-uuid',
        product: productWith(const [ProductSize(label: 'M', chest: 100, waist: 86, length: 68, variantId: 'v-m')]),
        sizeLabel: 'M',
        autoSelectSize: false,
      );

      expect(body.containsKey('size_label'), isFalse);
    });

    test('pins an explicit size by variant id and turns auto-select off', () {
      final body = tryOnRequestBody(
        scanId: 'scan-uuid',
        product: productWith(const [
          ProductSize(label: 'M', chest: 100, waist: 86, length: 68, variantId: 'v-m'),
          ProductSize(label: 'L', chest: 106, waist: 92, length: 71, variantId: 'v-l'),
        ]),
        sizeLabel: 'L',
        autoSelectSize: false,
      );

      expect(body, {
        'scan_id': 'scan-uuid',
        'product_variant_id': 'v-l',
        'auto_select_size': false,
      });
    });

    test('first view asks the backend to choose, by product id', () {
      final body = tryOnRequestBody(
        scanId: 'scan-uuid',
        product: productWith(const [ProductSize(label: 'M', chest: 100, waist: 86, length: 68, variantId: 'v-m')]),
        sizeLabel: 'M',
        autoSelectSize: true,
      );

      expect(body, {
        'scan_id': 'scan-uuid',
        'product_id': 'prod-uuid',
        'auto_select_size': true,
      });
    });

    test('falls back to auto-select when the size has no variant id', () {
      // The live product today: sizes known to the app, `variants: []` on the API.
      final body = tryOnRequestBody(
        scanId: 'scan-uuid',
        product: productWith(const [ProductSize(label: 'L', chest: 106, waist: 92, length: 71)]),
        sizeLabel: 'L',
        autoSelectSize: false,
      );

      expect(body, {
        'scan_id': 'scan-uuid',
        'product_id': 'prod-uuid',
        'auto_select_size': true,
      });
    });

    test('a product with no sizes at all still builds a valid body', () {
      final body = tryOnRequestBody(
        scanId: 'scan-uuid',
        product: productWith(const []),
        sizeLabel: '',
        autoSelectSize: true,
      );

      expect(body['product_id'], 'prod-uuid');
      expect(body['auto_select_size'], isTrue);
    });
  });

  group('MockSeed.testProduct', () {
    test('carries the real backend product id, in the dashed form the API returns', () {
      expect(MockSeed.testProduct.id, '016174c8-8e75-4542-b0fa-e1eb1c2220de');
      expect(MockSeed.testProduct.name, 'test');
      expect(MockSeed.testProduct.tryOnAvailable, isTrue);
      expect(MockSeed.testProduct.sizes.map((s) => s.label), ['XS', 'S', 'M', 'L', 'XL']);
    });

    test('is in the catalog, appended so the order history indices still hold', () {
      expect(MockSeed.products, contains(MockSeed.testProduct));
      expect(MockSeed.products.last, MockSeed.testProduct);
      expect(MockSeed.products.first.id, 'p1');
    });
  });
}

import 'package:axis_y/core/models/catalog.dart';
import 'package:axis_y/core/models/fit.dart';
import 'package:axis_y/core/repositories/api_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Shaped after the live backend's ProductResponse (OpenAPI `ProductResponse`
  // / `ProductVariantResponse`).
  Map<String, dynamic> product({List<Map<String, dynamic>>? variants}) => {
        'id': '3f6e1c2a-0000-4000-8000-000000000001',
        'store_id': '3f6e1c2a-0000-4000-8000-0000000000ff',
        'template_slug': 'tshirt',
        'sku': 'AX-TS-01',
        'name': 'Basic Tee',
        'brand': 'AXIS',
        'gender': 'unisex',
        'active': true,
        'created_at': '2026-07-01T10:00:00Z',
        'variants': variants ?? const [],
      };

  Map<String, dynamic> variant(
    String id,
    String size, {
    String? colorName = 'Black',
    String? colorHex = '#101820',
    num? price = 499,
    bool inStock = true,
  }) =>
      {
        'id': id,
        'product_id': '3f6e1c2a-0000-4000-8000-000000000001',
        'size_label': size,
        'color_name': colorName,
        'color_hex': colorHex,
        'price': price,
        'in_stock': inStock,
      };

  group('productFromApi', () {
    test('keeps the variant id per size — try-on selects a size by that id', () {
      final p = productFromApi(product(variants: [
        variant('v-s', 'S'),
        variant('v-m', 'M'),
      ]));

      expect(p.sizes.map((s) => s.label), ['S', 'M']);
      expect(p.sizes.firstWhere((s) => s.label == 'M').variantId, 'v-m');
    });

    test('projects variants onto the two independent axes the UI uses', () {
      // One (size × colour) grid: 2 sizes × 2 colours = 4 variants.
      final p = productFromApi(product(variants: [
        variant('v1', 'S', colorName: 'Black', colorHex: '#101820'),
        variant('v2', 'S', colorName: 'White', colorHex: '#FFFFFF'),
        variant('v3', 'M', colorName: 'Black', colorHex: '#101820'),
        variant('v4', 'M', colorName: 'White', colorHex: '#FFFFFF'),
      ]));

      expect(p.sizes.map((s) => s.label), ['S', 'M']);
      expect(p.colors.map((c) => c.name), ['Black', 'White']);
    });

    test('a size is available when any of its variants is in stock', () {
      final p = productFromApi(product(variants: [
        variant('v1', 'S', colorName: 'Black', inStock: false),
        variant('v2', 'S', colorName: 'White', inStock: true),
        variant('v3', 'M', colorName: 'Black', inStock: false),
      ]));

      expect(p.sizes.firstWhere((s) => s.label == 'S').available, isTrue);
      expect(p.sizes.firstWhere((s) => s.label == 'M').available, isFalse);
    });

    test('shows the lowest variant price, since price is per variant', () {
      final p = productFromApi(product(variants: [
        variant('v1', 'S', price: 799),
        variant('v2', 'M', price: 499),
      ]));

      expect(p.price, 499);
    });

    test('maps the template slug onto the app category', () {
      ProductCategory categoryOf(String slug) =>
          productFromApi({...product(), 'template_slug': slug}).category;

      expect(categoryOf('tshirt'), ProductCategory.tops);
      expect(categoryOf('jeans'), ProductCategory.pants);
      expect(categoryOf('hoodie'), ProductCategory.jackets);
      expect(categoryOf('summer_dress'), ProductCategory.dresses);
    });

    test('parses colour hex with and without the leading #, opaque either way', () {
      final p = productFromApi(product(variants: [
        variant('v1', 'S', colorName: 'Ink', colorHex: '#101820'),
        variant('v2', 'M', colorName: 'Sand', colorHex: 'D9C7A7'),
      ]));

      expect(p.colors[0].hex, 0xFF101820);
      expect(p.colors[1].hex, 0xFFD9C7A7);
    });

    test('survives a product with no variants at all', () {
      final p = productFromApi(product());

      expect(p.sizes, isEmpty);
      expect(p.colors, isEmpty);
      expect(p.price, 0);
      expect(p.name, 'Basic Tee');
    });
  });

  group('TryOnResult.fromApi', () {
    test('reads the auto-selected size from the response, not from fit_result', () {
      // `FitResult` has no size_label field at all — the size the server chose
      // is a sibling of fit_result.
      final r = TryOnResult.fromApi({
        'tryon_id': 't-1',
        'garment_glb_url': 'https://x/garment.glb',
        'body_glb_url': 'https://x/body.glb',
        'selected_size_label': 'L',
        'fit_result': {
          'overall_verdict': 'PERFECT_FIT',
          'overall_confidence': 0.93,
          'regions': {
            'chest_cm': {'body_cm': 99.5, 'garment_cm': 104.0, 'ease_cm': 4.5, 'verdict': 'PERFECT_FIT'},
          },
        },
      });

      expect(r.fitResult.sizeLabel, 'L');
      expect(r.fitResult.overallVerdict, FitVerdict.perfectFit);
      expect(r.hasMesh, isTrue);
    });
  });
}

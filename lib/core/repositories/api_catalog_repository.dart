import '../config/app_config.dart';
import '../models/catalog.dart';
import '../network/api_client.dart';
import '../utils/result.dart';
import 'catalog_repository.dart';

/// Catalog backed by the real product database (`GET /api/v1/products`).
///
/// The API's `ProductResponse` is a *fitting* record, not a storefront one: it
/// carries the SKU, the template slug and the size/colour variants, and nothing
/// merchandising — no images, no rating, no reviews, no description. So this
/// class maps what exists and synthesizes presentable defaults for the rest,
/// which is why every product still renders in the existing UI.
///
/// The part that matters for try-on: variant ids survive the mapping. They are
/// how `POST /try-on` selects a size.
class ApiCatalogRepository implements CatalogRepository {
  final ApiClient _api;
  ApiCatalogRepository(this._api);

  /// One page is enough for the catalog screens today; the guide's lazy-loading
  /// is a separate change (`page` / `page_size` are already supported).
  static const int pageSize = 100;

  @override
  Future<Result<List<Product>>> getProducts() async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '${AppConfig.mainApiPrefix}/products',
        queryParameters: <String, dynamic>{'page': 1, 'page_size': pageSize},
        options: standardOptions(),
      );
      final raw = (res.data?['products'] as List?) ?? const [];
      return Success(raw.whereType<Map<String, dynamic>>().map(productFromApi).toList());
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<Product>> getProduct(String id) async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '${AppConfig.mainApiPrefix}/products/$id',
        options: standardOptions(),
      );
      return Success(productFromApi(res.data ?? const {}));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  /// No search endpoint exists yet, so this filters the fetched page client
  /// side rather than pretending to be server-side search.
  @override
  Future<Result<List<Product>>> search(String query) async {
    final q = query.trim().toLowerCase();
    return (await getProducts()).when(
      success: (list) => q.isEmpty
          ? Success(list)
          : Success(list
              .where((p) =>
                  p.name.toLowerCase().contains(q) || p.storeName.toLowerCase().contains(q))
              .toList()),
      failure: Failure.new,
    );
  }

  /// `GET /stores` does not exist — only `POST` — so the store list is derived
  /// from the products themselves. Product counts are real; ratings are not
  /// modelled server-side at all.
  @override
  Future<Result<List<Store>>> getStores() async {
    return (await getProducts()).when(
      success: (products) {
        final counts = <String, int>{};
        for (final p in products) {
          counts[p.storeId] = (counts[p.storeId] ?? 0) + 1;
        }
        return Success(counts.entries
            .map((e) => Store(
                  id: e.key,
                  name: products.firstWhere((p) => p.storeId == e.key).storeName,
                  logo: '🏬',
                  productCount: e.value,
                  rating: 0,
                ))
            .toList());
      },
      failure: Failure.new,
    );
  }

  /// Banners are pure merchandising with no backend table behind them.
  @override
  Future<Result<List<AppBanner>>> getBanners() async => const Success([]);
}

/// Maps one `ProductResponse` onto the app's [Product].
///
/// Sizes and colours are both projections of the same `variants` list: the API
/// models a variant as one (size × colour) pair, while the UI picks size and
/// colour independently. Each is deduplicated on its own axis.
Product productFromApi(Map<String, dynamic> json) {
  final variants = ((json['variants'] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();

  // First variant per size wins the id. Colour is chosen separately in the UI,
  // so a size cannot map to a single (size, colour) variant without guessing —
  // see the note on [ProductSize.variantId].
  final sizes = <String, ProductSize>{};
  for (final v in variants) {
    final label = v['size_label'] as String?;
    if (label == null || label.isEmpty) continue;
    final inStock = v['in_stock'] as bool? ?? true;
    final existing = sizes[label];
    if (existing != null) {
      // Any in-stock variant makes the size selectable.
      if (inStock && !existing.available) {
        sizes[label] = ProductSize(
          label: label,
          chest: existing.chest,
          waist: existing.waist,
          length: existing.length,
          available: true,
          variantId: v['id'] as String?,
        );
      }
      continue;
    }
    sizes[label] = ProductSize(
      // Garment measurements are stored per size at creation but are not part
      // of ProductResponse. Nothing in the UI reads them — the backend owns
      // every verdict (guide §4) — so zero is honest here.
      label: label,
      chest: 0,
      waist: 0,
      length: 0,
      available: inStock,
      variantId: v['id'] as String?,
    );
  }

  final colors = <String, ProductColor>{};
  for (final v in variants) {
    final name = v['color_name'] as String? ?? v['color_hex'] as String?;
    if (name == null || name.isEmpty) continue;
    colors.putIfAbsent(
      name,
      () => ProductColor(
        name: name,
        hex: _parseHex(v['color_hex'] as String?),
        image: v['texture_url'] as String? ?? '',
      ),
    );
  }

  // Price lives on the variant, not the product. The lowest one is what a
  // storefront shows for a product with per-variant pricing.
  final prices = variants.map((v) => (v['price'] as num?)?.toDouble()).nonNulls.toList();
  final brand = json['brand'] as String?;

  final images = colors.values.map((c) => c.image).where((i) => i.isNotEmpty).toList();

  return Product(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    storeId: json['store_id'] as String? ?? '',
    storeName: brand == null || brand.isEmpty ? (json['sku'] as String? ?? '') : brand,
    price: prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b),
    // Never empty. A product with no variants — which is what the API returns
    // when a store registered sizes but no colour/size rows — would otherwise
    // blow up every `images.first` / `colors[0]` in the UI, and the mannequin
    // on the try-on screen reads `colors[colorIndex]` on its default path.
    // An empty url is a supported "no image" in [AppNetworkImage].
    images: images.isEmpty ? const [''] : images,
    colors: colors.isEmpty ? const [_defaultColor] : colors.values.toList(),
    // Sizes stay honest: with no variants there is no size the client may pin,
    // and `POST /try-on` then has to auto-select. See [ProductSize.variantId].
    sizes: sizes.values.toList(),
    material: '',
    description: '',
    rating: 0,
    reviewCount: 0,
    category: _categoryFor(json['template_slug'] as String?),
    // Every product in this database exists to be tried on — the template slug
    // is what the morph pipeline is keyed on.
    tryOnAvailable: true,
  );
}

const int _navy = 0xFF1B2A4A;

/// Stands in for a product whose variants carry no colour, so the swatch row
/// and the painted mannequin always have something to render.
const _defaultColor = ProductColor(name: '—', hex: _navy, image: '');

/// `"#1A2B3C"` / `"1A2B3C"` -> opaque ARGB. Falls back to the app's navy so a
/// missing or malformed colour never renders as an invisible swatch.
int _parseHex(String? hex) {
  if (hex == null) return _navy;
  final digits = hex.replaceFirst('#', '').trim();
  final value = int.tryParse(digits, radix: 16);
  if (value == null) return _navy;
  return digits.length <= 6 ? 0xFF000000 | value : value;
}

/// The backend groups garments by `template_slug` (the mesh template the morph
/// engine uses); the app groups them by [ProductCategory].
ProductCategory _categoryFor(String? slug) {
  final s = (slug ?? '').toLowerCase();
  if (s.contains('jean') || s.contains('pant') || s.contains('trouser') || s.contains('short')) {
    return ProductCategory.pants;
  }
  if (s.contains('dress') || s.contains('skirt')) return ProductCategory.dresses;
  if (s.contains('jacket') || s.contains('coat') || s.contains('hoodie')) {
    return ProductCategory.jackets;
  }
  return ProductCategory.tops;
}

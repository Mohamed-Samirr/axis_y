import '../data/mock_seed.dart';
import '../models/catalog.dart';
import '../utils/latency.dart';
import '../utils/result.dart';

abstract class CatalogRepository {
  Future<Result<List<Product>>> getProducts();
  Future<Result<List<Store>>> getStores();
  Future<Result<List<AppBanner>>> getBanners();
  Future<Result<Product>> getProduct(String id);
  Future<Result<List<Product>>> search(String query);
}

class MockCatalogRepository implements CatalogRepository {
  @override
  Future<Result<List<Product>>> getProducts() async {
    await mockLatency();
    return Success(List.unmodifiable(MockSeed.products));
  }

  @override
  Future<Result<List<Store>>> getStores() async {
    await mockLatency();
    return Success(List.unmodifiable(MockSeed.stores));
  }

  @override
  Future<Result<List<AppBanner>>> getBanners() async {
    await mockLatency();
    return Success(List.unmodifiable(MockSeed.banners));
  }

  @override
  Future<Result<Product>> getProduct(String id) async {
    await mockLatency();
    try {
      return Success(MockSeed.products.firstWhere((p) => p.id == id));
    } catch (_) {
      return const Failure('المنتج غير موجود');
    }
  }

  @override
  Future<Result<List<Product>>> search(String query) async {
    await mockLatency();
    final q = query.trim();
    if (q.isEmpty) return Success(List.unmodifiable(MockSeed.products));
    final results = MockSeed.products
        .where((p) => p.name.contains(q) || p.storeName.contains(q))
        .toList();
    return Success(results);
  }
}

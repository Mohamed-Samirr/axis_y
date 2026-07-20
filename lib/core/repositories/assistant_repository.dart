import '../data/mock_seed.dart';
import '../models/catalog.dart';
import '../utils/latency.dart';
import '../utils/result.dart';

enum Occasion { work, friends, party, sport, ramadan }

extension OccasionX on Occasion {
  String get key => switch (this) {
        Occasion.work => 'occ_work',
        Occasion.friends => 'occ_friends',
        Occasion.party => 'occ_party',
        Occasion.sport => 'occ_sport',
        Occasion.ramadan => 'occ_ramadan',
      };
}

abstract class AssistantRepository {
  /// Rule-based outfit suggestion over the catalog for an occasion.
  Future<Result<List<Product>>> suggestOutfit(Occasion occasion);

  /// Mock "match my clothes": analyzes a photo and returns catalog matches.
  Future<Result<List<Product>>> matchClothes();
}

class MockAssistantRepository implements AssistantRepository {
  List<Product> _byCategory(ProductCategory c) =>
      MockSeed.products.where((p) => p.category == c).toList();

  @override
  Future<Result<List<Product>>> suggestOutfit(Occasion occasion) async {
    await mockLatency();
    final List<Product> outfit;
    switch (occasion) {
      case Occasion.work:
        outfit = [_byCategory(ProductCategory.tops)[1], _byCategory(ProductCategory.pants)[4], _byCategory(ProductCategory.jackets)[2]];
      case Occasion.friends:
        outfit = [_byCategory(ProductCategory.tops)[4], _byCategory(ProductCategory.pants)[0], _byCategory(ProductCategory.jackets)[0]];
      case Occasion.party:
        outfit = [_byCategory(ProductCategory.dresses)[1], _byCategory(ProductCategory.jackets)[3]];
      case Occasion.sport:
        outfit = [_byCategory(ProductCategory.tops)[7], _byCategory(ProductCategory.pants)[6], _byCategory(ProductCategory.jackets)[6]];
      case Occasion.ramadan:
        outfit = [_byCategory(ProductCategory.dresses)[4], _byCategory(ProductCategory.tops)[5]];
    }
    return Success(outfit);
  }

  @override
  Future<Result<List<Product>>> matchClothes() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final matches = MockSeed.products.where((p) => p.category != ProductCategory.dresses).take(4).toList();
    return Success(matches);
  }
}

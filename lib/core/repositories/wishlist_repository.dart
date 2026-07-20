import '../data/local_store.dart';

abstract class WishlistRepository {
  Set<String> get ids;
  bool contains(String id);
  void toggle(String id);
}

class LocalWishlistRepository implements WishlistRepository {
  final LocalStore _store;
  final Set<String> _ids = {};

  LocalWishlistRepository(this._store) {
    final raw = _store.getJsonList(StoreKeys.wishlist);
    if (raw != null) _ids.addAll(raw.cast<String>());
  }

  @override
  Set<String> get ids => Set.unmodifiable(_ids);

  @override
  bool contains(String id) => _ids.contains(id);

  @override
  void toggle(String id) {
    if (!_ids.add(id)) _ids.remove(id);
    _store.setJsonList(StoreKeys.wishlist, _ids.toList());
  }
}

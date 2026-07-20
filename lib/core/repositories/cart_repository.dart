import '../data/local_store.dart';
import '../data/mock_seed.dart';
import '../models/catalog.dart';
import '../models/commerce.dart';

abstract class CartRepository {
  List<CartItem> get items;
  void add(CartItem item);
  void updateQty(String key, int qty);
  void remove(String key);
  void clear();
}

class LocalCartRepository implements CartRepository {
  final LocalStore _store;
  final List<CartItem> _items = [];

  LocalCartRepository(this._store) {
    _load();
  }

  @override
  List<CartItem> get items => List.unmodifiable(_items);

  void _load() {
    final raw = _store.getJsonList(StoreKeys.cart);
    if (raw == null) return;
    for (final e in raw) {
      final map = e as Map<String, dynamic>;
      Product? product;
      try {
        product = MockSeed.products.firstWhere((p) => p.id == map['productId']);
      } catch (_) {
        continue;
      }
      final color = product.colors.firstWhere(
        (c) => c.name == map['color'],
        orElse: () => product!.colors.first,
      );
      _items.add(CartItem(
        product: product,
        color: color,
        size: map['size'] as String,
        qty: map['qty'] as int,
      ));
    }
  }

  Future<void> _persist() async {
    await _store.setJsonList(
      StoreKeys.cart,
      _items
          .map((i) => {
                'productId': i.product.id,
                'color': i.color.name,
                'size': i.size,
                'qty': i.qty,
              })
          .toList(),
    );
  }

  @override
  void add(CartItem item) {
    final idx = _items.indexWhere((i) => i.key == item.key);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(qty: _items[idx].qty + item.qty);
    } else {
      _items.add(item);
    }
    _persist();
  }

  @override
  void updateQty(String key, int qty) {
    final idx = _items.indexWhere((i) => i.key == key);
    if (idx < 0) return;
    if (qty <= 0) {
      _items.removeAt(idx);
    } else {
      _items[idx] = _items[idx].copyWith(qty: qty);
    }
    _persist();
  }

  @override
  void remove(String key) {
    _items.removeWhere((i) => i.key == key);
    _persist();
  }

  @override
  void clear() {
    _items.clear();
    _persist();
  }
}

import '../data/mock_seed.dart';
import '../models/commerce.dart';
import '../utils/latency.dart';
import '../utils/result.dart';

abstract class OrderRepository {
  Future<Result<List<AppOrder>>> getOrders();
  Future<Result<AppOrder>> placeOrder(List<CartItem> items, double total);
}

class MockOrderRepository implements OrderRepository {
  final List<AppOrder> _orders = MockSeed.orders();

  @override
  Future<Result<List<AppOrder>>> getOrders() async {
    await mockLatency();
    return Success(List.unmodifiable(_orders));
  }

  @override
  Future<Result<AppOrder>> placeOrder(List<CartItem> items, double total) async {
    await mockLatency();
    final order = AppOrder(
      id: '${10000 + DateTime.now().millisecondsSinceEpoch % 90000}',
      date: DateTime.now().toIso8601String().substring(0, 10),
      status: OrderStatus.received,
      total: total,
      lines: items
          .map((i) => OrderLine(
                productName: i.product.name,
                image: i.product.images.first,
                size: i.size,
                color: i.color.name,
                qty: i.qty,
                price: i.product.price,
              ))
          .toList(),
    );
    _orders.insert(0, order);
    return Success(order);
  }
}

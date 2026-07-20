import 'package:equatable/equatable.dart';

import 'catalog.dart';

class CartItem extends Equatable {
  final Product product;
  final ProductColor color;
  final String size;
  final int qty;

  const CartItem({
    required this.product,
    required this.color,
    required this.size,
    this.qty = 1,
  });

  double get lineTotal => product.price * qty;

  CartItem copyWith({int? qty}) => CartItem(
        product: product,
        color: color,
        size: size,
        qty: qty ?? this.qty,
      );

  /// Unique key for a product + color + size combination.
  String get key => '${product.id}_${color.name}_$size';

  @override
  List<Object?> get props => [product.id, color.name, size, qty];
}

enum OrderStatus { received, preparing, shipping, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get key => switch (this) {
        OrderStatus.received => 'status_received',
        OrderStatus.preparing => 'status_preparing',
        OrderStatus.shipping => 'status_shipping',
        OrderStatus.delivered => 'status_delivered',
        OrderStatus.cancelled => 'status_cancelled',
      };
}

class OrderLine extends Equatable {
  final String productName;
  final String image;
  final String size;
  final String color;
  final int qty;
  final double price;

  const OrderLine({
    required this.productName,
    required this.image,
    required this.size,
    required this.color,
    required this.qty,
    required this.price,
  });

  @override
  List<Object?> get props => [productName, size, color, qty, price];
}

class AppOrder extends Equatable {
  final String id;
  final String date;
  final List<OrderLine> lines;
  final double total;
  final OrderStatus status;

  const AppOrder({
    required this.id,
    required this.date,
    required this.lines,
    required this.total,
    required this.status,
  });

  @override
  List<Object?> get props => [id];
}

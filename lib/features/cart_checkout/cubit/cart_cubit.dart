import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/commerce.dart';
import '../../../core/repositories/cart_repository.dart';

class CartState extends Equatable {
  final List<CartItem> items;

  const CartState(this.items);

  int get count => items.fold(0, (s, i) => s + i.qty);
  double get subtotal => items.fold(0, (s, i) => s + i.lineTotal);
  double get deliveryFee => items.isEmpty ? 0 : 40;
  double get total => subtotal + deliveryFee;

  double totalWith(double discount) => subtotal + deliveryFee - discount;

  @override
  List<Object?> get props => [items];
}

/// App-wide cart ViewModel. Shared across product, cart, checkout, badges.
class CartCubit extends Cubit<CartState> {
  final CartRepository _repo;

  CartCubit(this._repo) : super(CartState(_repo.items));

  void add(CartItem item) {
    _repo.add(item);
    emit(CartState(_repo.items));
  }

  void updateQty(String key, int qty) {
    _repo.updateQty(key, qty);
    emit(CartState(_repo.items));
  }

  void remove(String key) {
    _repo.remove(key);
    emit(CartState(_repo.items));
  }

  void clear() {
    _repo.clear();
    emit(CartState(_repo.items));
  }
}

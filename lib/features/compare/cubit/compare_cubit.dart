import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/catalog.dart';

/// App-wide compare tray, holding up to 3 products.
class CompareCubit extends Cubit<List<Product>> {
  CompareCubit() : super(const []);

  static const max = 3;

  bool contains(String id) => state.any((p) => p.id == id);
  bool get isFull => state.length >= max;

  /// Returns false if the tray is already full and the product isn't in it.
  bool toggle(Product product) {
    if (contains(product.id)) {
      emit(state.where((p) => p.id != product.id).toList());
      return true;
    }
    if (isFull) return false;
    emit([...state, product]);
    return true;
  }

  void remove(String id) => emit(state.where((p) => p.id != id).toList());
  void clear() => emit(const []);
}

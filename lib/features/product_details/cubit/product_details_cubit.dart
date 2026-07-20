import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/catalog.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/catalog_repository.dart';

sealed class ProductDetailsState extends Equatable {
  const ProductDetailsState();
  @override
  List<Object?> get props => [];
}

class ProductDetailsLoading extends ProductDetailsState {
  const ProductDetailsLoading();
}

class ProductDetailsError extends ProductDetailsState {
  final String message;
  const ProductDetailsError(this.message);
  @override
  List<Object?> get props => [message];
}

class ProductDetailsLoaded extends ProductDetailsState {
  final Product product;
  final int colorIndex;
  final String? selectedSize;
  final String? recommendedSize;
  final List<Product> similar;

  const ProductDetailsLoaded({
    required this.product,
    required this.colorIndex,
    required this.selectedSize,
    required this.recommendedSize,
    required this.similar,
  });

  ProductColor get selectedColor => product.colors[colorIndex];

  /// True when the user selected a size different from the recommendation.
  bool get sizeMismatch =>
      recommendedSize != null && selectedSize != null && selectedSize != recommendedSize;

  ProductDetailsLoaded copyWith({int? colorIndex, String? selectedSize}) => ProductDetailsLoaded(
        product: product,
        colorIndex: colorIndex ?? this.colorIndex,
        selectedSize: selectedSize ?? this.selectedSize,
        recommendedSize: recommendedSize,
        similar: similar,
      );

  @override
  List<Object?> get props => [product.id, colorIndex, selectedSize];
}

class ProductDetailsCubit extends Cubit<ProductDetailsState> {
  final CatalogRepository _catalog;
  final AuthRepository _auth;

  ProductDetailsCubit(this._catalog, this._auth) : super(const ProductDetailsLoading());

  Future<void> load(String id) async {
    emit(const ProductDetailsLoading());
    final result = await _catalog.getProduct(id);
    final all = await _catalog.getProducts();
    result.when(
      success: (product) {
        final recommended = _auth.currentUser?.measurements?.recommendedSize;
        final similar = (all.valueOrNull ?? [])
            .where((p) => p.category == product.category && p.id != product.id)
            .take(6)
            .toList();
        emit(ProductDetailsLoaded(
          product: product,
          colorIndex: 0,
          // Pre-select the recommended size if available.
          selectedSize: product.sizes.any((s) => s.label == recommended && s.available) ? recommended : null,
          recommendedSize: recommended,
          similar: similar,
        ));
      },
      failure: (m) => emit(ProductDetailsError(m)),
    );
  }

  void selectColor(int index) {
    final s = state;
    if (s is ProductDetailsLoaded) emit(s.copyWith(colorIndex: index));
  }

  void selectSize(String size) {
    final s = state;
    if (s is ProductDetailsLoaded) emit(s.copyWith(selectedSize: size));
  }
}

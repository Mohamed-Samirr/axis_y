import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/catalog_repository.dart';
import '../../../core/repositories/tryon_repository.dart';

sealed class TryOnState extends Equatable {
  const TryOnState();
  @override
  List<Object?> get props => [];
}

class TryOnLoading extends TryOnState {
  const TryOnLoading();
}

class TryOnError extends TryOnState {
  final String message;
  const TryOnError(this.message);
  @override
  List<Object?> get props => [message];
}

class TryOnReady extends TryOnState {
  final Product product;
  final int colorIndex;
  final String size;
  final Measurements measurements;

  const TryOnReady({
    required this.product,
    required this.colorIndex,
    required this.size,
    required this.measurements,
  });

  ProductColor get color => product.colors[colorIndex];
  ProductSize get sizeSpec => product.sizes.firstWhere((s) => s.label == size, orElse: () => product.sizes.first);

  TryOnReady copyWith({int? colorIndex, String? size}) => TryOnReady(
        product: product,
        colorIndex: colorIndex ?? this.colorIndex,
        size: size ?? this.size,
        measurements: measurements,
      );

  @override
  List<Object?> get props => [product.id, colorIndex, size];
}

class TryOnCubit extends Cubit<TryOnState> {
  final CatalogRepository _catalog;
  final TryOnRepository _tryOn;
  final AuthRepository _auth;

  TryOnCubit(this._catalog, this._tryOn, this._auth) : super(const TryOnLoading());

  Future<void> load(String productId) async {
    emit(const TryOnLoading());
    final result = await _catalog.getProduct(productId);
    await result.when(
      success: (product) async {
        await _tryOn.prepareScene(product);
        final measurements = _auth.currentUser?.measurements ??
            const Measurements(chest: 92, waist: 78, hips: 100, height: 172, weight: 74);
        final recommended = measurements.recommendedSize;
        final size = product.sizes.any((s) => s.label == recommended)
            ? recommended
            : product.sizes.first.label;
        emit(TryOnReady(product: product, colorIndex: 0, size: size, measurements: measurements));
      },
      failure: (m) async => emit(TryOnError(m)),
    );
  }

  void selectColor(int index) {
    final s = state;
    if (s is TryOnReady) emit(s.copyWith(colorIndex: index));
  }

  List<FitRow> fitRows() {
    final s = state;
    if (s is! TryOnReady) return [];
    return _tryOn.compareFit(size: s.sizeSpec, measurements: s.measurements);
  }
}

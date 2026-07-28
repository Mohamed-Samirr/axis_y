import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/fit.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/catalog_repository.dart';
import '../../../core/repositories/tryon_repository.dart';
import '../../../core/services/session_service.dart';

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

  /// Verdict from `POST /fit-check` for [selectedSize] (guide §5.5). Null until
  /// the first response, or when there is no registered scan.
  final FitResult? fit;
  final bool fitLoading;

  const ProductDetailsLoaded({
    required this.product,
    required this.colorIndex,
    required this.selectedSize,
    required this.recommendedSize,
    required this.similar,
    this.fit,
    this.fitLoading = false,
  });

  ProductColor get selectedColor => product.colors[colorIndex];

  /// True when the user selected a size different from the recommendation.
  bool get sizeMismatch =>
      recommendedSize != null && selectedSize != null && selectedSize != recommendedSize;

  ProductDetailsLoaded copyWith({
    int? colorIndex,
    String? selectedSize,
    FitResult? fit,
    bool? fitLoading,
    bool clearFit = false,
  }) =>
      ProductDetailsLoaded(
        product: product,
        colorIndex: colorIndex ?? this.colorIndex,
        selectedSize: selectedSize ?? this.selectedSize,
        recommendedSize: recommendedSize,
        similar: similar,
        fit: clearFit ? null : (fit ?? this.fit),
        fitLoading: fitLoading ?? this.fitLoading,
      );

  @override
  List<Object?> get props => [product.id, colorIndex, selectedSize, fit, fitLoading];
}

class ProductDetailsCubit extends Cubit<ProductDetailsState> {
  final CatalogRepository _catalog;
  final AuthRepository _auth;
  final TryOnRepository _tryOn;
  final SessionService _session;

  ProductDetailsCubit(this._catalog, this._auth, this._tryOn, this._session)
      : super(const ProductDetailsLoading());

  void _safeEmit(ProductDetailsState state) {
    if (!isClosed) emit(state);
  }

  Future<void> load(String id) async {
    emit(const ProductDetailsLoading());
    final result = await _catalog.getProduct(id);
    final all = await _catalog.getProducts();
    await result.when(
      success: (product) async {
        final recommended = _auth.currentUser?.measurements?.recommendedSize;
        final similar = (all.valueOrNull ?? [])
            .where((p) => p.category == product.category && p.id != product.id)
            .take(6)
            .toList();
        // Pre-select the recommended size if available.
        final preselected =
            product.sizes.any((s) => s.label == recommended && s.available) ? recommended : null;
        _safeEmit(ProductDetailsLoaded(
          product: product,
          colorIndex: 0,
          selectedSize: preselected,
          recommendedSize: recommended,
          similar: similar,
          fitLoading: preselected != null && _session.hasScan,
        ));
        if (preselected != null) await _checkFit(preselected);
      },
      failure: (m) async => _safeEmit(ProductDetailsError(m)),
    );
  }

  void selectColor(int index) {
    final s = state;
    if (s is ProductDetailsLoaded) emit(s.copyWith(colorIndex: index));
  }

  Future<void> selectSize(String size) async {
    final s = state;
    if (s is! ProductDetailsLoaded || s.selectedSize == size) return;
    emit(s.copyWith(selectedSize: size, clearFit: true, fitLoading: _session.hasScan));
    await _checkFit(size);
  }

  /// Lightweight verdict for the size on screen — no GLB is generated, so this
  /// is safe to fire on every size tap.
  Future<void> _checkFit(String sizeLabel) async {
    final s = state;
    if (s is! ProductDetailsLoaded) return;
    if (!_session.hasScan) {
      _safeEmit(s.copyWith(fitLoading: false));
      return;
    }

    final result = await _tryOn.fitCheck(
      scanId: _session.scanId!,
      product: s.product,
      sizeLabel: sizeLabel,
    );

    final current = state;
    if (current is! ProductDetailsLoaded || current.selectedSize != sizeLabel) return;
    await result.when(
      success: (fit) async => _safeEmit(current.copyWith(fit: fit, fitLoading: false)),
      failure: (key) async {
        // The scan is gone server-side; drop it so the UI stops promising a
        // fit verdict and the try-on screen asks for a re-scan (guide §12).
        if (key == 'err_scan_missing') await _session.clearScan();
        _safeEmit(current.copyWith(fitLoading: false, clearFit: true));
      },
    );
  }
}

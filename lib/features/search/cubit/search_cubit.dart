import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/catalog.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/catalog_repository.dart';

class PriceRange {
  final String label;
  final double min;
  final double max;
  const PriceRange(this.label, this.min, this.max);

  static const all = [
    PriceRange('< 200', 0, 200),
    PriceRange('200 – 500', 200, 500),
    PriceRange('500 – 1000', 500, 1000),
    PriceRange('> 1000', 1000, 1000000),
  ];
}

class SearchFilters extends Equatable {
  final ProductCategory? category;
  final PriceRange? price;
  final String? storeId;
  final double? minRating;
  final bool? tryOnOnly;

  const SearchFilters({this.category, this.price, this.storeId, this.minRating, this.tryOnOnly});

  SearchFilters copyWith({
    ProductCategory? category,
    PriceRange? price,
    String? storeId,
    double? minRating,
    bool? tryOnOnly,
    bool clearCategory = false,
    bool clearPrice = false,
    bool clearStore = false,
    bool clearRating = false,
    bool clearTryOn = false,
  }) =>
      SearchFilters(
        category: clearCategory ? null : (category ?? this.category),
        price: clearPrice ? null : (price ?? this.price),
        storeId: clearStore ? null : (storeId ?? this.storeId),
        minRating: clearRating ? null : (minRating ?? this.minRating),
        tryOnOnly: clearTryOn ? null : (tryOnOnly ?? this.tryOnOnly),
      );

  @override
  List<Object?> get props => [category, price?.label, storeId, minRating, tryOnOnly];
}

class SearchState extends Equatable {
  final bool loading;
  final String query;
  final SearchFilters filters;
  final List<Product> results;
  final List<Product> _all;
  final List<Store> stores;

  const SearchState({
    this.loading = true,
    this.query = '',
    this.filters = const SearchFilters(),
    this.results = const [],
    List<Product> all = const [],
    this.stores = const [],
  }) : _all = all;

  List<Product> get all => _all;

  SearchState copyWith({
    bool? loading,
    String? query,
    SearchFilters? filters,
    List<Product>? results,
    List<Product>? all,
    List<Store>? stores,
  }) =>
      SearchState(
        loading: loading ?? this.loading,
        query: query ?? this.query,
        filters: filters ?? this.filters,
        results: results ?? this.results,
        all: all ?? _all,
        stores: stores ?? this.stores,
      );

  @override
  List<Object?> get props => [loading, query, filters, results, stores];
}

class SearchCubit extends Cubit<SearchState> {
  final CatalogRepository _catalog;
  final AuthRepository _auth;

  SearchCubit(this._catalog, this._auth) : super(const SearchState());

  Future<void> load({ProductCategory? initialCategory}) async {
    emit(state.copyWith(loading: true));
    final products = await _catalog.getProducts();
    final stores = await _catalog.getStores();
    final all = products.valueOrNull ?? [];
    emit(state.copyWith(
      loading: false,
      all: all,
      stores: stores.valueOrNull ?? [],
      filters: SearchFilters(category: initialCategory),
    ));
    _apply();
  }

  void setQuery(String q) {
    emit(state.copyWith(query: q));
    _apply();
  }

  void setFilters(SearchFilters filters) {
    emit(state.copyWith(filters: filters));
    _apply();
  }

  void clearFilters() {
    emit(state.copyWith(filters: const SearchFilters()));
    _apply();
  }

  void _apply() {
    final f = state.filters;
    final q = state.query.trim();
    var list = state.all.where((p) {
      if (q.isNotEmpty && !p.name.contains(q) && !p.storeName.contains(q)) return false;
      if (f.category != null && p.category != f.category) return false;
      if (f.price != null && (p.price < f.price!.min || p.price > f.price!.max)) return false;
      if (f.storeId != null && p.storeId != f.storeId) return false;
      if (f.minRating != null && p.rating < f.minRating!) return false;
      if (f.tryOnOnly == true && !p.tryOnAvailable) return false;
      return true;
    }).toList();

    // Default sort = best fit for the user's measurements.
    final size = _auth.currentUser?.measurements?.recommendedSize;
    if (size != null) {
      list.sort((a, b) {
        final af = a.sizes.any((s) => s.label == size && s.available) ? 0 : 1;
        final bf = b.sizes.any((s) => s.label == size && s.available) ? 0 : 1;
        if (af != bf) return af - bf;
        return b.rating.compareTo(a.rating);
      });
    }
    emit(state.copyWith(results: list));
  }
}

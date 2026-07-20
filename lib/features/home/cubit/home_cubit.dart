import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/catalog_repository.dart';

sealed class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => [];
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);
  @override
  List<Object?> get props => [message];
}

class HomeLoaded extends HomeState {
  final List<AppBanner> banners;
  final List<Product> pickedForYou;
  final List<Store> stores;

  const HomeLoaded({required this.banners, required this.pickedForYou, required this.stores});

  @override
  List<Object?> get props => [banners, pickedForYou, stores];
}

class HomeCubit extends Cubit<HomeState> {
  final CatalogRepository _catalog;
  final AuthRepository _auth;

  HomeCubit(this._catalog, this._auth) : super(const HomeLoading());

  Future<void> load() async {
    emit(const HomeLoading());
    final banners = await _catalog.getBanners();
    final products = await _catalog.getProducts();
    final stores = await _catalog.getStores();

    if (banners.isFailure || products.isFailure || stores.isFailure) {
      emit(const HomeError('error_generic'));
      return;
    }

    final all = products.valueOrNull!;
    final measurements = _auth.currentUser?.measurements;
    emit(HomeLoaded(
      banners: banners.valueOrNull!,
      pickedForYou: _personalize(all, measurements),
      stores: stores.valueOrNull!,
    ));
  }

  /// "اخترنالك": prefer products whose sizes include a fit for the user, then
  /// bestsellers. Falls back to bestsellers when no measurements exist.
  List<Product> _personalize(List<Product> all, Measurements? m) {
    final list = List<Product>.of(all);
    if (m != null) {
      final size = m.recommendedSize;
      list.sort((a, b) {
        final af = a.sizes.any((s) => s.label == size && s.available) ? 0 : 1;
        final bf = b.sizes.any((s) => s.label == size && s.available) ? 0 : 1;
        if (af != bf) return af - bf;
        return b.soldCount.compareTo(a.soldCount);
      });
    } else {
      list.sort((a, b) => b.soldCount.compareTo(a.soldCount));
    }
    return list.take(10).toList();
  }
}

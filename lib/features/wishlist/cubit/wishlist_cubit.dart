import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/repositories/wishlist_repository.dart';

/// App-wide wishlist ViewModel. State is the set of favourited product ids.
class WishlistCubit extends Cubit<Set<String>> {
  final WishlistRepository _repo;

  WishlistCubit(this._repo) : super(_repo.ids);

  bool contains(String id) => state.contains(id);

  void toggle(String id) {
    _repo.toggle(id);
    emit(Set.of(_repo.ids));
  }
}

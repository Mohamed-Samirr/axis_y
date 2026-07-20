import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/catalog.dart';
import '../../../core/repositories/assistant_repository.dart';

class AssistantState extends Equatable {
  final bool loading;
  final Occasion? occasion;
  final List<Product> outfit;

  const AssistantState({this.loading = false, this.occasion, this.outfit = const []});

  double get total => outfit.fold(0, (s, p) => s + p.price);

  AssistantState copyWith({bool? loading, Occasion? occasion, List<Product>? outfit}) => AssistantState(
        loading: loading ?? this.loading,
        occasion: occasion ?? this.occasion,
        outfit: outfit ?? this.outfit,
      );

  @override
  List<Object?> get props => [loading, occasion, outfit];
}

class AssistantCubit extends Cubit<AssistantState> {
  final AssistantRepository _repo;
  AssistantCubit(this._repo) : super(const AssistantState());

  Future<void> suggest(Occasion occasion) async {
    emit(state.copyWith(loading: true, occasion: occasion, outfit: []));
    final result = await _repo.suggestOutfit(occasion);
    emit(state.copyWith(loading: false, outfit: result.valueOrNull ?? []));
  }

  Future<void> matchClothes() async {
    emit(state.copyWith(loading: true, outfit: []));
    final result = await _repo.matchClothes();
    emit(state.copyWith(loading: false, outfit: result.valueOrNull ?? []));
  }
}

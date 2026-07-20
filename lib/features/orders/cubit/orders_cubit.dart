import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/commerce.dart';
import '../../../core/repositories/order_repository.dart';

sealed class OrdersState extends Equatable {
  const OrdersState();
  @override
  List<Object?> get props => [];
}

class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

class OrdersError extends OrdersState {
  final String message;
  const OrdersError(this.message);
  @override
  List<Object?> get props => [message];
}

class OrdersLoaded extends OrdersState {
  final List<AppOrder> orders;
  const OrdersLoaded(this.orders);
  @override
  List<Object?> get props => [orders];
}

class OrdersCubit extends Cubit<OrdersState> {
  final OrderRepository _repo;
  OrdersCubit(this._repo) : super(const OrdersLoading());

  Future<void> load() async {
    emit(const OrdersLoading());
    final result = await _repo.getOrders();
    result.when(
      success: (orders) => emit(OrdersLoaded(orders)),
      failure: (m) => emit(OrdersError(m)),
    );
  }
}

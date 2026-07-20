import 'package:get_it/get_it.dart';

import '../config/app_config.dart';
import '../data/local_store.dart';
import '../repositories/assistant_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/body_scan_repository.dart';
import '../repositories/cart_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/tryon_repository.dart';
import '../repositories/wishlist_repository.dart';

final GetIt sl = GetIt.instance;

/// Registers all dependencies. Repositories are registered as their abstract
/// interfaces, so swapping mock -> real API later touches only this file.
Future<void> setupInjector() async {
  final localStore = await LocalStore.create();
  sl.registerSingleton<LocalStore>(localStore);

  if (AppConfig.useMockData) {
    sl.registerLazySingleton<CatalogRepository>(() => MockCatalogRepository());
    sl.registerLazySingleton<AuthRepository>(() => MockAuthRepository(sl()));
    sl.registerLazySingleton<CartRepository>(() => LocalCartRepository(sl()));
    sl.registerLazySingleton<WishlistRepository>(() => LocalWishlistRepository(sl()));
    sl.registerLazySingleton<OrderRepository>(() => MockOrderRepository());
    sl.registerLazySingleton<NotificationRepository>(() => MockNotificationRepository());
    sl.registerLazySingleton<BodyScanRepository>(() => MockBodyScanRepository());
    sl.registerLazySingleton<TryOnRepository>(() => MockTryOnRepository());
    sl.registerLazySingleton<AssistantRepository>(() => MockAssistantRepository());
  } else {
    // TODO: register Api* repositories (dio) when the backend is ready.
    throw UnimplementedError('Real API repositories not wired yet.');
  }
}

import 'package:get_it/get_it.dart';

import '../config/app_config.dart';
import '../data/local_store.dart';
import '../network/api_client.dart';
import '../repositories/assistant_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/body_scan_repository.dart';
import '../repositories/cart_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/tryon_repository.dart';
import '../repositories/wishlist_repository.dart';
import '../services/glb_cache.dart';
import '../services/session_service.dart';

final GetIt sl = GetIt.instance;

/// Registers all dependencies. Repositories are registered as their abstract
/// interfaces, so swapping mock -> real API later touches only this file.
Future<void> setupInjector() async {
  final localStore = await LocalStore.create();
  sl.registerSingleton<LocalStore>(localStore);

  // The anonymous session must exist before the http client, which stamps the
  // device_id onto every request.
  sl.registerSingleton<SessionService>(await SessionService.create());
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl()));
  sl.registerLazySingleton<GlbCache>(() => GlbCache());

  // Body scan has a real backend, so it opts out of the global mock flag on its
  // own. Flipping AppConfig.useRealBodyScan to false restores the offline flow.
  sl.registerLazySingleton<BodyScanRepository>(
    () => AppConfig.useRealBodyScan ? ApiBodyScanRepository(sl()) : MockBodyScanRepository(),
  );

  // Same deal for fit-check / try-on against the gateway.
  sl.registerLazySingleton<TryOnRepository>(
    () => AppConfig.useRealTryOn ? ApiTryOnRepository(sl()) : MockTryOnRepository(sl()),
  );

  if (AppConfig.useMockData) {
    sl.registerLazySingleton<CatalogRepository>(() => MockCatalogRepository());
    sl.registerLazySingleton<AuthRepository>(() => MockAuthRepository(sl()));
    sl.registerLazySingleton<CartRepository>(() => LocalCartRepository(sl()));
    sl.registerLazySingleton<WishlistRepository>(() => LocalWishlistRepository(sl()));
    sl.registerLazySingleton<OrderRepository>(() => MockOrderRepository());
    sl.registerLazySingleton<NotificationRepository>(() => MockNotificationRepository());
    sl.registerLazySingleton<AssistantRepository>(() => MockAssistantRepository());
  } else {
    // TODO: register Api* repositories (dio) when the backend is ready.
    throw UnimplementedError('Real API repositories not wired yet.');
  }
}

import '../data/mock_seed.dart';
import '../models/notification.dart';
import '../utils/latency.dart';
import '../utils/result.dart';

abstract class NotificationRepository {
  Future<Result<List<AppNotification>>> getNotifications();
  int get unreadCount;
  void markAllRead();
}

class MockNotificationRepository implements NotificationRepository {
  final List<AppNotification> _items = List.of(MockSeed.notifications);

  @override
  Future<Result<List<AppNotification>>> getNotifications() async {
    await mockLatency();
    return Success(List.unmodifiable(_items));
  }

  @override
  int get unreadCount => _items.where((n) => !n.read).length;

  @override
  void markAllRead() {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(read: true);
    }
  }
}

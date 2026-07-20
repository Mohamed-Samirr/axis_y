import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/notification.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = sl<NotificationRepository>();
    final result = await repo.getNotifications();
    repo.markAllRead();
    if (mounted) setState(() => _items = result.valueOrNull ?? []);
  }

  IconData _icon(NotificationType t) => switch (t) {
        NotificationType.order => Icons.local_shipping_outlined,
        NotificationType.offer => Icons.local_offer_outlined,
        NotificationType.priceDrop => Icons.trending_down,
        NotificationType.cartReminder => Icons.shopping_cart_outlined,
        NotificationType.points => Icons.stars_outlined,
        NotificationType.store => Icons.storefront_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('notifications'))),
      body: _items == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.navy))
          : _items!.isEmpty
              ? EmptyView(icon: Icons.notifications_off_outlined, title: context.tr('no_notifications'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items!.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = _items![i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                        child: Icon(_icon(n.type), color: AppColors.navy, size: 20),
                      ),
                      title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(n.body),
                      trailing: Text(n.date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    );
                  },
                ),
    );
  }
}

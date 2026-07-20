import 'package:equatable/equatable.dart';

enum NotificationType { order, offer, priceDrop, cartReminder, points, store }

class AppNotification extends Equatable {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String date;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.date,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        date: date,
        read: read ?? this.read,
      );

  @override
  List<Object?> get props => [id, read];
}

class NotificationAction {
  const NotificationAction({required this.kind, required this.id});

  final String kind;
  final dynamic id;

  factory NotificationAction.fromJson(Map<String, dynamic> json) {
    return NotificationAction(
      kind: json['kind'] is String ? json['kind'] as String : '',
      id: json['id'],
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.event,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
    this.action,
  });

  final String id;
  final String event;
  final String title;
  final String message;
  final bool read;
  final DateTime createdAt;
  final NotificationAction? action;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawDate = json['created_at'];
    final parsedDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
    final rawAction = json['action'];
    return AppNotification(
      id: json['id'] is String ? json['id'] as String : '',
      event: json['event'] is String ? json['event'] as String : '',
      title: json['title'] is String ? json['title'] as String : '',
      message: json['message'] is String ? json['message'] as String : '',
      read: json['read'] == true,
      createdAt:
          parsedDate?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
      action: rawAction is Map<String, dynamic>
          ? NotificationAction.fromJson(rawAction)
          : null,
    );
  }

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    event: event,
    title: title,
    message: message,
    read: read ?? this.read,
    createdAt: createdAt,
    action: action,
  );
}

class NotificationsResponse {
  const NotificationsResponse({
    required this.notifications,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int unreadCount;

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    final rawNotifications = json['notifications'];
    final notifications = rawNotifications is List
        ? rawNotifications
              .whereType<Map<String, dynamic>>()
              .map(AppNotification.fromJson)
              .toList(growable: false)
        : const <AppNotification>[];
    final rawUnread = json['unread_count'];
    final unreadCount = rawUnread is int
        ? rawUnread
        : rawUnread is num
        ? rawUnread.toInt()
        : int.tryParse(rawUnread?.toString() ?? '') ?? 0;
    return NotificationsResponse(
      notifications: notifications,
      unreadCount: unreadCount < 0 ? 0 : unreadCount,
    );
  }
}

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/features/patient/data/models/app_notification.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/notification_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses notifications, appointment and null actions robustly', () {
    final result = NotificationsResponse.fromJson({
      'unread_count': 11,
      'notifications': [
        {
          'id': 'abc',
          'event': 'future_event_type',
          'title': 'Aviso',
          'message': 'Mensaje',
          'read': false,
          'created_at': '2026-09-30T22:02:58.000000Z',
          'action': {'kind': 'appointment', 'id': 34},
        },
        {
          'id': 'def',
          'event': 'another_event',
          'title': 'Leída',
          'message': 'Mensaje leído',
          'read': true,
          'created_at': '2026-09-29T00:00:00Z',
          'action': null,
        },
      ],
    });
    expect(result.unreadCount, 11);
    expect(result.notifications.first.event, 'future_event_type');
    expect(result.notifications.first.action?.kind, 'appointment');
    expect(result.notifications.first.action?.id, 34);
    expect(result.notifications.first.createdAt.isUtc, isFalse);
    expect(result.notifications[1].read, isTrue);
    expect(result.notifications[1].action, isNull);
  });

  test(
    'repository fetches list/count and posts read actions with Sanctum token',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'notification-token',
      });
      final seen = <String>[];
      final repository = NotificationRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(
              request.headers['Authorization'],
              'Bearer notification-token',
            );
            seen.add('${request.method} ${request.url.path}');
            if (request.url.path.endsWith('/notifications')) {
              return http.Response(
                jsonEncode({'notifications': [], 'unread_count': 11}),
                200,
              );
            }
            if (request.url.path.endsWith('/unread-count')) {
              return http.Response(jsonEncode({'unread_count': 11}), 200);
            }
            return http.Response('{}', 200);
          }),
        ),
      );
      addTearDown(repository.apiClient.close);

      final response = await repository.fetchNotifications();
      expect(response.notifications, isEmpty);
      expect(response.unreadCount, 11);
      expect(await repository.fetchUnreadCount(), 11);
      await repository.markAsRead('id-1');
      await repository.markAllAsRead();
      expect(seen, [
        'GET /api/notifications',
        'GET /api/notifications/unread-count',
        'POST /api/notifications/id-1/read',
        'POST /api/notifications/read-all',
      ]);
    },
  );
}

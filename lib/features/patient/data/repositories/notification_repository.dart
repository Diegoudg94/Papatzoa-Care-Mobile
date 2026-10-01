import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exceptions.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  NotificationRepository({
    required this.apiClient,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final ApiClient apiClient;
  final FlutterSecureStorage _storage;

  Future<String> _token() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'La sesión ya no está disponible.',
        statusCode: 401,
      );
    }
    return token;
  }

  Future<NotificationsResponse> fetchNotifications() async {
    try {
      final response = await apiClient.get(
        'notifications',
        token: await _token(),
      );
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) throw const FormatException();
      return NotificationsResponse.fromJson(json);
    } on NetworkException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No pudimos cargar tus notificaciones.');
    }
  }

  Future<int> fetchUnreadCount() async {
    try {
      final response = await apiClient.get(
        'notifications/unread-count',
        token: await _token(),
      );
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) throw const FormatException();
      final rawCount = json['unread_count'];
      if (rawCount is int) return rawCount < 0 ? 0 : rawCount;
      if (rawCount is num) return rawCount.toInt().clamp(0, 0x7fffffff);
      return int.tryParse(rawCount?.toString() ?? '')?.clamp(0, 0x7fffffff) ??
          0;
    } on NetworkException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No pudimos consultar tus notificaciones.');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await apiClient.post(
        'notifications/${Uri.encodeComponent(id)}/read',
        token: await _token(),
      );
    } on NetworkException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No pudimos actualizar la notificación.');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await apiClient.post('notifications/read-all', token: await _token());
    } on NetworkException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No pudimos actualizar tus notificaciones.');
    }
  }
}

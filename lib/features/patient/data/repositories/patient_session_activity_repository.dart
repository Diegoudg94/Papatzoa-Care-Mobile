import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exceptions.dart';
import '../models/patient_dashboard_data.dart';

class PatientSessionActivityRepository {
  PatientSessionActivityRepository({
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

  Future<DashboardActivity?> current() async {
    final response = await apiClient.get(
      'patient/session-activity',
      token: await _token(),
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final activity = json['activity'];
    return activity is Map<String, dynamic>
        ? DashboardActivity.fromJson(activity)
        : null;
  }

  Future<void> respond(int id, String status, String comment) async {
    await apiClient.post(
      'patient/session-activity/$id/response',
      token: await _token(),
      body: {'estado': status, 'comentario_paciente': comment.trim()},
    );
  }
}

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exceptions.dart';
import '../models/patient_dashboard_data.dart';

class PatientDashboardRepository {
  PatientDashboardRepository({
    required this.apiClient,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final ApiClient apiClient;
  final FlutterSecureStorage _storage;

  Future<PatientDashboardData> loadDashboard() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'La sesión ya no está disponible.',
        statusCode: 401,
      );
    }

    try {
      final response = await apiClient.get('patient/dashboard', token: token);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PatientDashboardData.fromJson(json);
    } on NetworkException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No pudimos actualizar tu información.');
    }
  }
}

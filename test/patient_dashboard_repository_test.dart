import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/network/api_exceptions.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_dashboard_repository.dart';

const emptyDashboardJson = {
  'patient': {'id': 32, 'nombre': 'Ricardo', 'apellido': 'Cortez'},
  'therapist': null,
  'next_appointment': null,
  'between_session_activity': null,
  'emotional_summary': {'total_records': 0, 'records': []},
  'sessions': [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the real empty dashboard contract with Sanctum Bearer', () async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'dashboard-token',
    });
    final repository = PatientDashboardRepository(
      apiClient: ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/patient/dashboard');
          expect(request.headers['Authorization'], 'Bearer dashboard-token');
          return http.Response(jsonEncode(emptyDashboardJson), 200);
        }),
      ),
    );

    final data = await repository.loadDashboard();
    expect(data.patient.nombre, 'Ricardo');
    expect(data.therapist, isNull);
    expect(data.nextAppointment, isNull);
    expect(data.activity, isNull);
    expect(data.emotionalSummary.totalRecords, 0);
    expect(data.emotionalSummary.records, isEmpty);
    expect(data.sessions, isEmpty);
  });

  test(
    'missing token fails as unauthorized without making a request',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      var calls = 0;
      final repository = PatientDashboardRepository(
        apiClient: ApiClient(
          client: MockClient((_) async {
            calls++;
            return http.Response('{}', 200);
          }),
        ),
      );

      await expectLater(
        repository.loadDashboard(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(calls, 0);
    },
  );
}

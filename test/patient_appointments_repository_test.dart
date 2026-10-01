import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/network/api_exceptions.dart';
import 'package:papatzoa_mobile/features/patient/data/models/appointment_availability.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_appointments_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'availability supports empty slots, modalities and null surname',
    () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      final repository = PatientAppointmentsRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/patient/appointments/availability');
            expect(request.url.queryParameters, {
              'from': '2026-10-01',
              'to': '2026-10-14',
            });
            return http.Response(
              jsonEncode({
                'therapist': {'id': 3, 'nombre': 'Ana', 'apellido': null},
                'timezone': 'America/Mexico_City',
                'session_duration_minutes': 45,
                'available_modalities': ['online', 'presencial'],
                'slots': [],
              }),
              200,
            );
          }),
        ),
      );
      addTearDown(repository.apiClient.close);
      final result = await repository.getAvailability(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 14),
      );
      expect(result.slots, isEmpty);
      expect(result.therapist?.displayName, 'Ana');
      expect(result.availableModalities, ['online', 'presencial']);
    },
  );

  for (final status in ['pendiente', 'confirmada']) {
    test('creates appointment with exact slot and $status status', () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      final repository = PatientAppointmentsRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/patient/appointments');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body, {
              'start': '2026-10-05T11:00:00-06:00',
              'end': '2026-10-05T11:45:00-06:00',
              'motivo': 'Consulta',
              'modalidad': 'online',
            });
            return http.Response(
              jsonEncode({
                'message': 'Solicitud de cita enviada.',
                'appointment': {'id': 8, 'status': status},
              }),
              201,
            );
          }),
        ),
      );
      addTearDown(repository.apiClient.close);
      final created = await repository.createAppointment(
        slot: const AvailabilitySlot(
          start: '2026-10-05T11:00:00-06:00',
          end: '2026-10-05T11:45:00-06:00',
        ),
        motivo: 'Consulta',
        modalidad: 'online',
      );
      expect(created.status, status);
    });
  }

  test('loads upcoming and history with the Sanctum Bearer token', () async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'appointments-token',
    });
    final repository = PatientAppointmentsRepository(
      apiClient: ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/patient/appointments');
          expect(request.headers['Authorization'], 'Bearer appointments-token');
          return http.Response(
            jsonEncode({
              'upcoming': [
                {
                  'id': 4,
                  'date': '2026-10-05T14:30:00-06:00',
                  'time': '14:30',
                  'status': 'confirmada',
                  'modality': 'virtual',
                  'therapist': {'nombre': 'Ana', 'apellido': 'Lopez'},
                  'reschedule_proposal': {
                    'status': 'pending_patient',
                    'proposed_date': '2026-10-06T15:00:00-06:00',
                  },
                },
              ],
              'history': [],
            }),
            200,
          );
        }),
      ),
    );
    addTearDown(repository.apiClient.close);

    final data = await repository.loadAppointments();
    expect(data.upcoming.single.id, 4);
    expect(data.upcoming.single.therapist?.displayName, 'Ana Lopez');
    expect(data.upcoming.single.rescheduleProposal?.status, 'pending_patient');
    expect(data.history, isEmpty);
  });

  test(
    'loads a detail using the real endpoint and response envelope',
    () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'detail-token'});
      final repository = PatientAppointmentsRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/patient/appointments/12');
            expect(request.headers['Authorization'], 'Bearer detail-token');
            return http.Response(
              jsonEncode({
                'appointment': {
                  'id': 12,
                  'date': '2026-10-05T14:30:00-06:00',
                  'time': '14:30',
                  'status': 'confirmado',
                  'modality': 'virtual',
                  'therapist': {
                    'nombre': 'Ana',
                    'apellido': 'López',
                    'especialidad': 'Psicología',
                    'profile_photo': null,
                  },
                  'reschedule_proposal': {
                    'status': 'pending_patient',
                    'proposed_date': '2026-10-06T15:00:00-06:00',
                  },
                  'reason': 'Ansiedad',
                },
              }),
              200,
            );
          }),
        ),
      );
      addTearDown(repository.apiClient.close);

      final appointment = await repository.getAppointment(12);
      expect(appointment.id, 12);
      expect(appointment.therapist?.especialidad, 'Psicología');
      expect(appointment.reason, 'Ansiedad');
    },
  );

  test('supports missing lists and nullable appointment fields', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
    final repository = PatientAppointmentsRepository(
      apiClient: ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'upcoming': [],
              'history': [{}],
            }),
            200,
          ),
        ),
      ),
    );
    addTearDown(repository.apiClient.close);

    final data = await repository.loadAppointments();
    expect(data.upcoming, isEmpty);
    expect(data.history.single.date, isNull);
    expect(data.history.single.therapist, isNull);
  });

  test('missing token reports 401 without making a request', () async {
    FlutterSecureStorage.setMockInitialValues({});
    var calls = 0;
    final repository = PatientAppointmentsRepository(
      apiClient: ApiClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      ),
    );
    addTearDown(repository.apiClient.close);

    await expectLater(
      repository.loadAppointments(),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 401),
      ),
    );
    expect(calls, 0);
  });

  test('network exceptions stay identifiable for retry UI', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
    final repository = PatientAppointmentsRepository(
      apiClient: ApiClient(
        client: MockClient((_) async => throw http.ClientException('offline')),
      ),
    );
    addTearDown(repository.apiClient.close);

    await expectLater(
      repository.loadAppointments(),
      throwsA(isA<NetworkException>()),
    );
  });

  test(
    'cancel posts only optional reason to the selected appointment',
    () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      var calls = 0;
      final repository = PatientAppointmentsRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            calls++;
            expect(request.method, 'POST');
            expect(request.url.path, '/api/patient/appointments/27/cancel');
            expect(request.headers['Authorization'], 'Bearer token');
            if (calls == 1) {
              expect(request.body, isEmpty);
            } else {
              expect(jsonDecode(request.body), {'reason': 'Necesito cancelar'});
              expect(request.body, isNot(contains('patient_id')));
              expect(request.body, isNot(contains('therapist_id')));
            }
            return http.Response(
              jsonEncode({
                'message': 'Tu cita fue cancelada.',
                'appointment': {'id': 27, 'status': 'cancelada'},
              }),
              200,
            );
          }),
        ),
      );
      addTearDown(repository.apiClient.close);
      expect(
        await repository.cancelAppointment(appointmentId: 27),
        'Tu cita fue cancelada.',
      );
      expect(
        await repository.cancelAppointment(
          appointmentId: 27,
          reason: ' Necesito cancelar ',
        ),
        'Tu cita fue cancelada.',
      );
      expect(calls, 2);
    },
  );

  test('cancel preserves backend 422 message', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
    final repository = PatientAppointmentsRepository(
      apiClient: ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Esta cita ya no puede cancelarse.'}),
            422,
          ),
        ),
      ),
    );
    addTearDown(repository.apiClient.close);
    await expectLater(
      repository.cancelAppointment(appointmentId: 27),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having(
              (e) => e.message,
              'message',
              'Esta cita ya no puede cancelarse.',
            ),
      ),
    );
  });
  test(
    'reschedule posts only exact start and end to the old ID and reads new ID',
    () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      final repository = PatientAppointmentsRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/patient/appointments/26/reschedule');
            expect(jsonDecode(request.body), {
              'start': '2026-10-05T11:00:00-06:00',
              'end': '2026-10-05T11:45:00-06:00',
            });
            return http.Response(
              jsonEncode({
                'appointment': {
                  'id': 30,
                  'previous_appointment_id': 26,
                  'status': 'confirmada',
                },
              }),
              201,
            );
          }),
        ),
      );
      addTearDown(repository.apiClient.close);
      final created = await repository.rescheduleAppointment(
        appointmentId: 26,
        start: '2026-10-05T11:00:00-06:00',
        end: '2026-10-05T11:45:00-06:00',
      );
      expect(created.id, 30);
      expect(created.status, 'confirmada');
    },
  );
}

import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/routing/app_routes.dart';
import 'package:papatzoa_mobile/core/theme/app_theme.dart';
import 'package:papatzoa_mobile/features/auth/data/models/auth_user.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_appointments_repository.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_dashboard_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_dashboard_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_appointments_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_appointment_detail_page.dart';

const emptyAppointments = {'upcoming': [], 'history': []};
const patient = AuthUser(
  id: 32,
  firstName: 'Ricardo',
  lastName: 'Cortez',
  email: 'ricardo@example.com',
  role: 'patient',
  isTherapist: false,
);

Future<AuthRepository> pumpAppointments(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request request) handler,
  String? initialRoute,
}) async {
  FlutterSecureStorage.setMockInitialValues({
    'auth_token': 'appointments-token',
  });
  final client = ApiClient(client: MockClient(handler));
  final auth = AuthRepository(apiClient: client);
  final appointments = PatientAppointmentsRepository(apiClient: client);
  Widget detailRoute(BuildContext context) => PatientAppointmentDetailPage(
    repository: auth,
    appointmentsRepository: appointments,
    appointmentId: ModalRoute.of(context)!.settings.arguments as int,
  );
  addTearDown(auth.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routes: {
        AppRoutes.login: (_) => const Scaffold(body: Text('LOGIN')),
        AppRoutes.patientAppointmentDetail: detailRoute,
      },
      home: PatientAppointmentsPage(
        repository: auth,
        appointmentsRepository: appointments,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cancel confirms, posts once, and refetches upcoming/history', (
    tester,
  ) async {
    var cancelled = false;
    var posts = 0;
    var listGets = 0;
    await pumpAppointments(
      tester,
      handler: (request) async {
        if (request.method == 'POST') {
          posts++;
          expect(request.url.path, '/api/patient/appointments/27/cancel');
          expect(jsonDecode(request.body), {'reason': 'Cambio de planes'});
          cancelled = true;
          return http.Response(
            jsonEncode({
              'message': 'Tu cita fue cancelada.',
              'appointment': {'id': 27, 'status': 'cancelada'},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/appointments/27')) {
          return http.Response(
            jsonEncode({
              'appointment': {
                'id': 27,
                'date': '2026-10-05T14:30:00-06:00',
                'time': '14:30',
                'status': 'confirmada',
                'therapist': {'nombre': 'Ana'},
              },
            }),
            200,
          );
        }
        listGets++;
        return http.Response(
          jsonEncode({
            'upcoming': cancelled
                ? []
                : [
                    {'id': 27, 'status': 'confirmada'},
                  ],
            'history': cancelled
                ? [
                    {'id': 27, 'status': 'cancelada'},
                  ]
                : [],
          }),
          200,
        );
      },
    );
    await tester.tap(find.text('Sesión'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Cancelar cita'), 200);
    expect(find.text('Reagendar cita'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Reagendar cita')).dy,
      lessThan(tester.getTopLeft(find.text('Cancelar cita')).dy),
    );
    await tester.tap(find.text('Cancelar cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar con cancelación'));
    await tester.pumpAndSettle();
    expect(posts, 0);
    expect(find.text('¿Quieres cancelar esta cita?'), findsOneWidget);
    expect(
      find.text('Este horario volverá a estar disponible.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Cambio de planes');
    await tester.tap(find.text('Cancelar cita').last);
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(listGets, 2);
    expect(find.text('No tienes próximas citas.'), findsOneWidget);
    expect(find.text('Tu cita fue cancelada.'), findsOneWidget);
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('cancelada'), findsOneWidget);
  });

  testWidgets('cancel action is hidden for cancelled detail', (tester) async {
    await pumpAppointments(
      tester,
      handler: (request) async {
        if (request.url.path.endsWith('/appointments/27')) {
          return http.Response(
            jsonEncode({
              'appointment': {'id': 27, 'status': 'cancelada'},
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'upcoming': [],
            'history': [
              {'id': 27, 'status': 'cancelada'},
            ],
          }),
          200,
        );
      },
    );
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar cita'), findsNothing);
  });

  for (final status in [422, 404, 503]) {
    testWidgets('cancel handles HTTP $status', (tester) async {
      var listGets = 0;
      var detailGets = 0;
      await pumpAppointments(
        tester,
        handler: (request) async {
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({'message': 'Esta cita ya no puede cancelarse.'}),
              status,
            );
          }
          if (request.url.path.endsWith('/appointments/27')) {
            detailGets++;
            return http.Response(
              jsonEncode({
                'appointment': {
                  'id': 27,
                  'status': detailGets > 1 ? 'cancelada' : 'confirmada',
                },
              }),
              200,
            );
          }
          listGets++;
          return http.Response(
            jsonEncode({
              'upcoming': [
                {'id': 27, 'status': 'confirmada'},
              ],
              'history': [],
            }),
            200,
          );
        },
      );
      await tester.tap(find.text('Sesión'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Cancelar cita'), 200);
      await tester.tap(find.text('Cancelar cita'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar con cancelación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar cita').last);
      await tester.pumpAndSettle();
      if (status == 404) {
        expect(find.text('Esta cita ya no está disponible.'), findsOneWidget);
        expect(listGets, 2);
      } else if (status == 422) {
        expect(find.text('Esta cita ya no puede cancelarse.'), findsOneWidget);
        expect(detailGets, 2);
        expect(find.text('Cancelar cita'), findsNothing);
      } else {
        expect(
          find.text('No pudimos cancelar la cita. Intenta nuevamente.'),
          findsOneWidget,
        );
        expect(find.text('Detalle de la cita'), findsOneWidget);
      }
    });
  }

  testWidgets(
    'optional reason limits input and loading prevents duplicate POST',
    (tester) async {
      final response = Completer<http.Response>();
      var posts = 0;
      await pumpAppointments(
        tester,
        handler: (request) async {
          if (request.method == 'POST') {
            posts++;
            expect(request.body, isEmpty);
            return response.future;
          }
          if (request.url.path.endsWith('/appointments/27')) {
            return http.Response(
              jsonEncode({
                'appointment': {'id': 27, 'status': 'confirmada'},
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'upcoming': [
                {'id': 27, 'status': 'confirmada'},
              ],
              'history': [],
            }),
            200,
          );
        },
      );
      await tester.tap(find.text('Sesión'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Cancelar cita'), 200);
      await tester.tap(find.text('Cancelar cita'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar con cancelación'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'x' * 4001);
      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text
            .length,
        4000,
      );
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Cancelar cita').last);
      await tester.pump();
      expect(posts, 1);
      expect(find.text('Cancelando...'), findsOneWidget);
      await tester.tap(find.text('Cancelando...'));
      await tester.pump();
      expect(posts, 1);
      response.complete(
        http.Response(
          jsonEncode({
            'message': 'Tu cita fue cancelada.',
            'appointment': {'id': 27, 'status': 'cancelada'},
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('network failure keeps detail open for retry', (tester) async {
    var posts = 0;
    await pumpAppointments(
      tester,
      handler: (request) async {
        if (request.method == 'POST') {
          posts++;
          throw http.ClientException('offline');
        }
        if (request.url.path.endsWith('/appointments/27')) {
          return http.Response(
            jsonEncode({
              'appointment': {'id': 27, 'status': 'confirmada'},
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'upcoming': [
              {'id': 27, 'status': 'confirmada'},
            ],
            'history': [],
          }),
          200,
        );
      },
    );
    await tester.tap(find.text('Sesión'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Cancelar cita'), 200);
    await tester.tap(find.text('Cancelar cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar con cancelación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar cita').last);
    await tester.pumpAndSettle();
    expect(find.text('Detalle de la cita'), findsOneWidget);
    expect(
      find.text('No pudimos cancelar la cita. Intenta nuevamente.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar con cancelación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar cita').last);
    await tester.pumpAndSettle();
    expect(posts, 2);
  });

  testWidgets('upcoming and history empty states are clear', (tester) async {
    await pumpAppointments(
      tester,
      handler: (_) async => http.Response(jsonEncode(emptyAppointments), 200),
    );

    expect(find.text('No tienes próximas citas.'), findsOneWidget);
    expect(
      find.text('Cuando tengas una sesión agendada, aparecerá aquí.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes citas anteriores.'), findsOneWidget);
  });

  testWidgets(
    'upcoming appointment shows real fields, friendly status and proposal',
    (tester) async {
      await pumpAppointments(
        tester,
        handler: (request) async {
          if (request.url.path.endsWith('/patient/appointments/8')) {
            // GET detail response.
            return http.Response(
              jsonEncode({
                'appointment': {
                  'id': 8,
                  'date': '2026-10-05T14:30:00-06:00',
                  'time': '14:30',
                  'status': 'confirmado',
                  'modality': 'virtual',
                  'therapist': {
                    'nombre': 'Ana',
                    'apellido': 'López',
                    'especialidad': 'Psicología',
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
          }
          return http.Response(
            jsonEncode({
              'upcoming': [
                {
                  'id': 8,
                  'date': '2026-10-05T14:30:00-06:00',
                  'time': '14:30',
                  'status': 'confirmado',
                  'modality': 'virtual',
                  'therapist': {
                    'nombre': 'Ana',
                    'apellido': 'López',
                    'especialidad': 'Psicología',
                  },
                  'reschedule_proposal': {
                    'status': 'pending_patient',
                    'proposed_date': '2026-10-06T15:00:00-06:00',
                  },
                },
              ],
              'history': [
                {
                  'id': 9,
                  'date': '2026-08-01T10:00:00-06:00',
                  'status': 'aceptada',
                  'modality': 'presencial',
                },
              ],
            }),
            200,
          );
        },
      );

      expect(find.text('Confirmada'), findsOneWidget);
      expect(find.text('En línea'), findsOneWidget);
      expect(find.text('Ana López'), findsOneWidget);
      expect(find.text('Cambio de horario pendiente'), findsOneWidget);
      expect(find.text('06/10/2026 · 15:00'), findsOneWidget);
      await tester.tap(find.text('Confirmada'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('Detalle de la cita'), findsOneWidget);
      expect(find.text('No pudimos cargar esta cita.'), findsNothing);
      expect(find.text('Esta cita ya no está disponible.'), findsNothing);
      expect(find.text('Psicología'), findsOneWidget);
      expect(find.text('Nuevo horario propuesto'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Motivo de la cita'), 200);
      expect(find.text('Ansiedad'), findsOneWidget);
      expect(find.text('Aceptar nuevo horario'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Mis citas'), findsWidgets);
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('Aceptada'), findsOneWidget);
    },
  );

  testWidgets('history appointment appears in history tab', (tester) async {
    await pumpAppointments(
      tester,
      handler: (_) async => http.Response(
        jsonEncode({
          'upcoming': [],
          'history': [
            {
              'id': 10,
              'date': '2026-08-01T10:00:00-06:00',
              'status': 'aceptada',
              'modality': 'presencial',
            },
          ],
        }),
        200,
      ),
    );

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Aceptada'), findsOneWidget);
    expect(find.text('Presencial'), findsOneWidget);
  });

  testWidgets('detail renders reason from the detail payload', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'appointments-token',
    });
    final client = ApiClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'appointment': {
              'id': 8,
              'date': '2026-10-05T14:30:00-06:00',
              'time': '14:30',
              'status': 'confirmado',
              'modality': 'virtual',
              'therapist': {'nombre': 'Ana', 'apellido': 'López'},
              'reschedule_proposal': {
                'status': 'pending_patient',
                'proposed_date': '2026-10-06T15:00:00-06:00',
              },
              'reason': 'Ansiedad',
            },
          }),
          200,
        ),
      ),
    );
    final auth = AuthRepository(apiClient: client);
    addTearDown(auth.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PatientAppointmentDetailPage(
          repository: auth,
          appointmentsRepository: PatientAppointmentsRepository(
            apiClient: client,
          ),
          appointmentId: 8,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar esta cita.'), findsNothing);
    expect(find.text('Esta cita ya no está disponible.'), findsNothing);
    await tester.scrollUntilVisible(find.text('Motivo de la cita'), 200);
    expect(find.text('Ansiedad'), findsOneWidget);
    expect(find.textContaining('Martes 6 de octubre'), findsOneWidget);
  });

  testWidgets('network error shows retry and retry reloads', (tester) async {
    var calls = 0;
    await pumpAppointments(
      tester,
      handler: (_) async {
        calls++;
        if (calls == 1) throw http.ClientException('offline');
        return http.Response(jsonEncode(emptyAppointments), 200);
      },
    );

    expect(find.text('No pudimos cargar tus citas.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('No pudimos cargar tus citas.'), findsNothing);
    expect(find.text('No tienes próximas citas.'), findsOneWidget);
  });

  testWidgets('401 invalidates local session and uses login route', (
    tester,
  ) async {
    AuthRepository? auth;
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'appointments-token',
    });
    final client = ApiClient(
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    auth = AuthRepository(apiClient: client);
    final appointments = PatientAppointmentsRepository(apiClient: client);
    addTearDown(auth.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        routes: {AppRoutes.login: (_) => const Scaffold(body: Text('LOGIN'))},
        home: PatientAppointmentsPage(
          repository: auth,
          appointmentsRepository: appointments,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
    expect(await const FlutterSecureStorage().read(key: 'auth_token'), isNull);
  });

  testWidgets('detail omits null fields and renders network error and 404', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'appointments-token',
    });
    var status = 0;
    final client = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/patient/appointments') &&
            !request.url.path.contains('/appointments/')) {
          return http.Response(
            jsonEncode({
              'upcoming': [
                {
                  'id': 55,
                  'date': null,
                  'time': null,
                  'status': null,
                  'modality': null,
                  'therapist': null,
                  'reschedule_proposal': null,
                },
              ],
              'history': [],
            }),
            200,
          );
        }
        status++;
        if (status == 1) throw http.ClientException('offline');
        if (status == 2) {
          return http.Response(jsonEncode({'appointment': {}}), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    final auth = AuthRepository(apiClient: client);
    addTearDown(auth.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        routes: {
          AppRoutes.patientAppointmentDetail: (context) =>
              PatientAppointmentDetailPage(
                repository: auth,
                appointmentsRepository: PatientAppointmentsRepository(
                  apiClient: client,
                ),
                appointmentId:
                    ModalRoute.of(context)!.settings.arguments as int,
              ),
          AppRoutes.login: (_) => const Scaffold(body: Text('LOGIN')),
        },
        home: PatientAppointmentsPage(
          repository: auth,
          appointmentsRepository: PatientAppointmentsRepository(
            apiClient: client,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próximas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sesión'));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar esta cita.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Fecha'), findsNothing);
    expect(find.text('Hora'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Esta cita ya no está disponible.'), findsOneWidget);
  });

  testWidgets(
    'dashboard Mis sesiones quick action navigates to patient appointments',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'appointments-token',
      });
      var dashboardCalls = 0;
      final client = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/patient/dashboard')) {
            dashboardCalls++;
            return http.Response(
              jsonEncode({
                'patient': {
                  'id': 32,
                  'nombre': 'Ricardo',
                  'apellido': 'Cortez',
                },
                'therapist': null,
                'next_appointment': null,
                'between_session_activity': null,
                'emotional_summary': {'total_records': 0, 'records': []},
                'sessions': [],
              }),
              200,
            );
          }
          expect(request.url.path, endsWith('/patient/appointments'));
          return http.Response(jsonEncode(emptyAppointments), 200);
        }),
      );
      final auth = AuthRepository(apiClient: client);
      addTearDown(auth.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.patientAppointments: (_) => PatientAppointmentsPage(
              repository: auth,
              appointmentsRepository: PatientAppointmentsRepository(
                apiClient: client,
              ),
            ),
            AppRoutes.login: (_) => const Scaffold(body: Text('LOGIN')),
          },
          home: PatientDashboardPage(
            user: patient,
            repository: auth,
            dashboardRepository: PatientDashboardRepository(apiClient: client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(dashboardCalls, 1);
      await tester.tap(find.text('Mis sesiones').first);
      await tester.pumpAndSettle();
      expect(find.text('Mis citas'), findsWidgets);
      expect(find.text('No tienes próximas citas.'), findsOneWidget);
    },
  );
}

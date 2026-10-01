import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/routing/app_routes.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/patient/data/models/patient_appointment.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_appointments_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_appointment_detail_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_appointments_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_reschedule_appointment_page.dart';

const proposal = {
  'status': 'pending_patient',
  'proposed_date': '2026-10-05T10:00:00-06:00',
  'proposed_end': '2026-10-05T10:45:00-06:00',
  'timezone': 'America/Mexico_City',
};

Map<String, Object?> appointment({
  String status = 'confirmada',
  Object? rescheduleProposal = proposal,
  int id = 28,
}) => {
  'id': id,
  'date': '2026-10-06T11:00:00-06:00',
  'time': '11:00',
  'status': status,
  'modality': 'presencial',
  'therapist': {'nombre': 'Ana', 'apellido': 'López'},
  'reschedule_proposal': rescheduleProposal,
};

Future<void> pumpFlow(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
  final client = ApiClient(client: MockClient(handler));
  final auth = AuthRepository(apiClient: client);
  final appointments = PatientAppointmentsRepository(apiClient: client);
  addTearDown(auth.close);
  await tester.pumpWidget(
    MaterialApp(
      routes: {
        AppRoutes.login: (_) => const Scaffold(body: Text('LOGIN')),
        AppRoutes.patientAppointmentDetail: (context) =>
            PatientAppointmentDetailPage(
              repository: auth,
              appointmentsRepository: appointments,
              appointmentId: ModalRoute.of(context)!.settings.arguments as int,
            ),
      },
      home: PatientAppointmentsPage(
        repository: auth,
        appointmentsRepository: appointments,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cambio de horario pendiente'));
  await tester.pumpAndSettle();
}

Future<void> tapCardAction(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> confirmAccept(WidgetTester tester) async {
  await tapCardAction(tester, 'Aceptar nuevo horario');
  expect(find.text('¿Aceptar este nuevo horario?'), findsOneWidget);
  await tester.tap(find.text('Aceptar horario'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('proposal fields remain nullable after acceptance', () {
    final parsed = PatientRescheduleProposal.fromJson({
      'status': 'accepted',
      'proposed_date': null,
      'proposed_end': null,
      'timezone': null,
    });
    expect(parsed.status, 'accepted');
    expect(parsed.proposedDate, isNull);
    expect(parsed.proposedEnd, isNull);
    expect(parsed.timezone, isNull);
    final pending = PatientRescheduleProposal.fromJson(proposal);
    expect(pending.proposedEnd, '2026-10-05T10:45:00-06:00');
    expect(pending.timezone, 'America/Mexico_City');
  });

  testWidgets(
    'pending proposal shows current and proposed schedules with ordered actions',
    (tester) async {
      await pumpFlow(tester, (request) async {
        if (request.url.path.endsWith('/28')) {
          return http.Response(jsonEncode({'appointment': appointment()}), 200);
        }
        return http.Response(
          jsonEncode({
            'upcoming': [appointment()],
            'history': [],
          }),
          200,
        );
      });
      expect(find.text('Nuevo horario propuesto'), findsOneWidget);
      expect(
        find.text('Horario actual: Martes 6 de octubre · 11:00'),
        findsOneWidget,
      );
      expect(
        find.text('Horario propuesto: Lunes 5 de octubre · 10:00–10:45'),
        findsOneWidget,
      );
      expect(find.text('Modalidad: Presencial'), findsOneWidget);
      expect(find.text('Terapeuta: Ana López'), findsOneWidget);
      final accept = find.text('Aceptar nuevo horario');
      final other = find.text('Elegir otro horario');
      final cancel = find.text('Cancelar cita');
      expect(
        tester.getTopLeft(accept).dy,
        lessThan(tester.getTopLeft(other).dy),
      );
      expect(
        tester.getTopLeft(other).dy,
        lessThan(tester.getTopLeft(cancel).dy),
      );
      expect(find.text('Reagendar cita'), findsNothing);
    },
  );

  testWidgets(
    'accept posts no body, shows success, and refetches new ID and history',
    (tester) async {
      var accepted = false;
      var listGets = 0;
      var newDetailGets = 0;
      await pumpFlow(tester, (request) async {
        if (request.method == 'POST') {
          expect(
            request.url.path,
            '/api/patient/appointments/28/reschedule-proposal/accept',
          );
          expect(request.body, isEmpty);
          accepted = true;
          return http.Response(
            jsonEncode({
              'message': 'Nuevo horario aceptado.',
              'appointment': {
                'id': 32,
                'previous_appointment_id': 28,
                'status': 'confirmada',
              },
            }),
            201,
          );
        }
        if (request.url.path.endsWith('/28')) {
          return http.Response(jsonEncode({'appointment': appointment()}), 200);
        }
        if (request.url.path.endsWith('/32')) {
          newDetailGets++;
          return http.Response(
            jsonEncode({
              'appointment': appointment(id: 32, rescheduleProposal: null),
            }),
            200,
          );
        }
        listGets++;
        return http.Response(
          jsonEncode({
            'upcoming': [
              accepted
                  ? appointment(id: 32, rescheduleProposal: null)
                  : appointment(),
            ],
            'history': accepted
                ? [
                    appointment(
                      status: 'reagendada',
                      rescheduleProposal: {'status': 'accepted'},
                    ),
                  ]
                : [],
          }),
          200,
        );
      });
      await confirmAccept(tester);
      expect(find.text('Nuevo horario confirmado'), findsOneWidget);
      expect(
        find.text('Tu cita fue actualizada correctamente.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ver mis citas'));
      await tester.pumpAndSettle();
      expect(listGets, 2);
      expect(find.text('Cambio de horario pendiente'), findsNothing);
      await tester.tap(find.textContaining('11:00').first);
      await tester.pumpAndSettle();
      expect(newDetailGets, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('reagendada'), findsOneWidget);
    },
  );

  testWidgets('409 removes accept and offers choosing another slot', (
    tester,
  ) async {
    var detailGets = 0;
    await pumpFlow(tester, (request) async {
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'message': 'El horario propuesto ya no está disponible.',
          }),
          409,
        );
      }
      if (request.url.path.endsWith('/28')) {
        detailGets++;
        return http.Response(jsonEncode({'appointment': appointment()}), 200);
      }
      return http.Response(
        jsonEncode({
          'upcoming': [appointment()],
          'history': [],
        }),
        200,
      );
    });
    await confirmAccept(tester);
    await tester.pumpAndSettle();
    expect(detailGets, 2);
    expect(find.text('Ese horario ya no está disponible.'), findsOneWidget);
    expect(find.text('Aceptar nuevo horario'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, 'Elegir otro horario'),
      findsOneWidget,
    );
  });

  testWidgets('422 refreshes detail and hides resolved proposal', (
    tester,
  ) async {
    var detailGets = 0;
    await pumpFlow(tester, (request) async {
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({'message': 'Esta propuesta ya fue respondida.'}),
          422,
        );
      }
      if (request.url.path.endsWith('/28')) {
        detailGets++;
        return http.Response(
          jsonEncode({
            'appointment': appointment(
              rescheduleProposal: detailGets == 1
                  ? proposal
                  : {'status': 'accepted'},
            ),
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'upcoming': [appointment()],
          'history': [],
        }),
        200,
      );
    });
    await confirmAccept(tester);
    await tester.pumpAndSettle();
    expect(detailGets, 2);
    expect(find.text('Nuevo horario propuesto'), findsNothing);
    expect(find.text('Esta propuesta ya fue respondida.'), findsOneWidget);
  });

  testWidgets('network error keeps proposal and allows retry', (tester) async {
    var posts = 0;
    await pumpFlow(tester, (request) async {
      if (request.method == 'POST') {
        posts++;
        throw http.ClientException('offline');
      }
      if (request.url.path.endsWith('/28')) {
        return http.Response(jsonEncode({'appointment': appointment()}), 200);
      }
      return http.Response(
        jsonEncode({
          'upcoming': [appointment()],
          'history': [],
        }),
        200,
      );
    });
    await confirmAccept(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos aceptar el nuevo horario. Intenta nuevamente.'),
      findsOneWidget,
    );
    expect(find.text('Aceptar nuevo horario'), findsOneWidget);
    await confirmAccept(tester);
    await tester.pumpAndSettle();
    expect(posts, 2);
  });

  testWidgets('choose another opens existing reschedule page', (tester) async {
    await pumpFlow(tester, (request) async {
      if (request.url.path.endsWith('/availability')) {
        return http.Response(jsonEncode({'slots': []}), 200);
      }
      if (request.url.path.endsWith('/28')) {
        return http.Response(jsonEncode({'appointment': appointment()}), 200);
      }
      return http.Response(
        jsonEncode({
          'upcoming': [appointment()],
          'history': [],
        }),
        200,
      );
    });
    await tapCardAction(tester, 'Elegir otro horario');
    expect(find.byType(PatientRescheduleAppointmentPage), findsOneWidget);
    expect(find.text('Reagendar cita'), findsOneWidget);
  });

  testWidgets('proposal cancel opens cancellation confirmation directly', (
    tester,
  ) async {
    await pumpFlow(tester, (request) async {
      if (request.url.path.endsWith('/28')) {
        return http.Response(jsonEncode({'appointment': appointment()}), 200);
      }
      return http.Response(
        jsonEncode({
          'upcoming': [appointment()],
          'history': [],
        }),
        200,
      );
    });
    await tapCardAction(tester, 'Cancelar cita');
    expect(find.text('¿Quieres cancelar esta cita?'), findsOneWidget);
    expect(find.text('¿Necesitas cambiar tu cita?'), findsNothing);
  });
  testWidgets('404 returns to Mis citas and refetches', (tester) async {
    var listGets = 0;
    await pumpFlow(tester, (request) async {
      if (request.method == 'POST') return http.Response('{}', 404);
      if (request.url.path.endsWith('/28')) {
        return http.Response(jsonEncode({'appointment': appointment()}), 200);
      }
      listGets++;
      return http.Response(
        jsonEncode({
          'upcoming': [appointment()],
          'history': [],
        }),
        200,
      );
    });
    await confirmAccept(tester);
    await tester.pumpAndSettle();
    expect(find.text('Esta cita ya no está disponible.'), findsOneWidget);
    expect(listGets, 2);
    expect(find.text('Mis citas'), findsWidgets);
  });

  testWidgets('accept loading prevents a second submit', (tester) async {
    final response = Completer<http.Response>();
    var posts = 0;
    await pumpFlow(tester, (request) async {
      if (request.method == 'POST') {
        posts++;
        return response.future;
      }
      if (request.url.path.endsWith('/28')) {
        return http.Response(jsonEncode({'appointment': appointment()}), 200);
      }
      return http.Response(
        jsonEncode({
          'upcoming': [appointment()],
          'history': [],
        }),
        200,
      );
    });
    await confirmAccept(tester);
    expect(posts, 1);
    expect(
      find.widgetWithText(FilledButton, 'Aceptar nuevo horario'),
      findsNothing,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    response.complete(
      http.Response(
        jsonEncode({
          'appointment': {
            'id': 32,
            'previous_appointment_id': 28,
            'status': 'confirmada',
          },
        }),
        201,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(posts, 1);
    expect(find.text('Nuevo horario confirmado'), findsOneWidget);
  });

  testWidgets(
    'proposal cancellation uses existing endpoint and refreshes list',
    (tester) async {
      var posts = 0;
      var listGets = 0;
      await pumpFlow(tester, (request) async {
        if (request.method == 'POST') {
          posts++;
          expect(request.url.path, '/api/patient/appointments/28/cancel');
          return http.Response(
            jsonEncode({
              'message': 'Tu cita fue cancelada.',
              'appointment': {'id': 28, 'status': 'cancelada'},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/28')) {
          return http.Response(jsonEncode({'appointment': appointment()}), 200);
        }
        listGets++;
        return http.Response(
          jsonEncode({
            'upcoming': posts == 0 ? [appointment()] : [],
            'history': posts == 0
                ? []
                : [
                    appointment(
                      status: 'cancelada',
                      rescheduleProposal: {'status': 'cancelled'},
                    ),
                  ],
          }),
          200,
        );
      });
      await tapCardAction(tester, 'Cancelar cita');
      expect(find.text('¿Quieres cancelar esta cita?'), findsOneWidget);
      expect(find.text('¿Necesitas cambiar tu cita?'), findsNothing);
      await tester.tap(find.text('Cancelar cita').last);
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(listGets, 2);
      expect(find.text('No tienes próximas citas.'), findsOneWidget);
    },
  );
}

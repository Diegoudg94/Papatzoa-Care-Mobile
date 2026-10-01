import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/routing/app_routes.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_appointments_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_appointments_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_book_appointment_page.dart';

Map<String, dynamic> availability({bool empty = false}) => {
  'therapist': {'id': 3, 'nombre': 'Ana', 'apellido': null},
  'timezone': 'America/Mexico_City',
  'session_duration_minutes': 45,
  'available_modalities': ['online', 'presencial'],
  'slots': empty
      ? []
      : [
          {
            'start': '2026-10-05T11:00:00-06:00',
            'end': '2026-10-05T11:45:00-06:00',
          },
        ],
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
        AppRoutes.patientBookAppointment: (_) => PatientBookAppointmentPage(
          repository: auth,
          appointmentsRepository: appointments,
        ),
      },
      home: PatientAppointmentsPage(
        repository: auth,
        appointmentsRepository: appointments,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Solicitar cita').first);
  await tester.pumpAndSettle();
}

Future<void> fillForm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ChoiceChip, '11:00'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ChoiceChip, 'En línea'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), 'Consulta');
  await tester.scrollUntilVisible(
    find.widgetWithText(FilledButton, 'Solicitar cita'),
    300,
    scrollable: find
        .descendant(
          of: find.byType(PatientBookAppointmentPage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty availability shows message and next range', (
    tester,
  ) async {
    var calls = 0;
    await pumpFlow(tester, (request) async {
      if (request.url.path.endsWith('/availability')) {
        calls++;
        return http.Response(jsonEncode(availability(empty: true)), 200);
      }
      return http.Response(jsonEncode({'upcoming': [], 'history': []}), 200);
    });
    expect(
      find.text('No encontramos horarios disponibles en estas fechas.'),
      findsOneWidget,
    );
    expect(find.text('Cita con Ana'), findsOneWidget);
    await tester.tap(find.byTooltip('Siguientes fechas'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  for (final status in ['pendiente', 'confirmada']) {
    testWidgets('201 $status confirms and refreshes Mis citas', (tester) async {
      var created = false;
      var listCalls = 0;
      await pumpFlow(tester, (request) async {
        if (request.url.path.endsWith('/availability')) {
          return http.Response(jsonEncode(availability()), 200);
        }
        if (request.method == 'POST') {
          created = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.keys.toSet(), {'start', 'end', 'motivo', 'modalidad'});
          expect(body['start'], '2026-10-05T11:00:00-06:00');
          return http.Response(
            jsonEncode({
              'appointment': {'id': 8, 'status': status},
            }),
            201,
          );
        }
        listCalls++;
        return http.Response(
          jsonEncode({
            'upcoming': created
                ? [
                    {
                      'id': 8,
                      'date': '2026-10-05T11:00:00-06:00',
                      'time': '11:00',
                      'status': status,
                    },
                  ]
                : [],
            'history': [],
          }),
          200,
        );
      });
      await fillForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Solicitar cita'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Solicitud enviada'), findsOneWidget);
      expect(
        find.text(
          status == 'pendiente'
              ? 'Tu terapeuta debe confirmar la cita.'
              : 'Tu cita quedó confirmada.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Ver mis citas'));
      await tester.pumpAndSettle();
      expect(listCalls, 2);
      expect(find.textContaining('11:00'), findsOneWidget);
    });
  }

  testWidgets('409 reloads availability and clears slot', (tester) async {
    var availabilityCalls = 0;
    await pumpFlow(tester, (request) async {
      if (request.url.path.endsWith('/availability')) {
        availabilityCalls++;
        return http.Response(jsonEncode(availability()), 200);
      }
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({'message': 'Ese horario ya no está disponible.'}),
          409,
        );
      }
      return http.Response(jsonEncode({'upcoming': [], 'history': []}), 200);
    });
    await fillForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Solicitar cita'));
    await tester.pumpAndSettle();
    expect(availabilityCalls, 2);
    await tester.drag(find.byType(ListView).last, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(
      find.text('Ese horario acaba de dejar de estar disponible.'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Hora: Sin seleccionar'), findsOneWidget);
  });

  testWidgets('422 shows backend message', (tester) async {
    await pumpFlow(tester, (request) async {
      if (request.url.path.endsWith('/availability')) {
        return http.Response(jsonEncode(availability()), 200);
      }
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'message': 'Necesitas vincularte con un terapeuta antes de solicitar una cita.',
          }),
          422,
        );
      }
      return http.Response(jsonEncode({'upcoming': [], 'history': []}), 200);
    });
    await fillForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Solicitar cita'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Necesitas vincularte con un terapeuta antes de solicitar una cita.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reason is required before posting', (tester) async {
    var posts = 0;
    await pumpFlow(tester, (request) async {
      if (request.url.path.endsWith('/availability')) {
        return http.Response(jsonEncode(availability()), 200);
      }
      if (request.method == 'POST') posts++;
      return http.Response(jsonEncode({'upcoming': [], 'history': []}), 200);
    });
    await tester.tap(find.widgetWithText(ChoiceChip, '11:00'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'En línea'));
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Solicitar cita'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(PatientBookAppointmentPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Solicitar cita'));
    await tester.pumpAndSettle();
    expect(posts, 0);
    expect(find.text('Escribe el motivo de la cita.'), findsOneWidget);
  });

  testWidgets('network failure shows retry', (tester) async {
    await pumpFlow(tester, (request) async {
      if (request.url.path.endsWith('/availability')) {
        throw http.ClientException('offline');
      }
      return http.Response(jsonEncode({'upcoming': [], 'history': []}), 200);
    });
    expect(
      find.text(
        'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });
}

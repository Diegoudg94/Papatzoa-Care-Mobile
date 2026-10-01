import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/patient/data/models/patient_appointment.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_appointments_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_reschedule_appointment_page.dart';

const slot = {
  'start': '2026-10-05T11:00:00-06:00',
  'end': '2026-10-05T11:45:00-06:00',
};
const current = PatientAppointment(
  id: 26,
  date: '2026-10-05T10:00:00-06:00',
  time: '10:00',
  status: 'confirmada',
  modality: 'presencial',
  therapist: PatientAppointmentTherapist(nombre: 'Ana'),
);

Future<void> pumpPage(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
  final client = ApiClient(client: MockClient(handler));
  final auth = AuthRepository(apiClient: client);
  addTearDown(auth.close);
  await tester.pumpWidget(
    MaterialApp(
      home: PatientRescheduleAppointmentPage(
        repository: auth,
        appointmentsRepository: PatientAppointmentsRepository(
          apiClient: client,
        ),
        appointment: current,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectAndConfirm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ChoiceChip, '11:00'));
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView), const Offset(0, -700));
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(FilledButton, 'Confirmar reagendamiento').first,
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(FilledButton, 'Confirmar reagendamiento').last,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final status in ['pendiente', 'confirmada']) {
    testWidgets('reschedule $status sends exact slot and shows actual status', (
      tester,
    ) async {
      var posts = 0;
      await pumpPage(tester, (request) async {
        if (request.method == 'POST') {
          posts++;
          expect(request.url.path, '/api/patient/appointments/26/reschedule');
          expect(jsonDecode(request.body), slot);
          return http.Response(
            jsonEncode({
              'appointment': {
                'id': 30,
                'previous_appointment_id': 26,
                'status': status,
              },
            }),
            201,
          );
        }
        expect(request.url.path, '/api/patient/appointments/availability');
        expect(request.url.queryParameters.keys.toSet(), {'from', 'to'});
        return http.Response(
          jsonEncode({
            'slots': [slot],
            'available_modalities': ['presencial'],
          }),
          200,
        );
      });
      expect(find.text('Horario actual'), findsOneWidget);
      expect(find.textContaining('10:00'), findsWidgets);
      expect(find.text('Modalidad: Presencial'), findsWidgets);
      expect(find.text('11:00'), findsWidgets);
      await selectAndConfirm(tester);
      expect(posts, 1);
      expect(
        find.text(
          status == 'pendiente'
              ? 'Solicitud de cambio enviada'
              : 'Cita reagendada',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          status == 'pendiente'
              ? 'Tu terapeuta debe confirmar el nuevo horario.'
              : 'Tu nuevo horario quedó confirmado.',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('409 clears slot and reloads availability', (tester) async {
    var gets = 0;
    await pumpPage(tester, (request) async {
      if (request.method == 'POST') return http.Response('{}', 409);
      gets++;
      return http.Response(
        jsonEncode({
          'slots': [slot],
        }),
        200,
      );
    });
    await selectAndConfirm(tester);
    expect(gets, 2);
    expect(
      find.text('Ese horario acaba de dejar de estar disponible.'),
      findsOneWidget,
    );
    expect(find.textContaining('Sin seleccionar'), findsWidgets);
  });

  testWidgets('network failure keeps selection for retry', (tester) async {
    await pumpPage(tester, (request) async {
      if (request.method == 'POST') throw http.ClientException('offline');
      return http.Response(
        jsonEncode({
          'slots': [slot],
        }),
        200,
      );
    });
    await selectAndConfirm(tester);
    expect(
      find.text('No pudimos reagendar la cita. Intenta nuevamente.'),
      findsOneWidget,
    );
    expect(find.textContaining('11:00'), findsWidgets);
  });
}

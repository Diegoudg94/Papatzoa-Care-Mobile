import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/routing/app_router.dart';
import 'package:papatzoa_mobile/features/auth/data/models/auth_user.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_support_network_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_dashboard_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/support_network/patient_support_network_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/support_network/support_contact_detail_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/support_network/support_contact_form_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/support_network/support_contact_wizard_page.dart';

const metadata = {
  'support_types': [
    {'value': 'escucharme', 'label': 'Escucharme'},
    {'value': 'acompanarme', 'label': 'Acompañarme'},
    {'value': 'otro', 'label': 'Otro'},
  ],
  'trust_level': {'min': 1, 'max': 5},
  'support_type_count': {'min': 1, 'max': 6},
};
const ana = {
  'id': 2,
  'nombre': 'Ana',
  'relacion': 'Amiga',
  'telefono_lada': null,
  'telefono': null,
  'nivel_confianza': 5,
  'tipos_apoyo': ['escucharme'],
  'tipo_apoyo_otro': null,
  'nota': null,
};

http.Response jsonResponse(Object value, int status) => http.Response.bytes(
  utf8.encode(jsonEncode(value)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> pumpNetwork(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
  final client = ApiClient(
    client: MockClient((request) async {
      if (request.url.path.endsWith('/options')) {
        return jsonResponse(metadata, 200);
      }
      return handler(request);
    }),
  );
  final auth = AuthRepository(apiClient: client);
  addTearDown(auth.close);
  await tester.pumpWidget(
    MaterialApp(
      home: PatientSupportNetworkPage(
        repository: auth,
        supportRepository: PatientSupportNetworkRepository(apiClient: client),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openCreate(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Agregar persona'));
  await tester.pumpAndSettle();
  expect(find.byType(SupportContactWizardPage), findsOneWidget);
}

Future<void> saveForm(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty state opens guided wizard without reading contacts', (
    tester,
  ) async {
    await pumpNetwork(tester, (_) async => jsonResponse({'contacts': []}, 200));
    await openCreate(tester);
    expect(find.text('¿A quién quieres agregar?'), findsOneWidget);
    expect(find.text('Elegir de mis contactos'), findsOneWidget);
    expect(find.text('Escribir manualmente'), findsOneWidget);
  });

  testWidgets('list and detail show support labels, not note preview', (
    tester,
  ) async {
    await pumpNetwork(
      tester,
      (_) async => jsonResponse({
        'contacts': [
          {...ana, 'nota': 'Nota privada'},
        ],
      }, 200),
    );
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Confianza: 5/5'), findsOneWidget);
    expect(find.text('Escucharme'), findsOneWidget);
    expect(find.text('Nota privada'), findsNothing);
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportContactDetailPage), findsOneWidget);
    expect(find.text('Nota privada'), findsOneWidget);
    expect(find.text('Teléfono'), findsNothing);
  });

  testWidgets('edit preloads all fields, PUT uses ID and 200 refetches', (
    tester,
  ) async {
    var puts = 0, lists = 0;
    final existing = {
      ...ana,
      'telefono_lada': '+52',
      'telefono': '55 1234-5678',
      'nota': 'Nota privada',
    };
    await pumpNetwork(tester, (request) async {
      if (request.method == 'PUT') {
        puts++;
        expect(request.url.path, '/api/patient/support-network/2');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['nombre'], 'Ana nueva');
        expect(body['nota'], 'Nota privada');
        return jsonResponse({
          'contact': {...existing, ...body},
        }, 200);
      }
      lists++;
      return jsonResponse({
        'contacts': [
          puts == 0 ? existing : {...existing, 'nombre': 'Ana nueva'},
        ],
      }, 200);
    });
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Nombre'))
          .controller!
          .text,
      'Ana',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Nota'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SupportContactFormPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Nota'))
          .controller!
          .text,
      'Nota privada',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre'),
      'Ana nueva',
    );
    await saveForm(tester, 'Guardar cambios');
    expect(puts, 1);
    expect(lists, 2);
    expect(find.text('Ana nueva'), findsOneWidget);
  });

  testWidgets('delete confirms before 204 and refetches', (tester) async {
    var deletes = 0, lists = 0;
    await pumpNetwork(tester, (request) async {
      if (request.method == 'DELETE') {
        deletes++;
        expect(request.url.path, '/api/patient/support-network/2');
        return http.Response('', 204);
      }
      lists++;
      return jsonResponse({
        'contacts': deletes == 0 ? [ana] : [],
      }, 200);
    });
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    expect(find.text('¿Eliminar de tu red de apoyo?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Volver'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(lists, 2);
    expect(find.text('Aún no has agregado personas a tu red.'), findsOneWidget);
  });

  testWidgets(
    '422 and network errors retain form; 404 returns to refetched list',
    (tester) async {
      var puts = 0, lists = 0;
      await pumpNetwork(tester, (request) async {
        if (request.method == 'PUT') {
          puts++;
          if (puts == 1) {
            return jsonResponse({
              'errors': {
                'telefono': ['Invalid'],
              },
            }, 422);
          }
          if (puts == 2) {
            throw http.ClientException('offline');
          }
          return http.Response('', 404);
        }
        lists++;
        return jsonResponse({
          'contacts': [ana],
        }, 200);
      });
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre'),
        'Ana editada',
      );
      await saveForm(tester, 'Guardar cambios');
      expect(find.text('Ingresa un teléfono válido.'), findsOneWidget);
      expect(find.text('Ana editada'), findsOneWidget);
      await saveForm(tester, 'Guardar cambios');
      expect(
        find.text('No pudimos guardar los cambios. Intenta nuevamente.'),
        findsOneWidget,
      );
      expect(find.text('Ana editada'), findsOneWidget);
      await saveForm(tester, 'Guardar cambios');
      expect(find.byType(PatientSupportNetworkPage), findsOneWidget);
      expect(find.text('Este contacto ya no está disponible.'), findsOneWidget);
      expect(lists, 2);
    },
  );

  testWidgets('delete network failure stays in detail; 404 refreshes list', (
    tester,
  ) async {
    var deletes = 0, lists = 0;
    await pumpNetwork(tester, (request) async {
      if (request.method == 'DELETE') {
        deletes++;
        if (deletes == 1) {
          throw http.ClientException('offline');
        }
        return http.Response('', 404);
      }
      lists++;
      return jsonResponse({
        'contacts': [ana],
      }, 200);
    });
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportContactDetailPage), findsOneWidget);
    expect(
      find.text('No pudimos eliminar este contacto. Intenta nuevamente.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(find.byType(PatientSupportNetworkPage), findsOneWidget);
    expect(find.text('Este contacto ya no está disponible.'), findsOneWidget);
    expect(lists, 2);
  });

  testWidgets('dashboard quick action opens support network route', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
    final client = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/patient/dashboard')) {
          return jsonResponse({
            'patient': {'id': 1, 'nombre': 'Ana'},
            'therapist': null,
            'next_appointment': null,
            'between_session_activity': null,
            'emotional_summary': {'total_records': 0, 'records': []},
            'sessions': [],
          }, 200);
        }
        if (request.url.path.endsWith('/options')) {
          return jsonResponse(metadata, 200);
        }
        return jsonResponse({'contacts': []}, 200);
      }),
    );
    final auth = AuthRepository(apiClient: client);
    addTearDown(auth.close);
    await tester.pumpWidget(
      MaterialApp(
        routes: AppRouter.routesFor(auth),
        home: PatientDashboardPage(
          repository: auth,
          user: const AuthUser(
            id: 1,
            firstName: 'Ana',
            lastName: '',
            email: 'ana@example.com',
            role: 'patient',
            isTherapist: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Red de apoyo'));
    await tester.pumpAndSettle();
    expect(find.byType(PatientSupportNetworkPage), findsOneWidget);
  });
}

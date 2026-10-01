import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/patient/data/models/support_network_contact.dart';
import 'package:papatzoa_mobile/features/patient/data/models/support_network_options.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_support_network_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/support_network/device_contact_picker.dart';
import 'package:papatzoa_mobile/features/patient/presentation/support_network/support_contact_wizard_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/support_network/support_whatsapp.dart';

class FakePicker implements DeviceContactPicker {
  FakePicker(this.result);
  ContactPickResult result;
  int calls = 0;
  int settingsCalls = 0;
  @override
  Future<ContactPickResult> pick() async {
    calls++;
    return result;
  }

  @override
  Future<void> openSettings() async {
    settingsCalls++;
  }
}

const options = SupportNetworkOptions(
  supportTypes: [
    SupportTypeOption(value: 'escucharme', label: 'Escucharme'),
    SupportTypeOption(value: 'otro', label: 'Otro'),
  ],
  trustMin: 1,
  trustMax: 5,
  supportTypeMin: 1,
  supportTypeMax: 2,
);

http.Response response(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> pumpWizard(
  WidgetTester tester,
  FakePicker picker,
  Future<http.Response> Function(http.Request) handler,
) async {
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
  final client = ApiClient(client: MockClient(handler));
  final auth = AuthRepository(apiClient: client);
  addTearDown(auth.close);
  await tester.pumpWidget(
    MaterialApp(
      home: SupportContactWizardPage(
        repository: auth,
        supportRepository: PatientSupportNetworkRepository(apiClient: client),
        options: options,
        contactPicker: picker,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('phone import preserves unknown country codes and infers explicit Mexico code', () {
    expect(prefillSupportPhone('+52 (55) 1234-5678'), (
      code: '+52',
      phone: '(55) 1234-5678',
    ));
    expect(prefillSupportPhone('+1 212 555 1234'), (
      code: '',
      phone: '+1 212 555 1234',
    ));
  });

  test(
    'WhatsApp uses web message and number rule without changing stored fields',
    () {
      const contact = SupportNetworkContact(
        id: 1,
        name: 'Ana',
        relationship: 'Amiga',
        trustLevel: 5,
        supportTypes: ['escucharme'],
        phoneCode: '+52',
        phone: '55 1234-5678',
      );
      expect(
        supportWhatsappMessage,
        'Hola, ¿tienes un momento para hablar? Me vendría bien un poco de compañía.',
      );
      expect(supportWhatsappNumber(contact), '525512345678');
      expect(
        supportWhatsappUrl(contact, supportWhatsappMessage)!.toString(),
        'https://wa.me/525512345678?text=Hola%2C+%C2%BFtienes+un+momento+para+hablar%3F+Me+vendr%C3%ADa+bien+un+poco+de+compa%C3%B1%C3%ADa.',
      );
      expect(contact.phone, '55 1234-5678');
    },
  );

  testWidgets(
    'manual wizard preserves data, uses options, reviews and posts only on confirmation',
    (tester) async {
      var posts = 0;
      await pumpWizard(
        tester,
        FakePicker(const ContactPickResult(ContactPickStatus.cancelled)),
        (request) async {
          posts++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['nombre'], 'Ana');
          expect(body['relacion'], 'Amiga');
          expect(body['nivel_confianza'], 4);
          expect(body['tipos_apoyo'], ['escucharme', 'otro']);
          expect(body['tipo_apoyo_otro'], 'Conversar');
          expect(body['nota'], 'Me escucha');
          expect(body['telefono'], null);
          return response({
            'contact': {'id': 1, ...body},
          }, 201);
        },
      );
      await tester.tap(find.text('Escribir manualmente'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Ana');
      await next(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Relación'),
        'Amiga',
      );
      await next(tester);
      expect(tester.widget<Slider>(find.byType(Slider)).max, 5);
      await tester.drag(find.byType(Slider), const Offset(220, 0));
      await tester.pumpAndSettle();
      await next(tester);
      expect(find.text('Escucharme'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Escucharme'));
      await tester.tap(find.widgetWithText(FilterChip, 'Otro'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '¿Qué tipo de apoyo?'),
        'Conversar',
      );
      await next(tester);
      await next(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nota'),
        'Me escucha',
      );
      await next(tester);
      expect(find.text('Revisa a la persona'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(posts, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar a mi red'));
      await tester.pumpAndSettle();
      expect(posts, 1);
    },
  );

  testWidgets(
    'denied permission offers manual fallback and dirty exit confirms',
    (tester) async {
      final picker = FakePicker(
        const ContactPickResult(ContactPickStatus.denied),
      );
      await pumpWizard(tester, picker, (_) async => response({}, 500));
      expect(picker.calls, 0);
      await tester.tap(find.text('Elegir de mis contactos'));
      await tester.pumpAndSettle();
      expect(find.text('No pudimos acceder a tus contactos.'), findsOneWidget);
      await tester.tap(find.text('Escribir manualmente').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Ana');
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      expect(
        find.text('Los cambios que hiciste no se guardarán.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'permanent denial offers settings and imported multiple phones require choice',
    (tester) async {
      final picker = FakePicker(
        const ContactPickResult(ContactPickStatus.permanentlyDenied),
      );
      await pumpWizard(tester, picker, (_) async => response({}, 500));
      await tester.tap(find.text('Elegir de mis contactos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir configuración'));
      expect(picker.settingsCalls, 1);
      picker.result = const ContactPickResult(
        ContactPickStatus.selected,
        PickedSupportContact('Ana', ['1111111111', '+52 55 1234 5678']),
      );
      await tester.tap(find.text('Elegir de mis contactos'));
      await tester.pumpAndSettle();
      expect(find.text('Elige un teléfono'), findsOneWidget);
      await tester.tap(find.text('+52 55 1234 5678'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Nombre'))
            .controller!
            .text,
        'Ana',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre'),
        'Ana nueva',
      );
      await next(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Relación'),
        'Amiga',
      );
      await next(tester);
      await next(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Escucharme'));
      await next(tester);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Lada'))
            .controller!
            .text,
        '+52',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Teléfono'))
            .controller!
            .text,
        '55 1234 5678',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Teléfono'),
        '55 0000 0000',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Teléfono'))
            .controller!
            .text,
        '55 0000 0000',
      );
    },
  );

  testWidgets('WhatsApp preview does not send and reports launch failure', (
    tester,
  ) async {
    const contact = SupportNetworkContact(
      id: 1,
      name: 'Ana',
      relationship: 'Amiga',
      trustLevel: 5,
      supportTypes: ['escucharme'],
      phoneCode: '+52',
      phone: '5512345678',
    );
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => prepareSupportWhatsapp(
                context,
                contact,
                opener: (uri) async {
                  opened = uri;
                  return false;
                },
              ),
              child: const Text('Preparar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Preparar'));
    await tester.pumpAndSettle();
    expect(opened, null);
    expect(find.text(supportWhatsappMessage), findsOneWidget);
    await tester.tap(find.text('Abrir WhatsApp'));
    await tester.pumpAndSettle();
    expect(opened!.host, 'wa.me');
    expect(
      find.text('No pudimos abrir WhatsApp en este dispositivo.'),
      findsOneWidget,
    );
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/network/api_exceptions.dart';
import 'package:papatzoa_mobile/features/patient/data/models/support_network_contact.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_support_network_repository.dart';

const contact = {
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
const options = {
  'support_types': [
    {'value': 'escucharme', 'label': 'Escucharme'},
    {'value': 'otro', 'label': 'Otro'},
  ],
  'trust_level': {'min': 1, 'max': 5},
  'support_type_count': {'min': 1, 'max': 6},
};

http.Response jsonResponse(Object value, int status) => http.Response.bytes(
  utf8.encode(jsonEncode(value)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'list and metadata parse nullable fields, confidence int and labels',
    () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      final repo = PatientSupportNetworkRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer token');
            if (request.url.path.endsWith('/options')) {
              return jsonResponse(options, 200);
            }
            expect(request.url.path, '/api/patient/support-network');
            return jsonResponse({
              'contacts': [contact],
            }, 200);
          }),
        ),
      );
      addTearDown(repo.apiClient.close);
      final metadata = await repo.getOptions();
      final people = await repo.getContacts();
      expect(metadata.labelFor('escucharme'), 'Escucharme');
      expect(metadata.trustMax, 5);
      expect(metadata.supportTypeMin, 1);
      expect(people.single.trustLevel, isA<int>());
      expect(people.single.trustLevel, 5);
      expect(people.single.phoneCode, isNull);
      expect(people.single.phone, isNull);
      expect(people.single.note, isNull);
      expect(people.single.supportTypes, ['escucharme']);
    },
  );

  test(
    'POST, PUT and DELETE use bearer, exact IDs, safe fields and statuses',
    () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      final printed = <String>[];
      final methods = <String>[];
      final repo = PatientSupportNetworkRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            methods.add(request.method);
            expect(request.headers['Authorization'], 'Bearer token');
            if (request.method == 'DELETE') {
              expect(request.url.path, '/api/patient/support-network/2');
              return http.Response('', 204);
            }
            expect(
              request.url.path,
              request.method == 'POST'
                  ? '/api/patient/support-network'
                  : '/api/patient/support-network/2',
            );
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body.keys, isNot(contains('user_id')));
            expect(body.keys, isNot(contains('patient_id')));
            expect(body['nombre'], 'Ana');
            expect(body['nivel_confianza'], 5);
            expect(body['tipos_apoyo'], ['escucharme', 'otro']);
            expect(
              body['telefono'],
              request.method == 'POST' ? '55 1234-5678' : null,
            );
            expect(
              body['nota'],
              request.method == 'POST' ? 'Nota sensible' : null,
            );
            return jsonResponse({
              'contact': {...contact, ...body},
            }, request.method == 'POST' ? 201 : 200);
          }),
        ),
      );
      addTearDown(repo.apiClient.close);
      await runZoned(
        () async {
          final created = await repo.createContact(
            const SupportNetworkDraft(
              name: 'Ana',
              relationship: 'Amiga',
              trustLevel: 5,
              supportTypes: ['escucharme', 'otro'],
              otherSupportType: 'Conversar',
              phone: '55 1234-5678',
              note: 'Nota sensible',
            ),
          );
          expect(created.id, 2);
          final updated = await repo.updateContact(
            2,
            const SupportNetworkDraft(
              name: 'Ana',
              relationship: 'Amiga',
              trustLevel: 5,
              supportTypes: ['escucharme', 'otro'],
              otherSupportType: 'Conversar',
            ),
          );
          expect(updated.note, isNull);
          await repo.deleteContact(2);
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );
      expect(methods, ['POST', 'PUT', 'DELETE']);
      expect(printed.join(' '), isNot(contains('Nota sensible')));
      expect(printed.join(' '), isNot(contains('55 1234-5678')));
    },
  );

  test('422 maps Laravel field error without logging input', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
    final repo = PatientSupportNetworkRepository(
      apiClient: ApiClient(
        client: MockClient(
          (_) async => jsonResponse({
            'message': 'The given data was invalid.',
            'errors': {
              'telefono': ['The telefono format is invalid.'],
            },
          }, 422),
        ),
      ),
    );
    addTearDown(repo.apiClient.close);
    await expectLater(
      repo.createContact(
        const SupportNetworkDraft(
          name: 'Ana',
          relationship: 'Amiga',
          trustLevel: 5,
          supportTypes: ['escucharme'],
          phone: '123',
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Ingresa un teléfono válido.',
        ),
      ),
    );
  });
}

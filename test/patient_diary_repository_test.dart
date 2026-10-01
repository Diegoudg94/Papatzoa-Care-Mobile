import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/network/api_exceptions.dart';
import 'package:papatzoa_mobile/features/patient/data/models/diary_entry.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_diary_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'models accept nullable intensity, text, dates and follow-up fields',
    () {
      final entry = DiaryEntry.fromJson({
        'id': 10,
        'emotion': 'Ansiedad',
        'intensity': null,
        'recorded_at': null,
        'follow_ups': [
          {'id': 4, 'note': null, 'recorded_at': null},
        ],
      });
      expect(entry.id, 10);
      expect(entry.intensity, isNull);
      expect(entry.recordedAt, isNull);
      expect(entry.situation, isNull);
      expect(entry.followUps.single.note, isNull);
      expect(entry.followUps.single.recordedAt, isNull);
      final another = DiaryEntry.fromJson({
        'id': 11,
        'emotion': 'Alegría',
        'intensity': 7,
        'recorded_at': '2026-09-29T22:10:20+00:00',
      });
      expect(another.intensity, 7);
      expect(another.recordedAt, isNotNull);
    },
  );

  test(
    'history and detail use real response envelopes and Bearer token',
    () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      final repository = PatientDiaryRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer token');
            if (request.url.path == '/api/patient/diary') {
              return http.Response(
                jsonEncode({
                  'entries': [
                    {
                      'id': 10,
                      'emotion': 'Ansiedad',
                      'intensity': null,
                      'recorded_at': '2026-09-29T22:10:20+00:00',
                      'preview': 'Resumen',
                    },
                  ],
                }),
                200,
              );
            }
            expect(request.url.path, '/api/patient/diary/10');
            return http.Response(
              jsonEncode({
                'entry': {
                  'id': 10,
                  'emotion': 'Ansiedad',
                  'intensity': 6,
                  'recorded_at': '2026-09-29T22:10:20+00:00',
                  'situation': 'Situación privada',
                  'follow_ups': [
                    {
                      'id': 3,
                      'note': 'Seguimiento privado',
                      'recorded_at': '2026-09-30T12:00:00+00:00',
                    },
                  ],
                },
              }),
              200,
            );
          }),
        ),
      );
      addTearDown(repository.apiClient.close);
      final entries = await repository.getDiaryEntries();
      expect(entries.single.intensity, isNull);
      expect(entries.single.preview, 'Resumen');
      final detail = await repository.getDiaryEntry(10);
      expect(detail.intensity, 6);
      expect(detail.followUps.single.note, 'Seguimiento privado');
    },
  );

  test(
    'create sends only Laravel fields, optional integer and no content in logs',
    () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      final printed = <String>[];
      var posts = 0;
      final repository = PatientDiaryRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            posts++;
            expect(request.url.path, '/api/patient/diary');
            expect(request.method, 'POST');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(
              body.keys.toSet().intersection({'patient_id', 'user_id'}),
              isEmpty,
            );
            expect(body['emocion'], 'Ansiedad');
            expect(body['situacion'], 'Contenido privado');
            if (posts == 1) {
              expect(body.containsKey('intensidad'), isFalse);
            } else {
              expect(body['intensidad'], 10);
              expect(body['intensidad'], isA<int>());
            }
            return http.Response(
              jsonEncode({
                'entry': {
                  'id': posts,
                  'emotion': 'Ansiedad',
                  'intensity': body['intensidad'],
                  'recorded_at': '2026-09-29T22:10:20+00:00',
                },
              }),
              201,
            );
          }),
        ),
      );
      addTearDown(repository.apiClient.close);
      await runZoned(
        () async {
          await repository.createDiaryEntry(
            emotion: 'Ansiedad',
            situation: 'Contenido privado',
          );
          await repository.createDiaryEntry(
            emotion: 'Ansiedad',
            intensity: 10,
            situation: 'Contenido privado',
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );
      expect(posts, 2);
      expect(printed.join(' '), isNot(contains('Contenido privado')));
    },
  );

  test('422 preserves a useful Laravel message', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
    final repository = PatientDiaryRepository(
      apiClient: ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'La intensidad debe estar entre 1 y 10.'}),
            422,
          ),
        ),
      ),
    );
    addTearDown(repository.apiClient.close);
    await expectLater(
      repository.createDiaryEntry(emotion: 'Ansiedad'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'La intensidad debe estar entre 1 y 10.',
        ),
      ),
    );
  });

  test('options use authenticated endpoint and parse API catalog', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
    final repository = PatientDiaryRepository(
      apiClient: ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/patient/diary/options');
          expect(request.headers['Authorization'], 'Bearer token');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'emotions': [
                  {'value': 'Ansiedad', 'emoji': '😰'},
                ],
                'supports_custom_emotion': true,
                'intensity': {'min': 1, 'max': 10, 'optional': true},
                'interpretations': [
                  {
                    'value': 'Catastrofización',
                    'title': 'Pensar que pasará lo peor',
                    'description': 'Descripción',
                    'technical_label': 'Catastrofización',
                  },
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
    addTearDown(repository.apiClient.close);
    final options = await repository.getDiaryOptions();
    expect(options.emotions.single.emoji, '😰');
    expect(options.supportsCustomEmotion, isTrue);
    expect(options.intensityOptional, isTrue);
    expect(options.interpretations.single.value, 'Catastrofización');
  });

  test(
    'custom emotion uses Laravel fields and 422 points to Emotion step',
    () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      var posts = 0;
      final repository = PatientDiaryRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            posts++;
            expect(request.url.path, '/api/patient/diary');
            expect(jsonDecode(request.body), {
              'emocion': 'Otro',
              'emocion_otro': 'Inquietud',
            });
            return http.Response(
              jsonEncode({
                'message': 'The given data was invalid.',
                'errors': {
                  'emocion_otro': ['Inválido'],
                },
              }),
              422,
            );
          }),
        ),
      );
      addTearDown(repository.apiClient.close);
      await expectLater(
        repository.createDiaryEntry(
          emotion: 'Otro',
          customEmotion: ' Inquietud ',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('paso Emoción'),
          ),
        ),
      );
      expect(posts, 1);
    },
  );

  test(
    'follow-up rejects over 2000 characters without a request or logs',
    () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      var requests = 0;
      final printed = <String>[];
      final repository = PatientDiaryRepository(
        apiClient: ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 201);
          }),
        ),
      );
      addTearDown(repository.apiClient.close);
      await runZoned(
        () async {
          await expectLater(
            repository.addFollowUp(
              entryId: 10,
              note: 'sensitive ${'x' * 2001}',
            ),
            throwsA(
              isA<ApiException>().having(
                (error) => error.statusCode,
                'status',
                422,
              ),
            ),
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );
      expect(requests, 0);
      expect(printed.join(), isNot(contains('sensitive')));
    },
  );
}

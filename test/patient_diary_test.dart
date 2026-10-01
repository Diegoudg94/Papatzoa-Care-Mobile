import 'dart:async';
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
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_diary_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/diary/patient_diary_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/diary/patient_diary_detail_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/diary/patient_diary_new_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_dashboard_page.dart';

const summary = {
  'id': 10,
  'emotion': 'Ansiedad',
  'intensity': 6,
  'recorded_at': '2026-09-29T22:10:20+00:00',
  'preview': 'Una reunión importante',
};
const detail = {
  'id': 10,
  'emotion': 'Ansiedad',
  'intensity': 6,
  'recorded_at': '2026-09-29T22:10:20+00:00',
  'situation': 'Tuve una reunión importante',
  'thought': 'Pensé que algo saldría mal',
  'behavior': 'Respiré lentamente',
  'interpretation': 'Anticipé un resultado negativo',
  'restructuring': 'Puedo prepararme sin asumir lo peor',
  'follow_ups': [
    {
      'id': 2,
      'note': 'Me sentí mejor después',
      'recorded_at': '2026-09-30T22:10:20+00:00',
    },
  ],
};
const diaryOptions = {
  'emotions': [
    {'value': 'Ansiedad', 'emoji': '😰'},
    {'value': 'Alegría', 'emoji': '😊'},
  ],
  'supports_custom_emotion': true,
  'intensity': {'min': 1, 'max': 10, 'optional': true},
  'interpretations': [
    {
      'value': 'Catastrofización',
      'title': 'Pensar que pasará lo peor',
      'description': 'Imaginar lo peor.',
      'technical_label': 'Catastrofización',
    },
    {
      'value': 'Lectura de mente',
      'title': 'Creer saber lo que otros piensan',
      'description': 'Dar por hecho lo que piensan.',
      'technical_label': 'Lectura de mente',
    },
  ],
};

Future<void> pumpDiary(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
  final client = ApiClient(
    client: MockClient((request) {
      if (request.url.path == '/api/patient/diary/options') {
        return Future.value(
          http.Response.bytes(
            utf8.encode(jsonEncode(diaryOptions)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        );
      }
      return handler(request);
    }),
  );
  final auth = AuthRepository(apiClient: client);
  addTearDown(auth.close);
  await tester.pumpWidget(
    MaterialApp(
      home: PatientDiaryPage(
        repository: auth,
        diaryRepository: PatientDiaryRepository(apiClient: client),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty history offers a warm create action', (tester) async {
    await pumpDiary(
      tester,
      (_) async => http.Response(jsonEncode({'entries': []}), 200),
    );
    expect(find.text('Aún no tienes registros.'), findsOneWidget);
    expect(
      find.text('Puedes empezar escribiendo cómo te sientes hoy.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Crear registro'));
    await tester.pumpAndSettle();
    expect(find.byType(PatientDiaryNewPage), findsOneWidget);
  });

  testWidgets('network failure keeps Retry and loads history on retry', (
    tester,
  ) async {
    var requests = 0;
    await pumpDiary(tester, (_) async {
      requests++;
      if (requests == 1) throw http.ClientException('offline');
      return http.Response(
        jsonEncode({
          'entries': [summary],
        }),
        200,
      );
    });
    expect(find.text('No pudimos cargar tu diario.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Ansiedad'), findsOneWidget);
  });

  testWidgets('history shows summaries, nullable intensity, and opens detail', (
    tester,
  ) async {
    var detailGets = 0;
    await pumpDiary(tester, (request) async {
      if (request.url.path.endsWith('/10')) {
        detailGets++;
        return http.Response(jsonEncode({'entry': detail}), 200);
      }
      return http.Response(
        jsonEncode({
          'entries': [
            summary,
            {
              'id': 9,
              'emotion': 'Alegría',
              'intensity': null,
              'recorded_at': '2026-09-28T22:10:20+00:00',
              'preview': null,
            },
          ],
        }),
        200,
      );
    });
    expect(find.text('Ansiedad'), findsOneWidget);
    expect(find.text('Intensidad 6/10'), findsOneWidget);
    expect(find.text('Alegría'), findsOneWidget);
    expect(find.text('Una reunión importante'), findsOneWidget);
    expect(find.text('Tuve una reunión importante'), findsNothing);
    await tester.tap(find.text('Ansiedad'));
    await tester.pumpAndSettle();
    expect(detailGets, 1);
    expect(find.byType(PatientDiaryDetailPage), findsOneWidget);
    for (final text in [
      'Tuve una reunión importante',
      'Pensé que algo saldría mal',
      'Respiré lentamente',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
    await tester.pumpAndSettle();
    for (final text in [
      'Anticipé un resultado negativo',
      'Puedo prepararme sin asumir lo peor',
      'Me sentí mejor después',
      'Seguimientos',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.textContaining('2026-09-29T'), findsNothing);
    expect(find.textContaining('de septiembre de 2026'), findsWidgets);
  });

  testWidgets('detail hides empty fields and absent follow-ups', (
    tester,
  ) async {
    await pumpDiary(tester, (request) async {
      if (request.url.path.endsWith('/10')) {
        return http.Response(
          jsonEncode({
            'entry': {
              'id': 10,
              'emotion': 'Ansiedad',
              'intensity': null,
              'recorded_at': '2026-09-29T22:10:20+00:00',
              'situation': 'Una situación',
              'thought': null,
              'follow_ups': [],
            },
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'entries': [summary],
        }),
        200,
      );
    });
    await tester.tap(find.text('Ansiedad'));
    await tester.pumpAndSettle();
    expect(find.text('Una situación'), findsOneWidget);
    expect(find.text('Qué pensé'), findsNothing);
    expect(find.text('Seguimientos'), findsOneWidget);
    expect(find.text('Aún no has añadido seguimientos.'), findsOneWidget);
    expect(find.textContaining('Intensidad'), findsNothing);
  });

  testWidgets('follow-up validates, posts once, and refetches detail', (
    tester,
  ) async {
    var posts = 0;
    var gets = 0;
    final pending = Completer<http.Response>();
    await pumpDiary(tester, (request) async {
      if (request.url.path.endsWith('/follow-ups')) {
        posts++;
        expect(request.url.path, '/api/patient/diary/10/follow-ups');
        expect(jsonDecode(request.body), {'nota': 'Nota privada'});
        return pending.future;
      }
      if (request.url.path.endsWith('/10')) {
        gets++;
        return http.Response(
          jsonEncode({
            'entry': {
              ...detail,
              'follow_ups': gets > 1
                  ? [
                      {
                        'id': 3,
                        'note': 'Nota privada',
                        'recorded_at': '2026-09-29T22:10:20+00:00',
                      },
                    ]
                  : [],
            },
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'entries': [summary],
        }),
        200,
      );
    });
    await tester.tap(find.text('Ansiedad'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Añadir seguimiento'), 200);
    await tester.tap(find.text('Añadir seguimiento'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 2000'), findsOneWidget);
    await tester.tap(find.text('Guardar seguimiento'));
    await tester.pumpAndSettle();
    expect(posts, 0);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Guardar seguimiento'));
    await tester.pumpAndSettle();
    expect(posts, 0);
    await tester.enterText(find.byType(TextField), ' Nota privada ');
    await tester.tap(find.text('Guardar seguimiento'));
    await tester.pump();
    expect(posts, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(
      http.Response(
        jsonEncode({
          'follow_up': {
            'id': 3,
            'note': 'Nota privada',
            'recorded_at': '2026-09-29T22:10:20+00:00',
          },
        }),
        201,
      ),
    );
    await tester.pumpAndSettle();
    expect(gets, 2);
    expect(find.text('Seguimiento guardado'), findsOneWidget);
    expect(find.text('Nota privada'), findsOneWidget);
    expect(find.textContaining('de septiembre de 2026'), findsWidgets);
  });

  testWidgets('follow-up 422 and network error retain text', (tester) async {
    var posts = 0;
    await pumpDiary(tester, (request) async {
      if (request.url.path.endsWith('/follow-ups')) {
        posts++;
        if (posts == 1) return http.Response('{}', 422);
        throw http.ClientException('offline');
      }
      if (request.url.path.endsWith('/10')) {
        return http.Response(jsonEncode({'entry': detail}), 200);
      }
      return http.Response(
        jsonEncode({
          'entries': [summary],
        }),
        200,
      );
    });
    await tester.tap(find.text('Ansiedad'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Añadir seguimiento'), 200);
    await tester.tap(find.text('Añadir seguimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nota sensible');
    await tester.tap(find.text('Guardar seguimiento'));
    await tester.pumpAndSettle();
    expect(
      find.text('Revisa el seguimiento e inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Nota sensible'), findsOneWidget);
    await tester.tap(find.text('Guardar seguimiento'));
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos guardar el seguimiento. Intenta nuevamente.'),
      findsOneWidget,
    );
    expect(find.text('Nota sensible'), findsOneWidget);
  });

  testWidgets('follow-up 404 returns to refreshed history', (tester) async {
    var lists = 0;
    await pumpDiary(tester, (request) async {
      if (request.url.path.endsWith('/follow-ups')) {
        return http.Response('{}', 404);
      }
      if (request.url.path.endsWith('/10')) {
        return http.Response(jsonEncode({'entry': detail}), 200);
      }
      lists++;
      return http.Response(
        jsonEncode({
          'entries': [summary],
        }),
        200,
      );
    });
    await tester.tap(find.text('Ansiedad'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Añadir seguimiento'), 200);
    await tester.tap(find.text('Añadir seguimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nota');
    await tester.tap(find.text('Guardar seguimiento'));
    await tester.pumpAndSettle();
    expect(find.byType(PatientDiaryPage), findsOneWidget);
    expect(find.text('Este registro ya no está disponible.'), findsOneWidget);
    expect(lists, 2);
  });

  testWidgets('dashboard Diario opens the real diary route', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
    final client = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/patient/dashboard')) {
          return http.Response(
            jsonEncode({
              'patient': {'id': 1, 'nombre': 'Ana'},
              'therapist': null,
              'next_appointment': null,
              'between_session_activity': null,
              'emotional_summary': {'total_records': 0, 'records': []},
              'sessions': [],
            }),
            200,
          );
        }
        expect(request.url.path, '/api/patient/diary');
        return http.Response(jsonEncode({'entries': []}), 200);
      }),
    );
    final auth = AuthRepository(apiClient: client);
    addTearDown(auth.close);
    await tester.pumpWidget(
      MaterialApp(
        routes: AppRouter.routesFor(auth),
        home: PatientDashboardPage(
          user: const AuthUser(
            id: 1,
            firstName: 'Ana',
            lastName: '',
            email: 'ana@example.com',
            role: 'patient',
            isTherapist: false,
          ),
          repository: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diario').first);
    await tester.pumpAndSettle();
    expect(find.byType(PatientDiaryPage), findsOneWidget);
  });
}

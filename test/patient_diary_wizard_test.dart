import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_diary_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/diary/patient_diary_new_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/diary/patient_diary_page.dart';

const options = {
  'emotions': [
    {'value': 'Ansiedad', 'emoji': '😰'},
    {'value': 'Alegría', 'emoji': '😊'},
  ],
  'supports_custom_emotion': true,
  'intensity': {'min': 2, 'max': 8, 'optional': true},
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
      'description': 'Suponer pensamientos.',
      'technical_label': 'Lectura de mente',
    },
  ],
};

Future<void> openWizard(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
  final client = ApiClient(client: MockClient(handler));
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
  await tester.tap(find.text('Nuevo registro'));
  await tester.pumpAndSettle();
  expect(find.byType(PatientDiaryNewPage), findsOneWidget);
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.text('Siguiente'));
  await tester.pumpAndSettle();
}

Future<void> goToReview(WidgetTester tester) async {
  for (var step = 1; step < 8; step++) {
    await next(tester);
  }
  expect(find.text('Paso 8 de 8'), findsOneWidget);
}

http.Response fixture(http.Request request) {
  if (request.url.path.endsWith('/options')) {
    return http.Response.bytes(
      utf8.encode(jsonEncode(options)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
  return http.Response(jsonEncode({'entries': []}), 200);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'loads API options, emoji, custom emotion, slider and navigation',
    (tester) async {
      var optionGets = 0;
      await openWizard(tester, (request) async {
        if (request.url.path.endsWith('/options')) optionGets++;
        return fixture(request);
      });
      expect(optionGets, 1);
      expect(find.textContaining('😰'), findsOneWidget);
      expect(find.textContaining('😊'), findsOneWidget);
      expect(find.text('Paso 1 de 8'), findsOneWidget);
      await next(tester);
      expect(find.text('Selecciona una emoción.'), findsOneWidget);
      await tester.tap(find.textContaining('Otro'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cómo describirías lo que sientes?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Inquietud');
      await next(tester);
      expect(find.text('Paso 2 de 8'), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 2);
      expect(slider.max, 8);
      expect(find.text('Sin especificar'), findsOneWidget);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Inquietud'), findsOneWidget);
      await next(tester);
      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('/ 8'), findsOneWidget);
      await tester.tap(find.text('Dejar sin especificar'));
      await tester.pumpAndSettle();
      expect(find.text('Sin especificar'), findsOneWidget);
    },
  );

  testWidgets('help and example preserve situation draft', (tester) async {
    await openWizard(tester, (request) async => fixture(request));
    await tester.tap(find.textContaining('Ansiedad'));
    await next(tester);
    await next(tester);
    expect(find.text('Paso 3 de 8'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Una conversación privada');
    await tester.tap(find.text('¿Necesitas ayuda?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Empieza por lo que ocurrió'), findsOneWidget);
    await tester.tap(find.text('Ver un ejemplo').last);
    await tester.pumpAndSettle();
    expect(find.text('Andrea es un personaje hipotético.'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Una conversación privada',
    );
  });

  testWidgets(
    'review edits steps and POST uses Laravel fields only on Registrar',
    (tester) async {
      var posts = 0, lists = 0;
      Map<String, dynamic>? body;
      await openWizard(tester, (request) async {
        if (request.url.path.endsWith('/options')) return fixture(request);
        if (request.method == 'POST') {
          posts++;
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'entry': {
                'id': 11,
                'emotion': 'Inquietud',
                'recorded_at': '2026-09-29T22:10:20+00:00',
              },
            }),
            201,
          );
        }
        lists++;
        return http.Response(
          jsonEncode({
            'entries': posts == 0
                ? []
                : [
                    {
                      'id': 11,
                      'emotion': 'Inquietud',
                      'recorded_at': '2026-09-29T22:10:20+00:00',
                    },
                  ],
          }),
          200,
        );
      });
      await tester.tap(find.textContaining('Otro'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Inquietud');
      await next(tester); // intensity remains null
      await next(tester);
      await tester.enterText(find.byType(TextField), 'Situación privada');
      await next(tester);
      await tester.enterText(find.byType(TextField), 'Pensamiento privado');
      await next(tester);
      await tester.enterText(find.byType(TextField), 'Conducta privada');
      await next(tester);
      await tester.tap(find.text('Pensar que pasará lo peor'));
      await tester.tap(find.text('Creer saber lo que otros piensan'));
      await next(tester);
      await tester.enterText(
        find.byType(TextField),
        'Otra explicación privada',
      );
      await next(tester);
      expect(posts, 0);
      expect(
        find.text('Este registro será compartido con tu terapeuta.'),
        findsOneWidget,
      );
      expect(find.text('Situación privada'), findsOneWidget);
      await tester.ensureVisible(find.text('Editar').at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar').at(2));
      await tester.pumpAndSettle();
      expect(find.text('Paso 3 de 8'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Situación privada',
      );
      for (var i = 0; i < 5; i++) {
        await next(tester);
      }
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(lists, 2);
      expect(body, {
        'emocion': 'Otro',
        'emocion_otro': 'Inquietud',
        'situacion': 'Situación privada',
        'pensamiento': 'Pensamiento privado',
        'conducta': 'Conducta privada',
        'interpretacion': 'Catastrofización, Lectura de mente',
        'reestructuracion': 'Otra explicación privada',
      });
      expect(find.text('Registro guardado'), findsOneWidget);
      expect(find.text('Inquietud'), findsOneWidget);
    },
  );

  testWidgets('exit confirmation and failed save retain draft', (tester) async {
    var posts = 0;
    await openWizard(tester, (request) async {
      if (request.method == 'POST') {
        posts++;
        return http.Response(jsonEncode({'message': 'Revisa los datos.'}), 422);
      }
      return fixture(request);
    });
    await tester.tap(find.textContaining('Ansiedad'));
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await tester.tap(find.text('Seguir escribiendo'));
    await tester.pumpAndSettle();
    await goToReview(tester);
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(find.text('Revisa los datos.'), findsOneWidget);
    expect(find.text('Paso 8 de 8'), findsOneWidget);
  });

  testWidgets(
    'loading blocks duplicate final submit and network error retains draft',
    (tester) async {
      final pending = Completer<http.Response>();
      var posts = 0;
      await openWizard(tester, (request) async {
        if (request.method == 'POST') {
          posts++;
          return pending.future;
        }
        return fixture(request);
      });
      await tester.tap(find.textContaining('Ansiedad'));
      await goToReview(tester);
      await tester.tap(find.text('Registrar'));
      await tester.pump();
      expect(posts, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.completeError(http.ClientException('offline'));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos guardar tu registro. Intenta nuevamente.'),
        findsOneWidget,
      );
      expect(find.text('Paso 8 de 8'), findsOneWidget);
    },
  );
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/routing/app_router.dart';
import 'package:papatzoa_mobile/core/theme/app_theme.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/auth/presentation/pages/login_page.dart';

import 'auth_test_support.dart';

Future<void> submitLogin(WidgetTester tester, MockClient client) async {
  FlutterSecureStorage.setMockInitialValues({});
  final repository = AuthRepository(apiClient: ApiClient(client: client));
  addTearDown(repository.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      routes: AppRouter.routesFor(repository),
      home: LoginPage(repository: repository),
    ),
  );
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'usuario@example.com',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  for (final role in ['patient', 'therapist', 'unexpected']) {
    testWidgets('Routes by backend role $role only', (tester) async {
      final json = {
        ...loginJson,
        'user': {...loginJson['user'] as Map<String, Object>, 'role': role},
      };
      // The therapist boolean deliberately remains false: only role decides.
      var requests = 0;
      await submitLogin(
        tester,
        MockClient((_) async {
          requests++;
          return http.Response(jsonEncode(json), 200);
        }),
      );
      expect(requests, role == 'patient' ? 3 : 1);
      if (role == 'unexpected') {
        expect(find.byType(LoginPage), findsOneWidget);
        expect(
          find.text('No pudimos identificar el tipo de cuenta.'),
          findsOneWidget,
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
      } else {
        expect(
          find.text(role == 'patient' ? 'Tu espacio' : 'Panel del terapeuta'),
          findsOneWidget,
        );
        expect(find.text('Hola, Ricardo'), findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);
        expect(
          Navigator.of(tester.element(find.text('Hola, Ricardo'))).canPop(),
          isFalse,
        );
      }
    });
  }

  for (final status in [401, 422]) {
    testWidgets('HTTP $status stays in login with a readable error', (
      tester,
    ) async {
      await submitLogin(
        tester,
        MockClient((_) async => http.Response('{}', status)),
      );
      expect(find.byType(LoginPage), findsOneWidget);
      expect(
        find.text(
          status == 401
              ? 'El correo o la contraseña son incorrectos.'
              : 'Revisa tu correo y contraseña e intenta nuevamente.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }

  testWidgets('Network failure stays in login and restores submit', (
    tester,
  ) async {
    await submitLogin(
      tester,
      MockClient((_) async => throw http.ClientException('technical detail')),
    );
    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      find.text('No pudimos conectar con Papatzoa. Intenta nuevamente.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}

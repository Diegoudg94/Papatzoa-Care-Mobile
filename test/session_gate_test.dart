import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/app/app.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/auth/presentation/pages/login_page.dart';

import 'auth_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('No token opens login without a request', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    var requests = 0;
    final repository = AuthRepository(
      apiClient: ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 500);
        }),
      ),
    );
    addTearDown(repository.close);
    await tester.pumpWidget(PapatzoaApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(requests, 0);
  });

  for (final role in ['patient', 'therapist']) {
    testWidgets('Valid $role token restores the dashboard and logs out', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'secret'});
      var logoutRequests = 0;
      final repository = AuthRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer secret');
            if (request.url.path == '/api/me') {
              expect(request.method, 'GET');
              final user = {
                ...loginJson['user'] as Map<String, Object>,
                'role': role,
                'apellido': null,
              };
              return http.Response(jsonEncode({'user': user}), 200);
            }
            expect(request.url.path, '/api/logout');
            expect(request.method, 'POST');
            logoutRequests++;
            return http.Response('{}', 200);
          }),
        ),
      );
      addTearDown(repository.close);
      await tester.pumpWidget(PapatzoaApp(repository: repository));
      expect(find.byType(LoginPage), findsNothing);
      await tester.pumpAndSettle();
      expect(
        find.text(
          role == 'patient' ? 'Dashboard del paciente' : 'Panel del terapeuta',
        ),
        findsOneWidget,
      );
      expect(repository.currentUser?.lastName, '');
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(logoutRequests, 1);
      expect(
        await const FlutterSecureStorage().read(key: 'auth_token'),
        isNull,
      );
      expect(repository.currentUser, isNull);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(LoginPage))).canPop(),
        isFalse,
      );
    });
  }

  testWidgets('401 clears token and opens login', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'expired'});
    final repository = AuthRepository(
      apiClient: ApiClient(
        client: MockClient((_) async => http.Response('{}', 401)),
      ),
    );
    addTearDown(repository.close);
    await tester.pumpWidget(PapatzoaApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(await const FlutterSecureStorage().read(key: 'auth_token'), isNull);
  });

  testWidgets('Network error retains token and offers retry', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'secret'});
    var requests = 0;
    final repository = AuthRepository(
      apiClient: ApiClient(
        client: MockClient((_) async {
          requests++;
          if (requests == 1) throw http.ClientException('offline');
          return http.Response(jsonEncode({'user': loginJson['user']}), 200);
        }),
      ),
    );
    addTearDown(repository.close);
    await tester.pumpWidget(PapatzoaApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos conectar con Papatzoa.'), findsOneWidget);
    expect(
      await const FlutterSecureStorage().read(key: 'auth_token'),
      'secret',
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard del paciente'), findsOneWidget);
  });

  testWidgets('Offline logout still clears local session', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'secret'});
    final repository = AuthRepository(
      apiClient: ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/api/logout') {
            throw http.ClientException('offline');
          }
          return http.Response(jsonEncode({'user': loginJson['user']}), 200);
        }),
      ),
    );
    addTearDown(repository.close);
    await tester.pumpWidget(PapatzoaApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(await const FlutterSecureStorage().read(key: 'auth_token'), isNull);
  });
}

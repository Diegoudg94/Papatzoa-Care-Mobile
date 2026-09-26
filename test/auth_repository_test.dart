import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/network/api_exceptions.dart';
import 'package:papatzoa_mobile/features/auth/data/models/auth_result.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';

import 'auth_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Parses the confirmed login and user contract', () {
    final result = AuthResult.fromJson(loginJson);
    expect(result.user.id, 32);
    expect(result.user.firstName, 'Ricardo');
    expect(result.user.lastName, 'Cortez');
    expect(result.user.email, 'usuario@example.com');
    expect(result.user.isTherapist, isFalse);
    expect(result.user.role, 'patient');
    expect(result.message, 'Inicio de sesión correcto.');
  });

  test(
    '200 stores the token and retains user after the confirmed POST',
    () async {
      final repository = AuthRepository(
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/login');
            expect(request.headers['Accept'], 'application/json');
            expect(jsonDecode(request.body), {
              'email': 'usuario@example.com',
              'password': 'test-password',
            });
            return http.Response(jsonEncode(loginJson), 200);
          }),
        ),
      );
      addTearDown(repository.close);
      await repository.login(
        email: 'usuario@example.com',
        password: 'test-password',
      );
      expect(
        await const FlutterSecureStorage().read(key: 'auth_token'),
        loginJson['token'],
      );
      expect(repository.currentUser?.id, 32);
    },
  );

  for (final status in [401, 422, 500]) {
    test('$status returns a safe error and saves no session', () async {
      final repository = AuthRepository(
        apiClient: ApiClient(
          client: MockClient(
            (_) async =>
                http.Response('{"message":"technical detail"}', status),
          ),
        ),
      );
      addTearDown(repository.close);
      await expectLater(
        repository.login(email: 'test@example.com', password: 'test-password'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            status,
          ),
        ),
      );
      expect(repository.currentUser, isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'auth_token'),
        isNull,
      );
    });
  }

  test('Network failure returns a safe message', () async {
    final repository = AuthRepository(
      apiClient: ApiClient(
        client: MockClient(
          (_) async => throw http.ClientException('internal URL'),
        ),
      ),
    );
    addTearDown(repository.close);
    await expectLater(
      repository.login(email: 'test@example.com', password: 'test-password'),
      throwsA(
        isA<NetworkException>().having(
          (error) => error.message,
          'message',
          'No pudimos conectar con Papatzoa. Intenta nuevamente.',
        ),
      ),
    );
  });
}

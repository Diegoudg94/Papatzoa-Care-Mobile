import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/network/api_exceptions.dart';
import 'package:papatzoa_mobile/core/routing/app_router.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/auth/data/services/google_sign_in_service.dart';
import 'package:papatzoa_mobile/features/auth/presentation/pages/login_page.dart';

import 'auth_test_support.dart';

class FakeGoogleSignIn extends GoogleSignInService {
  FakeGoogleSignIn(this.result);
  final Future<String?> result;
  int calls = 0;

  @override
  Future<String?> signIn() {
    calls++;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  AuthRepository repositoryFor(http.Client client) {
    final repository = AuthRepository(apiClient: ApiClient(client: client));
    addTearDown(repository.close);
    return repository;
  }

  test(
    'Google 200 posts only id_token, parses and saves Sanctum session',
    () async {
      final json = {
        ...loginJson,
        'message': 'Inicio de sesión con Google correcto.',
        'user': {
          ...loginJson['user'] as Map<String, Object>,
          'avatar_url': 'https://example.test/google.jpg',
        },
      };
      final repository = repositoryFor(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/login/google');
          expect(jsonDecode(request.body), {
            'id_token': 'test-google-id-token',
          });
          return http.Response(jsonEncode(json), 200);
        }),
      );
      final result = await repository.loginWithGoogle(
        idToken: 'test-google-id-token',
      );
      expect(result.message, json['message']);
      expect(result.user.id, 32);
      expect(result.user.email, 'usuario@example.com');
      expect(result.user.role, 'patient');
      expect(result.user.avatarUrl, 'https://example.test/google.jpg');
      expect(repository.currentUser, result.user);
      expect(await const FlutterSecureStorage().readAll(), {
        'auth_token': loginJson['token'],
      });
    },
  );

  const messages = {
    401: 'No pudimos validar tu cuenta de Google.',
    404: 'No encontramos una cuenta de Papatzoa asociada a este correo.',
    409: 'Esta cuenta ya está vinculada con otra identidad de Google.',
    503: 'No pudimos conectar con Papatzoa. Intenta nuevamente.',
  };
  for (final entry in messages.entries) {
    test(
      'Google ${entry.key} returns safe message without saving session',
      () async {
        final repository = repositoryFor(
          MockClient(
            (_) async =>
                http.Response('{"message":"technical detail"}', entry.key),
          ),
        );
        await expectLater(
          repository.loginWithGoogle(idToken: 'test-google-id-token'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', entry.key)
                .having((e) => e.message, 'message', entry.value),
          ),
        );
        expect(repository.currentUser, isNull);
        expect(await const FlutterSecureStorage().readAll(), isEmpty);
      },
    );
  }

  test('Google network failure returns safe message', () async {
    final repository = repositoryFor(
      MockClient((_) async => throw http.ClientException('technical detail')),
    );
    await expectLater(
      repository.loginWithGoogle(idToken: 'test-google-id-token'),
      throwsA(
        isA<NetworkException>().having(
          (e) => e.message,
          'message',
          messages[503],
        ),
      ),
    );
  });

  Future<void> showLogin(
    WidgetTester tester,
    AuthRepository repository,
    FakeGoogleSignIn google,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: AppRouter.routes,
        home: LoginPage(repository: repository, googleSignInService: google),
      ),
    );
    await tester.ensureVisible(find.text('Continuar con Google'));
    await tester.tap(find.text('Continuar con Google'));
  }

  testWidgets('Google button is reachable and tappable after vertical drag', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = repositoryFor(
      MockClient((_) async => http.Response('{}', 401)),
    );
    final google = FakeGoogleSignIn(Future.value(null));
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(repository: repository, googleSignInService: google),
      ),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continuar con Google'), findsOneWidget);
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();
    expect(google.calls, 1);
    expect(tester.takeException(), isNull);
  });

  for (final role in ['patient', 'therapist']) {
    testWidgets('Google navigates to $role from backend role', (tester) async {
      final repository = repositoryFor(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              ...loginJson,
              'user': {
                ...loginJson['user'] as Map<String, Object>,
                'role': role,
              },
            }),
            200,
          ),
        ),
      );
      await showLogin(
        tester,
        repository,
        FakeGoogleSignIn(Future.value('test-google-id-token')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsNothing);
      expect(
        find.text(role == 'patient' ? 'Tu espacio' : 'Panel del terapeuta'),
        findsOneWidget,
      );
      expect(
        Navigator.of(tester.element(find.text('Hola, Ricardo'))).canPop(),
        isFalse,
      );
    });
  }

  testWidgets('Cancel restores both buttons and prevents concurrent login', (
    tester,
  ) async {
    var requests = 0;
    final repository = repositoryFor(
      MockClient((_) async {
        requests++;
        return http.Response(jsonEncode(loginJson), 200);
      }),
    );
    final completer = Completer<String?>();
    final google = FakeGoogleSignIn(completer.future);
    await showLogin(tester, repository, google);
    await tester.pump();
    final button = find.widgetWithText(OutlinedButton, 'Continuar con Google');
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(google.calls, 1);
    completer.complete(null);
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}

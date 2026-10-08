import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/app/app.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_account_page.dart';

import 'auth_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == label,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  AuthRepository restoredRepository(String? avatarUrl) {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'secret'});
    final repository = AuthRepository(
      apiClient: ApiClient(
        client: MockClient((request) async {
          switch (request.url.path) {
            case '/api/me':
              return http.Response(
                jsonEncode({
                  'user': {
                    ...loginJson['user'] as Map<String, Object>,
                    'avatar_url': avatarUrl,
                  },
                }),
                200,
              );
            case '/api/patient/dashboard':
              return http.Response(
                jsonEncode({
                  'patient': {
                    'id': 32,
                    'nombre': 'Ricardo',
                    'apellido': 'Cortez',
                  },
                  'therapist': null,
                  'next_appointment': null,
                  'between_session_activity': null,
                  'emotional_summary': {'total_records': 0, 'records': []},
                  'sessions': [],
                }),
                200,
              );
            case '/api/patient/diary':
              return http.Response('{"entries":[]}', 200);
            default:
              return http.Response('{}', 500);
          }
        }),
      ),
    );
    addTearDown(repository.close);
    return repository;
  }

  testWidgets(
    'restored session navigates repeatedly without a route user argument',
    (tester) async {
      final repository = restoredRepository(null);
      await tester.pumpWidget(PapatzoaApp(repository: repository));
      await tester.pumpAndSettle();
      await tapTab(tester, 'Mi cuenta');
      expect(find.byType(PatientAccountPage), findsOneWidget);
      await tapTab(tester, 'Diario');
      await tapTab(tester, 'Mi cuenta');
      await tapTab(tester, 'Mis sesiones');
      await tapTab(tester, 'Mi cuenta');
      await tapTab(tester, 'Inicio');
      expect(find.text('Tu espacio'), findsOneWidget);
    },
  );

  for (final avatarUrl in <String?>[
    'https://example.test/google.jpg',
    null,
    'https://invalid.invalid/missing.jpg',
  ]) {
    testWidgets('account avatar uses session URL or initials: $avatarUrl', (
      tester,
    ) async {
      final repository = restoredRepository(avatarUrl);
      await tester.pumpWidget(PapatzoaApp(repository: repository));
      await tester.pumpAndSettle();
      await tapTab(tester, 'Mi cuenta');
      final avatar = tester.widget<CircleAvatar>(
        find.byWidgetPredicate(
          (widget) => widget is CircleAvatar && widget.radius == 42,
        ),
      );
      expect(
        avatar.foregroundImage,
        avatarUrl == null
            ? isNull
            : isA<NetworkImage>().having(
                (image) => image.url,
                'url',
                avatarUrl,
              ),
      );
      expect(avatar.child, isA<Text>());
      expect((avatar.child! as Text).data, 'RC');
      expect(tester.takeException(), isNull);
    });
  }
}

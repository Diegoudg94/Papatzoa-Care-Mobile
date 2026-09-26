import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';

const loginJson = {
  'message': 'Inicio de sesión correcto.',
  'token': 'test-only-token',
  'user': {
    'id': 32,
    'nombre': 'Ricardo',
    'apellido': 'Cortez',
    'correo': 'usuario@example.com',
    'terapeuta': false,
    'role': 'patient',
  },
};

AuthRepository testRepository() {
  FlutterSecureStorage.setMockInitialValues({});
  return AuthRepository(
    apiClient: ApiClient(
      client: MockClient(
        (_) async => http.Response(jsonEncode(loginJson), 200),
      ),
    ),
  );
}

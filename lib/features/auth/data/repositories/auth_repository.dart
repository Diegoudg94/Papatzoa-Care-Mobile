import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exceptions.dart';
import '../models/auth_result.dart';
import '../models/auth_user.dart';

class AuthRepository {
  AuthRepository({ApiClient? apiClient, FlutterSecureStorage? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? const FlutterSecureStorage();

  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;
  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        'login',
        body: {'email': email, 'password': password},
      );
      final result = AuthResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      await _storage.write(key: 'auth_token', value: result.token);
      _currentUser = result.user;
      return result;
    } on NetworkException {
      throw const NetworkException(
        'No pudimos conectar con Papatzoa. Intenta nuevamente.',
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        throw const ApiException(
          'El correo o la contraseña son incorrectos.',
          statusCode: 401,
        );
      }
      if (error.statusCode == 422) {
        throw const ApiException(
          'Revisa tu correo y contraseña e intenta nuevamente.',
          statusCode: 422,
        );
      }
      rethrow;
    } catch (_) {
      throw const ApiException(
        'No pudimos iniciar sesión. Intenta nuevamente.',
      );
    }
  }

  void close() => _apiClient.close();
}

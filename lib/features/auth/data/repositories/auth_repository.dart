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
  ApiClient get apiClient => _apiClient;
  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;

  Future<void> invalidateSession() async {
    try {
      await _storage.delete(key: 'auth_token');
    } finally {
      _currentUser = null;
    }
  }

  Future<AuthUser?> restoreSession() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) return null;
    try {
      final response = await _apiClient.get('me', token: token);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
      _currentUser = user;
      return user;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _storage.delete(key: 'auth_token');
        _currentUser = null;
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null && token.isNotEmpty) {
        await _apiClient.post('logout', token: token);
      }
    } on NetworkException catch (_) {
      // The local session must end even when the server is unavailable.
    } on ApiException catch (_) {
      // An expired server token still needs local cleanup.
    } finally {
      await _storage.delete(key: 'auth_token');
      _currentUser = null;
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        'login',
        body: {'email': email, 'password': password},
      );
      return await _saveSession(response.body);
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

  Future<AuthResult> loginWithGoogle({required String idToken}) async {
    try {
      final response = await _apiClient.post(
        'login/google',
        body: {'id_token': idToken},
      );
      return await _saveSession(response.body);
    } on NetworkException {
      throw const NetworkException(
        'No pudimos conectar con Papatzoa. Intenta nuevamente.',
      );
    } on ApiException catch (error) {
      final message = switch (error.statusCode) {
        401 => 'No pudimos validar tu cuenta de Google.',
        404 => 'No encontramos una cuenta de Papatzoa asociada a este correo.',
        409 => 'Esta cuenta ya está vinculada con otra identidad de Google.',
        _ => 'No pudimos conectar con Papatzoa. Intenta nuevamente.',
      };
      throw ApiException(message, statusCode: error.statusCode);
    } catch (_) {
      throw const ApiException(
        'No pudimos iniciar sesión. Intenta nuevamente.',
      );
    }
  }

  Future<AuthResult> _saveSession(String body) async {
    final result = AuthResult.fromJson(
      jsonDecode(body) as Map<String, dynamic>,
    );
    await _storage.write(key: 'auth_token', value: result.token);
    _currentUser = result.user;
    return result;
  }

  void close() => _apiClient.close();
}

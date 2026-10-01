import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exceptions.dart';
import '../models/support_network_contact.dart';
import '../models/support_network_options.dart';

class PatientSupportNetworkRepository {
  PatientSupportNetworkRepository({
    required this.apiClient,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final ApiClient apiClient;
  final FlutterSecureStorage _storage;

  Future<String> _token() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'La sesión ya no está disponible.',
        statusCode: 401,
      );
    }
    return token;
  }

  Future<List<SupportNetworkContact>> getContacts() async {
    final token = await _token();
    try {
      final response = await apiClient.get(
        'patient/support-network',
        token: token,
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['contacts'] as List<dynamic>)
          .map(
            (item) =>
                SupportNetworkContact.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } on NetworkException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No pudimos cargar tu red de apoyo.');
    }
  }

  Future<SupportNetworkOptions> getOptions() async {
    final token = await _token();
    try {
      final response = await apiClient.get(
        'patient/support-network/options',
        token: token,
      );
      return SupportNetworkOptions.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on NetworkException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No pudimos cargar las opciones de apoyo.');
    }
  }

  Future<SupportNetworkContact> createContact(SupportNetworkDraft draft) async {
    final token = await _token();
    try {
      final response = await apiClient.post(
        'patient/support-network',
        token: token,
        body: draft.toRequestBody(),
      );
      if (response.statusCode != 201) {
        throw const FormatException('Unexpected support network response');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SupportNetworkContact.fromJson(
        json['contact'] as Map<String, dynamic>,
      );
    } on NetworkException {
      rethrow;
    } on ApiException catch (error) {
      throw _friendly(error);
    } catch (_) {
      throw const ApiException(
        'No pudimos guardar los cambios. Intenta nuevamente.',
      );
    }
  }

  Future<SupportNetworkContact> updateContact(
    int id,
    SupportNetworkDraft draft,
  ) async {
    final token = await _token();
    try {
      final response = await apiClient.put(
        'patient/support-network/$id',
        token: token,
        body: draft.toRequestBody(),
      );
      if (response.statusCode != 200) {
        throw const FormatException('Unexpected support network response');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SupportNetworkContact.fromJson(
        json['contact'] as Map<String, dynamic>,
      );
    } on NetworkException {
      rethrow;
    } on ApiException catch (error) {
      throw _friendly(error);
    } catch (_) {
      throw const ApiException(
        'No pudimos guardar los cambios. Intenta nuevamente.',
      );
    }
  }

  Future<void> deleteContact(int id) async {
    final token = await _token();
    try {
      final response = await apiClient.delete(
        'patient/support-network/$id',
        token: token,
      );
      if (response.statusCode != 204) {
        throw const FormatException('Unexpected support network response');
      }
    } on NetworkException {
      rethrow;
    } on ApiException catch (error) {
      throw _friendly(error);
    } catch (_) {
      throw const ApiException(
        'No pudimos eliminar este contacto. Intenta nuevamente.',
      );
    }
  }

  ApiException _friendly(ApiException error) {
    if (error.statusCode != 422) return error;
    try {
      final json = jsonDecode(error.responseBody ?? '') as Map<String, dynamic>;
      final errors = json['errors'] as Map<String, dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        final key = errors.keys.first.split('.').first;
        final message = switch (key) {
          'nombre' =>
            'Revisa el nombre. Es obligatorio y admite hasta 120 caracteres.',
          'relacion' =>
            'Revisa la relación. Es obligatoria y admite hasta 100 caracteres.',
          'nivel_confianza' => 'Selecciona un nivel de confianza válido.',
          'tipos_apoyo' =>
            'Selecciona entre uno y seis tipos de apoyo válidos.',
          'tipo_apoyo_otro' => 'Describe qué tipo de apoyo puede darte.',
          'telefono_lada' => 'Ingresa una lada válida.',
          'telefono' => 'Ingresa un teléfono válido.',
          'nota' => 'La nota debe tener hasta 1000 caracteres.',
          _ => 'Revisa los datos de esta persona e inténtalo de nuevo.',
        };
        return ApiException(message, statusCode: 422);
      }
    } catch (_) {}
    return const ApiException(
      'Revisa los datos de esta persona e inténtalo de nuevo.',
      statusCode: 422,
    );
  }
}

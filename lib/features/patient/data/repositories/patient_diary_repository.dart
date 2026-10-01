import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exceptions.dart';
import '../models/diary_entry.dart';
import '../models/diary_options.dart';

class PatientDiaryRepository {
  PatientDiaryRepository({
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

  Future<List<DiaryEntry>> getDiaryEntries() async {
    final token = await _token();
    try {
      final response = await apiClient.get('patient/diary', token: token);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['entries'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(DiaryEntry.fromJson)
          .toList(growable: false);
    } on NetworkException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No pudimos cargar tu diario.');
    }
  }

  Future<DiaryOptions> getDiaryOptions() async {
    final token = await _token();
    try {
      final response = await apiClient.get(
        'patient/diary/options',
        token: token,
      );
      return DiaryOptions.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on NetworkException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No pudimos cargar las opciones del diario.');
    }
  }

  Future<DiaryEntry> getDiaryEntry(int id) async {
    final token = await _token();
    try {
      final response = await apiClient.get('patient/diary/$id', token: token);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DiaryEntry.fromJson(json['entry'] as Map<String, dynamic>);
    } on NetworkException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No pudimos cargar este registro.');
    }
  }

  Future<DiaryFollowUp> addFollowUp({
    required int entryId,
    required String note,
  }) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty || trimmed.length > 2000) {
      throw const ApiException(
        'Escribe un seguimiento de hasta 2000 caracteres.',
        statusCode: 422,
      );
    }
    final token = await _token();
    try {
      final response = await apiClient.post(
        'patient/diary/$entryId/follow-ups',
        token: token,
        body: {'nota': trimmed},
      );
      if (response.statusCode != 201) {
        throw const FormatException('Unexpected follow-up response');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DiaryFollowUp.fromJson(json['follow_up'] as Map<String, dynamic>);
    } on NetworkException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 422) {
        throw const ApiException(
          'Revisa el seguimiento e inténtalo de nuevo.',
          statusCode: 422,
        );
      }
      rethrow;
    } catch (_) {
      throw const ApiException(
        'No pudimos guardar el seguimiento. Intenta nuevamente.',
      );
    }
  }

  Future<DiaryEntry> createDiaryEntry({
    required String emotion,
    String? customEmotion,
    int? intensity,
    String? situation,
    String? thought,
    String? behavior,
    String? interpretation,
    String? restructuring,
  }) async {
    if (emotion == 'Otro' &&
        (customEmotion == null ||
            customEmotion.trim().isEmpty ||
            customEmotion.trim().length > 100)) {
      throw ArgumentError.value(
        null,
        'customEmotion',
        'Escribe una emoción de hasta 100 caracteres.',
      );
    }
    if (emotion.trim().isEmpty) {
      throw ArgumentError.value(emotion, 'emotion', 'Selecciona una emoción.');
    }
    if (intensity != null && (intensity < 1 || intensity > 10)) {
      throw ArgumentError.value(
        intensity,
        'intensity',
        'La intensidad debe estar entre 1 y 10.',
      );
    }
    final token = await _token();
    final body = <String, Object>{'emocion': emotion};
    if (emotion == 'Otro') body['emocion_otro'] = customEmotion!.trim();
    if (intensity != null) body['intensidad'] = intensity;
    void addText(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) body[key] = value.trim();
    }

    addText('situacion', situation);
    addText('pensamiento', thought);
    addText('conducta', behavior);
    addText('interpretacion', interpretation);
    addText('reestructuracion', restructuring);
    try {
      final response = await apiClient.post(
        'patient/diary',
        token: token,
        body: body,
      );
      if (response.statusCode != 201) {
        throw const FormatException('Unexpected diary response');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DiaryEntry.fromJson(json['entry'] as Map<String, dynamic>);
    } on NetworkException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 422) {
        String? message;
        bool customEmotionInvalid = false;
        try {
          final payload =
              jsonDecode(error.responseBody ?? '') as Map<String, dynamic>;
          message = payload['message'] as String?;
          customEmotionInvalid =
              (payload['errors'] as Map<String, dynamic>?)?.containsKey(
                'emocion_otro',
              ) ==
              true;
        } catch (_) {}
        throw ApiException(
          customEmotionInvalid
              ? 'Revisa la emoción personalizada en el paso Emoción.'
              : message?.trim().isNotEmpty == true &&
                    message != 'The given data was invalid.'
              ? message!
              : 'Revisa la emoción y la intensidad e inténtalo de nuevo.',
          statusCode: 422,
        );
      }
      rethrow;
    } catch (_) {
      throw const ApiException(
        'No pudimos guardar tu registro. Intenta nuevamente.',
      );
    }
  }
}

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exceptions.dart';
import '../models/patient_appointments_data.dart';
import '../models/patient_appointment.dart';
import '../models/appointment_availability.dart';

class PatientAppointmentsRepository {
  PatientAppointmentsRepository({
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

  Future<AppointmentAvailability> getAvailability(
    DateTime from,
    DateTime to,
  ) async {
    if (to.difference(from).inDays > 30 || to.isBefore(from)) {
      throw ArgumentError('El rango debe ser de 31 días como máximo.');
    }
    final token = await _token();
    final query = Uri(queryParameters: {'from': _date(from), 'to': _date(to)})
        .query;
    try {
      final response = await apiClient.get(
        'patient/appointments/availability?$query',
        token: token,
      );
      return AppointmentAvailability.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on NetworkException {
      rethrow;
    } on ApiException catch (error) {
      throw _friendlyError(error, 'No pudimos consultar los horarios.');
    } catch (_) {
      throw const ApiException('No pudimos consultar los horarios.');
    }
  }

  Future<CreatedAppointment> createAppointment({
    required AvailabilitySlot slot,
    required String motivo,
    required String modalidad,
  }) async {
    if (slot.start == null || slot.end == null) {
      throw ArgumentError('Selecciona un horario válido.');
    }
    final token = await _token();
    try {
      final response = await apiClient.post(
        'patient/appointments',
        token: token,
        body: {
          'start': slot.start,
          'end': slot.end,
          'motivo': motivo,
          'modalidad': modalidad,
        },
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return CreatedAppointment.fromJson(
        json['appointment'] as Map<String, dynamic>,
      );
    } on NetworkException {
      rethrow;
    } on ApiException catch (error) {
      throw _friendlyError(error, 'No pudimos solicitar la cita.');
    } catch (_) {
      throw const ApiException('No pudimos solicitar la cita.');
    }
  }

  ApiException _friendlyError(ApiException error, String fallback) {
    if (error.statusCode == 401) {
      return const ApiException(
        'Tu sesión terminó. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }
    if (error.statusCode == 403) {
      return const ApiException(
        'No tienes permiso para solicitar una cita.',
        statusCode: 403,
      );
    }
    if (error.statusCode == 409) {
      return const ApiException(
        'Ese horario acaba de dejar de estar disponible.',
        statusCode: 409,
      );
    }
    if (error.statusCode == 422) {
      String? message;
      try {
        message =
            (jsonDecode(error.responseBody ?? '')
                    as Map<String, dynamic>)['message']
                as String?;
      } catch (_) {}
      return ApiException(
        message?.trim().isNotEmpty == true
            ? message!
            : 'Revisa los datos de la cita e inténtalo de nuevo.',
        statusCode: 422,
      );
    }
    return ApiException(fallback, statusCode: error.statusCode);
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<PatientAppointmentsData> loadAppointments() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'La sesión ya no está disponible.',
        statusCode: 401,
      );
    }

    try {
      final response = await apiClient.get(
        'patient/appointments',
        token: token,
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PatientAppointmentsData.fromJson(json);
    } on NetworkException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No pudimos cargar tus citas.');
    }
  }

  Future<PatientAppointment> getAppointment(int id) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'La sesión ya no está disponible.',
        statusCode: 401,
      );
    }

    try {
      final response = await apiClient.get(
        'patient/appointments/$id',
        token: token,
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final appointment = json['appointment'] as Map<String, dynamic>;
      return PatientAppointment.fromJson(appointment);
    } on NetworkException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No pudimos cargar esta cita.');
    }
  }

  Future<CreatedAppointment> rescheduleAppointment({
    required int appointmentId,
    required String start,
    required String end,
  }) async {
    final token = await _token();
    try {
      final response = await apiClient.post(
        'patient/appointments/$appointmentId/reschedule',
        token: token,
        body: {'start': start, 'end': end},
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final created = CreatedAppointment.fromJson(
        json['appointment'] as Map<String, dynamic>,
      );
      if (response.statusCode != 201 ||
          created.id == null ||
          created.id == appointmentId ||
          (created.status != 'pendiente' && created.status != 'confirmada')) {
        throw const FormatException('Unexpected reschedule response');
      }
      return created;
    } on NetworkException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        throw const ApiException(
          'Esta cita ya no está disponible.',
          statusCode: 404,
        );
      }
      if (error.statusCode == 403) {
        throw const ApiException(
          'No tienes permiso para reagendar esta cita.',
          statusCode: 403,
        );
      }
      throw _friendlyError(
        error,
        'No pudimos reagendar la cita. Intenta nuevamente.',
      );
    } catch (_) {
      throw const ApiException(
        'No pudimos reagendar la cita. Intenta nuevamente.',
      );
    }
  }

  Future<CreatedAppointment> acceptRescheduleProposal({
    required int appointmentId,
  }) async {
    final token = await _token();
    try {
      final response = await apiClient.post(
        'patient/appointments/$appointmentId/reschedule-proposal/accept',
        token: token,
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final appointment = json['appointment'] as Map<String, dynamic>;
      final created = CreatedAppointment.fromJson(appointment);
      if (response.statusCode != 201 ||
          created.id == null ||
          created.id == appointmentId ||
          (appointment['previous_appointment_id'] as num?)?.toInt() !=
              appointmentId) {
        throw const FormatException('Unexpected acceptance response');
      }
      return created;
    } on NetworkException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        throw const ApiException(
          'Esta cita ya no está disponible.',
          statusCode: 404,
        );
      }
      if (error.statusCode == 409) {
        throw const ApiException(
          'Ese horario ya no está disponible.',
          statusCode: 409,
        );
      }
      if (error.statusCode == 403) {
        throw const ApiException(
          'No tienes permiso para aceptar este horario.',
          statusCode: 403,
        );
      }
      throw _friendlyError(
        error,
        'No pudimos aceptar el nuevo horario. Intenta nuevamente.',
      );
    } catch (_) {
      throw const ApiException(
        'No pudimos aceptar el nuevo horario. Intenta nuevamente.',
      );
    }
  }

  Future<String> cancelAppointment({
    required int appointmentId,
    String? reason,
  }) async {
    final token = await _token();
    final trimmedReason = reason?.trim();
    try {
      final response = await apiClient.post(
        'patient/appointments/$appointmentId/cancel',
        token: token,
        body: trimmedReason == null || trimmedReason.isEmpty
            ? null
            : {'reason': trimmedReason},
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final appointment = json['appointment'] as Map<String, dynamic>;
      if (appointment['id'] != appointmentId ||
          appointment['status'] != 'cancelada') {
        throw const FormatException('Unexpected cancellation response');
      }
      return json['message'] as String? ?? 'Tu cita fue cancelada.';
    } on NetworkException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 422) {
        String? message;
        try {
          message =
              (jsonDecode(error.responseBody ?? '')
                      as Map<String, dynamic>)['message']
                  as String?;
        } catch (_) {}
        throw ApiException(
          message?.trim().isNotEmpty == true
              ? message!
              : 'Esta cita ya no puede cancelarse.',
          statusCode: 422,
        );
      }
      rethrow;
    } catch (_) {
      throw const ApiException(
        'No pudimos cancelar la cita. Intenta nuevamente.',
      );
    }
  }
}

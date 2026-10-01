import 'patient_appointment.dart';

class AvailabilitySlot {
  const AvailabilitySlot({this.start, this.end});

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) =>
      AvailabilitySlot(
        start: json['start'] as String?,
        end: json['end'] as String?,
      );

  final String? start;
  final String? end;
}

class AppointmentAvailability {
  const AppointmentAvailability({
    this.therapist,
    this.timezone,
    this.sessionDurationMinutes,
    required this.availableModalities,
    required this.slots,
  });

  factory AppointmentAvailability.fromJson(Map<String, dynamic> json) =>
      AppointmentAvailability(
        therapist: json['therapist'] is Map<String, dynamic>
            ? PatientAppointmentTherapist.fromJson(
                json['therapist'] as Map<String, dynamic>,
              )
            : null,
        timezone: json['timezone'] as String?,
        sessionDurationMinutes: (json['session_duration_minutes'] as num?)
            ?.toInt(),
        availableModalities:
            (json['available_modalities'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            [],
        slots:
            (json['slots'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(AvailabilitySlot.fromJson)
                .toList() ??
            [],
      );

  final PatientAppointmentTherapist? therapist;
  final String? timezone;
  final int? sessionDurationMinutes;
  final List<String> availableModalities;
  final List<AvailabilitySlot> slots;
}

class CreatedAppointment {
  const CreatedAppointment({
    this.id,
    this.start,
    this.end,
    this.timezone,
    this.status,
    this.modality,
    this.therapist,
  });

  factory CreatedAppointment.fromJson(Map<String, dynamic> json) =>
      CreatedAppointment(
        id: (json['id'] as num?)?.toInt(),
        start: json['start'] as String?,
        end: json['end'] as String?,
        timezone: json['timezone'] as String?,
        status: json['status'] as String?,
        modality: json['modality'] as String?,
        therapist: json['therapist'] is Map<String, dynamic>
            ? PatientAppointmentTherapist.fromJson(
                json['therapist'] as Map<String, dynamic>,
              )
            : null,
      );

  final int? id;
  final String? start;
  final String? end;
  final String? timezone;
  final String? status;
  final String? modality;
  final PatientAppointmentTherapist? therapist;
}

class PatientAppointment {
  const PatientAppointment({
    this.id,
    this.date,
    this.time,
    this.status,
    this.modality,
    this.therapist,
    this.rescheduleProposal,
    this.reason,
  });

  factory PatientAppointment.fromJson(Map<String, dynamic> json) =>
      PatientAppointment(
        id: _int(json['id']),
        date: json['date'] as String?,
        time: json['time'] as String?,
        status: json['status'] as String?,
        modality: json['modality'] as String?,
        therapist: json['therapist'] is Map<String, dynamic>
            ? PatientAppointmentTherapist.fromJson(
                json['therapist'] as Map<String, dynamic>,
              )
            : null,
        rescheduleProposal: json['reschedule_proposal'] is Map<String, dynamic>
            ? PatientRescheduleProposal.fromJson(
                json['reschedule_proposal'] as Map<String, dynamic>,
              )
            : null,
        reason: json['reason'] as String?,
      );

  final int? id;
  final String? date;
  final String? time;
  final String? status;
  final String? modality;
  final PatientAppointmentTherapist? therapist;
  final PatientRescheduleProposal? rescheduleProposal;
  final String? reason;
}

class PatientAppointmentTherapist {
  const PatientAppointmentTherapist({
    this.id,
    this.nombre,
    this.apellido,
    this.especialidad,
    this.profilePhoto,
  });

  factory PatientAppointmentTherapist.fromJson(Map<String, dynamic> json) =>
      PatientAppointmentTherapist(
        id: _int(json['id']),
        nombre: json['nombre'] as String?,
        apellido: json['apellido'] as String?,
        especialidad: json['especialidad'] as String?,
        profilePhoto: json['profile_photo'] as String?,
      );

  final int? id;
  final String? nombre;
  final String? apellido;
  final String? especialidad;
  final String? profilePhoto;

  String get displayName => [nombre, apellido]
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(' ');
}

class PatientRescheduleProposal {
  const PatientRescheduleProposal({
    this.status,
    this.proposedDate,
    this.proposedEnd,
    this.timezone,
  });

  factory PatientRescheduleProposal.fromJson(Map<String, dynamic> json) =>
      PatientRescheduleProposal(
        status: json['status'] as String?,
        proposedDate: json['proposed_date'] as String?,
        proposedEnd: json['proposed_end'] as String?,
        timezone: json['timezone'] as String?,
      );

  final String? status;
  final String? proposedDate;
  final String? proposedEnd;
  final String? timezone;
}

int? _int(Object? value) => value is num ? value.toInt() : null;

class PatientDashboardData {
  const PatientDashboardData({
    required this.patient,
    required this.therapist,
    required this.nextAppointment,
    required this.activity,
    required this.emotionalSummary,
    required this.sessions,
  });

  factory PatientDashboardData.fromJson(Map<String, dynamic> json) =>
      PatientDashboardData(
        patient: DashboardPatient.fromJson(_map(json['patient'])),
        therapist: json['therapist'] == null
            ? null
            : DashboardTherapist.fromJson(_map(json['therapist'])),
        nextAppointment: json['next_appointment'] == null
            ? null
            : DashboardAppointment.fromJson(_map(json['next_appointment'])),
        activity: json['between_session_activity'] == null
            ? null
            : DashboardActivity.fromJson(
                _map(json['between_session_activity']),
              ),
        emotionalSummary: EmotionalSummary.fromJson(
          _map(json['emotional_summary']),
        ),
        sessions: (json['sessions'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DashboardAppointment.fromJson)
            .toList(growable: false),
      );

  final DashboardPatient patient;
  final DashboardTherapist? therapist;
  final DashboardAppointment? nextAppointment;
  final DashboardActivity? activity;
  final EmotionalSummary emotionalSummary;
  final List<DashboardAppointment> sessions;
}

class DashboardPatient {
  const DashboardPatient({this.id, this.nombre, this.apellido});

  factory DashboardPatient.fromJson(Map<String, dynamic> json) =>
      DashboardPatient(
        id: _int(json['id']),
        nombre: json['nombre'] as String?,
        apellido: json['apellido'] as String?,
      );

  final int? id;
  final String? nombre;
  final String? apellido;
}

class DashboardTherapist {
  const DashboardTherapist({
    this.id,
    this.nombre,
    this.apellido,
    this.especialidad,
    this.modalidad,
    this.profilePhoto,
  });

  factory DashboardTherapist.fromJson(Map<String, dynamic> json) =>
      DashboardTherapist(
        id: _int(json['id']),
        nombre: json['nombre'] as String?,
        apellido: json['apellido'] as String?,
        especialidad: json['especialidad'] as String?,
        modalidad: json['modalidad'] as String?,
        profilePhoto: json['profile_photo'] as String?,
      );

  final int? id;
  final String? nombre;
  final String? apellido;
  final String? especialidad;
  final String? modalidad;
  final String? profilePhoto;

  String get displayName => [nombre, apellido]
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(' ');
}

class DashboardAppointment {
  const DashboardAppointment({
    this.id,
    this.date,
    this.time,
    this.status,
    this.modality,
  });

  factory DashboardAppointment.fromJson(Map<String, dynamic> json) =>
      DashboardAppointment(
        id: _int(json['id']),
        date: json['date'] as String?,
        time: json['time'] as String?,
        status: json['status'] as String?,
        modality: json['modality'] as String?,
      );

  final int? id;
  final String? date;
  final String? time;
  final String? status;
  final String? modality;
}

class DashboardActivity {
  const DashboardActivity({
    this.id,
    this.title,
    this.instructions,
    this.objective,
    this.suggestedDate,
    this.status,
    this.response,
  });

  factory DashboardActivity.fromJson(Map<String, dynamic> json) =>
      DashboardActivity(
        id: _int(json['id']),
        title: json['title'] as String?,
        instructions: json['instructions'] as String?,
        objective: json['objective'] as String?,
        suggestedDate: json['suggested_date'] as String?,
        status: json['status'] as String?,
        response: json['response'] is Map<String, dynamic>
            ? DashboardActivityResponse.fromJson(
                json['response'] as Map<String, dynamic>,
              )
            : null,
      );

  final int? id;
  final String? title;
  final String? instructions;
  final String? objective;
  final String? suggestedDate;
  final String? status;
  final DashboardActivityResponse? response;
}

class DashboardActivityResponse {
  const DashboardActivityResponse({this.status, this.comment});
  factory DashboardActivityResponse.fromJson(Map<String, dynamic> json) =>
      DashboardActivityResponse(
        status: json['status'] as String?,
        comment: json['comment'] as String?,
      );
  final String? status;
  final String? comment;
}

class EmotionalSummary {
  const EmotionalSummary({required this.totalRecords, required this.records});

  factory EmotionalSummary.fromJson(Map<String, dynamic> json) =>
      EmotionalSummary(
        totalRecords: _int(json['total_records']) ?? 0,
        records: (json['records'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EmotionalRecord.fromJson)
            .toList(growable: false),
      );

  final int totalRecords;
  final List<EmotionalRecord> records;
}

class EmotionalRecord {
  const EmotionalRecord({
    this.id,
    this.emotion,
    this.intensity,
    this.recordedAt,
  });

  factory EmotionalRecord.fromJson(Map<String, dynamic> json) =>
      EmotionalRecord(
        id: _int(json['id']),
        emotion: json['emotion'] as String?,
        intensity: _int(json['intensity']),
        recordedAt: json['recorded_at'] as String?,
      );

  final int? id;
  final String? emotion;
  final int? intensity;
  final String? recordedAt;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

int? _int(Object? value) => value is num ? value.toInt() : null;

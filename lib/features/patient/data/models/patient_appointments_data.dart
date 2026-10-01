import 'patient_appointment.dart';

class PatientAppointmentsData {
  const PatientAppointmentsData({
    required this.upcoming,
    required this.history,
  });

  factory PatientAppointmentsData.fromJson(Map<String, dynamic> json) =>
      PatientAppointmentsData(
        upcoming: _appointments(json['upcoming']),
        history: _appointments(json['history']),
      );

  final List<PatientAppointment> upcoming;
  final List<PatientAppointment> history;
}

List<PatientAppointment> _appointments(Object? value) =>
    (value as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PatientAppointment.fromJson)
        .toList(growable: false);

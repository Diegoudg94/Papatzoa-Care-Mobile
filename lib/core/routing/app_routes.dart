class AppRoutes {
  AppRoutes._();

  static const String login = '/login';

  static const String patientDashboard = '/patient';
  static const String patientAppointments = '/patient/citas';
  static const String patientBookAppointment = '/patient/citas/nueva';
  static const String patientAppointmentDetail = '/patient/citas/detalle';
  static const String patientDiary = '/patient/diario';
  static const String patientSupportNetwork = '/patient/red-apoyo';
  static const String patientAccount = '/patient/mi-cuenta';
  static const String patientNotifications = '/patient/notificaciones';

  static const String therapistDashboard = '/therapist';
  static const String therapistAppointments = '/therapist/citas';
  static const String therapistPatients = '/therapist/pacientes';
  static const String therapistAccount = '/therapist/mi-cuenta';
}

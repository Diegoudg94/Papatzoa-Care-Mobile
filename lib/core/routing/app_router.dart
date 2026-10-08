import 'package:flutter/material.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/data/models/auth_user.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/patient/presentation/pages/patient_root_shell.dart';
import '../../features/patient/presentation/pages/patient_account_page.dart';
import '../../features/patient/data/repositories/patient_appointments_repository.dart';
import '../../features/patient/presentation/pages/patient_appointments_page.dart';
import '../../features/patient/presentation/pages/patient_book_appointment_page.dart';
import '../../features/patient/presentation/pages/patient_appointment_detail_page.dart';
import '../../features/patient/data/repositories/notification_repository.dart';
import '../../features/patient/presentation/pages/patient_notifications_page.dart';
import '../../features/patient/data/repositories/patient_diary_repository.dart';
import '../../features/patient/presentation/diary/patient_diary_page.dart';
import '../../features/patient/data/repositories/patient_support_network_repository.dart';
import '../../features/patient/presentation/support_network/patient_support_network_page.dart';
import '../../features/therapist/presentation/pages/therapist_dashboard_page.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Map<String, WidgetBuilder> get routes => routesFor(AuthRepository());

  static Map<String, WidgetBuilder> routesFor(AuthRepository repository) => {
    AppRoutes.login: (_) => LoginPage(repository: repository),
    AppRoutes.patientDashboard: (context) {
      final user =
          ModalRoute.of(context)?.settings.arguments as AuthUser? ??
          repository.currentUser;
      if (user == null) return LoginPage(repository: repository);
      return PatientRootShell(user: user, repository: repository);
    },
    AppRoutes.patientAccount: (_) => PatientAccountPage(repository: repository),
    AppRoutes.patientNotifications: (_) => PatientNotificationsPage(
      repository: repository,
      notificationRepository: NotificationRepository(
        apiClient: repository.apiClient,
      ),
    ),
    AppRoutes.patientAppointments: (_) => PatientAppointmentsPage(
      repository: repository,
      appointmentsRepository: PatientAppointmentsRepository(
        apiClient: repository.apiClient,
      ),
    ),
    AppRoutes.patientBookAppointment: (_) => PatientBookAppointmentPage(
      repository: repository,
      appointmentsRepository: PatientAppointmentsRepository(
        apiClient: repository.apiClient,
      ),
    ),
    AppRoutes.patientAppointmentDetail: (context) =>
        PatientAppointmentDetailPage(
          repository: repository,
          appointmentsRepository: PatientAppointmentsRepository(
            apiClient: repository.apiClient,
          ),
          appointmentId: ModalRoute.of(context)!.settings.arguments as int,
        ),
    AppRoutes.patientDiary: (_) => PatientDiaryPage(
      repository: repository,
      diaryRepository: PatientDiaryRepository(apiClient: repository.apiClient),
    ),
    AppRoutes.patientSupportNetwork: (_) => PatientSupportNetworkPage(
      repository: repository,
      supportRepository: PatientSupportNetworkRepository(
        apiClient: repository.apiClient,
      ),
    ),
    AppRoutes.therapistDashboard: (context) {
      final user =
          ModalRoute.of(context)?.settings.arguments as AuthUser? ??
          repository.currentUser;
      if (user == null) return LoginPage(repository: repository);
      return TherapistDashboardPage(user: user, repository: repository);
    },
  };
}

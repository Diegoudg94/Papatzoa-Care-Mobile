import 'package:flutter/material.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/data/models/auth_user.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/patient/presentation/pages/patient_dashboard_page.dart';
import '../../features/therapist/presentation/pages/therapist_dashboard_page.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Map<String, WidgetBuilder> get routes => routesFor(AuthRepository());

  static Map<String, WidgetBuilder> routesFor(AuthRepository repository) => {
    AppRoutes.login: (_) => LoginPage(repository: repository),
    AppRoutes.patientDashboard: (context) => PatientDashboardPage(
      user: ModalRoute.of(context)!.settings.arguments as AuthUser,
      repository: repository,
    ),
    AppRoutes.therapistDashboard: (context) => TherapistDashboardPage(
      user: ModalRoute.of(context)!.settings.arguments as AuthUser,
      repository: repository,
    ),
  };
}

import 'package:flutter/material.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Map<String, WidgetBuilder> get routes => {
    AppRoutes.login: (_) => const LoginPage(),
  };
}

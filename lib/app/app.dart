import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/routing/app_router.dart';
import '../core/routing/app_routes.dart';

class PapatzoaApp extends StatelessWidget {
  const PapatzoaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Papatzoa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.login,
      routes: AppRouter.routes,
    );
  }
}

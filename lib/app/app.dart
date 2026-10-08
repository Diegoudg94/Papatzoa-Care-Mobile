import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/routing/app_router.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/auth/presentation/pages/auth_gate.dart';

class PapatzoaApp extends StatefulWidget {
  const PapatzoaApp({super.key, this.repository, this.themeController});

  final AuthRepository? repository;
  final ThemeController? themeController;

  @override
  State<PapatzoaApp> createState() => _PapatzoaAppState();
}

class _PapatzoaAppState extends State<PapatzoaApp> {
  late final AuthRepository _repository = widget.repository ?? AuthRepository();
  late final ThemeController _themeController =
      widget.themeController ?? ThemeController();

  @override
  void initState() {
    super.initState();
    _themeController.load();
  }

  @override
  void dispose() {
    if (widget.repository == null) _repository.close();
    if (widget.themeController == null) _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeControllerScope(
      controller: _themeController,
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, _) => MaterialApp(
          title: 'Papatzoa',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(_themeController.preset, Brightness.light),
          darkTheme: AppTheme.build(_themeController.preset, Brightness.dark),
          themeMode: _themeController.mode,
          home: AuthGate(repository: _repository),
          routes: AppRouter.routesFor(_repository),
        ),
      ),
    );
  }
}

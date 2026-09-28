import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/routing/app_router.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/auth/presentation/pages/auth_gate.dart';

class PapatzoaApp extends StatefulWidget {
  const PapatzoaApp({super.key, this.repository});

  final AuthRepository? repository;

  @override
  State<PapatzoaApp> createState() => _PapatzoaAppState();
}

class _PapatzoaAppState extends State<PapatzoaApp> {
  late final AuthRepository _repository = widget.repository ?? AuthRepository();

  @override
  void dispose() {
    if (widget.repository == null) _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Papatzoa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: AuthGate(repository: _repository),
      routes: AppRouter.routesFor(_repository),
    );
  }
}

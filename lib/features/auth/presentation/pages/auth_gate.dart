import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../data/repositories/auth_repository.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _networkError = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() => _networkError = false);
    try {
      final user = await widget.repository.restoreSession();
      if (!mounted) return;
      final route = switch (user?.role) {
        'patient' => AppRoutes.patientDashboard,
        'therapist' => AppRoutes.therapistDashboard,
        _ => AppRoutes.login,
      };
      Navigator.of(context)
          .pushNamedAndRemoveUntil(route, (_) => false, arguments: user);
    } on NetworkException catch (_) {
      if (mounted) setState(() => _networkError = true);
    } catch (_) {
      if (mounted) setState(() => _networkError = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _networkError
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No pudimos conectar con Papatzoa.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _restore,
                  child: const Text('Reintentar'),
                ),
              ],
            )
          : const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Papatzoa'),
                SizedBox(height: 16),
                CircularProgressIndicator(),
              ],
            ),
    ),
  );
}

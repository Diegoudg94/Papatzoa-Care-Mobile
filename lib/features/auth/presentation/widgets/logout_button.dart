import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../data/repositories/auth_repository.dart';

class LogoutButton extends StatefulWidget {
  const LogoutButton({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<LogoutButton> {
  bool _busy = false;

  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.logout();
    } catch (_) {
      // Local cleanup is performed by the repository even if the request fails.
    }
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: _busy ? null : _logout,
    child: const Text('Cerrar sesión'),
  );
}

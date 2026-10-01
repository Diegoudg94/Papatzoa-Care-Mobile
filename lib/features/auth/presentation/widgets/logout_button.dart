import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../data/repositories/auth_repository.dart';

class LogoutButton extends StatefulWidget {
  const LogoutButton({
    super.key,
    required this.repository,
    this.compact = false,
  });

  final AuthRepository repository;
  final bool compact;

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
  Widget build(BuildContext context) {
    if (widget.compact) {
      return PopupMenuButton<String>(
        tooltip: 'Opciones de cuenta',
        enabled: !_busy,
        icon: _busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.account_circle_outlined),
        onSelected: (_) => _logout(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
        ],
      );
    }
    return TextButton(
      onPressed: _busy ? null : _logout,
      child: const Text('Cerrar sesión'),
    );
  }
}

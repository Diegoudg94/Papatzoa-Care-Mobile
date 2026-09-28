import 'package:flutter/material.dart';

import '../../../auth/data/models/auth_user.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/widgets/logout_button.dart';

class TherapistDashboardPage extends StatelessWidget {
  const TherapistDashboardPage({
    super.key,
    required this.user,
    this.repository,
  });

  final AuthUser user;
  final AuthRepository? repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Papatzoa'),
        actions: [LogoutButton(repository: repository ?? AuthRepository())],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hola, ${user.firstName}',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Bienvenido a tu espacio de Papatzoa.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Panel del terapeuta',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

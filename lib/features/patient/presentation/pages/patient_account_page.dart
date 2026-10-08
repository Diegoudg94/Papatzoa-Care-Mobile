import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/widgets/logout_button.dart';
import '../widgets/patient_bottom_navigation.dart';
import 'patient_root_scope.dart';

class PatientAccountPage extends StatelessWidget {
  const PatientAccountPage({super.key, required this.repository});

  final AuthRepository repository;

  @override
  Widget build(BuildContext context) {
    final user = repository.currentUser;
    final colors = Theme.of(context).colorScheme;
    final fullName = [user?.firstName, user?.lastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    final photo = user?.avatarUrl?.trim();
    final initials = [user?.firstName, user?.lastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map((part) => part.characters.first.toUpperCase())
        .take(2)
        .join();
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Mi cuenta')),
      bottomNavigationBar: PatientRootScope.contains(context)
          ? null
          : PatientBottomNavigation(
              currentRoute: AppRoutes.patientAccount,
              user: user,
              onDestinationSelected: (route) =>
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil(route, (route) => route.isFirst),
            ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 132),
          children: [
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundColor: colors.primaryContainer,
                foregroundImage: photo == null || photo.isEmpty
                    ? null
                    : NetworkImage(photo),
                onForegroundImageError: photo == null || photo.isEmpty
                    ? null
                    : (_, _) {},
                child: initials.isNotEmpty
                    ? Text(
                        initials,
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Icon(
                        Icons.person_outline,
                        color: colors.onPrimaryContainer,
                        size: 34,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (fullName.isNotEmpty)
              Text(
                fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            if (user?.email != null) ...[
              const SizedBox(height: 4),
              Text(user!.email, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            const Divider(),
            LogoutButton(repository: repository),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/repositories/patient_appointments_repository.dart';
import '../../data/repositories/patient_diary_repository.dart';
import '../widgets/patient_bottom_navigation.dart';
import 'patient_account_page.dart';
import 'patient_appointments_page.dart';
import 'patient_dashboard_page.dart';
import 'patient_root_scope.dart';
import '../diary/patient_diary_page.dart';

class PatientRootShell extends StatefulWidget {
  const PatientRootShell({
    super.key,
    required this.user,
    required this.repository,
    this.dashboardPage,
    this.diaryPage,
    this.appointmentsPage,
    this.accountPage,
  });

  final AuthUser user;
  final AuthRepository repository;
  final PatientDashboardPage? dashboardPage;
  final PatientDiaryPage? diaryPage;
  final PatientAppointmentsPage? appointmentsPage;
  final PatientAccountPage? accountPage;

  @override
  State<PatientRootShell> createState() => _PatientRootShellState();
}

class _PatientRootShellState extends State<PatientRootShell> {
  late final PageController _pageController = PageController();
  int _activeIndex = 0;

  // Keep this order aligned with the destinations in PatientBottomNavigation.
  static const _routes = [
    AppRoutes.patientDashboard,
    AppRoutes.patientDiary,
    AppRoutes.patientAppointments,
    AppRoutes.patientAccount,
  ];

  // These root pages stay mounted in the PageView so their loaded state and
  // in-progress UI survive tab changes. Detail flows remain pushed routes.
  late final List<Widget> _pages = [
    widget.dashboardPage ??
        PatientDashboardPage(user: widget.user, repository: widget.repository),
    widget.diaryPage ??
        PatientDiaryPage(
          repository: widget.repository,
          diaryRepository: PatientDiaryRepository(
            apiClient: widget.repository.apiClient,
          ),
        ),
    widget.appointmentsPage ??
        PatientAppointmentsPage(
          repository: widget.repository,
          appointmentsRepository: PatientAppointmentsRepository(
            apiClient: widget.repository.apiClient,
          ),
        ),
    widget.accountPage ?? PatientAccountPage(repository: widget.repository),
  ];

  void _selectIndex(int index) {
    if (index < 0 || index >= _routes.length || index == _activeIndex) return;
    setState(() => _activeIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectRoute(String route) {
    final index = _routes.indexOf(route);
    if (index >= 0) _selectIndex(index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PatientRootScope(
      onSelectRoute: _selectRoute,
      child: PageView(
        key: const ValueKey('patient-root-page-view'),
        controller: _pageController,
        onPageChanged: (index) => setState(() => _activeIndex = index),
        children: _pages,
      ),
    ),
    bottomNavigationBar: _ShellBottomNavigation(
      route: _routes[_activeIndex],
      user: widget.user,
      onSelected: _selectRoute,
    ),
  );
}

class _ShellBottomNavigation extends StatelessWidget {
  const _ShellBottomNavigation({
    required this.route,
    required this.user,
    required this.onSelected,
  });
  final String route;
  final AuthUser user;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => PatientBottomNavigation(
    currentRoute: route,
    user: user,
    onDestinationSelected: onSelected,
  );
}

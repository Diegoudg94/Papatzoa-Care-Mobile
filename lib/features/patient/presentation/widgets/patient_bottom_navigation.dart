import 'package:flutter/material.dart';

import 'dart:ui';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/models/auth_user.dart';

class PatientBottomNavigation extends StatelessWidget {
  const PatientBottomNavigation({
    super.key,
    required this.currentRoute,
    this.onDestinationSelected,
    this.user,
  });

  final String currentRoute;
  final ValueChanged<String>? onDestinationSelected;
  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tokens = theme.extension<AppColors>();
    final isDark = theme.brightness == Brightness.dark;
    final items = [
      _Destination(AppRoutes.patientDashboard, 'Inicio', Icons.home_outlined),
      _Destination(AppRoutes.patientDiary, 'Diario', Icons.menu_book_outlined),
      _Destination(
        AppRoutes.patientAppointments,
        'Mis sesiones',
        Icons.event_note_outlined,
      ),
      _Destination(AppRoutes.patientAccount, 'Mi perfil', Icons.person_outline),
    ];
    final glassBase = isDark
        ? (tokens?.surfaceAccent ?? colors.surface)
        : (tokens?.surfaceElevated ?? colors.surface);
    final glassColor = glassBase.withValues(alpha: isDark ? 0.96 : 0.92);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: glassColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: (tokens?.border ?? colors.outline).withValues(
                      alpha: isDark ? 0.88 : 0.84,
                    ),
                    width: 1,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (tokens?.surfaceElevated ?? colors.surface).withValues(
                        alpha: isDark ? 0.12 : 0.16,
                      ),
                      (tokens?.surfaceElevated ?? colors.surface).withValues(
                        alpha: 0.01,
                      ),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(
                        alpha: isDark ? 0.16 : 0.06,
                      ),
                      blurRadius: 16,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      Expanded(
                        child: _BottomNavItem(
                          destination: items[index],
                          user: index == 3 ? user : null,
                          selected: currentRoute == items[index].route,
                          onTap: () {
                            if (onDestinationSelected != null) {
                              onDestinationSelected!(items[index].route);
                              return;
                            }
                            if (currentRoute == items[index].route) return;
                            if (items[index].route ==
                                AppRoutes.patientAccount) {
                              Navigator.of(context)
                                  .pushNamed(items[index].route);
                              return;
                            }
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              items[index].route,
                              (route) => route.isFirst,
                              arguments:
                                  items[index].route ==
                                      AppRoutes.patientDashboard
                                  ? user
                                  : null,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.route, this.label, this.icon);
  final String route;
  final String label;
  final IconData icon;
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final AuthUser? user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tokens = theme.extension<AppColors>();
    final isDark = theme.brightness == Brightness.dark;
    final color = selected
        ? (tokens?.primaryActive ?? colors.primary)
        : colors.onSurfaceVariant;
    final label = destination.label;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.route == AppRoutes.patientAccount
          ? 'Mi cuenta'
          : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 62,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected
                  ? (tokens?.primaryContainer ?? colors.primaryContainer)
                        .withValues(alpha: isDark ? 0.82 : 0.90)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (destination.route == AppRoutes.patientAccount &&
                    user != null)
                  _PatientAvatar(user: user!, selected: selected)
                else if (destination.route == AppRoutes.patientAccount)
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: colors.primaryContainer,
                    child: Icon(
                      Icons.person_outline,
                      size: 17,
                      color: colors.onPrimaryContainer,
                    ),
                  )
                else
                  Icon(destination.icon, color: color, size: 22),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientAvatar extends StatelessWidget {
  const _PatientAvatar({required this.user, required this.selected});
  final AuthUser user;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = [user.firstName, user.lastName]
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .map((name) => name.characters.first.toUpperCase())
        .take(2)
        .join();
    final photo = user.avatarUrl?.trim();
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: selected ? Border.all(color: colors.primary, width: 2) : null,
        color: selected ? colors.primary.withValues(alpha: 0.12) : null,
      ),
      child: CircleAvatar(
        radius: 13,
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
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: colors.onPrimaryContainer,
                ),
              )
            : Icon(
                Icons.person_outline,
                size: 17,
                color: colors.onPrimaryContainer,
              ),
      ),
    );
  }
}

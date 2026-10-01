import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/patient_dashboard_data.dart';
import '../../data/repositories/patient_dashboard_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/patient_session_activity_repository.dart';
import 'patient_session_activity_page.dart';
import '../widgets/patient_bottom_navigation.dart';

class PatientDashboardPage extends StatefulWidget {
  const PatientDashboardPage({
    super.key,
    required this.user,
    this.repository,
    this.dashboardRepository,
    this.notificationRepository,
  });

  final AuthUser user;
  final AuthRepository? repository;
  final PatientDashboardRepository? dashboardRepository;
  final NotificationRepository? notificationRepository;

  @override
  State<PatientDashboardPage> createState() => _PatientDashboardPageState();
}

class _PatientDashboardPageState extends State<PatientDashboardPage> {
  late final AuthRepository _authRepository =
      widget.repository ?? AuthRepository();
  late final PatientDashboardRepository _dashboardRepository =
      widget.dashboardRepository ??
      PatientDashboardRepository(apiClient: _authRepository.apiClient);
  late final NotificationRepository _notificationRepository =
      widget.notificationRepository ??
      NotificationRepository(apiClient: _authRepository.apiClient);

  PatientDashboardData? _data;
  bool _loading = true;
  bool _networkError = false;
  bool _forbidden = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _networkError = false;
      _forbidden = false;
    });

    var dashboardLoaded = false;
    try {
      final data = await _dashboardRepository.loadDashboard();
      dashboardLoaded = true;
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        try {
          await _authRepository.invalidateSession();
        } catch (_) {
          // Navigate away even if secure storage reports a cleanup error.
        }
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        }
        return;
      }
      if (mounted) {
        setState(() {
          _forbidden = error.statusCode == 403;
          _networkError = error.statusCode != 403;
        });
      }
    } on NetworkException {
      if (mounted) setState(() => _networkError = true);
    } catch (_) {
      if (mounted) setState(() => _networkError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (dashboardLoaded) _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notificationRepository.fetchUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // A notification count outage should not block the dashboard.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).pushNamed(AppRoutes.patientNotifications);
    if (mounted) _loadUnreadCount();
  }

  Future<void> _openActivity() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PatientSessionActivityPage(
          repository: PatientSessionActivityRepository(
            apiClient: _authRepository.apiClient,
          ),
        ),
      ),
    );
    if (mounted) _loadDashboard();
  }

  @override
  void dispose() {
    if (widget.repository == null) _authRepository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dashboard = _data;
    final activity = dashboard?.activity;
    final therapist = dashboard?.therapist;
    final emotional = dashboard?.emotionalSummary;
    final nextAppointment = dashboard?.nextAppointment;
    final user = _authRepository.currentUser ?? widget.user;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(
          'Papatzoa',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: _openNotifications,
            icon: _NotificationBell(unreadCount: _unreadCount),
          ),
          const SizedBox(width: 12),
        ],
      ),
      bottomNavigationBar: PatientBottomNavigation(
        currentRoute: AppRoutes.patientDashboard,
        user: user,
      ),
      body: SafeArea(
        bottom: false,
        child: _forbidden
            ? const Center(child: Text('No tienes acceso a este dashboard.'))
            : Column(
                children: [
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 132),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Hola, ${widget.user.firstName}',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '¿Cómo te sientes hoy?',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'Tu espacio',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _QuickAction(
                                      icon: Icons.menu_book_outlined,
                                      title: 'Diario',
                                      onTap: () => Navigator.of(context)
                                          .pushNamed(AppRoutes.patientDiary),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: _QuickAction(
                                      icon: Icons.calendar_today_outlined,
                                      title: 'Mis sesiones',
                                      onTap: () => Navigator.of(context)
                                          .pushNamed(
                                            AppRoutes.patientAppointments,
                                          ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: _QuickAction(
                                      icon: Icons.people_outline,
                                      title: 'Red de apoyo',
                                      onTap: () => Navigator.of(context)
                                          .pushNamed(
                                            AppRoutes.patientSupportNetwork,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_networkError) ...[
                                const SizedBox(height: 16),
                                _RetryNotice(onRetry: _loadDashboard),
                              ],
                              const SizedBox(height: 28),
                              _SectionCard(
                                icon: Icons.assignment_outlined,
                                title: 'Actividad entre sesiones',
                                message: activity == null
                                    ? 'Cuando tu terapeuta te deje una actividad, aparecerá aquí.'
                                    : null,
                                details: activity == null
                                    ? const []
                                    : _activityDetails(activity, theme, colors),
                                action: activity == null ? null : _openActivity,
                              ),
                              const SizedBox(height: 12),
                              _SectionCard(
                                icon: Icons.person_outline,
                                title: 'Tu terapeuta',
                                message: therapist == null
                                    ? 'La información de tu terapeuta aparecerá aquí.'
                                    : null,
                                details: therapist == null
                                    ? const []
                                    : _therapistDetails(
                                        therapist,
                                        theme,
                                        colors,
                                      ),
                              ),
                              const SizedBox(height: 12),
                              const _SectionCard(
                                icon: Icons.menu_book_outlined,
                                title: 'Consejos para tu registro',
                                message: 'Cuando uses tu diario, intenta describir lo que ocurrió y cómo te hizo sentir.',
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.spa_outlined,
                                      color: colors.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ejercicios de respiración',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      colors.onPrimaryContainer,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Tómate un momento para respirar y bajar el ritmo.',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      colors.onPrimaryContainer,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _SectionCard(
                                icon: Icons.favorite_border,
                                title: 'Seguimiento emocional',
                                message:
                                    emotional == null ||
                                        emotional.totalRecords == 0 ||
                                        emotional.records.isEmpty
                                    ? 'Tus registros emocionales aparecerán aquí.'
                                    : null,
                                details:
                                    emotional == null ||
                                        emotional.totalRecords == 0
                                    ? const []
                                    : _emotionalDetails(
                                        emotional.records,
                                        theme,
                                        colors,
                                      ),
                              ),
                              const SizedBox(height: 12),
                              _SectionCard(
                                icon: Icons.event_available_outlined,
                                title: 'Próxima sesión',
                                message: nextAppointment == null
                                    ? 'Aquí aparecerá tu próxima sesión.'
                                    : null,
                                details: nextAppointment == null
                                    ? const []
                                    : _appointmentDetails(
                                        nextAppointment,
                                        theme,
                                        colors,
                                      ),
                              ),
                              const SizedBox(height: 12),
                              _SectionCard(
                                icon: Icons.calendar_today_outlined,
                                title: 'Mis sesiones',
                                message:
                                    dashboard == null ||
                                        dashboard.sessions.isEmpty
                                    ? 'Tus sesiones agendadas aparecerán aquí.'
                                    : null,
                                details:
                                    dashboard == null ||
                                        dashboard.sessions.isEmpty
                                    ? const []
                                    : dashboard.sessions
                                          .map(
                                            (session) => _sessionDetails(
                                              session,
                                              theme,
                                              colors,
                                            ),
                                          )
                                          .toList(growable: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _activityDetails(
    DashboardActivity activity,
    ThemeData theme,
    ColorScheme colors,
  ) => [
    if (_present(activity.title)) _detailText(activity.title!, theme, colors),
    _labeledDetail(
      'Estado',
      activity.status == 'intentada' ? 'La intenté' : 'Pendiente',
      theme,
      colors,
    ),
  ];

  List<Widget> _therapistDetails(
    DashboardTherapist therapist,
    ThemeData theme,
    ColorScheme colors,
  ) => [
    if (_present(therapist.profilePhoto))
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CircleAvatar(
          radius: 28,
          backgroundColor: colors.primaryContainer,
          foregroundImage: NetworkImage(therapist.profilePhoto!),
          onForegroundImageError: (_, _) {},
          child: Icon(Icons.person_outline, color: colors.onPrimaryContainer),
        ),
      ),
    if (_present(therapist.displayName))
      _detailText(therapist.displayName, theme, colors),
    if (_present(therapist.especialidad))
      _labeledDetail('Especialidad', therapist.especialidad!, theme, colors),
    if (_present(therapist.modalidad))
      _labeledDetail('Modalidad', therapist.modalidad!, theme, colors),
  ];

  List<Widget> _emotionalDetails(
    List<EmotionalRecord> records,
    ThemeData theme,
    ColorScheme colors,
  ) => records
      .map((record) {
        final parts = <String>[];
        if (_present(record.emotion)) parts.add(record.emotion!);
        if (record.intensity != null) {
          parts.add('Intensidad: ${record.intensity}');
        }
        if (_present(record.recordedAt)) {
          parts.add(_friendlyDate(record.recordedAt!));
        }
        return _detailText(parts.join(' · '), theme, colors);
      })
      .toList(growable: false);

  Widget _sessionDetails(
    DashboardAppointment session,
    ThemeData theme,
    ColorScheme colors,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _appointmentDetails(session, theme, colors),
    ),
  );

  List<Widget> _appointmentDetails(
    DashboardAppointment appointment,
    ThemeData theme,
    ColorScheme colors,
  ) => [
    if (_present(appointment.date))
      _labeledDetail('Fecha', _friendlyDate(appointment.date!), theme, colors),
    if (_present(appointment.time))
      _labeledDetail('Hora', appointment.time!, theme, colors),
    if (_present(appointment.status))
      _labeledDetail('Estado', appointment.status!, theme, colors),
    if (_present(appointment.modality))
      _labeledDetail('Modalidad', appointment.modality!, theme, colors),
  ];

  Widget _labeledDetail(
    String label,
    String value,
    ThemeData theme,
    ColorScheme colors,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );

  Widget _detailText(String value, ThemeData theme, ColorScheme colors) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      );

  bool _present(String? value) => value != null && value.trim().isNotEmpty;

  String _friendlyDate(String value) {
    final datePart = value.split('T').first;
    final parts = datePart.split('-');
    if (parts.length != 3) return value;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Center(child: Icon(Icons.notifications_none_rounded)),
          if (unreadCount > 0)
            Positioned(
              top: 1,
              right: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RetryNotice extends StatelessWidget {
  const _RetryNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: colors.primary),
          const SizedBox(width: 12),
          const Expanded(child: Text('No pudimos actualizar tu información.')),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.primary, size: 27),
            const SizedBox(height: 9),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              onTap == null
                  ? 'Próximamente'
                  : title == 'Diario'
                  ? 'Abrir diario'
                  : title == 'Red de apoyo'
                  ? 'Ver red'
                  : 'Ver citas',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    this.message,
    this.details = const [],
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> details;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: colors.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (message != null)
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            )
          else
            ...details,
          if (action != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: action, child: const Text('Ver actividad')),
          ],
        ],
      ),
    );
  }
}

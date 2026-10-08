import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_picker_page.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/patient_dashboard_data.dart';
import '../../data/models/diary_options.dart';
import '../../data/repositories/patient_dashboard_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/patient_session_activity_repository.dart';
import 'patient_session_activity_page.dart';
import 'patient_root_scope.dart';
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

class _PatientDashboardPageState extends State<PatientDashboardPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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

  void _openAppearance() {
    final controller = ThemeControllerScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context)
          .extension<AppColors>()
          ?.surfaceElevated,
      builder: (sheetContext) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            4,
            24,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apariencia',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text('Modo', style: Theme.of(context).textTheme.titleMedium),
              RadioGroup<ThemeMode>(
                groupValue: controller.mode,
                onChanged: (mode) {
                  if (mode != null) controller.setMode(mode);
                },
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text('Claro'),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('Oscuro'),
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Tema', style: Theme.of(context).textTheme.titleMedium),
              ListTile(
                title: Text(controller.preset.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(sheetContext).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ThemePickerPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    super.build(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dashboard = _data;
    final activity = dashboard?.activity;
    final therapist = dashboard?.therapist;
    final emotional = dashboard?.emotionalSummary;
    final nextAppointment = dashboard?.nextAppointment;
    final user = _authRepository.currentUser ?? widget.user;
    final firstName = widget.user.firstName.trim().split(RegExp(r'\s+'));
    final greetingName = firstName.isEmpty || firstName.first.isEmpty
        ? ''
        : firstName.first;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 104,
        leading: const SizedBox.shrink(),
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
          IconButton(
            tooltip: 'Apariencia',
            onPressed: _openAppearance,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: PatientRootScope.contains(context)
          ? null
          : PatientBottomNavigation(
              currentRoute: AppRoutes.patientDashboard,
              user: user,
              onDestinationSelected: (route) => Navigator.of(context)
                  .pushNamedAndRemoveUntil(
                    route,
                    (route) => route.isFirst,
                    arguments: route == AppRoutes.patientDashboard
                        ? user
                        : null,
                  ),
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
                                greetingName.isEmpty
                                    ? 'Hola'
                                    : 'Hola, $greetingName',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.22,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '¿Cómo te sientes hoy?',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 36),
                              Text(
                                'Tu espacio',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _QuickAction(
                                      icon: Icons.menu_book_rounded,
                                      title: 'Diario',
                                      category: _QuickCategory.diary,
                                      onTap: () {
                                        if (!PatientRootScope.selectRoute(
                                          context,
                                          AppRoutes.patientDiary,
                                        )) {
                                          Navigator.of(
                                            context,
                                          ).pushNamed(AppRoutes.patientDiary);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _QuickAction(
                                      icon: Icons.calendar_month_rounded,
                                      title: 'Mis sesiones',
                                      category: _QuickCategory.sessions,
                                      onTap: () {
                                        if (!PatientRootScope.selectRoute(
                                          context,
                                          AppRoutes.patientAppointments,
                                        )) {
                                          Navigator.of(context).pushNamed(
                                            AppRoutes.patientAppointments,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _QuickAction(
                                      icon: Icons.diversity_3_rounded,
                                      title: 'Red de apoyo',
                                      category: _QuickCategory.support,
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
                              const SizedBox(height: 30),
                              _SectionCard(
                                icon: Icons.assignment_rounded,
                                title: 'Actividad entre sesiones',
                                accent: _SemanticAccent.activity,
                                tone: _CardTone.action,
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
                                icon: Icons.person_rounded,
                                title: 'Tu terapeuta',
                                accent: _SemanticAccent.therapist,
                                tone: _CardTone.neutral,
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
                                icon: Icons.lightbulb_rounded,
                                title: 'Consejos para tu registro',
                                accent: _SemanticAccent.tips,
                                tone: _CardTone.warm,
                                message: 'Cuando uses tu diario, intenta describir lo que ocurrió y cómo te hizo sentir.',
                              ),
                              const SizedBox(height: 12),
                              _EmotionalSummaryCard(
                                records: emotional?.records ?? const [],
                                onTap: () {
                                  if (!PatientRootScope.selectRoute(
                                    context,
                                    AppRoutes.patientDiary,
                                  )) {
                                    Navigator.of(context)
                                        .pushNamed(AppRoutes.patientDiary);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              _SectionCard(
                                icon: Icons.event_rounded,
                                title: 'Próxima sesión',
                                accent: _SemanticAccent.sessions,
                                tone: _CardTone.action,
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
                                icon: Icons.calendar_month_rounded,
                                title: 'Mis sesiones',
                                accent: _SemanticAccent.sessions,
                                tone: _CardTone.neutral,
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
  ) {
    final hasPhoto = _present(therapist.profilePhoto);
    final appColors = Theme.of(context).extension<AppColors>();
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_present(therapist.displayName))
          Text(therapist.displayName, style: theme.textTheme.titleSmall),
        if (_present(therapist.especialidad))
          _detailText(therapist.especialidad!, theme, colors),
      ],
    );
    return [
      if (hasPhoto)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor:
                    appColors?.therapistAccentContainer ??
                    colors.primaryContainer,
                foregroundImage: NetworkImage(therapist.profilePhoto!),
                onForegroundImageError: (_, _) {},
                child: Icon(
                  Icons.person_rounded,
                  color:
                      appColors?.therapistAccent ?? colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: identity),
            ],
          ),
        )
      else ...[
        if (_present(therapist.displayName))
          _detailText(therapist.displayName, theme, colors),
        if (_present(therapist.especialidad))
          _labeledDetail(
            'Especialidad',
            therapist.especialidad!,
            theme,
            colors,
          ),
      ],
      if (_present(therapist.modalidad))
        _labeledDetail('Modalidad', therapist.modalidad!, theme, colors),
    ];
  }

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

class _EmotionalSummaryCard extends StatelessWidget {
  const _EmotionalSummaryCard({required this.records, required this.onTap});

  final List<EmotionalRecord> records;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = theme.extension<AppColors>();
    final accentContainer =
        appColors?.emotionalTrackingAccentContainer ?? colors.primaryContainer;
    final recent = records.toList()
      ..sort((first, second) {
        final firstDate = DateTime.tryParse(first.recordedAt ?? '');
        final secondDate = DateTime.tryParse(second.recordedAt ?? '');
        if (firstDate != null && secondDate != null) {
          final byDate = secondDate.compareTo(firstDate);
          if (byDate != 0) return byDate;
        } else if (firstDate != null) {
          return -1;
        } else if (secondDate != null) {
          return 1;
        }
        return (second.id ?? 0).compareTo(first.id ?? 0);
      });
    final summaryRecords = recent.take(3).toList(growable: false);
    return Semantics(
      button: true,
      label: 'Seguimiento emocional, abrir Diario',
      child: Material(
        color: appColors?.surface ?? colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: appColors?.border ?? colors.outline),
        ),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        color:
                            appColors?.emotionalTrackingAccent ??
                            colors.primary,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Seguimiento emocional',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                  ],
                ),
                if (summaryRecords.isEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Aún no tienes registros emocionales.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    summaryRecords.length == 1
                        ? 'Tu último registro'
                        : 'Tus últimos ${summaryRecords.length} registros',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (
                    var index = 0;
                    index < summaryRecords.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(height: 10),
                    _EmotionSummaryRow(record: summaryRecords[index]),
                  ],
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    records.isEmpty ? 'Registrar en mi diario' : 'Ver diario',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
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

class _EmotionSummaryRow extends StatelessWidget {
  const _EmotionSummaryRow({required this.record});

  final EmotionalRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final emotion = record.emotion?.trim();
    final name = emotion == null || emotion.isEmpty ? 'Emoción' : emotion;
    return Row(
      children: [
        Text(diaryEmotionEmoji(name), style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (record.intensity != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${record.intensity}/10',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
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

enum _QuickCategory { diary, sessions, support }

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.category,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final _QuickCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = theme.extension<AppColors>();
    final (_, _, iconContainer) = switch (category) {
      _QuickCategory.diary => (
        appColors?.surface ?? colors.surface,
        appColors?.diaryAccent ?? colors.primary,
        appColors?.diaryAccentContainer ?? colors.primaryContainer,
      ),
      _QuickCategory.sessions => (
        appColors?.surface ?? colors.surface,
        appColors?.sessionsAccent ?? colors.secondary,
        appColors?.sessionsAccentContainer ?? colors.primaryContainer,
      ),
      _QuickCategory.support => (
        appColors?.surface ?? colors.surface,
        appColors?.supportAccent ?? colors.tertiary,
        appColors?.supportAccentContainer ?? colors.primaryContainer,
      ),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 128),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 16),
        decoration: BoxDecoration(
          color: appColors?.surface ?? colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (appColors?.border ?? colors.outline).withValues(
              alpha: 0.82,
            ),
            width: 0.8,
          ),
          boxShadow: const [],
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: switch (category) {
                  _QuickCategory.diary =>
                    appColors?.diaryAccent ?? colors.primary,
                  _QuickCategory.sessions =>
                    appColors?.sessionsAccent ?? colors.primary,
                  _QuickCategory.support =>
                    appColors?.supportAccent ?? colors.primary,
                },
                size: 25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.3,
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
    this.tone = _CardTone.neutral,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> details;
  final VoidCallback? action;
  final _CardTone tone;
  final _SemanticAccent accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = theme.extension<AppColors>();
    final cardColor = switch (tone) {
      _CardTone.neutral => appColors?.surface ?? colors.surface,
      _CardTone.action => appColors?.surface ?? colors.surface,
      _CardTone.warm => appColors?.surface ?? colors.surface,
    };
    final (_, iconContainer) = switch (accent) {
      _SemanticAccent.sessions => (
        appColors?.sessionsAccent ?? colors.primary,
        appColors?.sessionsAccentContainer ?? colors.primaryContainer,
      ),
      _SemanticAccent.activity => (
        appColors?.activityAccent ?? colors.primary,
        appColors?.activityAccentContainer ?? colors.primaryContainer,
      ),
      _SemanticAccent.therapist => (
        appColors?.therapistAccent ?? colors.secondary,
        appColors?.therapistAccentContainer ?? colors.primaryContainer,
      ),
      _SemanticAccent.tips => (
        appColors?.tipsAccent ?? colors.secondary,
        appColors?.tipsAccentContainer ?? colors.primaryContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (appColors?.border ?? colors.outline).withValues(alpha: 0.82),
          width: 0.8,
        ),
        boxShadow: const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: switch (accent) {
                    _SemanticAccent.sessions =>
                      appColors?.sessionsAccent ?? colors.primary,
                    _SemanticAccent.activity =>
                      appColors?.activityAccent ?? colors.primary,
                    _SemanticAccent.therapist =>
                      appColors?.therapistAccent ?? colors.primary,
                    _SemanticAccent.tips =>
                      appColors?.tipsAccent ?? colors.primary,
                  },
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.32,
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
            FilledButton.icon(
              onPressed: action,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Ver actividad'),
            ),
          ],
        ],
      ),
    );
  }
}

enum _CardTone { neutral, action, warm }

enum _SemanticAccent { sessions, activity, therapist, tips }

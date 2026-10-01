import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';

class PatientNotificationsPage extends StatefulWidget {
  const PatientNotificationsPage({
    super.key,
    required this.repository,
    required this.notificationRepository,
  });

  final AuthRepository repository;
  final NotificationRepository notificationRepository;

  @override
  State<PatientNotificationsPage> createState() =>
      _PatientNotificationsPageState();
}

class _PatientNotificationsPageState extends State<PatientNotificationsPage> {
  List<AppNotification> _notifications = const [];
  int _unreadCount = 0;
  bool _loading = true;
  bool _error = false;
  bool _markingAll = false;
  String? _markingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _error = false;
      _loading = !refresh && _notifications.isEmpty;
    });
    try {
      final response = await widget.notificationRepository.fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = response.notifications;
          _unreadCount = response.unreadCount;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAll() async {
    if (_markingAll || _unreadCount == 0) return;
    setState(() => _markingAll = true);
    try {
      await widget.notificationRepository.markAllAsRead();
      if (mounted) {
        setState(() {
          _notifications = _notifications
              .map((notification) => notification.copyWith(read: true))
              .toList(growable: false);
          _unreadCount = 0;
        });
      }
    } catch (_) {
      _showMessage('No pudimos actualizar tus notificaciones.');
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (_markingId != null) return;
    setState(() => _markingId = notification.id);
    try {
      await widget.notificationRepository.markAsRead(notification.id);
      if (mounted) {
        setState(() {
          _notifications = _notifications
              .map(
                (item) => item.id == notification.id
                    ? item.copyWith(read: true)
                    : item,
              )
              .toList(growable: false);
          if (!notification.read && _unreadCount > 0) _unreadCount--;
        });
      }
    } catch (_) {
      _showMessage('No pudimos actualizar esta notificación.');
      if (mounted) setState(() => _markingId = null);
      return;
    }
    if (!mounted) return;
    final action = notification.action;
    final appointmentId = action?.kind == 'appointment'
        ? _asInt(action?.id)
        : null;
    if (appointmentId != null) {
      final result = await Navigator.of(
        context,
      ).pushNamed(AppRoutes.patientAppointmentDetail, arguments: appointmentId);
      if (!mounted) return;
      if (result == 'notFound') _showMessage('No pudimos abrir esta cita.');
    } else if (action?.kind == 'session_activity') {
      // No hay un destino de detalle de actividad en esta fase.
    }
    if (mounted) setState(() => _markingId = null);
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.isNegative || difference.inSeconds < 60) return 'Ahora';
    if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
    final today = DateTime(now.year, now.month, now.day);
    final notificationDay = DateTime(date.year, date.month, date.day);
    if (today.difference(notificationDay).inDays == 1) {
      return 'Ayer';
    }
    if (difference.inDays < 7) return 'Hace ${difference.inDays} días';
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  IconData _iconFor(AppNotification notification) {
    if (notification.action?.kind == 'appointment' ||
        notification.event.startsWith('appointment_') ||
        notification.event == 'therapist_reschedule_proposed') {
      return Icons.calendar_today_outlined;
    }
    if (notification.action?.kind == 'session_activity' ||
        notification.event.startsWith('session_activity_')) {
      return Icons.assignment_outlined;
    }
    return Icons.notifications_none_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(_unreadCount),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Notificaciones'),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markingAll ? null : _markAll,
              child: _markingAll
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Marcar todas como leídas'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error && _notifications.isEmpty
          ? _ErrorState(onRetry: _load)
          : RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: _notifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 170),
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 40,
                          color: AppTheme.primarySoft,
                        ),
                        SizedBox(height: 14),
                        Center(
                          child: Text(
                            'Todavía no tienes notificaciones',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 36),
                          child: Text(
                            'Aquí aparecerán novedades sobre tus citas y actividades.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      itemCount: _notifications.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _NotificationTile(
                          notification: notification,
                          dateLabel: _relativeDate(notification.createdAt),
                          icon: _iconFor(notification),
                          onTap: () => _openNotification(notification),
                        );
                      },
                    ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.dateLabel,
    required this.icon,
    required this.onTap,
  });

  final AppNotification notification;
  final String dateLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: notification.read ? colors.surface : const Color(0xFFEEF4F0),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: notification.read
                    ? Icon(icon, size: 20, color: colors.primary)
                    : Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: notification.read
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      dateLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 38,
            color: AppTheme.primarySoft,
          ),
          const SizedBox(height: 14),
          const Text(
            'No pudimos cargar tus notificaciones.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

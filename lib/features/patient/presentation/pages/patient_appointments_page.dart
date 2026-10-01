import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/patient_appointment.dart';
import '../../data/models/patient_appointments_data.dart';
import '../../data/repositories/patient_appointments_repository.dart';
import '../widgets/patient_bottom_navigation.dart';

class PatientAppointmentsPage extends StatefulWidget {
  const PatientAppointmentsPage({
    super.key,
    required this.repository,
    required this.appointmentsRepository,
  });

  final AuthRepository repository;
  final PatientAppointmentsRepository appointmentsRepository;

  @override
  State<PatientAppointmentsPage> createState() =>
      _PatientAppointmentsPageState();
}

class _PatientAppointmentsPageState extends State<PatientAppointmentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  PatientAppointmentsData? _data;
  bool _loading = true;
  bool _networkError = false;
  bool _forbidden = false;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _networkError = false;
      _forbidden = false;
    });

    try {
      final data = await widget.appointmentsRepository.loadAppointments();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        try {
          await widget.repository.invalidateSession();
        } catch (_) {
          // Continue to login if secure-storage cleanup fails.
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
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Mis citas'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final created = await Navigator.of(context)
                  .pushNamed(AppRoutes.patientBookAppointment);
              if (created == true) _loadAppointments();
            },
            icon: const Icon(Icons.add),
            label: const Text('Solicitar cita'),
          ),
        ],
      ),
      bottomNavigationBar: PatientBottomNavigation(
        currentRoute: AppRoutes.patientAppointments,
        user: widget.repository.currentUser,
      ),
      body: SafeArea(
        bottom: false,
        child: _forbidden
            ? const Center(child: Text('No tienes acceso a estas citas.'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mis citas',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Consulta tus próximas sesiones y tu historial.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_networkError)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _AppointmentError(onRetry: _loadAppointments),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: TabBar(
                        controller: _tabs,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        labelColor: colors.onPrimaryContainer,
                        unselectedLabelColor: colors.onSurfaceVariant,
                        tabs: const [
                          Tab(text: 'Próximas'),
                          Tab(text: 'Historial'),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _appointmentList(
                          _data?.upcoming ?? const [],
                          emptyTitle: 'No tienes próximas citas.',
                          emptyMessage: 'Cuando tengas una sesión agendada, aparecerá aquí.',
                        ),
                        _appointmentList(
                          _data?.history ?? const [],
                          emptyTitle: 'Aún no tienes citas anteriores.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _appointmentList(
    List<PatientAppointment> appointments, {
    required String emptyTitle,
    String? emptyMessage,
  }) => RefreshIndicator(
    onRefresh: _loadAppointments,
    child: appointments.isEmpty
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 132),
            children: [
              _EmptyAppointments(title: emptyTitle, message: emptyMessage),
            ],
          )
        : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 132),
            itemCount: appointments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _AppointmentCard(
              appointment: appointments[index],
              onTap: appointments[index].id == null
                  ? null
                  : () async {
                      final result = await Navigator.of(context).pushNamed(
                        AppRoutes.patientAppointmentDetail,
                        arguments: appointments[index].id,
                      );
                      if (!context.mounted) return;
                      if (result == 'proposalAccepted') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nuevo horario confirmado.'),
                          ),
                        );
                      } else if (result == 'rescheduled') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tu cita fue reagendada.'),
                          ),
                        );
                      } else if (result == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tu cita fue cancelada.'),
                          ),
                        );
                      } else if (result == 'notFound') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Esta cita ya no está disponible.'),
                          ),
                        );
                      }
                      _loadAppointments();
                    },
            ),
          ),
  );
}

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments({required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, size: 34, color: colors.primary),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppointmentError extends StatelessWidget {
  const _AppointmentError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: colors.primary),
          const SizedBox(width: 10),
          const Expanded(child: Text('No pudimos cargar tus citas.')),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, this.onTap});

  final PatientAppointment appointment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final therapist = appointment.therapist;
    final proposal = appointment.rescheduleProposal;
    final hasProposal = proposal?.status == 'pending_patient';

    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dateAndTime(appointment),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_present(appointment.status))
                    _StatusChip(status: appointment.status!),
                ],
              ),
              if (_present(appointment.modality)) ...[
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.place_outlined,
                  text: _friendlyModality(appointment.modality!),
                ),
              ],
              if (therapist != null && _present(therapist.displayName)) ...[
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.person_outline,
                  text: therapist.displayName,
                ),
              ],
              if (_present(therapist?.especialidad)) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Text(
                    therapist!.especialidad!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              if (hasProposal) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cambio de horario pendiente',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onTertiaryContainer,
                        ),
                      ),
                      if (_present(proposal?.proposedDate)) ...[
                        const SizedBox(height: 4),
                        Text(
                          _friendlyDate(proposal!.proposedDate!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 11),
      Expanded(child: Text(text)),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _friendlyStatus(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _dateAndTime(PatientAppointment appointment) {
  final date = _present(appointment.date)
      ? _friendlyDate(appointment.date!)
      : null;
  final time = _present(appointment.time) ? appointment.time : null;
  if (date != null && time != null) return '$date · $time';
  return date ?? time ?? 'Sesión';
}

String _friendlyDate(String raw) {
  final datePart = raw.split('T').first;
  final dateParts = datePart.split('-');
  if (dateParts.length != 3) return raw;
  final date = '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}';
  if (!raw.contains('T')) return date;

  final timePart = raw.split('T').elementAtOrNull(1);
  if (timePart == null) return date;
  final time = timePart.split(RegExp(r'[+-]|Z')).first;
  final hourAndMinute = time.split(':');
  if (hourAndMinute.length < 2) return date;
  return '$date · ${hourAndMinute[0]}:${hourAndMinute[1]}';
}

String _friendlyStatus(String status) => switch (status.toLowerCase()) {
  'pendiente' => 'Pendiente',
  'confirmada' || 'confirmado' => 'Confirmada',
  'aceptada' || 'aceptado' => 'Aceptada',
  _ => status,
};

String _friendlyModality(String modality) => switch (modality.toLowerCase()) {
  'virtual' || 'online' => 'En línea',
  'presencial' => 'Presencial',
  'hibrida' || 'híbrida' => 'Híbrida',
  _ => modality,
};

bool _present(String? value) => value != null && value.trim().isNotEmpty;

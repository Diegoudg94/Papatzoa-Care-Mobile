import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/patient_appointment.dart';
import '../../data/repositories/patient_appointments_repository.dart';
import 'appointment_slot_picker.dart';
import 'patient_reschedule_appointment_page.dart';

class PatientAppointmentDetailPage extends StatefulWidget {
  const PatientAppointmentDetailPage({
    super.key,
    required this.repository,
    required this.appointmentsRepository,
    required this.appointmentId,
  });

  final AuthRepository repository;
  final PatientAppointmentsRepository appointmentsRepository;
  final int appointmentId;

  @override
  State<PatientAppointmentDetailPage> createState() =>
      _PatientAppointmentDetailPageState();
}

class _PatientAppointmentDetailPageState
    extends State<PatientAppointmentDetailPage> {
  PatientAppointment? _appointment;
  bool _loading = true;
  bool _notFound = false;
  bool _error = false;
  bool _cancelling = false;
  bool _accepting = false;
  bool _proposalSlotUnavailable = false;
  String? _proposalMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
      _notFound = false;
      _appointment = null;
    });
    final request = widget.appointmentsRepository.getAppointment(
      widget.appointmentId,
    );
    try {
      final appointment = await request;
      if (mounted) setState(() => _appointment = appointment);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        try {
          await widget.repository.invalidateSession();
        } catch (_) {}
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        }
      } else if (mounted) {
        setState(() {
          _notFound = error.statusCode == 404;
          _error = error.statusCode != 404;
        });
      }
    } on NetworkException {
      if (mounted) setState(() => _error = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openReschedule() async {
    final appointment = _appointment;
    if (appointment == null || appointment.id == null) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PatientRescheduleAppointmentPage(
          repository: widget.repository,
          appointmentsRepository: widget.appointmentsRepository,
          appointment: appointment,
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'rescheduled' || result == 'notFound') {
      Navigator.of(context).pop(result);
    } else if (result != null && result.startsWith('refresh:')) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.substring('refresh:'.length))),
        );
      }
    }
  }

  Future<void> _cancelEntry() async {
    if (_cancelling || _appointment == null) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Necesitas cambiar tu cita?'),
        content: const Text(
          'Si este horario ya no te funciona, puedes elegir uno nuevo en lugar de cancelar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Continuar con cancelación'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'reschedule'),
            child: const Text('Reagendar cita'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'reschedule') await _openReschedule();
    if (choice == 'cancel' && mounted) await _confirmCancellation();
  }

  Future<void> _confirmCancellation() async {
    if (_cancelling || _accepting || _appointment == null) return;
    final appointment = _appointment!;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _CancelDialog(appointment: appointment),
    );
    if (!mounted || reason == null || _cancelling) return;
    setState(() => _cancelling = true);
    try {
      await widget.appointmentsRepository.cancelAppointment(
        appointmentId: widget.appointmentId,
        reason: reason,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        try {
          await widget.repository.invalidateSession();
        } catch (_) {}
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        }
      } else if (error.statusCode == 404) {
        if (mounted) Navigator.of(context).pop('notFound');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.statusCode == 422
                  ? error.message
                  : 'No pudimos cancelar la cita. Intenta nuevamente.',
            ),
          ),
        );
        if (error.statusCode == 422) await _load();
      }
    } on NetworkException {
      if (mounted) _showCancellationNetworkError();
    } catch (_) {
      if (mounted) _showCancellationNetworkError();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _acceptProposal() async {
    final appointment = _appointment;
    final proposal = appointment?.rescheduleProposal;
    if (_accepting ||
        _cancelling ||
        _proposalSlotUnavailable ||
        appointment?.id == null ||
        proposal?.status != 'pending_patient') {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Aceptar este nuevo horario?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Horario propuesto: ${_proposedSchedule(proposal!)}'),
            if (_present(appointment!.therapist?.displayName))
              Text('Terapeuta: ${appointment.therapist!.displayName}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Aceptar horario'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _accepting) return;
    setState(() {
      _accepting = true;
      _proposalMessage = null;
    });
    try {
      await widget.appointmentsRepository.acceptRescheduleProposal(
        appointmentId: appointment!.id!,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Nuevo horario confirmado'),
          content: const Text('Tu cita fue actualizada correctamente.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ver mis citas'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop('proposalAccepted');
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        try {
          await widget.repository.invalidateSession();
        } catch (_) {}
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        }
        return;
      }
      if (error.statusCode == 404) {
        if (mounted) Navigator.of(context).pop('notFound');
        return;
      }
      if (error.statusCode == 409) {
        _proposalSlotUnavailable = true;
        await _load();
        if (mounted) {
          setState(
            () => _proposalMessage = 'Ese horario ya no está disponible.',
          );
        }
      } else if (error.statusCode == 422) {
        await _load();
        if (mounted) setState(() => _proposalMessage = error.message);
      } else if (mounted) {
        setState(() => _proposalMessage = error.message);
      }
    } on NetworkException {
      if (mounted) {
        setState(
          () => _proposalMessage =
              'No pudimos aceptar el nuevo horario. Intenta nuevamente.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _proposalMessage =
              'No pudimos aceptar el nuevo horario. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  void _showCancellationNetworkError() => ScaffoldMessenger.of(context)
      .showSnackBar(
        const SnackBar(
          content: Text('No pudimos cancelar la cita. Intenta nuevamente.'),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la cita')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _notFound
            ? const _MessageCard(message: 'Esta cita ya no está disponible.')
            : _error
            ? _MessageCard(
                message: 'No pudimos cargar esta cita.',
                action: TextButton(
                  onPressed: _load,
                  child: const Text('Reintentar'),
                ),
              )
            : _appointment == null
            ? const SizedBox.shrink()
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    Text(
                      'Tu sesión',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    _SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(
                            icon: Icons.calendar_month_outlined,
                            label: 'Fecha',
                            value: _friendlyDate(_appointment!.date),
                          ),
                          _InfoRow(
                            icon: Icons.schedule_outlined,
                            label: 'Hora',
                            value: _friendlyTime(
                              _appointment!.time,
                              _appointment!.date,
                            ),
                          ),
                          _InfoRow(
                            icon: Icons.circle_outlined,
                            label: 'Estado',
                            value: _friendlyStatus(_appointment!.status),
                          ),
                          _InfoRow(
                            icon: Icons.place_outlined,
                            label: 'Modalidad',
                            value: _friendlyModality(_appointment!.modality),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _therapistCard(context, _appointment!.therapist),
                    if (_appointment!.rescheduleProposal?.status ==
                            'pending_patient' &&
                        reschedulableStatus(_appointment!.status)) ...[
                      const SizedBox(height: 14),
                      _proposalCard(
                        context,
                        _appointment!,
                        accepting: _accepting,
                        cancelling: _cancelling,
                        slotUnavailable: _proposalSlotUnavailable,
                        message: _proposalMessage,
                        onAccept: _acceptProposal,
                        onChooseOther: _openReschedule,
                        onCancel: _confirmCancellation,
                      ),
                    ],
                    if (_proposalMessage != null &&
                        _appointment!.rescheduleProposal?.status !=
                            'pending_patient')
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          _proposalMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_present(_appointment!.reason)) ...[
                      const SizedBox(height: 14),
                      _SurfaceCard(
                        child: _InfoRow(
                          icon: Icons.notes_outlined,
                          label: 'Motivo de la cita',
                          value: _appointment!.reason!.trim(),
                        ),
                      ),
                    ],
                    if (reschedulableStatus(_appointment!.status) &&
                        _appointment!.rescheduleProposal?.status !=
                            'pending_patient') ...[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _cancelling ? null : _openReschedule,
                        icon: const Icon(Icons.event_repeat),
                        label: const Text('Reagendar cita'),
                      ),
                    ],
                    if (_canOfferCancellation(_appointment!.status) &&
                        _appointment!.rescheduleProposal?.status !=
                            'pending_patient') ...[
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _cancelling ? null : _cancelEntry,
                        icon: _cancelling
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.event_busy_outlined),
                        label: Text(
                          _cancelling ? 'Cancelando...' : 'Cancelar cita',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.error,
                          ),
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

bool _canOfferCancellation(String? status) {
  final normalized = status?.trim().toLowerCase();
  return normalized != 'cancelada' &&
      normalized != 'cancelado' &&
      normalized != 'rechazada' &&
      normalized != 'rechazado' &&
      normalized != 'reagendada' &&
      normalized != 'reagendado' &&
      normalized != 'completada' &&
      normalized != 'completado';
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.appointment});
  final PatientAppointment appointment;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('¿Quieres cancelar esta cita?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_present(widget.appointment.date))
            Text('Fecha: ${_friendlyDate(widget.appointment.date)}'),
          if (_friendlyTime(widget.appointment.time, widget.appointment.date) !=
              null)
            Text(
              'Hora: ${_friendlyTime(widget.appointment.time, widget.appointment.date)}',
            ),
          if (_present(widget.appointment.therapist?.displayName))
            Text('Terapeuta: ${widget.appointment.therapist!.displayName}'),
          const SizedBox(height: 12),
          const Text('Este horario volverá a estar disponible.'),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            decoration: const InputDecoration(
              labelText: 'Motivo de cancelación (opcional)',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 4,
            maxLength: 4000,
            inputFormatters: [LengthLimitingTextInputFormatter(4000)],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Volver'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_reason.text),
        child: const Text('Cancelar cita'),
      ),
    ],
  );
}

Widget _therapistCard(
  BuildContext context,
  PatientAppointmentTherapist? therapist,
) {
  final colors = Theme.of(context).colorScheme;
  if (therapist == null) {
    return const _SurfaceCard(
      child: Text('La información del terapeuta no está disponible.'),
    );
  }
  final name = therapist.displayName;
  return _SurfaceCard(
    child: Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: colors.primaryContainer,
          foregroundImage: _present(therapist.profilePhoto)
              ? NetworkImage(therapist.profilePhoto!)
              : null,
          child: !_present(therapist.profilePhoto)
              ? Icon(Icons.person_outline, color: colors.onPrimaryContainer)
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu terapeuta',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (_present(name))
                Text(name, style: Theme.of(context).textTheme.titleMedium),
              if (_present(therapist.especialidad))
                Text(
                  therapist.especialidad!,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _proposalCard(
  BuildContext context,
  PatientAppointment appointment, {
  required bool accepting,
  required bool cancelling,
  required bool slotUnavailable,
  required String? message,
  required VoidCallback onAccept,
  required VoidCallback onChooseOther,
  required VoidCallback onCancel,
}) {
  final colors = Theme.of(context).colorScheme;
  final proposal = appointment.rescheduleProposal!;
  final busy = accepting || cancelling;
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: colors.tertiaryContainer,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Nuevo horario propuesto',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.onTertiaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tu terapeuta propuso un nuevo horario.',
          style: TextStyle(color: colors.onTertiaryContainer),
        ),
        const SizedBox(height: 16),
        Text('Horario actual: ${_currentSchedule(appointment)}'),
        Text('Horario propuesto: ${_proposedSchedule(proposal)}'),
        Text(
          'Modalidad: ${_friendlyModality(appointment.modality) ?? 'Sin información'}',
        ),
        Text(
          'Terapeuta: ${_present(appointment.therapist?.displayName) ? appointment.therapist!.displayName : 'Sin información'}',
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: colors.error)),
        ],
        const SizedBox(height: 16),
        if (!slotUnavailable)
          FilledButton(
            onPressed: busy ? null : onAccept,
            child: accepting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Aceptar nuevo horario'),
          ),
        if (slotUnavailable)
          FilledButton(
            onPressed: busy ? null : onChooseOther,
            child: const Text('Elegir otro horario'),
          )
        else
          OutlinedButton(
            onPressed: busy ? null : onChooseOther,
            child: const Text('Elegir otro horario'),
          ),
        TextButton(
          onPressed: busy ? null : onCancel,
          style: TextButton.styleFrom(foregroundColor: colors.error),
          child: const Text('Cancelar cita'),
        ),
      ],
    ),
  );
}

String _currentSchedule(PatientAppointment appointment) {
  final date = appointment.date;
  if (!_present(date)) return 'Sin información';
  final day = appointmentDayLabel(date!.split('T').first);
  final time = _friendlyTime(appointment.time, date);
  return time == null ? day : '$day · $time';
}

String _proposedSchedule(PatientRescheduleProposal proposal) {
  final start = proposal.proposedDate;
  if (!_present(start)) return 'Sin información';
  final day = appointmentDayLabel(start!.split('T').first);
  final startTime = start.contains('T') ? appointmentSlotTime(start) : null;
  final end = proposal.proposedEnd;
  final endTime = _present(end) && end!.contains('T')
      ? appointmentSlotTime(end)
      : null;
  if (startTime == null) return day;
  return '$day · $startTime${endTime == null ? '' : '–$endTime'}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (!_present(value)) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value!, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.action});
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: _SurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            ?action,
          ],
        ),
      ),
    ),
  );
}

String? _friendlyDate(String? raw) {
  if (!_present(raw)) return null;
  final parsed = DateTime.tryParse(raw!);
  if (parsed == null) return raw;
  return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
}

String? _friendlyTime(String? time, String? date) {
  if (_present(time)) {
    final parts = time!.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }
  if (!_present(date)) return null;
  final parsed = DateTime.tryParse(date!);
  return parsed == null
      ? null
      : '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
}

String? _friendlyStatus(String? status) {
  if (!_present(status)) return null;
  return switch (status!.toLowerCase()) {
    'pendiente' => 'Pendiente',
    'confirmada' || 'confirmado' => 'Confirmada',
    'aceptada' || 'aceptado' => 'Aceptada',
    _ => status,
  };
}

String? _friendlyModality(String? modality) {
  if (!_present(modality)) return null;
  return switch (modality!.toLowerCase()) {
    'virtual' || 'online' => 'En línea',
    'presencial' => 'Presencial',
    'hibrida' || 'híbrida' => 'Híbrida',
    _ => modality,
  };
}

bool _present(String? value) => value != null && value.trim().isNotEmpty;

import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/appointment_availability.dart';
import '../../data/models/patient_appointment.dart';
import '../../data/repositories/patient_appointments_repository.dart';
import 'appointment_slot_picker.dart';

class PatientRescheduleAppointmentPage extends StatefulWidget {
  const PatientRescheduleAppointmentPage({
    super.key,
    required this.repository,
    required this.appointmentsRepository,
    required this.appointment,
  });
  final AuthRepository repository;
  final PatientAppointmentsRepository appointmentsRepository;
  final PatientAppointment appointment;

  @override
  State<PatientRescheduleAppointmentPage> createState() =>
      _PatientRescheduleAppointmentPageState();
}

class _PatientRescheduleAppointmentPageState
    extends State<PatientRescheduleAppointmentPage> {
  late DateTime _from = DateUtils.dateOnly(DateTime.now());
  AppointmentAvailability? _availability;
  AvailabilitySlot? _slot;
  String? _error;
  bool _loading = false;
  bool _submitting = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _requestId++;
    super.dispose();
  }

  Future<void> _sessionExpired() async {
    try {
      await widget.repository.invalidateSession();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }

  Future<void> _load({bool clearSelection = true}) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      if (clearSelection) _slot = null;
    });
    try {
      final availability = await widget.appointmentsRepository.getAvailability(
        _from,
        _from.add(const Duration(days: 13)),
      );
      if (!mounted || id != _requestId) return;
      setState(() => _availability = availability);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionExpired();
        return;
      }
      if (mounted && id == _requestId) setState(() => _error = error.message);
    } on NetworkException {
      if (mounted && id == _requestId) {
        setState(() => _error = 'No pudimos consultar los horarios.');
      }
    } catch (_) {
      if (mounted && id == _requestId) {
        setState(() => _error = 'No pudimos consultar los horarios.');
      }
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final slot = _slot;
    final appointmentId = widget.appointment.id;
    if (_submitting ||
        slot?.start == null ||
        slot?.end == null ||
        appointmentId == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Reagendar tu cita?'),
        content: const Text(
          'Tu horario anterior quedará disponible y se solicitará el nuevo horario seleccionado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar reagendamiento'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await widget.appointmentsRepository.rescheduleAppointment(
        appointmentId: appointmentId,
        start: slot!.start!,
        end: slot.end!,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            created.status == 'pendiente'
                ? 'Solicitud de cambio enviada'
                : 'Cita reagendada',
          ),
          content: Text(
            created.status == 'pendiente'
                ? 'Tu terapeuta debe confirmar el nuevo horario.'
                : 'Tu nuevo horario quedó confirmado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ver mis citas'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, 'rescheduled');
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionExpired();
        return;
      }
      if (error.statusCode == 404) {
        if (mounted) Navigator.pop(context, 'notFound');
        return;
      }
      if (error.statusCode == 409) {
        await _load();
        if (mounted) {
          setState(
            () => _error = 'Ese horario acaba de dejar de estar disponible.',
          );
        }
      } else if (mounted) {
        setState(() => _error = error.message);
        if (error.statusCode == 422) {
          try {
            final latest = await widget.appointmentsRepository.getAppointment(
              appointmentId,
            );
            if (!mounted) return;
            if (!reschedulableStatus(latest.status)) {
              Navigator.pop(context, 'refresh:${error.message}');
            }
          } catch (_) {
            if (mounted) Navigator.pop(context, 'refresh:${error.message}');
          }
        }
      }
    } on NetworkException {
      if (mounted) {
        setState(
          () => _error = 'No pudimos reagendar la cita. Intenta nuevamente.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos reagendar la cita. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final therapist = appointment.therapist?.displayName ?? '';
    final currentDate = appointment.date == null
        ? 'Sin información'
        : appointmentDayLabel(appointment.date!.split('T').first);
    final currentTime =
        appointment.time?.substring(
          0,
          appointment.time!.length < 5 ? appointment.time!.length : 5,
        ) ??
        (appointment.date != null && appointment.date!.contains('T')
            ? appointmentSlotTime(appointment.date!)
            : 'Sin información');
    final modality = appointment.modality == null
        ? 'Sin información'
        : appointmentModalityLabel(appointment.modality!);
    final newDate = _slot == null
        ? 'Sin seleccionar'
        : appointmentDayLabel(_slot!.start!.substring(0, 10));
    final newTime = _slot == null
        ? 'Sin seleccionar'
        : appointmentSlotTime(_slot!.start!);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reagendar cita')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Elige un nuevo horario para tu cita.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Horario actual', style: theme.textTheme.titleMedium),
                    Text('$currentDate · $currentTime'),
                    Text(
                      'Terapeuta: ${therapist.isEmpty ? 'Sin información' : therapist}',
                    ),
                    Text('Modalidad: $modality'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            AppointmentSlotPicker(
              from: _from,
              availability: _availability,
              selectedSlot: _slot,
              loading: _loading,
              submitting: _submitting,
              error: _error,
              onPrevious: () {
                setState(
                  () => _from = _from.subtract(const Duration(days: 14)),
                );
                _load();
              },
              onNext: () {
                setState(() => _from = _from.add(const Duration(days: 14)));
                _load();
              },
              onRetry: () => _load(clearSelection: false),
              onSelected: (slot) => setState(() => _slot = slot),
            ),
            const SizedBox(height: 24),
            Text('Resumen', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Horario actual: $currentDate · $currentTime'),
            Text('Nuevo horario: $newDate · $newTime'),
            Text('Modalidad: $modality'),
            Text(
              'Terapeuta: ${therapist.isEmpty ? 'Sin información' : therapist}',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting || _loading || _slot == null
                  ? null
                  : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar reagendamiento'),
            ),
          ],
        ),
      ),
    );
  }
}

bool reschedulableStatus(String? status) => const {
  'pendiente',
  'confirmada',
  'confirmado',
  'aceptada',
  'aceptado',
}.contains(status?.trim().toLowerCase());

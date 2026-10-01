import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/appointment_availability.dart';
import '../../data/repositories/patient_appointments_repository.dart';
import 'appointment_slot_picker.dart';

class PatientBookAppointmentPage extends StatefulWidget {
  const PatientBookAppointmentPage({
    super.key,
    required this.repository,
    required this.appointmentsRepository,
  });
  final AuthRepository repository;
  final PatientAppointmentsRepository appointmentsRepository;

  @override
  State<PatientBookAppointmentPage> createState() =>
      _PatientBookAppointmentPageState();
}

class _PatientBookAppointmentPageState
    extends State<PatientBookAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late DateTime _from = DateUtils.dateOnly(DateTime.now());
  AppointmentAvailability? _availability;
  AvailabilitySlot? _slot;
  String? _modality;
  String? _error;
  bool _loading = false;
  bool _submitting = false;
  int _requestId = 0;
  DateTime get _to => _from.add(const Duration(days: 13));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _requestId++;
    _reason.dispose();
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

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _slot = null;
    });
    try {
      final result = await widget.appointmentsRepository.getAvailability(
        _from,
        _to,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _availability = result;
        _modality = result.availableModalities.contains(_modality)
            ? _modality
            : result.availableModalities.length == 1
            ? result.availableModalities.first
            : null;
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionExpired();
        return;
      }
      if (mounted && id == _requestId) setState(() => _error = error.message);
    } on NetworkException catch (error) {
      if (mounted && id == _requestId) setState(() => _error = error.message);
    } catch (_) {
      if (mounted && id == _requestId) {
        setState(() => _error = 'No pudimos consultar los horarios.');
      }
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting ||
        _slot == null ||
        _modality == null ||
        !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await widget.appointmentsRepository.createAppointment(
        slot: _slot!,
        motivo: _reason.text.trim(),
        modalidad: _modality!,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Solicitud enviada'),
          content: Text(
            created.status == 'confirmada'
                ? 'Tu cita quedó confirmada.'
                : created.status == 'pendiente'
                ? 'Tu terapeuta debe confirmar la cita.'
                : 'Tu solicitud de cita se envió correctamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ver mis citas'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionExpired();
        return;
      }
      if (error.statusCode == 409) {
        if (mounted) setState(() => _slot = null);
        await _load();
        if (mounted) {
          setState(
            () => _error = 'Ese horario acaba de dejar de estar disponible.',
          );
        }
      } else if (mounted) {
        setState(() => _error = error.message);
      }
    } on NetworkException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos solicitar la cita. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availability = _availability;
    final therapist = availability?.therapist?.displayName ?? '';
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar cita')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (therapist.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Cita con $therapist',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              AppointmentSlotPicker(
                from: _from,
                availability: availability,
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
                onRetry: _load,
                onSelected: (slot) => setState(() => _slot = slot),
              ),
              const SizedBox(height: 24),
              Text('3. Modalidad', style: theme.textTheme.titleMedium),
              if (availability != null &&
                  availability.availableModalities.isEmpty)
                const Text('No hay modalidades disponibles.'),
              Wrap(
                spacing: 8,
                children: (availability?.availableModalities ?? [])
                    .map(
                      (value) => ChoiceChip(
                        label: Text(appointmentModalityLabel(value)),
                        selected: _modality == value,
                        onSelected: _submitting
                            ? null
                            : (_) => setState(() => _modality = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text('4. Motivo', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reason,
                maxLines: 4,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la cita',
                  helperText: 'Cuéntanos brevemente qué deseas tratar.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe el motivo de la cita.'
                    : value.length > 4000
                    ? 'Máximo 4000 caracteres.'
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                '5. Confirmar solicitud',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Fecha: ${_slot == null ? 'Sin seleccionar' : appointmentDayLabel(_slot!.start!.substring(0, 10))}',
              ),
              Text(
                'Hora: ${_slot == null ? 'Sin seleccionar' : appointmentSlotTime(_slot!.start!)}',
              ),
              Text(
                'Modalidad: ${_modality == null ? 'Sin seleccionar' : appointmentModalityLabel(_modality!)}',
              ),
              Text(
                'Terapeuta: ${therapist.isEmpty ? 'Sin información' : therapist}',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed:
                    _submitting ||
                        _loading ||
                        _slot == null ||
                        _modality == null
                    ? null
                    : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Solicitar cita'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

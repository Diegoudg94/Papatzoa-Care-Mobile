import 'package:flutter/material.dart';

import '../../data/models/appointment_availability.dart';

const appointmentMonths = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const appointmentWeekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

String appointmentDateLabel(DateTime date) =>
    '${date.day} de ${appointmentMonths[date.month - 1]}';
String appointmentDayLabel(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  final label =
      '${appointmentWeekdays[date.weekday - 1]} ${appointmentDateLabel(date)}';
  return '${label[0].toUpperCase()}${label.substring(1)}';
}

String appointmentSlotTime(String iso) =>
    iso.length >= 16 ? iso.substring(11, 16) : iso;
String appointmentModalityLabel(String value) => switch (value.toLowerCase()) {
  'online' || 'virtual' => 'En línea',
  'presencial' => 'Presencial',
  _ => value,
};

class AppointmentSlotPicker extends StatelessWidget {
  const AppointmentSlotPicker({
    super.key,
    required this.from,
    required this.availability,
    required this.selectedSlot,
    required this.loading,
    required this.submitting,
    required this.error,
    required this.onPrevious,
    required this.onNext,
    required this.onRetry,
    required this.onSelected,
  });
  final DateTime from;
  final AppointmentAvailability? availability;
  final AvailabilitySlot? selectedSlot;
  final bool loading;
  final bool submitting;
  final String? error;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final ValueChanged<AvailabilitySlot> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final to = from.add(const Duration(days: 13));
    final groups = <String, List<AvailabilitySlot>>{};
    for (final slot in availability?.slots ?? <AvailabilitySlot>[]) {
      if (slot.start == null || slot.end == null || slot.start!.length < 16) {
        continue;
      }
      groups.putIfAbsent(slot.start!.substring(0, 10), () => []).add(slot);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Text('1. Fecha', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '${appointmentDateLabel(from)} – ${appointmentDateLabel(to)}',
              ),
            ),
            IconButton(
              tooltip: 'Fechas anteriores',
              onPressed:
                  loading || !from.isAfter(DateUtils.dateOnly(DateTime.now()))
                  ? null
                  : onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Siguientes fechas',
              onPressed: loading ? null : onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (error != null && !loading)
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        if (!loading && availability != null && groups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No encontramos horarios disponibles en estas fechas.'),
          ),
        for (final entry in groups.entries) ...[
          const SizedBox(height: 12),
          Text(
            appointmentDayLabel(entry.key),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.value
                .map(
                  (slot) => ChoiceChip(
                    label: Text(appointmentSlotTime(slot.start!)),
                    selected: identical(selectedSlot, slot),
                    onSelected: submitting ? null : (_) => onSelected(slot),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 24),
        Text('2. Horario', style: theme.textTheme.titleMedium),
        Text(
          selectedSlot == null
              ? 'Elige un horario disponible.'
              : appointmentSlotTime(selectedSlot!.start!),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../data/models/patient_dashboard_data.dart';
import '../../data/repositories/patient_session_activity_repository.dart';

class PatientSessionActivityPage extends StatefulWidget {
  const PatientSessionActivityPage({super.key, required this.repository});
  final PatientSessionActivityRepository repository;

  @override
  State<PatientSessionActivityPage> createState() =>
      _PatientSessionActivityPageState();
}

class _PatientSessionActivityPageState
    extends State<PatientSessionActivityPage> {
  final _pager = PageController();
  final _comment = TextEditingController();
  DashboardActivity? _activity;
  String? _status;
  int _step = 0;
  bool _loading = true, _saving = false, _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pager.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activity = await widget.repository.current();
      if (mounted) {
        setState(() {
          _activity = activity;
          _status = activity?.response?.status == 'intentada'
              ? 'intentada'
              : null;
          _comment.text = activity?.response?.comment ?? '';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos cargar tu actividad.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _go(int target) {
    if (_saving || target < 0 || target > 3) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _step = target;
      _error = null;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _pager.jumpToPage(target);
    } else {
      _pager.animateToPage(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _submit() async {
    if (_saving || _activity?.id == null || _status == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.respond(_activity!.id!, _status!, _comment.text);
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos guardar tu respuesta.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _content(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    ),
  );

  Widget _section(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activity = _activity;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad entre sesiones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Atrás',
          onPressed: _saving
              ? null
              : () {
                  if (_step == 0 || _sent) {
                    Navigator.pop(context, _sent);
                  } else {
                    _go(_step - 1);
                  }
                },
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _sent
            ? _content(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: colors.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Respuesta enviada',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text('Tu terapeuta podrá verla en tu seguimiento.'),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Volver al inicio'),
                    ),
                  ],
                ),
              )
            : _error != null && activity == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            : activity == null
            ? const Center(
                child: Text(
                  'Cuando tu terapeuta te deje una actividad, aparecerá aquí.',
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                    child: Text(
                      'Paso ${_step + 1} de 4',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pager,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _content(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tu actividad',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 24),
                              _section(
                                'Tu terapeuta te propuso:',
                                activity.title ?? '',
                              ),
                              if ((activity.instructions ?? '').isNotEmpty)
                                _section('', activity.instructions!),
                              if ((activity.objective ?? '').isNotEmpty)
                                _section('Objetivo', activity.objective!),
                            ],
                          ),
                        ),
                        _content(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¿Cómo avanzaste con esta actividad?',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 24),
                              for (final choice in [
                                ('intentada', 'La intenté'),
                                ('realizada', 'La realicé'),
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Card(
                                    color: _status == choice.$1
                                        ? colors.primaryContainer
                                        : colors.surface,
                                    child: InkWell(
                                      onTap: () =>
                                          setState(() => _status = choice.$1),
                                      child: Padding(
                                        padding: const EdgeInsets.all(18),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _status == choice.$1
                                                  ? Icons.radio_button_checked
                                                  : Icons
                                                        .radio_button_unchecked,
                                              color: colors.primary,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(choice.$2),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _content(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¿Cómo te fue?',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Si quieres, puedes contarle a tu terapeuta cómo viviste la actividad.',
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _comment,
                                maxLines: 7,
                                maxLength: 3000,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Puedes contarle a tu terapeuta cómo viviste la actividad.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        _content(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Revisar',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 24),
                              _section('Tu actividad', activity.title ?? ''),
                              _section(
                                'Tu avance',
                                _status == 'intentada'
                                    ? 'La intenté'
                                    : 'La realicé',
                              ),
                              _section(
                                'Cómo te fue',
                                _comment.text.trim().isEmpty
                                    ? 'No agregaste comentarios.'
                                    : _comment.text.trim(),
                              ),
                              const Text(
                                'Tu respuesta será compartida con tu terapeuta.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _error!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving || (_step == 1 && _status == null)
                            ? null
                            : (_step == 3 ? _submit : () => _go(_step + 1)),
                        child: Text(
                          _saving
                              ? 'Guardando respuesta…'
                              : _step == 3
                              ? (_error == null
                                    ? 'Enviar respuesta'
                                    : 'Intentar de nuevo')
                              : 'Continuar',
                        ),
                      ),
                    ),
                  ),
                  if (_step == 3)
                    TextButton(
                      onPressed: _saving ? null : () => _go(2),
                      child: const Text('Volver'),
                    ),
                ],
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/diary_options.dart';
import '../../data/repositories/patient_diary_repository.dart';

class PatientDiaryNewPage extends StatefulWidget {
  const PatientDiaryNewPage({
    super.key,
    required this.repository,
    required this.diaryRepository,
  });
  final AuthRepository repository;
  final PatientDiaryRepository diaryRepository;
  @override
  State<PatientDiaryNewPage> createState() => _PatientDiaryNewPageState();
}

class _PatientDiaryNewPageState extends State<PatientDiaryNewPage> {
  final _pager = PageController();
  final _custom = TextEditingController();
  final _situation = TextEditingController();
  final _thought = TextEditingController();
  final _behavior = TextEditingController();
  final _restructuring = TextEditingController();
  final _interpretations = <String>{};
  DiaryOptions? _options;
  String? _emotion, _error;
  int? _intensity;
  int _step = 0;
  bool _loading = true, _saving = false, _leaving = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _pager.dispose();
    for (final c in [
      _custom,
      _situation,
      _thought,
      _behavior,
      _restructuring,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasDraft =>
      _emotion != null ||
      _intensity != null ||
      _interpretations.isNotEmpty ||
      [
        _custom,
        _situation,
        _thought,
        _behavior,
        _restructuring,
      ].any((c) => c.text.trim().isNotEmpty);

  String get _interpretationValue => _options!.interpretations
      .where((option) => _interpretations.contains(option.value))
      .map((option) => option.value)
      .join(', ');

  Future<void> _sessionExpired() async {
    try {
      await widget.repository.invalidateSession();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.diaryRepository.getDiaryOptions();
      if (mounted) setState(() => _options = result);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _sessionExpired();
        return;
      }
      if (mounted) {
        setState(() => _error = 'No pudimos cargar las opciones del diario.');
      }
    } on NetworkException {
      if (mounted) {
        setState(() => _error = 'No pudimos cargar las opciones del diario.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exit() async {
    if (_saving) return;
    final leave =
        !_hasDraft ||
        await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('¿Salir sin guardar?'),
                content: const Text(
                  'Lo que escribiste en este registro no se guardará.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Seguir escribiendo'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Salir'),
                  ),
                ],
              ),
            ) ==
            true;
    if (leave && mounted) {
      _leaving = true;
      Navigator.of(context).pop();
    }
  }

  void _go(int target) {
    if (target < 0 || target > 7 || _saving) return;
    if (_step == 0 && target > 0) {
      if (_emotion == null) {
        setState(() => _error = 'Selecciona una emoción.');
        return;
      }
      if (_emotion == 'Otro' &&
          (_custom.text.trim().isEmpty || _custom.text.trim().length > 100)) {
        setState(() => _error = 'Escribe una emoción de hasta 100 caracteres.');
        return;
      }
    }
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.diaryRepository.createDiaryEntry(
        emotion: _emotion!,
        customEmotion: _emotion == 'Otro' ? _custom.text : null,
        intensity: _intensity,
        situation: _situation.text,
        thought: _thought.text,
        behavior: _behavior.text,
        interpretation: _interpretationValue,
        restructuring: _restructuring.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _sessionExpired();
        return;
      }
      if (mounted) {
        setState(
          () => _error = e.statusCode == 422
              ? e.message
              : 'No pudimos guardar tu registro. Intenta nuevamente.',
        );
      }
    } on NetworkException {
      if (mounted) {
        setState(
          () => _error = 'No pudimos guardar tu registro. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _help() {
    const tips = [
      'Ponle nombre a lo que sentiste. No hay respuestas correctas o incorrectas.',
      'Puedes dejar la intensidad sin especificar.',
      'Empieza por lo que ocurrió. Sé específico cuando puedas.',
      'Escribe lo primero que recuerdes. No necesitas encontrar las palabras perfectas.',
      'Piensa en lo que hiciste después, aunque parezca algo pequeño.',
      'Estas opciones describen patrones de pensamiento. Elige las que se parezcan a lo que pensaste.',
      '¿Existe otra explicación posible? No tienes que obligarte a pensar en positivo.',
      'Este espacio sirve para entender mejor cómo viviste la situación.',
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Necesitas ayuda?',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(tips[_step]),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _example();
                },
                child: const Text('Ver un ejemplo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _example() {
    const example = [
      (
        'Situación',
        'Andrea escribió a una amiga para invitarla a salir. Pasaron horas sin respuesta.',
      ),
      ('Pensamiento', '“Seguro está molesta conmigo. Tal vez hice algo mal.”'),
      ('Emoción e intensidad', '😰 Ansiedad · 7/10'),
      (
        'Lo que hizo',
        'Revisó varias veces el teléfono y pensó en enviar otro mensaje.',
      ),
      (
        'Cómo lo interpretó',
        'Creyó saber lo que su amiga pensaba sin confirmarlo.',
      ),
      (
        'Otra forma de verlo',
        '“No sé por qué no ha respondido. Puede estar ocupada. Puedo esperar antes de asumir lo peor.”',
      ),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .78,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Ver un ejemplo', style: Theme.of(ctx).textTheme.titleLarge),
              const Text('Andrea es un personaje hipotético.'),
              const SizedBox(height: 12),
              for (final item in example) _summary(item.$1, item.$2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 22),
    ],
  );
  Widget _textStep(
    String title,
    String subtitle,
    String hint,
    TextEditingController controller,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(title, subtitle),
      TextField(
        controller: controller,
        minLines: 4,
        maxLines: 7,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    ],
  );
  Widget _summary(String title, String? value, {int? edit}) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  value?.trim().isNotEmpty == true ? value! : 'Sin registrar',
                ),
              ],
            ),
          ),
          if (edit != null)
            TextButton(onPressed: () => _go(edit), child: const Text('Editar')),
        ],
      ),
    ),
  );
  Widget _choice(
    String label,
    bool selected,
    VoidCallback select, {
    String? description,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: InkWell(
      onTap: select,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  if (description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle),
          ],
        ),
      ),
    ),
  );

  Widget _body(int step, DiaryOptions options) {
    switch (step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
              '¿Cómo te sientes?',
              'Elige la emoción que más se acerque a lo que estás sintiendo.',
            ),
            for (final item in options.emotions)
              _choice(
                '${item.emoji}  ${item.value}',
                _emotion == item.value,
                () => setState(() {
                  _emotion = item.value;
                  _error = null;
                }),
              ),
            if (options.supportsCustomEmotion) ...[
              _choice(
                '➕  Otro',
                _emotion == 'Otro',
                () => setState(() {
                  _emotion = 'Otro';
                  _error = null;
                }),
              ),
              if (_emotion == 'Otro')
                TextField(
                  controller: _custom,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: '¿Cómo describirías lo que sientes?',
                    border: OutlineInputBorder(),
                  ),
                ),
            ],
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
              '¿Qué tan fuerte lo sientes?',
              'Muévelo hasta donde mejor represente cómo lo sientes.',
            ),
            Center(
              child: Text(
                _intensity == null
                    ? 'Sin especificar'
                    : '$_intensity / ${options.intensityMax}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Slider(
              value: (_intensity ?? options.intensityMin).toDouble(),
              min: options.intensityMin.toDouble(),
              max: options.intensityMax.toDouble(),
              divisions: options.intensityMax - options.intensityMin,
              label: '${_intensity ?? options.intensityMin}',
              onChanged: (v) => setState(() => _intensity = v.round()),
            ),
            if (options.intensityOptional)
              TextButton(
                onPressed: () => setState(() => _intensity = null),
                child: const Text('Dejar sin especificar'),
              ),
          ],
        );
      case 2:
        return _textStep(
          '¿Qué estaba pasando?',
          'Describe brevemente qué ocurrió.',
          'Ej: discutí con alguien…',
          _situation,
        );
      case 3:
        return _textStep(
          '¿Qué pasó por tu mente?',
          'Piensa en lo primero que pensaste en ese momento.',
          'Ej: voy a fracasar…',
          _thought,
        );
      case 4:
        return _textStep(
          '¿Qué hiciste después?',
          'Puedes contar cómo reaccionaste.',
          'Ej: me aislé, lloré…',
          _behavior,
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
              '¿Cómo interpretaste lo que pasó?',
              '¿Qué forma de pensar se parece más a lo que pasó por tu mente?',
            ),
            for (final item in options.interpretations)
              _choice(
                item.title,
                _interpretations.contains(item.value),
                () => setState(
                  () => _interpretations.contains(item.value)
                      ? _interpretations.remove(item.value)
                      : _interpretations.add(item.value),
                ),
                description: '${item.description}\n${item.technicalLabel}',
              ),
          ],
        );
      case 6:
        return _textStep(
          '¿Hay otra forma de verlo?',
          'Ahora que lo observas con un poco de distancia, ¿hay otra explicación posible?',
          'Tal vez no respondió porque estaba ocupada…',
          _restructuring,
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
              'Revisa tu registro',
              'Puedes volver a cualquier paso antes de registrar.',
            ),
            _summary(
              'Emoción',
              _emotion == 'Otro' ? _custom.text.trim() : _emotion,
              edit: 0,
            ),
            _summary(
              'Intensidad',
              _intensity == null
                  ? null
                  : '$_intensity / ${options.intensityMax}',
              edit: 1,
            ),
            _summary('Situación', _situation.text, edit: 2),
            _summary('Pensamiento', _thought.text, edit: 3),
            _summary('Lo que hice', _behavior.text, edit: 4),
            _summary('Cómo lo interpreté', _interpretationValue, edit: 5),
            _summary('Otra forma de verlo', _restructuring.text, edit: 6),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nuevo registro cognitivo'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cerrar',
            onPressed: _exit,
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : options == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error ?? 'No pudimos cargar las opciones del diario.',
                      ),
                      TextButton(
                        onPressed: _loadOptions,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paso ${_step + 1} de 8',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (_step + 1) / 8,
                            minHeight: 4,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pager,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 8,
                        itemBuilder: (ctx, index) => SingleChildScrollView(
                          key: PageStorageKey(index),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                          child: _body(index, options),
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_error?.contains('paso Emoción') == true)
                      TextButton(
                        onPressed: () => _go(0),
                        child: const Text('Ir a Emoción'),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Column(
                        children: [
                          if (_step == 7)
                            Card(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: .45),
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Este registro será compartido con tu terapeuta.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Tu terapeuta podrá consultar esta información y puede utilizarla para comprender mejor cómo viviste esta situación y orientar una próxima sesión.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _help,
                                icon: const Icon(Icons.help_outline),
                                label: const Text('¿Necesitas ayuda?'),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _example,
                                child: const Text('Ver un ejemplo'),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              if (_step > 0)
                                OutlinedButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _go(_step - 1),
                                  child: const Text('Volver'),
                                ),
                              const Spacer(),
                              FilledButton(
                                onPressed: _saving
                                    ? null
                                    : _step == 7
                                    ? _save
                                    : () => _go(_step + 1),
                                child: _saving
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _step == 7 ? 'Registrar' : 'Siguiente',
                                      ),
                              ),
                            ],
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

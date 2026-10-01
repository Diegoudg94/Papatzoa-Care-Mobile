import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/support_network_contact.dart';
import '../../data/models/support_network_options.dart';
import '../../data/repositories/patient_support_network_repository.dart';
import 'device_contact_picker.dart';
import 'patient_support_network_page.dart';
import 'support_contact_form_page.dart';

class SupportContactWizardPage extends StatefulWidget {
  const SupportContactWizardPage({
    super.key,
    required this.repository,
    required this.supportRepository,
    required this.options,
    this.contactPicker,
  });
  final AuthRepository repository;
  final PatientSupportNetworkRepository supportRepository;
  final SupportNetworkOptions options;
  final DeviceContactPicker? contactPicker;

  @override
  State<SupportContactWizardPage> createState() =>
      _SupportContactWizardPageState();
}

class _SupportContactWizardPageState extends State<SupportContactWizardPage> {
  final _pages = PageController();
  final _name = TextEditingController();
  final _relationship = TextEditingController();
  final _code = TextEditingController();
  final _phone = TextEditingController();
  final _other = TextEditingController();
  final _note = TextEditingController();
  final _types = <String>{};
  int _step = 0;
  bool _manual = false, _saving = false, _changed = false;
  bool _permissionDenied = false, _permanent = false;
  String? _error;
  late int _trust = widget.options.trustMin;
  late final DeviceContactPicker _picker =
      widget.contactPicker ?? NativeDeviceContactPicker();

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _name,
      _relationship,
      _code,
      _phone,
      _other,
      _note,
    ]) {
      controller.addListener(() {
        _changed = true;
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final controller in [
      _name,
      _relationship,
      _code,
      _phone,
      _other,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    ContactPickResult result;
    try {
      result = await _picker.pick();
    } catch (_) {
      result = const ContactPickResult(ContactPickStatus.denied);
    }
    if (!mounted) return;
    if (result.status == ContactPickStatus.denied ||
        result.status == ContactPickStatus.permanentlyDenied) {
      setState(() {
        _permissionDenied = true;
        _permanent = result.status == ContactPickStatus.permanentlyDenied;
      });
      return;
    }
    final contact = result.contact;
    if (contact == null) return;
    String? selected;
    if (contact.phones.length == 1) {
      selected = contact.phones.first;
    } else if (contact.phones.length > 1) {
      selected = await showModalBottomSheet<String>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Elige un teléfono')),
              for (final number in contact.phones)
                ListTile(
                  title: Text(number),
                  onTap: () => Navigator.pop(sheetContext, number),
                ),
            ],
          ),
        ),
      );
      if (selected == null) return;
    }
    if (!mounted) return;
    final prefill = prefillSupportPhone(selected ?? '');
    setState(() {
      _name.text = contact.name;
      _code.text = prefill.code;
      _phone.text = prefill.phone;
      _manual = true;
      _changed = true;
      _permissionDenied = false;
    });
  }

  Future<bool> _canLeave() async {
    if (!_changed || _saving) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('¿Salir sin guardar?'),
            content: const Text('Los cambios que hiciste no se guardarán.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Seguir aquí'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Salir sin guardar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String? _validation() {
    switch (_step) {
      case 0:
        if (!_manual || _name.text.trim().isEmpty) return 'Escribe el nombre.';
        if (_name.text.trim().length > 120) {
          return 'El nombre debe tener hasta 120 caracteres.';
        }
      case 1:
        if (_relationship.text.trim().isEmpty) {
          return 'Escribe qué relación tienes con esta persona.';
        }
        if (_relationship.text.trim().length > 100) {
          return 'La relación debe tener hasta 100 caracteres.';
        }
      case 3:
        if (_types.length < widget.options.supportTypeMin) {
          return 'Selecciona al menos un tipo de apoyo.';
        }
        if (_types.length > widget.options.supportTypeMax) {
          return 'Selecciona menos tipos de apoyo.';
        }
        if (_types.contains('otro') && _other.text.trim().isEmpty) {
          return 'Describe qué tipo de apoyo puede darte.';
        }
        if (_other.text.trim().length > 120) {
          return 'El otro tipo de apoyo debe tener hasta 120 caracteres.';
        }
      case 4:
        if (!_validPhone(_code.text, 1, 4, 8)) {
          return 'Ingresa una lada válida.';
        }
        if (!_validPhone(_phone.text, 7, 12, 30)) {
          return 'Ingresa un teléfono válido.';
        }
      case 5:
        if (_note.text.length > 1000) {
          return 'La nota debe tener hasta 1000 caracteres.';
        }
    }
    return null;
  }

  bool _validPhone(String value, int min, int max, int length) {
    final text = value.trim();
    if (text.isEmpty) return true;
    if (text.length > length || !RegExp(r'^[0-9\s()+.\-]+$').hasMatch(text)) {
      return false;
    }
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.length >= min && digits.length <= max;
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    final error = _validation();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (_step < 6) _go(_step + 1);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.supportRepository.createContact(
        SupportNetworkDraft(
          name: _name.text,
          relationship: _relationship.text,
          trustLevel: _trust,
          supportTypes: widget.options.supportTypes
              .where((item) => _types.contains(item.value))
              .map((item) => item.value)
              .toList(),
          phoneCode: _code.text,
          phone: _phone.text,
          otherSupportType: _types.contains('otro') ? _other.text : null,
          note: _note.text,
        ),
      );
      if (mounted) Navigator.pop(context, SupportContactResult.saved);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        if (mounted) {
          await supportNetworkSessionExpired(context, widget.repository);
        }
      } else if (mounted) {
        setState(
          () => _error = error.statusCode == 422
              ? error.message
              : 'No pudimos guardar los cambios. Intenta nuevamente.',
        );
      }
    } on NetworkException {
      if (mounted) {
        setState(
          () => _error = 'No pudimos guardar los cambios. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int? maxLength,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
    String? hint,
  }) => TextField(
    controller: controller,
    maxLength: maxLength,
    keyboardType: keyboardType,
    minLines: minLines,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _review(String label, String value, int step) => ListTile(
    title: Text(label),
    subtitle: Text(value),
    trailing: TextButton(
      onPressed: () => _go(step),
      child: const Text('Editar'),
    ),
  );

  Widget _content(int page) {
    switch (page) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.contacts_outlined),
              label: const Text('Elegir de mis contactos'),
            ),
            OutlinedButton(
              onPressed: () => setState(() {
                _manual = true;
                _permissionDenied = false;
              }),
              child: const Text('Escribir manualmente'),
            ),
            if (_permissionDenied) ...[
              const Text('No pudimos acceder a tus contactos.'),
              TextButton(
                onPressed: () => setState(() {
                  _manual = true;
                  _permissionDenied = false;
                }),
                child: const Text('Escribir manualmente'),
              ),
              if (_permanent)
                TextButton(
                  onPressed: _picker.openSettings,
                  child: const Text('Abrir configuración'),
                ),
            ],
            if (_manual) ...[
              const SizedBox(height: 20),
              _field(_name, 'Nombre', maxLength: 120),
            ],
          ],
        );
      case 1:
        return Column(
          children: [
            _field(
              _relationship,
              'Relación',
              maxLength: 100,
              hint: 'Amiga, papá, hermana, compañero de trabajo',
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            Text(
              '$_trust / ${widget.options.trustMax}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Slider(
              value: _trust.toDouble(),
              min: widget.options.trustMin.toDouble(),
              max: widget.options.trustMax.toDouble(),
              divisions: widget.options.trustMax - widget.options.trustMin,
              label: '$_trust',
              onChanged: (value) => setState(() {
                _trust = value.round();
                _changed = true;
              }),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Elige entre ${widget.options.supportTypeMin} y ${widget.options.supportTypeMax} formas de apoyo.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in widget.options.supportTypes)
                  FilterChip(
                    label: Text(type.label),
                    selected: _types.contains(type.value),
                    onSelected: (selected) => setState(() {
                      if (selected &&
                          _types.length < widget.options.supportTypeMax) {
                        _types.add(type.value);
                      }
                      if (!selected) _types.remove(type.value);
                      _changed = true;
                    }),
                  ),
              ],
            ),
            if (_types.contains('otro')) ...[
              const SizedBox(height: 16),
              _field(_other, '¿Qué tipo de apoyo?', maxLength: 120),
            ],
          ],
        );
      case 4:
        return Column(
          children: [
            _field(
              _code,
              'Lada',
              maxLength: 8,
              keyboardType: TextInputType.phone,
              hint: '+52',
            ),
            const SizedBox(height: 8),
            _field(
              _phone,
              'Teléfono',
              maxLength: 30,
              keyboardType: TextInputType.phone,
            ),
            const Text('Ambos campos son opcionales.'),
          ],
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Puedes escribir cómo suele apoyarte o algo que quieras tener presente.',
            ),
            const SizedBox(height: 16),
            _field(_note, 'Nota', maxLength: 1000, minLines: 3, maxLines: 6),
          ],
        );
      default:
        return Column(
          children: [
            _review('Nombre', _name.text.trim(), 0),
            _review('Relación', _relationship.text.trim(), 1),
            _review('Confianza', '$_trust / ${widget.options.trustMax}', 2),
            _review(
              'Tipos de apoyo',
              _types
                  .map(
                    (type) => type == 'otro'
                        ? 'Otro: ${_other.text.trim()}'
                        : widget.options.labelFor(type),
                  )
                  .join(' · '),
              3,
            ),
            if (_phone.text.trim().isNotEmpty)
              _review(
                'Teléfono',
                '${_code.text.trim()} ${_phone.text.trim()}'.trim(),
                4,
              ),
            if (_note.text.trim().isNotEmpty)
              _review('Nota', _note.text.trim(), 5),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      '¿A quién quieres agregar?',
      '¿Qué relación tienes con esta persona?',
      '¿Qué tanta confianza tienes con esta persona?',
      '¿Cómo puede apoyarte?',
      '¿Cómo puedes contactar a esta persona?',
      '¿Quieres recordar algo sobre esta persona?',
      'Revisa a la persona',
    ];
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _canLeave() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Agregar persona'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _canLeave() && context.mounted) Navigator.pop(context);
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(value: (_step + 1) / 7),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 7,
                  itemBuilder: (context, page) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paso ${page + 1} de 7',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          titles[page],
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 28),
                        _content(page),
                      ],
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: _saving ? null : () => _go(_step - 1),
                        child: const Text('Volver'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _saving ? null : (_step == 6 ? _save : _next),
                      child: Text(
                        _saving
                            ? 'Guardando…'
                            : _step == 6
                            ? 'Agregar a mi red'
                            : 'Siguiente',
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

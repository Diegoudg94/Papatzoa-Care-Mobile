import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/support_network_contact.dart';
import '../../data/models/support_network_options.dart';
import '../../data/repositories/patient_support_network_repository.dart';
import 'patient_support_network_page.dart';

enum SupportContactResult { saved, deleted, unavailable }

class SupportContactFormPage extends StatefulWidget {
  const SupportContactFormPage({
    super.key,
    required this.repository,
    required this.supportRepository,
    required this.options,
    this.contact,
  });
  final AuthRepository repository;
  final PatientSupportNetworkRepository supportRepository;
  final SupportNetworkOptions options;
  final SupportNetworkContact? contact;

  @override
  State<SupportContactFormPage> createState() => _SupportContactFormPageState();
}

class _SupportContactFormPageState extends State<SupportContactFormPage> {
  late final _name = TextEditingController(text: widget.contact?.name);
  late final _relationship = TextEditingController(
    text: widget.contact?.relationship,
  );
  late final _phoneCode = TextEditingController(
    text: widget.contact?.phoneCode,
  );
  late final _phone = TextEditingController(text: widget.contact?.phone);
  late final _other = TextEditingController(
    text: widget.contact?.otherSupportType,
  );
  late final _note = TextEditingController(text: widget.contact?.note);
  late int _trust = widget.contact?.trustLevel ?? widget.options.trustMin;
  late final _types = <String>{...?widget.contact?.supportTypes};
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _relationship,
      _phoneCode,
      _phone,
      _other,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Escribe el nombre.';
    if (_name.text.trim().length > 120) {
      return 'El nombre debe tener hasta 120 caracteres.';
    }
    if (_relationship.text.trim().isEmpty) {
      return 'Escribe qué relación tienes con esta persona.';
    }
    if (_relationship.text.trim().length > 100) {
      return 'La relación debe tener hasta 100 caracteres.';
    }
    if (_trust < widget.options.trustMin || _trust > widget.options.trustMax) {
      return 'Selecciona un nivel de confianza válido.';
    }
    if (_types.length < widget.options.supportTypeMin) {
      return 'Selecciona al menos un tipo de apoyo.';
    }
    if (_types.length > widget.options.supportTypeMax) {
      return 'Selecciona menos tipos de apoyo.';
    }
    if (_types.contains('otro') && _other.text.trim().isEmpty) {
      return 'Describe qué tipo de apoyo puede darte.';
    }
    if (_types.contains('otro') && _other.text.trim().length > 120) {
      return 'El otro tipo de apoyo debe tener hasta 120 caracteres.';
    }
    if (_phoneCode.text.trim().length > 8 ||
        !_validPhonePart(_phoneCode.text, minDigits: 1, maxDigits: 4)) {
      return 'Ingresa una lada válida.';
    }
    if (_phone.text.trim().length > 30 ||
        !_validPhonePart(_phone.text, minDigits: 7, maxDigits: 12)) {
      return 'Ingresa un teléfono válido.';
    }
    if (_note.text.length > 1000) {
      return 'La nota debe tener hasta 1000 caracteres.';
    }
    return null;
  }

  bool _validPhonePart(
    String value, {
    required int minDigits,
    required int maxDigits,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    if (!RegExp(r'^[0-9\s()+.\-]+$').hasMatch(trimmed)) return false;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return digits.length >= minDigits && digits.length <= maxDigits;
  }

  Future<void> _save() async {
    if (_saving) return;
    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = SupportNetworkDraft(
      name: _name.text,
      relationship: _relationship.text,
      trustLevel: _trust,
      supportTypes: widget.options.supportTypes
          .where((item) => _types.contains(item.value))
          .map((item) => item.value)
          .toList(),
      phoneCode: _phoneCode.text,
      phone: _phone.text,
      otherSupportType: _types.contains('otro') ? _other.text : null,
      note: _note.text,
    );
    try {
      if (widget.contact == null) {
        await widget.supportRepository.createContact(draft);
      } else {
        await widget.supportRepository.updateContact(widget.contact!.id, draft);
      }
      if (mounted) Navigator.of(context).pop(SupportContactResult.saved);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        if (!mounted) return;
        await supportNetworkSessionExpired(context, widget.repository);
        return;
      }
      if (error.statusCode == 404) {
        if (mounted) {
          Navigator.of(context).pop(SupportContactResult.unavailable);
        }
        return;
      }
      if (mounted) {
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

  Widget _section(String title, List<Widget> children) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final edit = widget.contact != null;
    return Scaffold(
      appBar: AppBar(title: Text(edit ? 'Editar persona' : 'Agregar persona')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _section('Información básica', [
                    TextField(
                      controller: _name,
                      maxLength: 120,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _relationship,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: '¿Qué relación tienes con esta persona?',
                        hintText: 'Amiga, papá, compañero de trabajo…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('¿Qué tanta confianza tienes con esta persona?'),
                    const SizedBox(height: 4),
                    const Text(
                      'Esto te ayuda a recordar con quién te sientes más cómodo al pedir apoyo.',
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '$_trust / ${widget.options.trustMax}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Slider(
                      value: _trust.toDouble(),
                      min: widget.options.trustMin.toDouble(),
                      max: widget.options.trustMax.toDouble(),
                      divisions:
                          widget.options.trustMax - widget.options.trustMin,
                      label: '$_trust',
                      onChanged: (value) =>
                          setState(() => _trust = value.round()),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _section('Cómo puede apoyarte', [
                    const Text('Elige una o varias formas de apoyo.'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in widget.options.supportTypes)
                          FilterChip(
                            label: Text(type.label),
                            selected: _types.contains(type.value),
                            onSelected: (selected) {
                              setState(() {
                                if (selected &&
                                    _types.length <
                                        widget.options.supportTypeMax) {
                                  _types.add(type.value);
                                } else if (!selected) {
                                  _types.remove(type.value);
                                }
                                _error = null;
                              });
                            },
                          ),
                      ],
                    ),
                    if (_types.contains('otro')) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _other,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: '¿Qué tipo de apoyo?',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  _section('Datos opcionales', [
                    TextField(
                      controller: _phoneCode,
                      maxLength: 8,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Lada',
                        hintText: '+52',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      maxLength: 30,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Puedes escribir algo que quieras recordar sobre cómo esta persona puede apoyarte.',
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      maxLength: 1000,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Nota',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(edit ? 'Guardar cambios' : 'Agregar persona'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

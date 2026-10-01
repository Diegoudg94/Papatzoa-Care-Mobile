import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/support_network_contact.dart';
import '../../data/models/support_network_options.dart';
import '../../data/repositories/patient_support_network_repository.dart';
import 'support_contact_detail_page.dart';
import 'support_contact_form_page.dart';
import 'support_contact_wizard_page.dart';
import 'support_whatsapp.dart';

Future<void> supportNetworkSessionExpired(
  BuildContext context,
  AuthRepository repository,
) async {
  try {
    await repository.invalidateSession();
  } catch (_) {}
  if (context.mounted) {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }
}

class PatientSupportNetworkPage extends StatefulWidget {
  const PatientSupportNetworkPage({
    super.key,
    required this.repository,
    required this.supportRepository,
  });
  final AuthRepository repository;
  final PatientSupportNetworkRepository supportRepository;
  @override
  State<PatientSupportNetworkPage> createState() =>
      _PatientSupportNetworkPageState();
}

class _PatientSupportNetworkPageState extends State<PatientSupportNetworkPage> {
  List<SupportNetworkContact> _contacts = const [];
  SupportNetworkOptions? _options;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await widget.supportRepository.getOptions();
      final contacts = await widget.supportRepository.getContacts();
      if (mounted) {
        setState(() {
          _options = options;
          _contacts = contacts;
        });
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        if (!mounted) return;
        await supportNetworkSessionExpired(context, widget.repository);
        return;
      }
      if (mounted) {
        setState(() => _error = 'No pudimos cargar tu red de apoyo.');
      }
    } on NetworkException {
      if (mounted) {
        setState(() => _error = 'No pudimos cargar tu red de apoyo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final options = _options;
    if (options == null) return;
    final result = await Navigator.of(context).push<SupportContactResult>(
      MaterialPageRoute(
        builder: (_) => SupportContactWizardPage(
          repository: widget.repository,
          supportRepository: widget.supportRepository,
          options: options,
        ),
      ),
    );
    if (!mounted) return;
    if (result == SupportContactResult.saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persona agregada a tu red')),
      );
      await _load();
    }
  }

  Future<void> _open(SupportNetworkContact contact) async {
    final options = _options;
    if (options == null) return;
    final result = await Navigator.of(context).push<SupportContactResult>(
      MaterialPageRoute(
        builder: (_) => SupportContactDetailPage(
          repository: widget.repository,
          supportRepository: widget.supportRepository,
          options: options,
          contact: contact,
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) return;
    if (result == SupportContactResult.unavailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este contacto ya no está disponible.')),
      );
    } else if (result == SupportContactResult.deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacto eliminado de tu red')),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cambios guardados')));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Red de apoyo')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              Text(
                'Red de apoyo',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Personas a las que puedes recurrir cuando necesitas apoyo.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_loading && _error == null) ...[
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Agregar persona'),
                ),
                const SizedBox(height: 18),
                if (_contacts.isEmpty)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.people_outline, size: 36),
                          SizedBox(height: 12),
                          Text('Aún no has agregado personas a tu red.'),
                          SizedBox(height: 8),
                          Text(
                            'Puedes registrar a personas en quienes confías y recordar de qué manera pueden apoyarte.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final contact in _contacts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => _open(contact),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      contact.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(contact.relationship),
                              const SizedBox(height: 10),
                              Text(
                                'Confianza: ${contact.trustLevel}/5',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final type in contact.supportTypes)
                                    Chip(label: Text(_options!.labelFor(type))),
                                ],
                              ),
                              if (contact.phone?.trim().isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    [contact.phoneCode, contact.phone]
                                        .where(
                                          (part) =>
                                              part?.trim().isNotEmpty == true,
                                        )
                                        .join(' '),
                                  ),
                                ),
                              if (supportWhatsappNumber(contact) != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: FilledButton.icon(
                                    onPressed: () => prepareSupportWhatsapp(
                                      context,
                                      contact,
                                    ),
                                    icon: const Icon(Icons.chat_outlined),
                                    label: const Text(
                                      'Enviar mensaje por WhatsApp',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
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

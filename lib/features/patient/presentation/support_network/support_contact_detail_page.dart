import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/support_network_contact.dart';
import '../../data/models/support_network_options.dart';
import '../../data/repositories/patient_support_network_repository.dart';
import 'patient_support_network_page.dart';
import 'support_contact_form_page.dart';
import 'support_whatsapp.dart';

class SupportContactDetailPage extends StatefulWidget {
  const SupportContactDetailPage({
    super.key,
    required this.repository,
    required this.supportRepository,
    required this.options,
    required this.contact,
  });
  final AuthRepository repository;
  final PatientSupportNetworkRepository supportRepository;
  final SupportNetworkOptions options;
  final SupportNetworkContact contact;
  @override
  State<SupportContactDetailPage> createState() =>
      _SupportContactDetailPageState();
}

class _SupportContactDetailPageState extends State<SupportContactDetailPage> {
  bool _deleting = false;
  String? _error;

  Future<void> _edit() async {
    final result = await Navigator.of(context).push<SupportContactResult>(
      MaterialPageRoute(
        builder: (_) => SupportContactFormPage(
          repository: widget.repository,
          supportRepository: widget.supportRepository,
          options: widget.options,
          contact: widget.contact,
        ),
      ),
    );
    if (mounted && result != null) Navigator.of(context).pop(result);
  }

  Future<void> _delete() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar de tu red de apoyo?'),
        content: const Text('Esta persona dejará de aparecer en tu red.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.supportRepository.deleteContact(widget.contact.id);
      if (mounted) Navigator.of(context).pop(SupportContactResult.deleted);
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
          () =>
              _error = 'No pudimos eliminar este contacto. Intenta nuevamente.',
        );
      }
    } on NetworkException {
      if (mounted) {
        setState(
          () =>
              _error = 'No pudimos eliminar este contacto. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _item(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final phone = [
      contact.phoneCode,
      contact.phone,
    ].where((part) => part?.trim().isNotEmpty == true).join(' ');
    return Scaffold(
      appBar: AppBar(title: const Text('Persona de apoyo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    _item('Relación', contact.relationship),
                    if (phone.isNotEmpty) _item('Teléfono', phone),
                    _item('Confianza', '${contact.trustLevel}/5'),
                    _item(
                      'Cómo puede apoyarte',
                      contact.supportTypes
                          .map(
                            (type) =>
                                type == 'otro' &&
                                    contact.otherSupportType
                                            ?.trim()
                                            .isNotEmpty ==
                                        true
                                ? '${widget.options.labelFor(type)}: ${contact.otherSupportType}'
                                : widget.options.labelFor(type),
                          )
                          .join(' · '),
                    ),
                    if (contact.note?.trim().isNotEmpty == true)
                      _item('Nota', contact.note!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (supportWhatsappNumber(contact) != null) ...[
              FilledButton.icon(
                onPressed: () => prepareSupportWhatsapp(context, contact),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Enviar mensaje por WhatsApp'),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton(
              onPressed: _deleting ? null : _edit,
              child: const Text('Editar'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _deleting ? null : _delete,
              child: _deleting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Eliminar'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

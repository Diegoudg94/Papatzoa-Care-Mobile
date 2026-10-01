import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/support_network_contact.dart';

const supportWhatsappMessage =
    'Hola, ¿tienes un momento para hablar? Me vendría bien un poco de compañía.';

String? supportWhatsappNumber(SupportNetworkContact contact) {
  if (contact.phoneCode?.trim().isEmpty != false ||
      contact.phone?.trim().isEmpty != false) {
    return null;
  }
  final code = contact.phoneCode!.replaceAll(RegExp(r'\D'), '');
  final phone = contact.phone!.replaceAll(RegExp(r'\D'), '');
  final number = '$code$phone';
  if (code.isEmpty ||
      code.length > 4 ||
      phone.length < 7 ||
      phone.length > 12 ||
      number.length > 15) {
    return null;
  }
  return number;
}

Uri? supportWhatsappUrl(SupportNetworkContact contact, String message) {
  final number = supportWhatsappNumber(contact);
  if (number == null || message.trim().isEmpty) return null;
  return Uri.https('wa.me', '/$number', {'text': message.trim()});
}

typedef WhatsappOpener = Future<bool> Function(Uri uri);

Future<bool> defaultWhatsappOpener(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<void> prepareSupportWhatsapp(
  BuildContext context,
  SupportNetworkContact contact, {
  WhatsappOpener opener = defaultWhatsappOpener,
}) async {
  final message = TextEditingController(text: supportWhatsappMessage);
  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Preparar mensaje'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Para ${contact.name}. Tú decides qué compartir.'),
              const SizedBox(height: 16),
              TextField(
                controller: message,
                maxLength: 2000,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Previsualización editable',
                  border: OutlineInputBorder(),
                ),
              ),
              const Text(
                'El mensaje no se envía desde Papatzoa. Podrás revisarlo también en WhatsApp.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final uri = supportWhatsappUrl(contact, message.text);
              if (uri == null) return;
              bool opened = false;
              try {
                opened = await opener(uri);
              } catch (_) {}
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No pudimos abrir WhatsApp en este dispositivo.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Abrir WhatsApp'),
          ),
        ],
      ),
    );
  } finally {
    message.dispose();
  }
}

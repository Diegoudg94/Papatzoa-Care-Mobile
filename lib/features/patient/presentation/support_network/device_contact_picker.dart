import 'dart:io';

import 'package:flutter_contacts/flutter_contacts.dart';

enum ContactPickStatus { selected, cancelled, denied, permanentlyDenied }

class PickedSupportContact {
  const PickedSupportContact(this.name, this.phones);
  final String name;
  final List<String> phones;
}

class ContactPickResult {
  const ContactPickResult(this.status, [this.contact]);
  final ContactPickStatus status;
  final PickedSupportContact? contact;
}

abstract class DeviceContactPicker {
  Future<ContactPickResult> pick();
  Future<void> openSettings();
}

class NativeDeviceContactPicker implements DeviceContactPicker {
  @override
  Future<ContactPickResult> pick() async {
    // The native picker needs read permission only on Android when requesting
    // phone properties. iOS grants access to the single chosen contact.
    if (Platform.isAndroid) {
      final status = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        return ContactPickResult(
          status == PermissionStatus.permanentlyDenied ||
                  status == PermissionStatus.restricted
              ? ContactPickStatus.permanentlyDenied
              : ContactPickStatus.denied,
        );
      }
    }
    final contact = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.phone},
    );
    if (contact == null) {
      return const ContactPickResult(ContactPickStatus.cancelled);
    }
    return ContactPickResult(
      ContactPickStatus.selected,
      PickedSupportContact(
        contact.displayName?.trim() ?? '',
        contact.phones
            .map((phone) => phone.number.trim())
            .where((number) => number.isNotEmpty)
            .toList(),
      ),
    );
  }

  @override
  Future<void> openSettings() => FlutterContacts.permissions.openSettings();
}

({String code, String phone}) prefillSupportPhone(String raw) {
  final value = raw.trim();
  // Only infer the Mexico country code when the international prefix is explicit.
  final match = RegExp(r'^(?:\+52|0052)[\s.-]*(.*)$').firstMatch(value);
  if (match != null) return (code: '+52', phone: match.group(1)!.trim());
  return (code: '', phone: value);
}

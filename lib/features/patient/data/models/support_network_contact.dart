class SupportNetworkContact {
  const SupportNetworkContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.trustLevel,
    required this.supportTypes,
    this.phoneCode,
    this.phone,
    this.otherSupportType,
    this.note,
  });

  factory SupportNetworkContact.fromJson(Map<String, dynamic> json) =>
      SupportNetworkContact(
        id: (json['id'] as num).toInt(),
        name: json['nombre'] as String,
        relationship: json['relacion'] as String,
        phoneCode: json['telefono_lada'] as String?,
        phone: json['telefono'] as String?,
        trustLevel: (json['nivel_confianza'] as num).toInt(),
        supportTypes: (json['tipos_apoyo'] as List<dynamic>).cast<String>(),
        otherSupportType: json['tipo_apoyo_otro'] as String?,
        note: json['nota'] as String?,
      );

  final int id;
  final String name;
  final String relationship;
  final String? phoneCode;
  final String? phone;
  final int trustLevel;
  final List<String> supportTypes;
  final String? otherSupportType;
  final String? note;
}

class SupportNetworkDraft {
  const SupportNetworkDraft({
    required this.name,
    required this.relationship,
    required this.trustLevel,
    required this.supportTypes,
    this.phoneCode,
    this.phone,
    this.otherSupportType,
    this.note,
  });

  final String name;
  final String relationship;
  final int trustLevel;
  final List<String> supportTypes;
  final String? phoneCode;
  final String? phone;
  final String? otherSupportType;
  final String? note;

  Map<String, Object?> toRequestBody() {
    String? optional(String? value) =>
        value?.trim().isNotEmpty == true ? value!.trim() : null;
    return <String, Object?>{
      'nombre': name.trim(),
      'relacion': relationship.trim(),
      'nivel_confianza': trustLevel,
      'tipos_apoyo': supportTypes,
      'telefono_lada': optional(phoneCode),
      'telefono': optional(phone),
      'tipo_apoyo_otro': supportTypes.contains('otro')
          ? optional(otherSupportType)
          : null,
      'nota': optional(note),
    };
  }
}

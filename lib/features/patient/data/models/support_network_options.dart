class SupportTypeOption {
  const SupportTypeOption({required this.value, required this.label});
  factory SupportTypeOption.fromJson(Map<String, dynamic> json) =>
      SupportTypeOption(
        value: json['value'] as String,
        label: json['label'] as String,
      );
  final String value;
  final String label;
}

class SupportNetworkOptions {
  const SupportNetworkOptions({
    required this.supportTypes,
    required this.trustMin,
    required this.trustMax,
    required this.supportTypeMin,
    required this.supportTypeMax,
  });
  factory SupportNetworkOptions.fromJson(Map<String, dynamic> json) {
    final trust = json['trust_level'] as Map<String, dynamic>;
    final count = json['support_type_count'] as Map<String, dynamic>;
    return SupportNetworkOptions(
      supportTypes: (json['support_types'] as List<dynamic>)
          .map(
            (value) =>
                SupportTypeOption.fromJson(value as Map<String, dynamic>),
          )
          .toList(growable: false),
      trustMin: (trust['min'] as num).toInt(),
      trustMax: (trust['max'] as num).toInt(),
      supportTypeMin: (count['min'] as num).toInt(),
      supportTypeMax: (count['max'] as num).toInt(),
    );
  }
  final List<SupportTypeOption> supportTypes;
  final int trustMin;
  final int trustMax;
  final int supportTypeMin;
  final int supportTypeMax;

  String labelFor(String value) =>
      supportTypes
          .where((item) => item.value == value)
          .map((item) => item.label)
          .firstOrNull ??
      value;
}

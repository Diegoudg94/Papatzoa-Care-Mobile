class DiaryOptions {
  const DiaryOptions({
    required this.emotions,
    required this.supportsCustomEmotion,
    required this.intensityMin,
    required this.intensityMax,
    required this.intensityOptional,
    required this.interpretations,
  });

  factory DiaryOptions.fromJson(Map<String, dynamic> json) {
    final intensity = json['intensity'] as Map<String, dynamic>;
    return DiaryOptions(
      emotions: (json['emotions'] as List<dynamic>)
          .map(
            (item) => DiaryEmotionOption.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      supportsCustomEmotion: json['supports_custom_emotion'] == true,
      intensityMin: (intensity['min'] as num).toInt(),
      intensityMax: (intensity['max'] as num).toInt(),
      intensityOptional: intensity['optional'] == true,
      interpretations: (json['interpretations'] as List<dynamic>)
          .map(
            (item) => DiaryInterpretationOption.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }

  final List<DiaryEmotionOption> emotions;
  final bool supportsCustomEmotion;
  final int intensityMin;
  final int intensityMax;
  final bool intensityOptional;
  final List<DiaryInterpretationOption> interpretations;

  String emojiFor(String emotion) => diaryEmotionEmoji(emotion, emotions);
}

String diaryEmotionEmoji(
  String emotion, [
  List<DiaryEmotionOption> catalog = const [],
]) {
  for (final option in catalog) {
    if (option.value.toLowerCase() == emotion.trim().toLowerCase()) {
      return option.emoji;
    }
  }
  return switch (emotion.trim().toLowerCase()) {
    'ansiedad' => '😰',
    'tristeza' => '😢',
    'enojo' => '😠',
    'miedo' => '😨',
    'vergüenza' => '😳',
    'culpa' => '😔',
    'alegría' => '😊',
    _ => '💭',
  };
}

class DiaryEmotionOption {
  const DiaryEmotionOption({required this.value, required this.emoji});
  factory DiaryEmotionOption.fromJson(Map<String, dynamic> json) =>
      DiaryEmotionOption(
        value: json['value'] as String,
        emoji: json['emoji'] as String,
      );
  final String value;
  final String emoji;
}

class DiaryInterpretationOption {
  const DiaryInterpretationOption({
    required this.value,
    required this.title,
    required this.description,
    required this.technicalLabel,
  });
  factory DiaryInterpretationOption.fromJson(Map<String, dynamic> json) =>
      DiaryInterpretationOption(
        value: json['value'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        technicalLabel: json['technical_label'] as String,
      );
  final String value;
  final String title;
  final String description;
  final String technicalLabel;
}

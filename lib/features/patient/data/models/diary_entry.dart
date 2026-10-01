class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.emotion,
    this.intensity,
    this.recordedAt,
    this.preview,
    this.situation,
    this.thought,
    this.behavior,
    this.interpretation,
    this.restructuring,
    this.followUps = const [],
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: (json['id'] as num).toInt(),
    emotion: json['emotion'] as String,
    intensity: (json['intensity'] as num?)?.toInt(),
    recordedAt: DateTime.tryParse(json['recorded_at'] as String? ?? ''),
    preview: json['preview'] as String?,
    situation: json['situation'] as String?,
    thought: json['thought'] as String?,
    behavior: json['behavior'] as String?,
    interpretation: json['interpretation'] as String?,
    restructuring: json['restructuring'] as String?,
    followUps: (json['follow_ups'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DiaryFollowUp.fromJson)
        .toList(growable: false),
  );

  final int id;
  final String emotion;
  final int? intensity;
  final DateTime? recordedAt;
  final String? preview;
  final String? situation;
  final String? thought;
  final String? behavior;
  final String? interpretation;
  final String? restructuring;
  final List<DiaryFollowUp> followUps;
}

class DiaryFollowUp {
  const DiaryFollowUp({this.id, this.note, this.recordedAt});

  factory DiaryFollowUp.fromJson(Map<String, dynamic> json) => DiaryFollowUp(
    id: (json['id'] as num?)?.toInt(),
    note: json['note'] as String?,
    recordedAt: DateTime.tryParse(json['recorded_at'] as String? ?? ''),
  );

  final int? id;
  final String? note;
  final DateTime? recordedAt;
}

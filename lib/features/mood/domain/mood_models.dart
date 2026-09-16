enum MoodLevel {
  veryUnpleasant,
  unpleasant,
  neutral,
  pleasant,
  veryPleasant;

  String get key {
    switch (this) {
      case MoodLevel.veryUnpleasant:
        return 'veryUnpleasant';
      case MoodLevel.unpleasant:
        return 'unpleasant';
      case MoodLevel.neutral:
        return 'neutral';
      case MoodLevel.pleasant:
        return 'pleasant';
      case MoodLevel.veryPleasant:
        return 'veryPleasant';
    }
  }

  String get label {
    switch (this) {
      case MoodLevel.veryUnpleasant:
        return 'Very Unpleasant';
      case MoodLevel.unpleasant:
        return 'Unpleasant';
      case MoodLevel.neutral:
        return 'Neutral';
      case MoodLevel.pleasant:
        return 'Pleasant';
      case MoodLevel.veryPleasant:
        return 'Very Pleasant';
    }
  }

  String get emoji {
    switch (this) {
      case MoodLevel.veryUnpleasant:
        return '😔';
      case MoodLevel.unpleasant:
        return '😕';
      case MoodLevel.neutral:
        return '😐';
      case MoodLevel.pleasant:
        return '🙂';
      case MoodLevel.veryPleasant:
        return '😊';
    }
  }

  static MoodLevel fromScore(double score) {
    if (score < 3.0) return MoodLevel.veryUnpleasant;
    if (score < 5.0) return MoodLevel.unpleasant;
    if (score < 7.0) return MoodLevel.neutral;
    if (score < 9.0) return MoodLevel.pleasant;
    return MoodLevel.veryPleasant;
  }

  /// A slider score that maps back to this level — used to restore the
  /// slider when the user returns to step 0 after picking a level.
  double get representativeScore {
    switch (this) {
      case MoodLevel.veryUnpleasant:
        return 2.0;
      case MoodLevel.unpleasant:
        return 4.0;
      case MoodLevel.neutral:
        return 6.0;
      case MoodLevel.pleasant:
        return 8.0;
      case MoodLevel.veryPleasant:
        return 10.0;
    }
  }
}

class MoodOption {
  const MoodOption({required this.text, required this.category});

  final String text;
  final String category;

  factory MoodOption.fromJson(Map<String, dynamic> json) => MoodOption(
        text: json['text'] as String,
        category: json['category'] as String,
      );
}

class MoodQuestion {
  const MoodQuestion({
    required this.id,
    required this.question,
    required this.options,
  });

  final String id;
  final String question;
  final List<MoodOption> options;

  factory MoodQuestion.fromJson(Map<String, dynamic> json) => MoodQuestion(
        id: json['id'] as String,
        question: json['question'] as String,
        options: [
          (json['options'] as List)
              .map((e) => MoodOption.fromJson(e as Map<String, dynamic>))
        ].expand((l) => l).toList(),
      );
}

/// One completed check-in.
class MoodRecord {
  const MoodRecord({
    required this.date,
    required this.osis,
    required this.level,
  });

  final DateTime date;
  final String osis; // recommended verse, e.g. PSA.23.4
  final MoodLevel level;
}

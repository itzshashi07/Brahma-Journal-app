import 'journal_entry.dart';

/// An unsaved reset lives only in memory, never preferences or analytics.
class QuickReset {
  int? mood;
  String topic = '';
  String thought = '';
  String nextStep = '';
  bool completed = false;
  String? ownerUid;

  static QuickReset? pending;
  static const topics = [
    'Studies',
    'Work',
    'Relationships',
    'Too much at once',
    'Something else'
  ];
  static const suggestions = <String, List<String>>{
    'Studies': [
      'Choose one task for tomorrow',
      'Put my study materials ready',
      'Take a screen-free break'
    ],
    'Work': [
      'Write down my first task for tomorrow',
      'Close work for today',
      'Ask someone for help'
    ],
    'Relationships': [
      'Give myself time before replying',
      'Write what I want to say privately',
      'Reach out to someone I trust'
    ],
    'Too much at once': [
      'Choose just one small task',
      'Put my phone away for a moment',
      'Make time to rest'
    ],
    'Something else': [
      'Choose just one small task',
      'Step away from my screen',
      'Talk to someone I trust'
    ],
  };

  /// Preserve all existing journal fields when adding this reset.
  JournalEntry toEntry(
      {required String uid, JournalEntry? existing, DateTime? now}) {
    final base = existing ??
        JournalEntry(
            uid: uid, mood: mood ?? 3, createdAt: now ?? DateTime.now());
    return base.copyWith(mood: mood ?? base.mood, checkIn: {
      ...base.checkIn,
      'reset_topic': topic,
      'reset_thought': thought.trim(),
      'reset_next_step': nextStep.trim(),
    });
  }
}

import 'package:flutter/material.dart';

/// What a member is actually trying to get good at.
///
/// The journal already proves you turned up; it does not prove you turned up
/// *for the thing you care about*. A singer who journals every day for a month
/// and never once sang has a perfect streak and nothing to show for it — and
/// the analytics screen, showing only mood and meditation minutes, cannot tell
/// them that.
///
/// So each member names their craft, and the journal gains one small card:
/// tap what you did today. It is three seconds of tapping, and it turns the
/// analytics screen from "how you felt" into "whether you are actually doing
/// the work" — which is the number people come back to check.
///
/// The habits under each profession are deliberately few and deliberately
/// concrete. "Practised" is a habit. "Worked on personal growth" is a mood.
class Profession {
  final String id;
  final String label;
  final String emoji;

  /// What this person's daily work looks like, as tappable habits.
  final List<CraftHabit> habits;

  /// Placeholder for the member's own one-line aim.
  final String aimHint;

  /// The word used for a unit of work in this craft — "riyaaz", "writing",
  /// "training". Appears in the analytics copy so it does not read like a
  /// generic productivity app.
  final String workWord;

  const Profession({
    required this.id,
    required this.label,
    required this.emoji,
    required this.habits,
    required this.aimHint,
    required this.workWord,
  });
}

class CraftHabit {
  final String id;
  final String label;
  final String emoji;

  /// Core habits are the ones consistency is measured against. Supporting
  /// habits still get recorded, but a week of only "listened to music" is not
  /// a week of practice and the streak should not pretend otherwise.
  final bool isCore;

  /// Written by the member rather than shipped with the app.
  ///
  /// The presets are a starting point, not a definition — no list of six can
  /// describe what someone is actually working on. Custom items behave exactly
  /// like preset ones everywhere downstream: they tick, they count towards the
  /// streak, and they appear in analytics. The flag exists only so the setup
  /// screen knows which ones the member is allowed to rename or remove.
  final bool isCustom;

  const CraftHabit(
    this.id,
    this.label,
    this.emoji, {
    this.isCore = false,
    this.isCustom = false,
  });

  /// Prefix that keeps a member's own item from ever colliding with a preset.
  ///
  /// This matters more than it looks: [JournalEntry.craftDone] stores habit
  /// *ids*, and a year of history is only readable while those ids stay stable.
  /// If someone's custom item happened to be called `study` it would silently
  /// merge with the Student preset of the same name.
  static const customPrefix = 'custom_';

  /// Builds a member-authored item. The id is derived from the moment of
  /// creation, never from the label — renaming "Gym" to "Training" must not
  /// orphan every day it was already ticked.
  factory CraftHabit.custom({
    required String label,
    String emoji = '✅',
    String? id,
  }) {
    return CraftHabit(
      id ?? '$customPrefix${DateTime.now().microsecondsSinceEpoch}',
      label,
      emoji.isEmpty ? '✅' : emoji,
      // A member does not add an item to their own checklist casually — if they
      // wrote it down, it counts towards whether the week happened.
      isCore: true,
      isCustom: true,
    );
  }

  factory CraftHabit.fromMap(Map<String, dynamic> data) => CraftHabit(
        data['id']?.toString() ?? '',
        data['label']?.toString() ?? '',
        data['emoji']?.toString().isNotEmpty == true
            ? data['emoji'].toString()
            : '✅',
        isCore: data['isCore'] != false,
        isCustom: true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'emoji': emoji,
        'isCore': isCore,
      };

  CraftHabit copyWith({String? label, String? emoji}) => CraftHabit(
        id,
        label ?? this.label,
        emoji ?? this.emoji,
        isCore: isCore,
        isCustom: isCustom,
      );
}

class Professions {
  static const all = <Profession>[
    Profession(
      id: 'student',
      label: 'Student',
      emoji: '🎓',
      workWord: 'studying',
      aimHint: 'e.g. Clear my boards with 90%+',
      habits: [
        CraftHabit('study', 'Studied', '📚', isCore: true),
        CraftHabit('revision', 'Revised old topics', '🔁', isCore: true),
        CraftHabit('practice_test', 'Practice test / mock', '📝', isCore: true),
        CraftHabit('doubts', 'Cleared a doubt', '❓'),
        CraftHabit('notes', 'Made notes', '🗒️'),
        CraftHabit('class', 'Attended class', '🏫'),
      ],
    ),
    Profession(
      id: 'aspirant',
      label: 'Competitive exam aspirant',
      emoji: '🏛️',
      workWord: 'preparation',
      aimHint: 'e.g. UPSC Prelims 2027',
      habits: [
        CraftHabit('syllabus', 'Covered syllabus', '📖', isCore: true),
        CraftHabit('answer_writing', 'Answer writing', '✍️', isCore: true),
        CraftHabit('mock', 'Mock test', '⏱️', isCore: true),
        CraftHabit('current_affairs', 'Current affairs', '📰'),
        CraftHabit('revision', 'Revision', '🔁'),
        CraftHabit('group_study', 'Discussed with peers', '👥'),
      ],
    ),
    Profession(
      id: 'engineer',
      label: 'Engineer / Developer',
      emoji: '💻',
      workWord: 'deep work',
      aimHint: 'e.g. Ship my own product this year',
      habits: [
        CraftHabit('deep_work', 'Deep work block', '🎯', isCore: true),
        CraftHabit('shipped', 'Shipped something', '🚀', isCore: true),
        CraftHabit('learned', 'Learned a new skill', '🧠', isCore: true),
        CraftHabit('reviewed', 'Reviewed / debugged', '🔍'),
        CraftHabit('planned', 'Planned the work', '🗺️'),
        CraftHabit('side_project', 'Side project', '🛠️'),
      ],
    ),
    Profession(
      id: 'singer',
      label: 'Singer / Musician',
      emoji: '🎤',
      workWord: 'riyaaz',
      aimHint: 'e.g. Record and release an original song',
      habits: [
        CraftHabit('riyaaz', 'Riyaaz / practice', '🎵', isCore: true),
        CraftHabit('new_piece', 'Worked on a new piece', '🎼', isCore: true),
        CraftHabit('recorded', 'Recorded myself', '🎙️', isCore: true),
        CraftHabit('listened', 'Listened actively', '🎧'),
        CraftHabit('performed', 'Performed for someone', '🌟'),
        CraftHabit('rest', 'Rested my voice', '🤫'),
      ],
    ),
    Profession(
      id: 'writer',
      label: 'Writer / Poet',
      emoji: '✍️',
      workWord: 'writing',
      aimHint: 'e.g. Finish the first draft of my book',
      habits: [
        CraftHabit('wrote', 'Wrote today', '📝', isCore: true),
        CraftHabit('edited', 'Edited / rewrote', '✂️', isCore: true),
        CraftHabit('read', 'Read seriously', '📚', isCore: true),
        CraftHabit('outlined', 'Outlined / planned', '🗂️'),
        CraftHabit('published', 'Published something', '📤'),
        CraftHabit('observed', 'Collected an idea', '💡'),
      ],
    ),
    Profession(
      id: 'artist',
      label: 'Artist / Designer',
      emoji: '🎨',
      workWord: 'making',
      aimHint: 'e.g. Build a portfolio worth showing',
      habits: [
        CraftHabit('made', 'Made something', '🖌️', isCore: true),
        CraftHabit('studied', 'Studied technique', '📐', isCore: true),
        CraftHabit('sketched', 'Sketched / drafted', '✏️', isCore: true),
        CraftHabit('shared', 'Shared my work', '📤'),
        CraftHabit('inspiration', 'Gathered references', '🖼️'),
        CraftHabit('feedback', 'Took feedback', '👀'),
      ],
    ),
    Profession(
      id: 'athlete',
      label: 'Athlete / Fitness',
      emoji: '🏃',
      workWord: 'training',
      aimHint: 'e.g. Run a half marathon under 2 hours',
      habits: [
        CraftHabit('trained', 'Trained', '💪', isCore: true),
        CraftHabit('skill_drill', 'Skill drill', '🎯', isCore: true),
        CraftHabit('recovery', 'Recovery / stretching', '🧊', isCore: true),
        CraftHabit('nutrition', 'Ate for my goal', '🥗'),
        CraftHabit('sleep', 'Slept enough', '😴'),
        CraftHabit('logged', 'Logged my numbers', '📊'),
      ],
    ),
    Profession(
      id: 'teacher',
      label: 'Teacher / Mentor',
      emoji: '📐',
      workWord: 'teaching',
      aimHint: 'e.g. Make my class the one they never skip',
      habits: [
        CraftHabit('taught', 'Taught a class', '🧑‍🏫', isCore: true),
        CraftHabit('prepared', 'Prepared material', '📋', isCore: true),
        CraftHabit('own_learning', 'Learned something myself', '📚', isCore: true),
        CraftHabit('helped', 'Helped a struggling student', '🤝'),
        CraftHabit('feedback', 'Took feedback', '👂'),
        CraftHabit('graded', 'Assessed work', '✅'),
      ],
    ),
    Profession(
      id: 'healthcare',
      label: 'Doctor / Healthcare',
      emoji: '🩺',
      workWord: 'practice',
      aimHint: 'e.g. Stay sharp without burning out',
      habits: [
        CraftHabit('patients', 'Saw patients', '🏥', isCore: true),
        CraftHabit('study', 'Studied / read up', '📚', isCore: true),
        CraftHabit('boundaries', 'Held my boundaries', '🛡️', isCore: true),
        CraftHabit('rest', 'Rested properly', '😴'),
        CraftHabit('colleague', 'Talked to a colleague', '🤝'),
        CraftHabit('reflected', 'Reflected on a case', '🤔'),
      ],
    ),
    Profession(
      id: 'business',
      label: 'Entrepreneur / Business',
      emoji: '📈',
      workWord: 'building',
      aimHint: 'e.g. Reach my first 100 paying customers',
      habits: [
        CraftHabit('customers', 'Talked to a customer', '🗣️', isCore: true),
        CraftHabit('built', 'Built / improved the product', '🔨', isCore: true),
        CraftHabit('sold', 'Sold / pitched', '💼', isCore: true),
        CraftHabit('numbers', 'Checked the numbers', '📊'),
        CraftHabit('learned', 'Learned something new', '🧠'),
        CraftHabit('team', 'Supported my team', '👥'),
      ],
    ),
    Profession(
      id: 'job_seeker',
      label: 'Looking for work',
      emoji: '🧭',
      workWord: 'the search',
      aimHint: 'e.g. Land a role I am actually excited about',
      habits: [
        CraftHabit('applied', 'Applied somewhere', '📨', isCore: true),
        CraftHabit('skill', 'Built a skill', '🧠', isCore: true),
        CraftHabit('reached_out', 'Reached out to someone', '🤝', isCore: true),
        CraftHabit('interview', 'Interviewed', '🎙️'),
        CraftHabit('portfolio', 'Improved my CV / portfolio', '📄'),
        CraftHabit('rested', 'Let myself rest', '🌿'),
      ],
    ),
    Profession(
      id: 'homemaker',
      label: 'Homemaker / Caregiver',
      emoji: '🏡',
      workWord: 'looking after everyone',
      aimHint: 'e.g. Keep something in the day that is mine',
      habits: [
        CraftHabit('cared', 'Looked after the family', '❤️', isCore: true),
        CraftHabit('own_time', 'Took time for myself', '🌿', isCore: true),
        CraftHabit('learned', 'Learned or made something', '🧵', isCore: true),
        CraftHabit('home', 'Ran the home', '🏠'),
        CraftHabit('rested', 'Actually rested', '😴'),
        CraftHabit('connected', 'Talked to a friend', '☎️'),
      ],
    ),
    Profession(
      id: 'seeker',
      label: 'Inner work & reflection',
      emoji: '🧭',
      workWord: 'practice',
      aimHint: 'e.g. Sit for twenty minutes every morning',
      habits: [
        CraftHabit('meditation', 'Meditated', '🧘', isCore: true),
        CraftHabit('study', 'Studied scripture', '📖', isCore: true),
        CraftHabit('service', 'Served someone', '🤲', isCore: true),
        CraftHabit('silence', 'Kept silence', '🤫'),
        CraftHabit('satsang', 'Satsang / class', '👥'),
        CraftHabit('journal', 'Reflected in writing', '📓'),
      ],
    ),
    Profession(
      id: 'other',
      label: 'Something else',
      emoji: '✨',
      workWord: 'the work',
      aimHint: 'e.g. Get better at the thing I care about',
      habits: [
        CraftHabit('worked', 'Worked on it', '🎯', isCore: true),
        CraftHabit('practised', 'Practised a skill', '🔁', isCore: true),
        CraftHabit('learned', 'Learned something', '🧠', isCore: true),
        CraftHabit('planned', 'Planned my next step', '🗺️'),
        CraftHabit('shared', 'Showed it to someone', '📤'),
        CraftHabit('rested', 'Rested on purpose', '🌿'),
      ],
    ),
  ];

  static Profession byId(String? id) => all.firstWhere(
        (p) => p.id == id,
        orElse: () => all.last, // 'other'
      );

  static bool isKnown(String? id) => all.any((p) => p.id == id);

  static CraftHabit? habit(String professionId, String habitId) {
    for (final h in byId(professionId).habits) {
      if (h.id == habitId) return h;
    }
    return null;
  }

  static String habitLabel(String professionId, String habitId) =>
      habit(professionId, habitId)?.label ?? habitId.replaceAll('_', ' ');

  /// The member's full daily checklist: the presets for their craft, then
  /// whatever they added themselves.
  ///
  /// Custom items come last so the list does not reshuffle under someone's
  /// thumb every time they add one — the presets stay where muscle memory left
  /// them.
  static List<CraftHabit> checklistFor(
    String? professionId,
    List<CraftHabit> custom,
  ) =>
      [...byId(professionId).habits, ...custom];

  /// Label for a habit id, custom items included.
  ///
  /// Falls back to the de-underscored id, which is what keeps a year-old entry
  /// readable after its custom item has been deleted. The alternative — hiding
  /// habits that no longer exist — would quietly rewrite somebody's history.
  static String resolveLabel(
    String? professionId,
    String habitId,
    List<CraftHabit> custom,
  ) {
    for (final h in custom) {
      if (h.id == habitId) return h.label;
    }
    if (professionId != null) {
      final preset = habit(professionId, habitId);
      if (preset != null) return preset.label;
    }
    return habitId.startsWith(CraftHabit.customPrefix)
        ? 'Removed item'
        : habitId.replaceAll('_', ' ');
  }

  /// Ceiling on member-authored items.
  ///
  /// Not a storage limit — it is a design one. A checklist of thirty things is
  /// not a checklist, it is a second job, and the one reliable way to make
  /// somebody stop ticking anything is to make ticking everything impossible.
  static const maxCustomHabits = 12;

  /// Weekly targets offered at setup. Seven is deliberately not the default:
  /// a target you break in week one is worse than no target, and this app is
  /// meant to build a habit rather than to catch you failing.
  static const weeklyTargets = <int>[3, 4, 5, 6, 7];
  static const defaultWeeklyTarget = 5;

  static Color accentFor(String? professionId) => switch (professionId) {
        'student' || 'aspirant' => const Color(0xFF3B82F6),
        'engineer' || 'business' => const Color(0xFF10B981),
        'singer' || 'artist' || 'writer' => const Color(0xFFEC4899),
        'athlete' => const Color(0xFFF59E0B),
        'teacher' || 'healthcare' => const Color(0xFF06B6D4),
        'seeker' => const Color(0xFF7C3AED),
        _ => const Color(0xFF9F67FA),
      };
}

import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntry {
  final String? id;
  final String uid;
  final int mood;
  final String newHabit;
  final String tinyStep;
  final String badHabit;
  final String affirmations;
  final String visualization;
  final String nightRoutine;
  final String triggerThought;
  final String triggerResponse;
  final String bestMoment;
  final String shivBabaLine;
  final String sleepReflection;

  // Tap-to-select fields. Stored as id lists so they can be aggregated later
  // (which practices correlate with better moods) in a way free text cannot.
  final String energyLevel;
  final List<String> practices;
  final List<String> influences;
  final List<String> habitsDone;
  final List<String> challenges;

  /// Daily check-in answers, keyed by question id. Kept as a map so questions
  /// can be added or rotated without a schema change.
  final Map<String, String> checkIn;

  /// What the member did today towards their own craft — habit ids from their
  /// chosen profession. See Professions.
  ///
  /// This is the field that lets analytics answer "am I actually doing the
  /// work", which mood and meditation minutes cannot. Stored as ids rather
  /// than labels so a wording change does not orphan a year of history.
  final List<String> craftDone;

  /// Minutes spent, when they bothered to say. Zero means "did not record",
  /// not "did nothing" — the habit ids are the record of that.
  final int craftMinutes;

  final DateTime createdAt;
  final DateTime? updatedAt;

  JournalEntry({
    this.id,
    required this.uid,
    required this.mood,
    this.newHabit = '',
    this.tinyStep = '',
    this.badHabit = '',
    this.affirmations = '',
    this.visualization = '',
    this.nightRoutine = '',
    this.triggerThought = '',
    this.triggerResponse = '',
    this.bestMoment = '',
    this.shivBabaLine = '',
    this.sleepReflection = '',
    this.energyLevel = '',
    this.practices = const [],
    this.influences = const [],
    this.habitsDone = const [],
    this.challenges = const [],
    this.checkIn = const {},
    this.craftDone = const [],
    this.craftMinutes = 0,
    required this.createdAt,
    this.updatedAt,
  });

  static DateTime _parseDateTime(dynamic value, DateTime fallback) {
    if (value == null) return fallback;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _parseMood(dynamic value) {
    if (value == null) return 3;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      switch (value.toLowerCase().trim()) {
        case 'very_sad':
        case 'verysad':
        case 'sad':
          return 2;
        case 'neutral':
        case 'meh':
          return 3;
        case 'happy':
        case 'good':
          return 4;
        case 'very_happy':
        case 'veryhappy':
        case 'excited':
          return 5;
        default:
          return 3;
      }
    }
    return 3;
  }

  factory JournalEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JournalEntry(
      id: doc.id,
      uid: data['uid'] ?? '',
      mood: _parseMood(data['mood']),
      newHabit: data['newHabit'] ?? '',
      tinyStep: data['tinyStep'] ?? '',
      badHabit: data['badHabit'] ?? '',
      affirmations: data['affirmations'] ?? '',
      visualization: data['visualization'] ?? '',
      nightRoutine: data['nightRoutine'] ?? '',
      triggerThought: data['triggerThought'] ?? '',
      triggerResponse: data['triggerResponse'] ?? '',
      bestMoment: data['bestMoment'] ?? '',
      shivBabaLine: data['shivBabaLine'] ?? '',
      sleepReflection: data['sleepReflection'] ?? '',
      energyLevel: data['energyLevel'] ?? '',
      practices: List<String>.from(data['practices'] ?? const []),
      influences: List<String>.from(data['influences'] ?? const []),
      habitsDone: List<String>.from(data['habitsDone'] ?? const []),
      challenges: List<String>.from(data['challenges'] ?? const []),
      checkIn: Map<String, String>.from(data['checkIn'] ?? const {}),
      craftDone: List<String>.from(data['craftDone'] ?? const []),
      craftMinutes:
          data['craftMinutes'] is num ? (data['craftMinutes'] as num).toInt() : 0,
      // clientCreatedAt covers the window where the server stamp is still
      // pending — without it a fresh entry falls back to "now", which is right
      // by luck today and wrong for anything written offline yesterday.
      createdAt: data['createdAt'] != null
          ? _parseDateTime(data['createdAt'], DateTime.now())
          : _parseDateTime(data['clientCreatedAt'], DateTime.now()),
      updatedAt: data['updatedAt'] != null ? _parseDateTime(data['updatedAt'], DateTime.now()) : null,
    );
  }

  /// Builds an entry from the Node.js API's JSON.
  ///
  /// Two shape differences from Firestore, and both are load-bearing:
  ///
  ///   * the document id is `_id`, not `doc.id`
  ///   * dates arrive as ISO 8601 strings, not `Timestamp` objects
  ///
  /// [_parseDateTime] already understands strings, so it is reused rather than
  /// duplicated — one place decides what a date is.
  ///
  /// There is no `clientCreatedAt` fallback here and none is needed. That field
  /// existed because a Firestore `serverTimestamp()` reads back as null until
  /// the write is acknowledged, so an entry written offline had no date at all
  /// and silently dropped out of the streak. The API stamps `createdAt` before
  /// it answers, so anything this parses already has one.
  factory JournalEntry.fromJson(Map<String, dynamic> data) {
    return JournalEntry(
      id: data['_id']?.toString(),
      uid: data['firebaseUid'] ?? '',
      mood: _parseMood(data['mood']),
      newHabit: data['newHabit'] ?? '',
      tinyStep: data['tinyStep'] ?? '',
      badHabit: data['badHabit'] ?? '',
      affirmations: data['affirmations'] ?? '',
      visualization: data['visualization'] ?? '',
      nightRoutine: data['nightRoutine'] ?? '',
      triggerThought: data['triggerThought'] ?? '',
      triggerResponse: data['triggerResponse'] ?? '',
      bestMoment: data['bestMoment'] ?? '',
      shivBabaLine: data['shivBabaLine'] ?? '',
      sleepReflection: data['sleepReflection'] ?? '',
      energyLevel: data['energyLevel'] ?? '',
      practices: List<String>.from(data['practices'] ?? const []),
      influences: List<String>.from(data['influences'] ?? const []),
      habitsDone: List<String>.from(data['habitsDone'] ?? const []),
      challenges: List<String>.from(data['challenges'] ?? const []),
      checkIn: Map<String, String>.from(data['checkIn'] ?? const {}),
      craftDone: List<String>.from(data['craftDone'] ?? const []),
      craftMinutes:
          data['craftMinutes'] is num ? (data['craftMinutes'] as num).toInt() : 0,
      createdAt: _parseDateTime(data['createdAt'], DateTime.now()),
      updatedAt:
          data['updatedAt'] != null ? _parseDateTime(data['updatedAt'], DateTime.now()) : null,
    );
  }

  /// The body this entry is sent to the API as.
  ///
  /// Deliberately omits `uid`: the server takes the owner from the verified
  /// Firebase ID token, and a client-supplied uid would be a client-supplied
  /// authorization decision. It is rejected there; leaving it out here makes
  /// that contract visible from this side too.
  Map<String, dynamic> toJson() {
    final map = toMap();
    map.remove('uid');
    return map;
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'mood': mood,
      'newHabit': newHabit,
      'tinyStep': tinyStep,
      'badHabit': badHabit,
      'affirmations': affirmations,
      'visualization': visualization,
      'nightRoutine': nightRoutine,
      'triggerThought': triggerThought,
      'triggerResponse': triggerResponse,
      'bestMoment': bestMoment,
      'shivBabaLine': shivBabaLine,
      'sleepReflection': sleepReflection,
      'energyLevel': energyLevel,
      'practices': practices,
      'influences': influences,
      'habitsDone': habitsDone,
      'challenges': challenges,
      'checkIn': checkIn,
      'craftDone': craftDone,
      'craftMinutes': craftMinutes,
    };
  }

  /// True when this day counts towards craft consistency — any recorded habit,
  /// or recorded minutes without the habit taps.
  bool get didCraft => craftDone.isNotEmpty || craftMinutes > 0;

  /// A copy with some fields changed.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// Every field is listed here on purpose
  ///
  /// This used to name only the sixteen scalar fields and quietly leave out the
  /// eight list-and-map ones — `energyLevel`, `practices`, `influences`,
  /// `habitsDone`, `challenges`, `checkIn`, `craftDone`, `craftMinutes`. They
  /// were not passed through to the constructor either, so they fell back to
  /// their empty defaults: `entry.copyWith(mood: 4)` returned an entry with the
  /// new mood and **no habits, no practices, no craft and no check-in**, and
  /// saving that would have erased the lot.
  ///
  /// Nothing called it, which is the only reason no journal was ever damaged by
  /// it — a `copyWith` that silently drops half its object is a landmine for the
  /// next caller, and the deep-work screen is the first one. A field added to
  /// this class must be added here in the same commit.
  JournalEntry copyWith({
    String? id, String? uid, int? mood, String? newHabit, String? tinyStep,
    String? badHabit, String? affirmations, String? visualization,
    String? nightRoutine, String? triggerThought, String? triggerResponse,
    String? bestMoment, String? shivBabaLine, String? sleepReflection,
    String? energyLevel, List<String>? practices, List<String>? influences,
    List<String>? habitsDone, List<String>? challenges,
    Map<String, String>? checkIn, List<String>? craftDone, int? craftMinutes,
    DateTime? createdAt, DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id, uid: uid ?? this.uid, mood: mood ?? this.mood,
      newHabit: newHabit ?? this.newHabit, tinyStep: tinyStep ?? this.tinyStep,
      badHabit: badHabit ?? this.badHabit, affirmations: affirmations ?? this.affirmations,
      visualization: visualization ?? this.visualization, nightRoutine: nightRoutine ?? this.nightRoutine,
      triggerThought: triggerThought ?? this.triggerThought, triggerResponse: triggerResponse ?? this.triggerResponse,
      bestMoment: bestMoment ?? this.bestMoment, shivBabaLine: shivBabaLine ?? this.shivBabaLine,
      sleepReflection: sleepReflection ?? this.sleepReflection,
      energyLevel: energyLevel ?? this.energyLevel,
      practices: practices ?? this.practices,
      influences: influences ?? this.influences,
      habitsDone: habitsDone ?? this.habitsDone,
      challenges: challenges ?? this.challenges,
      checkIn: checkIn ?? this.checkIn,
      craftDone: craftDone ?? this.craftDone,
      craftMinutes: craftMinutes ?? this.craftMinutes,
      createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

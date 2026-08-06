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
      // clientCreatedAt covers the window where the server stamp is still
      // pending — without it a fresh entry falls back to "now", which is right
      // by luck today and wrong for anything written offline yesterday.
      createdAt: data['createdAt'] != null
          ? _parseDateTime(data['createdAt'], DateTime.now())
          : _parseDateTime(data['clientCreatedAt'], DateTime.now()),
      updatedAt: data['updatedAt'] != null ? _parseDateTime(data['updatedAt'], DateTime.now()) : null,
    );
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
    };
  }

  JournalEntry copyWith({
    String? id, String? uid, int? mood, String? newHabit, String? tinyStep,
    String? badHabit, String? affirmations, String? visualization,
    String? nightRoutine, String? triggerThought, String? triggerResponse,
    String? bestMoment, String? shivBabaLine, String? sleepReflection,
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
      createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

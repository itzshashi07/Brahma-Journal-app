import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/stats_utils.dart';

class UserProfile {
  final String uid;
  final String? name;
  final String? email;
  final int? age;
  final String? gender; // 'male' | 'female'
  final String? phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int streak;
  final int longestStreak;
  final int totalMeditationSeconds;
  final int totalJournalEntries;
  final DateTime? lastActiveAt;
  /// Id of the chosen spiritual avatar. Photo upload was removed, so this is a
  /// short catalogue key rather than a URL — see SpiritualAvatars.
  final String? avatarId;

  UserProfile({
    required this.uid,
    this.name,
    this.email,
    this.age,
    this.gender,
    this.phone,
    this.createdAt,
    this.updatedAt,
    this.streak = 0,
    this.longestStreak = 0,
    this.totalMeditationSeconds = 0,
    this.totalJournalEntries = 0,
    this.lastActiveAt,
    this.avatarId,
  });

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      // /leaderboard rows carry a precomputed `displayName` instead of the
      // full identity fields — that collection is public to signed-in members,
      // so it deliberately holds no email, phone, age or gender.
      name: data['name'] ?? data['displayName'],
      email: data['email'],
      age: data['age'] is int
          ? data['age']
          : int.tryParse(data['age']?.toString() ?? ''),
      gender: data['gender'],
      phone: data['phone'],
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      streak: _parseInt(data['streak']),
      longestStreak: _parseInt(data['longestStreak']),
      totalMeditationSeconds: _parseInt(data['totalMeditationSeconds']),
      totalJournalEntries: _parseInt(data['totalJournalEntries']),
      lastActiveAt: _parseDateTime(data['lastActiveAt']),
      avatarId: data['avatarId'],
    );
  }

  /// Older documents wrote these counters as strings/doubles; a plain cast
  /// threw and dropped the whole profile off the leaderboard.
  static int _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Identity fields only.
  ///
  /// `streak` / `totalJournalEntries` / `totalMeditationSeconds` are owned by
  /// ProfileService.syncProfileStats and are deliberately left out: this map is
  /// merged into the profile doc when a user edits their name or phone, and
  /// including the counters wrote the in-memory defaults (0) over the real
  /// numbers, wiping the member off the leaderboard.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (phone != null) 'phone': phone,
    };
  }

  UserProfile copyWith({
    String? name, String? email, int? age, String? gender, String? phone,
    int? streak, int? longestStreak, int? totalMeditationSeconds,
    int? totalJournalEntries, DateTime? lastActiveAt,
    String? avatarId,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      createdAt: createdAt,
      updatedAt: updatedAt,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalMeditationSeconds: totalMeditationSeconds ?? this.totalMeditationSeconds,
      totalJournalEntries: totalJournalEntries ?? this.totalJournalEntries,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      avatarId: avatarId ?? this.avatarId,
    );
  }

  /// True when this member journalled or meditated on the current calendar day.
  bool get isActiveToday {
    final d = lastActiveAt;
    if (d == null) return false;
    return isSameDayAsToday(d);
  }

  /// The streak as of right now, rather than as of the last time this member
  /// opened the app.
  ///
  /// Firestore rules let a profile be rewritten only by its owner, so a member
  /// who stops practising leaves a frozen `streak` on their doc and sits at the
  /// top of the leaderboard forever. Anyone whose last activity is older than
  /// yesterday has broken their streak, so the board ages it out on read.
  int get currentStreak {
    if (streak <= 0) return 0;
    final d = lastActiveAt;
    if (d == null) return streak; // legacy doc — trust it until the owner syncs
    return daysBetween(d, DateTime.now()) <= 1 ? streak : 0;
  }

  String get displayName => name ?? email?.split('@').first ?? 'Soul';
  String get initials {
    if (name != null && name!.isNotEmpty) {
      final parts = name!.split(' ');
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return name![0].toUpperCase();
    }
    return email?.substring(0, 1).toUpperCase() ?? 'S';
  }
}

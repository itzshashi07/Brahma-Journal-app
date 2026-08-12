import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// One step towards a milestone.
///
/// The `id` is generated on the handset, before the server has seen it, because
/// a todo is ticked the moment it is tapped and needs identifying immediately.
class MilestoneTodo {
  final String id;
  final String label;
  final bool done;
  final DateTime? doneAt;

  const MilestoneTodo({
    required this.id,
    required this.label,
    this.done = false,
    this.doneAt,
  });

  factory MilestoneTodo.create(String label) => MilestoneTodo(
        id: 't${DateTime.now().microsecondsSinceEpoch}',
        label: label,
      );

  factory MilestoneTodo.fromJson(Map<String, dynamic> data) => MilestoneTodo(
        id: (data['id'] ?? '').toString(),
        label: (data['label'] ?? '').toString(),
        done: data['done'] == true,
        doneAt: DateTime.tryParse('${data['doneAt'] ?? ''}'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'done': done,
        if (doneAt != null) 'doneAt': doneAt!.toUtc().toIso8601String(),
      };

  MilestoneTodo copyWith({String? label, bool? done, DateTime? doneAt}) =>
      MilestoneTodo(
        id: id,
        label: label ?? this.label,
        done: done ?? this.done,
        doneAt: done == false ? null : (doneAt ?? this.doneAt),
      );
}

/// What somebody is building, and by when.
class Milestone {
  final String id;
  final String title;
  final String why;
  final String craft;
  final DateTime? targetDate;

  /// 'active' | 'achieved' | 'dropped'.
  final String status;

  final DateTime? achievedAt;
  final DateTime createdAt;
  final List<MilestoneTodo> todos;

  const Milestone({
    required this.id,
    required this.title,
    this.why = '',
    this.craft = '',
    this.targetDate,
    this.status = 'active',
    this.achievedAt,
    required this.createdAt,
    this.todos = const [],
  });

  factory Milestone.fromJson(Map<String, dynamic> data) => Milestone(
        id: (data['_id'] ?? data['id'] ?? '').toString(),
        title: (data['title'] ?? '').toString(),
        why: (data['why'] ?? '').toString(),
        craft: (data['craft'] ?? '').toString(),
        targetDate: DateTime.tryParse('${data['targetDate'] ?? ''}'),
        status: (data['status'] ?? 'active').toString(),
        achievedAt: DateTime.tryParse('${data['achievedAt'] ?? ''}'),
        createdAt:
            DateTime.tryParse('${data['createdAt'] ?? ''}') ?? DateTime.now(),
        todos: ((data['todos'] as List?) ?? const [])
            .map((t) => MilestoneTodo.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
      );

  bool get isActive => status == 'active';
  int get doneCount => todos.where((t) => t.done).length;
  int get openCount => todos.length - doneCount;

  /// 0–1. A milestone with no todos yet reads as 0 rather than as complete —
  /// an empty list is "not started", and showing 100% for it would be the
  /// worst possible first impression of a progress bar.
  double get progress => todos.isEmpty ? 0 : doneCount / todos.length;

  /// Whole days until the target, negative once it has passed.
  int? get daysLeft {
    final target = targetDate;
    if (target == null) return null;
    final today = DateTime.now();
    return DateTime(target.year, target.month, target.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  Milestone copyWith({
    String? title,
    String? why,
    DateTime? targetDate,
    bool clearTarget = false,
    String? status,
    List<MilestoneTodo>? todos,
  }) =>
      Milestone(
        id: id,
        title: title ?? this.title,
        why: why ?? this.why,
        craft: craft,
        targetDate: clearTarget ? null : (targetDate ?? this.targetDate),
        status: status ?? this.status,
        achievedAt: achievedAt,
        createdAt: createdAt,
        todos: todos ?? this.todos,
      );
}

/// Milestones, over the API.
///
/// Deliberately thin: the screen holds the milestone it is editing and sends
/// the whole todo list back on every change. A list of six lines is smaller
/// than the request that would carry a patch describing the change to it, and
/// "this is my list now" cannot get out of order the way six per-item routes
/// can when two of them land out of sequence.
class MilestoneService {
  final ApiService _api = ApiService();

  Future<List<Milestone>> all() async {
    try {
      final body = await _api.get('/api/practice/milestones', query: {'limit': '100'});
      return ((body?['milestones'] as List?) ?? const [])
          .map((m) => Milestone.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Could not load milestones: $e');
      rethrow;
    }
  }

  /// Achievements grouped by the month they were achieved in.
  ///
  /// Counted by the server rather than from [all], because that listing is
  /// paged: a total computed from page one is right until somebody has more
  /// than a page of achievements and quietly wrong for ever after.
  ///
  /// The timezone goes with the request — a month boundary is local, and
  /// without it everything achieved in the first five and a half hours of an
  /// Indian month is filed under the previous one.
  Future<AchievementHistory> achievements() async {
    try {
      final tz = DateTime.now().timeZoneOffset.inMinutes;
      final body = await _api.get('/api/practice/milestones/achievements',
          query: {'tz': '$tz'});

      return AchievementHistory(
        total: (body?['total'] as num?)?.toInt() ?? 0,
        months: ((body?['months'] as List?) ?? const [])
            .map((m) => AchievementMonth.fromJson(
                Map<String, dynamic>.from(m as Map)))
            .toList(),
      );
    } catch (e) {
      debugPrint('⚠️ Could not load achievements: $e');
      return const AchievementHistory(total: 0, months: []);
    }
  }

  Future<Milestone> create({
    required String title,
    String why = '',
    String craft = '',
    DateTime? targetDate,
    List<MilestoneTodo> todos = const [],
  }) async {
    final body = await _api.post('/api/practice/milestones', {
      'title': title,
      'why': why,
      'craft': craft,
      'targetDate': targetDate?.toUtc().toIso8601String(),
      'todos': todos.map((t) => t.toJson()).toList(),
    });
    return Milestone.fromJson(
        Map<String, dynamic>.from(body?['milestone'] as Map));
  }

  Future<Milestone> update(
    String id, {
    String? title,
    String? why,
    DateTime? targetDate,
    bool clearTarget = false,
    String? status,
    List<MilestoneTodo>? todos,
  }) async {
    final body = await _api.patch('/api/practice/milestones/$id', {
      if (title != null) 'title': title,
      if (why != null) 'why': why,
      if (clearTarget) 'targetDate': null,
      if (!clearTarget && targetDate != null)
        'targetDate': targetDate.toUtc().toIso8601String(),
      if (status != null) 'status': status,
      if (todos != null) 'todos': todos.map((t) => t.toJson()).toList(),
    });
    return Milestone.fromJson(
        Map<String, dynamic>.from(body?['milestone'] as Map));
  }

  Future<void> remove(String id) =>
      _api.delete('/api/practice/milestones/$id');
}

/// One month's achievements — how many, and which.
class AchievementMonth {
  /// 'yyyy-MM', in the member's own calendar.
  final String month;
  final int count;
  final List<String> titles;

  const AchievementMonth({
    required this.month,
    required this.count,
    this.titles = const [],
  });

  factory AchievementMonth.fromJson(Map<String, dynamic> data) =>
      AchievementMonth(
        month: (data['month'] ?? '').toString(),
        count: (data['count'] as num?)?.toInt() ?? 0,
        titles: ((data['titles'] as List?) ?? const [])
            .map((t) => t.toString())
            .toList(),
      );

  /// 'August 2026'. Falls back to the raw key rather than throwing on anything
  /// unexpected — a label is never worth an error screen.
  String get label {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    final year = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (year == null || m == null || m < 1 || m > 12) return month;

    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${names[m - 1]} $year';
  }

  bool get isThisMonth {
    final now = DateTime.now();
    return month ==
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }
}

class AchievementHistory {
  final int total;
  final List<AchievementMonth> months;

  const AchievementHistory({required this.total, required this.months});

  int get thisMonth =>
      months.where((m) => m.isThisMonth).fold(0, (sum, m) => sum + m.count);

  /// The best month, for the one line analytics leads with.
  AchievementMonth? get busiest {
    if (months.isEmpty) return null;
    return months.reduce((a, b) => b.count > a.count ? b : a);
  }
}

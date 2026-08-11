import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Reporting, blocking and hiding.
///
/// Google Play requires any app carrying user-generated content to give people
/// an in-app way to report what they see and to stop seeing a particular
/// person. This app had neither: the only moderation tool was an admin delete
/// button, so a member who read something abusive at 2am had no move except to
/// close the app. On an anonymous mental-health board that is the worst
/// possible answer.
///
/// Two mechanisms, because the app has two kinds of content and they are not
/// the same problem:
///
///   * **Named content** — articles and comments carry their author's uid, so
///     [blockUser] works properly: block someone and their writing disappears
///     from your feed for good.
///   * **The anonymous board** — reflections deliberately carry no author, and
///     that is a promise the app keeps rather than a gap to be closed. You
///     cannot block a person you cannot identify, so the answer there is
///     [hideThought]: this specific post, gone from your feed, permanently and
///     locally.
///
/// Reports go to an admin queue either way, and a report always carries enough
/// context for a human to find the thing being complained about.
class ModerationService {

  // ─────────────────────────── reporting ───────────────────────────

  /// Categories offered in the report sheet. Deliberately short: a long list
  /// makes people abandon the form, and every one of these routes to the same
  /// human anyway.
  static const reasons = <String>[
    'Harassment or bullying',
    'Self-harm or suicide risk',
    'Hate speech',
    'Sexual or explicit content',
    'Spam or scam',
    'Something else',
  ];

  /// Files a report for a human to read.
  ///
  /// [contentKind] is 'thought' | 'reply' | 'blog' | 'comment'. [excerpt] is a
  /// copy of the offending text, stored on the report itself on purpose: the
  /// content may be deleted — by its author, by the 30-day sweep, or by the
  /// reporter hiding it — before anybody reads the queue, and a report that
  /// says only "post xyz was abusive" is unactionable.
  ///
  /// 'Self-harm or suicide risk' is why this exists at all as much as abuse is.
  /// Somebody flagging that a stranger sounds in danger is the most valuable
  /// message this app can receive, and it must never be more than two taps.
  Future<bool> report({
    required String contentKind,
    required String contentId,
    required String reason,
    String excerpt = '',
    String? parentId,
    String? reportedUid,
    String note = '',
  }) async {
    try {
      // The server upserts on (reporter, content), so a second tap updates the
      // first report rather than filing a duplicate — one person reporting one
      // thing twice is not two complaints. The reporter comes off the verified
      // token, so a report cannot be filed in somebody else's name.
      await ApiService().post('/api/support/reports', {
        'contentKind': contentKind,
        'contentId': contentId,
        if (parentId != null) 'parentId': parentId,
        if (reportedUid != null) 'reportedUid': reportedUid,
        'reason': reason,
        'note': note.trim(),
        'excerpt': excerpt.length > 1000 ? excerpt.substring(0, 1000) : excerpt,
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ Report failed: $e');
      return false;
    }
  }

  /// The admin queue, newest first.
  ///
  /// A `Future` rather than a live stream: MongoDB has no client-side realtime
  /// channel, and the operator now learns about a report through FCM the moment
  /// it is filed rather than by keeping a listener open. The pull-to-refresh
  /// the screen already has covers the rest.
  Future<List<ContentReport>> openReports() async {
    try {
      final body = await ApiService()
          .get('/api/support/reports', query: {'status': 'open'});
      final list = (body?['reports'] as List? ?? const []);
      return list
          .map((r) => ContentReport.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Report queue unavailable: $e');
      return const [];
    }
  }

  /// Kept so existing StreamBuilder call sites compile unchanged.
  Stream<List<ContentReport>> streamOpenReports() =>
      Stream.fromFuture(openReports());

  /// Marks a report handled. [outcome] is recorded so a pattern of complaints
  /// about the same person is visible later.
  Future<void> resolveReport(String reportId, String outcome) async {
    await ApiService().patch('/api/support/reports/$reportId', {
      'status': 'resolved',
      'outcome': outcome,
    });
  }

  // ─────────────────────────── blocking ───────────────────────────

  Future<void> blockUser(String blockedUid) async {
    await ApiService().post('/api/community/blocks/$blockedUid');
  }

  Future<void> unblockUser(String blockedUid) async {
    await ApiService().delete('/api/community/blocks/$blockedUid');
  }

  /// The uids this member has blocked.
  ///
  /// Feeds filter against this. It is also applied server-side — the board
  /// endpoint excludes blocked authors before it answers — so a blocked post
  /// never reaches the device even if this set is stale.
  Future<Set<String>> blockedUidsOnce() async {
    try {
      final body = await ApiService().get('/api/community/blocks');
      final list = (body?['blocked'] as List? ?? const []);
      return list.map((e) => e.toString()).toSet();
    } catch (e) {
      return const {};
    }
  }

  /// Kept so existing StreamBuilder call sites compile unchanged.
  Stream<Set<String>> blockedUids() => Stream.fromFuture(blockedUidsOnce());

  // ─────────────────────── hiding anonymous posts ───────────────────────
  //
  // Local, in SharedPreferences, and that is the correct home for it. The
  // alternative — a Firestore document listing the reflections you have hidden
  // — would be a per-user record of which anonymous posts you cared enough
  // about to suppress, which is exactly the sort of trail this feature exists
  // to avoid leaving.

  static const _kHidden = 'moderation_hidden_thoughts';

  Future<Set<String>> hiddenThoughtIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kHidden) ?? const []).toSet();
  }

  Future<void> hideThought(String thoughtId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_kHidden) ?? const []).toSet()
      ..add(thoughtId);
    await prefs.setStringList(_kHidden, current.toList());
  }

  Future<void> unhideAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHidden);
  }
}

class ContentReport {
  final String id;
  final String reporterUid;
  final String contentKind;
  final String contentId;
  final String? parentId;
  final String? reportedUid;
  final String reason;
  final String note;
  final String excerpt;
  final DateTime createdAt;

  ContentReport({
    required this.id,
    required this.reporterUid,
    required this.contentKind,
    required this.contentId,
    this.parentId,
    this.reportedUid,
    required this.reason,
    required this.note,
    required this.excerpt,
    required this.createdAt,
  });

  factory ContentReport.fromJson(Map<String, dynamic> d) {
    return ContentReport(
      id: d['_id']?.toString() ?? '',
      reporterUid: d['reporterUid'] ?? '',
      contentKind: d['contentKind'] ?? '',
      contentId: d['contentId'] ?? '',
      parentId: d['parentId'],
      reportedUid: d['reportedUid'],
      reason: d['reason'] ?? '',
      note: d['note'] ?? '',
      excerpt: d['excerpt'] ?? '',
      createdAt:
          DateTime.tryParse(d['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// True when somebody flagged that the author may be in danger. The inbox
  /// pulls these to the top — everything else in the queue can wait.
  bool get isUrgent => reason.toLowerCase().contains('self-harm');
}

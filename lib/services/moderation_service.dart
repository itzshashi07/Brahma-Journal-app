import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

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
    final uid = _uid;
    if (uid == null) return false;

    try {
      // Deterministic id: one report per person per item. Someone tapping
      // report twice is not two complaints, and it stops the queue being
      // flooded from a single account.
      await _db.collection('content_reports').doc('${uid}_$contentId').set({
        'reporterUid': uid,
        'contentKind': contentKind,
        'contentId': contentId,
        if (parentId != null) 'parentId': parentId,
        if (reportedUid != null) 'reportedUid': reportedUid,
        'reason': reason,
        'note': note.trim(),
        'excerpt': excerpt.length > 1000 ? excerpt.substring(0, 1000) : excerpt,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ Report failed: $e');
      return false;
    }
  }

  /// The admin queue, newest first.
  Stream<List<ContentReport>> streamOpenReports() => _db
      .collection('content_reports')
      .where('status', isEqualTo: 'open')
      .snapshots()
      .map((s) {
        final list = s.docs.map(ContentReport.fromDoc).toList();
        // Sorted here rather than by Firestore: `where` + `orderBy` needs a
        // composite index, and a missing index fails the query outright — which
        // would leave the moderator staring at an empty queue.
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  /// Marks a report handled. [outcome] is recorded so a pattern of complaints
  /// about the same person is visible later.
  Future<void> resolveReport(String reportId, String outcome) async {
    await _db.collection('content_reports').doc(reportId).update({
      'status': 'resolved',
      'outcome': outcome,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────── blocking ───────────────────────────

  CollectionReference<Map<String, dynamic>> _blocks(String uid) =>
      _db.collection('blocks').doc(uid).collection('users');

  /// Stops [blockedUid]'s articles and comments reaching this member.
  ///
  /// Stored under the blocker's own document, readable only by them: who you
  /// have blocked is nobody else's business, and telling the blocked person
  /// would turn a quiet exit into a confrontation.
  Future<void> blockUser(String blockedUid) async {
    final uid = _uid;
    if (uid == null || blockedUid.isEmpty || blockedUid == uid) return;
    await _blocks(uid).doc(blockedUid).set({
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String blockedUid) async {
    final uid = _uid;
    if (uid == null) return;
    await _blocks(uid).doc(blockedUid).delete().catchError((_) {});
  }

  /// Live set of uids this member has blocked. Feeds filter against it.
  Stream<Set<String>> blockedUids() {
    final uid = _uid;
    if (uid == null) return Stream.value(const {});
    return _blocks(uid).snapshots().map((s) => s.docs.map((d) => d.id).toSet());
  }

  Future<Set<String>> blockedUidsOnce() async {
    final uid = _uid;
    if (uid == null) return const {};
    try {
      final snap = await _blocks(uid).get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (e) {
      return const {};
    }
  }

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

  factory ContentReport.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return ContentReport(
      id: doc.id,
      reporterUid: d['reporterUid'] ?? '',
      contentKind: d['contentKind'] ?? '',
      contentId: d['contentId'] ?? '',
      parentId: d['parentId'],
      reportedUid: d['reportedUid'],
      reason: d['reason'] ?? '',
      note: d['note'] ?? '',
      excerpt: d['excerpt'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// True when somebody flagged that the author may be in danger. The inbox
  /// pulls these to the top — everything else in the queue can wait.
  bool get isUrgent => reason.toLowerCase().contains('self-harm');
}

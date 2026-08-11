/// One reply on a reflection.
///
/// **Carries no `uid`, and that is the entire point.** Every reply used to
/// store its author's uid inside the parent thought document — the same
/// document every signed-in member is allowed to read. So while the reflection
/// itself was carefully anonymised (authorship was moved out to
/// /thought_authors, which no client can read), anyone could dump the feed,
/// read `replies[].uid`, and join it against /profiles to put a real name and
/// email against every reply on the board. The feature's promise held for the
/// posts and quietly failed for the conversation underneath them, which is
/// where people say the more revealing things.
///
/// Authorship now goes to /thought_reply_authors, readable only by an admin, so
/// moderation can still act on a person without the board exposing them.
class ThoughtReply {
  final String id;
  final String content;
  final DateTime createdAt;
  final String anonymousName;
  final String anonymousColor;

  ThoughtReply({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.anonymousName,
    required this.anonymousColor,
  });

  factory ThoughtReply.fromMap(Map<String, dynamic> data) {
    return ThoughtReply(
      id: (data['id'] ?? data['_id'] ?? '').toString(),
      content: data['content'] ?? '',
      createdAt:
          DateTime.tryParse(data['createdAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      anonymousName: data['anonymousName'] ?? 'Quiet Voice',
      anonymousColor: data['anonymousColor'] ?? '#8B5CF6',
    );
  }

  /// Deliberately omits `uid` — the API never returns one for a reply, and
  /// nothing on the device should be able to reintroduce it.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'anonymousName': anonymousName,
      'anonymousColor': anonymousColor,
    };
  }
}

class AnonymousThought {
  final String id;
  final String content;
  final DateTime createdAt;
  final List<ThoughtReply> replies;
  final String anonymousName;
  final String anonymousColor;

  /// Whether the person reading this wrote it.
  ///
  /// **The server says so; the device cannot work it out.** The board carries
  /// no author and the authorship map is admin-only, so this is the answer to a
  /// question only the API can answer, about the caller and nobody else. It is
  /// what draws the "delete" affordance on somebody's own reflection.
  ///
  /// The app used to keep a private local list for this, which meant a
  /// reinstall or a second phone quietly took away someone's ability to delete
  /// what they had written.
  final bool mine;

  AnonymousThought({
    required this.id,
    required this.content,
    required this.createdAt,
    this.replies = const [],
    required this.anonymousName,
    required this.anonymousColor,
    this.mine = false,
  });

  factory AnonymousThought.fromJson(Map<String, dynamic> data) {
    return AnonymousThought(
      id: (data['_id'] ?? data['id'] ?? '').toString(),
      content: data['content'] ?? '',
      createdAt:
          DateTime.tryParse(data['createdAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      replies: (data['replies'] as List<dynamic>?)
              ?.map((r) => ThoughtReply.fromMap(
                    Map<String, dynamic>.from(r as Map),
                  ))
              .toList() ??
          const [],
      anonymousName: data['anonymousName'] ?? 'Quiet Voice',
      anonymousColor: data['anonymousColor'] ?? '#8B5CF6',
      mine: data['mine'] == true,
    );
  }

  /// How many replies this reflection has. The notification feed compares this
  /// against what the reader has already seen, so it is worth naming rather
  /// than writing `.replies.length` at four call sites.
  int get replyCount => replies.length;
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/community_service.dart';
import '../../services/moderation_service.dart';
import '../../services/notification_center.dart';
import '../../widgets/report_sheet.dart';
import '../../models/anonymous_thought.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';

class AnonymousThoughtsScreen extends StatefulWidget {
  const AnonymousThoughtsScreen({super.key});

  @override
  State<AnonymousThoughtsScreen> createState() => _AnonymousThoughtsScreenState();
}

class _AnonymousThoughtsScreenState extends State<AnonymousThoughtsScreen> {
  final CommunityService _service = CommunityService();
  final ModerationService _moderation = ModerationService();
  List<AnonymousThought> _thoughts = [];

  /// Reflections this member wrote, so they can take their own words back.
  Set<String> _mine = const {};

  /// Reflections this member has chosen never to see again. Local by design —
  /// see ModerationService.hideThought.
  Set<String> _hidden = const {};
  bool _isLoading = true;
  final TextEditingController _thoughtCtrl = TextEditingController();
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadThoughts();
  }

  /// Threads that had unread replies when this screen opened.
  ///
  /// Captured once, before the badge is cleared, so the "new" marker survives
  /// long enough to be read. Clearing first and rendering from the live value
  /// would mean the thing the notification pointed at is unmarked by the time
  /// the member's eyes reach it.
  Set<String> _wasUnread = const {};

  Future<void> _loadThoughts() async {
    setState(() => _isLoading = true);
    final thoughts = await _service.getAnonymousThoughts();
    if (!mounted) return;

    final notifications = context.read<NotificationCenter>();
    final auth = context.read<AuthProvider>();

    final mine = auth.user == null
        ? const <String>{}
        : await _service.myAuthoredThoughtIds(auth.user!.uid);
    final hidden = await _moderation.hiddenThoughtIds();
    if (!mounted) return;

    setState(() {
      // Anything this member has hidden never reaches the list at all, rather
      // than being drawn and then filtered — a post you asked never to see
      // again should not flicker past on every refresh.
      _thoughts = thoughts.where((t) => !hidden.contains(t.id)).toList();
      _mine = mine;
      _hidden = hidden;
      _isLoading = false;
      if (_wasUnread.isEmpty) _wasUnread = notifications.unreadThreadIds;
    });

    // Everything on this screen counts as seen now.
    notifications.markThoughtRepliesSeen();

    // Clear out month-old posts in the background. Not awaited — the feed is
    // already filtered on read, so this is pure housekeeping and must never
    // make the screen feel slow.
    //
    // An admin sweeps everybody's expired reflections, which is what actually
    // delivers "deleted after a month" without a TTL policy or a scheduled
    // function; a member can only ever clear their own.
    if (auth.isAdmin) {
      _service.purgeExpiredThoughts();
      // Strips the author uid that pre-existing replies still carry inside the
      // public document. Only an admin can rewrite other people's reflections,
      // so this is the only place the old leak can actually be closed.
      _service.scrubLegacyReplyIds();
    } else if (auth.user != null) {
      _service.purgeMyExpiredThoughts(auth.user!.uid);
    }
  }

  Future<void> _postThought() async {
    if (_thoughtCtrl.text.trim().isEmpty) return;
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() => _isPosting = true);
    try {
      await _service.saveAnonymousThought(_thoughtCtrl.text.trim(), auth.user!.uid);
      _thoughtCtrl.clear();
      await _loadThoughts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      setState(() => _isPosting = false);
    }
  }

  /// Admin moderation. Confirmed, because it cannot be undone and the author
  /// has no way to repost what they wrote.
  Future<void> _deleteThought(String thoughtId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove this reflection?',
            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: const Text(
          'It will be deleted for everyone. This cannot be undone.',
          style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteThought(thoughtId);
      await _loadThoughts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove that reflection.',
                style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Admin moderation of a single reply.
  ///
  /// The reflection it hangs off is left alone. Before this existed the only
  /// moderation tool was deleting the whole post, so one abusive reply cost the
  /// author their reflection and everybody else the thread — punishing the
  /// wrong person for the thing that went wrong.
  Future<void> _deleteReply(String thoughtId, String replyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove this reply?',
            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: const Text(
          'Only this reply is removed. The reflection and every other reply '
          'stay exactly as they are.',
          style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteReply(thoughtId, replyId);
      await _loadThoughts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove that reply.',
                style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _hideThought(AnonymousThought t) async {
    await _moderation.hideThought(t.id);
    if (!mounted) return;
    setState(() {
      _hidden = {..._hidden, t.id};
      _thoughts = _thoughts.where((x) => x.id != t.id).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hidden. You will not see that one again.',
            style: TextStyle(fontFamily: 'Outfit')),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Future<void> _replyToThought(String thoughtId) async {
    final ctrl = TextEditingController();
    final auth = context.read<AuthProvider>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Reply', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
          decoration: const InputDecoration(hintText: 'Share your thoughts...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await _service.addReplyToThought(thoughtId, ctrl.text.trim(), auth.user!.uid);
              if (mounted) Navigator.pop(ctx);
              await _loadThoughts();
            },
            child: const Text('Reply'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _thoughtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20), onPressed: () => context.pop()),
                    const Expanded(
                      child: Text('Anonymous Thoughts', style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), textAlign: TextAlign.center),
                    ),
                    IconButton(icon: const Icon(Icons.refresh, color: AppTheme.textMuted), onPressed: _loadThoughts),
                  ],
                ),
              ),

              // Post a Thought
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2D2D4E)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Share Anonymously', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      const Text(
                        'Your identity is protected with a generated name. '
                        'Reflections are deleted a month after they are posted.',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _thoughtCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit', fontSize: 14),
                        decoration: const InputDecoration(hintText: 'What\'s on your mind...'),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isPosting ? null : _postThought,
                          child: _isPosting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Share Thought'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Thoughts List
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadThoughts,
                    color: AppTheme.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _thoughts.length,
                      itemBuilder: (ctx, i) {
                        final t = _thoughts[i];
                        final isAdmin = context.read<AuthProvider>().isAdmin;
                        final isMine = _mine.contains(t.id);
                        return _ThoughtCard(
                          thought: t,
                          onReply: () => _replyToThought(t.id),
                          // The author can take their own reflection down, and
                          // so can a moderator. Before this only an admin
                          // could, which meant somebody who regretted posting
                          // at 3am had to email support to unsay it.
                          canDelete: isAdmin || isMine,
                          isMine: isMine,
                          onDelete: () => _deleteThought(t.id),
                          canDeleteReplies: isAdmin || isMine,
                          onDeleteReply: (replyId) => _deleteReply(t.id, replyId),
                          onHide: () => _hideThought(t),
                          onReport: () => ReportSheet.show(
                            context,
                            contentKind: 'thought',
                            contentId: t.id,
                            excerpt: t.content,
                          ),
                          onReportReply: (r) => ReportSheet.show(
                            context,
                            contentKind: 'reply',
                            contentId: '${t.id}_${r.id}',
                            parentId: t.id,
                            excerpt: r.content,
                          ),
                          hasNewReplies: _wasUnread.contains(t.id),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThoughtCard extends StatefulWidget {
  final AnonymousThought thought;
  final VoidCallback onReply;
  final bool canDelete;
  final bool canDeleteReplies;
  final bool isMine;
  final VoidCallback onDelete;
  final void Function(String replyId) onDeleteReply;
  final VoidCallback onHide;
  final VoidCallback onReport;
  final void Function(ThoughtReply reply) onReportReply;

  /// Whether this thread had replies the member had not seen when the screen
  /// opened. Drives the "new" marker, not the data.
  final bool hasNewReplies;

  const _ThoughtCard({
    required this.thought,
    required this.onReply,
    this.canDelete = false,
    this.canDeleteReplies = false,
    this.isMine = false,
    required this.onDelete,
    required this.onDeleteReply,
    required this.onHide,
    required this.onReport,
    required this.onReportReply,
    this.hasNewReplies = false,
  });

  @override
  State<_ThoughtCard> createState() => _ThoughtCardState();
}

class _ThoughtCardState extends State<_ThoughtCard> {
  /// Collapsed to the first two replies until asked otherwise — long threads
  /// would otherwise push every other reflection off the screen.
  ///
  /// A thread the member has not caught up on opens expanded: they were sent
  /// here by a notification about a reply, and making them tap again to find it
  /// is the one thing this screen should not do.
  late bool _expanded = widget.hasNewReplies;

  static const _collapsedReplies = 2;

  @override
  Widget build(BuildContext context) {
    final thought = widget.thought;
    final canDelete = widget.canDelete;
    final canDeleteReplies = widget.canDeleteReplies;
    final color = hexToColor(thought.anonymousColor);
    final replies = thought.replies;
    final shown =
        _expanded ? replies : replies.take(_collapsedReplies).toList();
    final hidden = replies.length - shown.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D4E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.2),
                child: Text(thought.anonymousName[0], style: TextStyle(color: color, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(thought.anonymousName, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: color)),
                  Row(
                    children: [
                      if (canDelete) ...[
                        GestureDetector(
                          onTap: widget.onDelete,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.delete_outline_rounded,
                                size: 15, color: Colors.redAccent),
                          ),
                        ),
                      ],
                      Text(AppDateUtils.formatRelative(thought.createdAt), style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(width: 6),
                      // Reflections vanish after a month. Saying so on the card
                      // sets the expectation up front — a post silently
                      // disappearing later reads as data loss, not as a feature.
                      Text(
                        '· ${_expiryLabel(thought.createdAt)}',
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(thought.content, style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 15, height: 1.5)),
          const SizedBox(height: 12),

          // Replies
          if (replies.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  replies.length == 1 ? '1 reply' : '${replies.length} replies',
                  style: const TextStyle(
                      fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted),
                ),
                if (widget.hasNewReplies) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            ...shown.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 6, left: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgCardLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2D2D4E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.anonymousName,
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hexToColor(r.anonymousColor)),
                        ),
                      ),
                      // Anyone can flag a reply; only a moderator or the
                      // owner of the thread can remove one.
                      GestureDetector(
                        onTap: () => widget.onReportReply(r),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.flag_outlined,
                              size: 13, color: AppTheme.textMuted),
                        ),
                      ),
                      // Moderation on the individual reply. Sits on the reply
                      // rather than in a menu because whoever acts here has
                      // already been told which one is the problem.
                      if (canDeleteReplies)
                        GestureDetector(
                          onTap: () => widget.onDeleteReply(r.id),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.close_rounded,
                                size: 14, color: Colors.redAccent),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.content, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            )),
            if (hidden > 0 || _expanded && replies.length > _collapsedReplies)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    _expanded
                        ? 'Show fewer'
                        : hidden == 1
                            ? 'Show 1 more reply'
                            : 'Show $hidden more replies',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryLight,
                    ),
                  ),
                ),
              ),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: widget.onReply,
                behavior: HitTestBehavior.opaque,
                child: const Row(
                  children: [
                    Icon(Icons.reply, color: AppTheme.textMuted, size: 16),
                    SizedBox(width: 6),
                    Text('Reply', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              const Spacer(),
              // Reporting and hiding are not offered on your own reflection:
              // both would be nonsense, and the delete control above already
              // covers what you would actually want to do with it.
              if (!widget.isMine) ...[
                _CardAction(
                  icon: Icons.flag_outlined,
                  label: 'Report',
                  onTap: widget.onReport,
                ),
                const SizedBox(width: 14),
                _CardAction(
                  icon: Icons.visibility_off_outlined,
                  label: 'Hide',
                  onTap: widget.onHide,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A quiet text action in the card footer. Muted on purpose: reporting and
/// hiding must be findable without competing with Reply, which is the thing
/// the board actually wants people to do.
class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: AppTheme.textMuted,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

/// "fades in 3 days" — how long before this reflection is removed.
String _expiryLabel(DateTime createdAt) {
  final goesAt = createdAt.add(CommunityService.thoughtLifetime);
  final left = goesAt.difference(DateTime.now());
  if (left.isNegative) return 'fading now';
  if (left.inHours < 24) return 'fades today';
  final days = left.inDays + 1;
  if (days == 1) return 'fades tomorrow';
  // Beyond a fortnight the day count stops meaning anything to a reader —
  // "fades in 29 days" is noise where "fades in 4 weeks" is a shape.
  if (days <= 14) return 'fades in $days days';
  return 'fades in ${(days / 7).round()} weeks';
}

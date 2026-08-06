import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/community_service.dart';
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
  List<AnonymousThought> _thoughts = [];
  bool _isLoading = true;
  final TextEditingController _thoughtCtrl = TextEditingController();
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadThoughts();
  }

  Future<void> _loadThoughts() async {
    setState(() => _isLoading = true);
    final thoughts = await _service.getAnonymousThoughts();
    if (!mounted) return;
    setState(() { _thoughts = thoughts; _isLoading = false; });

    // Clear out this member's own week-old posts in the background. Not
    // awaited — the feed is already filtered, so this is pure housekeeping and
    // must never make the screen feel slow.
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) _service.purgeMyExpiredThoughts(uid);
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
                      const Text('Your identity is protected with a spiritual name', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted)),
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
                        return _ThoughtCard(thought: t, onReply: () => _replyToThought(t.id));
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

class _ThoughtCard extends StatelessWidget {
  final AnonymousThought thought;
  final VoidCallback onReply;

  const _ThoughtCard({required this.thought, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(thought.anonymousColor);

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
                      Text(AppDateUtils.formatRelative(thought.createdAt), style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(width: 6),
                      // Reflections vanish after a week. Saying so on the card
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
          if (thought.replies.isNotEmpty) ...[
            Text('${thought.replies.length} reply/replies', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 8),
            ...thought.replies.take(2).map((r) => Container(
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
                  Text(r.anonymousName, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.w600, color: hexToColor(r.anonymousColor))),
                  const SizedBox(height: 4),
                  Text(r.content, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            )),
          ],

          const SizedBox(height: 8),
          GestureDetector(
            onTap: onReply,
            child: const Row(
              children: [
                Icon(Icons.reply, color: AppTheme.textMuted, size: 16),
                SizedBox(width: 6),
                Text('Reply', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 13)),
              ],
            ),
          ),
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
  return days == 1 ? 'fades tomorrow' : 'fades in $days days';
}

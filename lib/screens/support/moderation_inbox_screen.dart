import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../services/community_service.dart';
import '../../services/moderation_service.dart';
import '../../widgets/sacred.dart';

/// Where reports land.
///
/// A report queue nobody reads is worse than no report button at all: it tells
/// the member their complaint went somewhere, and it did not. So this is a
/// working surface, not a log — each row carries the reported text and the two
/// actions a moderator actually takes.
///
/// **Self-harm reports sort to the top, regardless of age.** Everything else in
/// this queue is a moderation decision that can wait an hour; that one is
/// somebody saying a stranger might be in danger.
class ModerationInboxScreen extends StatelessWidget {
  const ModerationInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final moderation = ModerationService();

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: 'Reports',
                subtitle: 'What members have flagged',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: StreamBuilder<List<ContentReport>>(
                  stream: moderation.streamOpenReports(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary),
                      );
                    }
                    if (snap.hasError) {
                      return const _Empty(
                        icon: Icons.error_outline_rounded,
                        text: 'Could not load the queue.',
                      );
                    }

                    final reports = [...(snap.data ?? const <ContentReport>[])];
                    if (reports.isEmpty) {
                      return const _Empty(
                        icon: Icons.verified_outlined,
                        text: 'Nothing reported. The board is quiet.',
                      );
                    }

                    // Urgent first, then newest. Sorted here because Firestore
                    // cannot order by a derived property.
                    reports.sort((a, b) {
                      if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
                      return b.createdAt.compareTo(a.createdAt);
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          AppTheme.space4, 0, AppTheme.space4, AppTheme.space5),
                      itemCount: reports.length,
                      itemBuilder: (_, i) => _ReportCard(report: reports[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatefulWidget {
  final ContentReport report;
  const _ReportCard({required this.report});

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _busy = false;

  Future<void> _resolve(String outcome) async {
    setState(() => _busy = true);
    try {
      await ModerationService().resolveReport(widget.report.id, outcome);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Removes the reported item, then closes the report in one motion — the
  /// two are always done together, and leaving them as separate taps is how a
  /// queue ends up full of resolved reports pointing at live content.
  Future<void> _removeAndResolve() async {
    setState(() => _busy = true);
    final r = widget.report;
    try {
      final community = CommunityService();
      if (r.contentKind == 'thought') {
        await community.deleteThought(r.contentId);
      } else if (r.contentKind == 'reply' && r.parentId != null) {
        // contentId is `<thoughtId>_<replyId>`; the reply id is what follows
        // the parent id and its separator.
        final replyId = r.contentId.substring(r.parentId!.length + 1);
        await community.deleteReply(r.parentId!, replyId);
      }
      await ModerationService().resolveReport(r.id, 'removed');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove that.',
                style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final tint = r.isUrgent ? AppTheme.danger : AppTheme.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space3),
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: r.isUrgent
              ? AppTheme.danger.withValues(alpha: 0.55)
              : AppTheme.border,
          width: r.isUrgent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  r.reason,
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: r.isUrgent
                          ? const Color(0xFFFCA5A5)
                          : AppTheme.accentLight),
                ),
              ),
              const SizedBox(width: AppTheme.space2),
              Text(
                r.contentKind,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    color: AppTheme.textMuted),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM, HH:mm').format(r.createdAt),
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10.5,
                    color: AppTheme.textMuted),
              ),
            ],
          ),

          if (r.excerpt.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.border),
              ),
              // The copy taken at report time, not a live read: the original
              // may already be gone, and a report you cannot read is a report
              // you cannot action.
              child: Text(
                r.excerpt,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    height: 1.5,
                    color: AppTheme.textSecondary),
              ),
            ),
          ],

          if (r.note.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space2),
            Text(
              'Reporter said: ${r.note}',
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textMuted),
            ),
          ],

          const SizedBox(height: AppTheme.space4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _resolve('kept'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: const Text('Leave it up',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12.5,
                          color: AppTheme.textSecondary)),
                ),
              ),
              const SizedBox(width: AppTheme.space2),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _removeAndResolve,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Remove',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppTheme.textMuted),
          const SizedBox(height: AppTheme.space3),
          Text(text,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13.5,
                  color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

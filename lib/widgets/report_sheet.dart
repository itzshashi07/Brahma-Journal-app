import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/moderation_service.dart';
import 'sacred.dart';

/// "Report this" — one sheet, used everywhere content appears.
///
/// Deliberately short. Somebody reporting a post has just read something that
/// upset them, and a form with six required fields is a form they abandon. One
/// tap on a reason is enough to file it; the note is optional.
///
/// The reasons themselves are ordered with self-harm second rather than buried
/// at the bottom, because on this app that is not a moderation category — it is
/// somebody telling you a stranger might be in danger.
class ReportSheet extends StatefulWidget {
  final String contentKind;
  final String contentId;
  final String excerpt;
  final String? parentId;
  final String? reportedUid;

  const ReportSheet({
    super.key,
    required this.contentKind,
    required this.contentId,
    this.excerpt = '',
    this.parentId,
    this.reportedUid,
  });

  /// Returns true when a report was filed.
  static Future<bool> show(
    BuildContext context, {
    required String contentKind,
    required String contentId,
    String excerpt = '',
    String? parentId,
    String? reportedUid,
  }) async {
    final filed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportSheet(
        contentKind: contentKind,
        contentId: contentId,
        excerpt: excerpt,
        parentId: parentId,
        reportedUid: reportedUid,
      ),
    );
    return filed == true;
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _noteCtrl = TextEditingController();
  String? _reason;
  bool _sending = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null || _sending) return;
    setState(() => _sending = true);

    final ok = await ModerationService().report(
      contentKind: widget.contentKind,
      contentId: widget.contentId,
      reason: _reason!,
      excerpt: widget.excerpt,
      parentId: widget.parentId,
      reportedUid: widget.reportedUid,
      note: _noteCtrl.text,
    );

    if (!mounted) return;
    Navigator.pop(context, ok);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Reported. A moderator will look at this.'
              : 'Could not send that report. Please try again.',
          style: const TextStyle(fontFamily: 'Outfit'),
        ),
        backgroundColor: ok ? AppTheme.primary : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(AppTheme.space3),
          padding: const EdgeInsets.fromLTRB(AppTheme.space5, AppTheme.space4,
              AppTheme.space5, AppTheme.space5),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              const Text(
                'Report this',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 3),
              const Text(
                'A moderator reads every report. Nobody is told who sent it.',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppTheme.textMuted),
              ),
              const SizedBox(height: AppTheme.space4),

              ...ModerationService.reasons.map((r) {
                final on = _reason == r;
                final urgent = r.contains('Self-harm');
                return GestureDetector(
                  onTap: () => setState(() => _reason = r),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    margin: const EdgeInsets.only(bottom: AppTheme.space2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space3, vertical: 12),
                    decoration: BoxDecoration(
                      color: on
                          ? AppTheme.primary.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: on ? AppTheme.primary : AppTheme.border,
                        width: on ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          on
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: on ? AppTheme.primaryLight : AppTheme.textMuted,
                        ),
                        const SizedBox(width: AppTheme.space3),
                        Expanded(
                          child: Text(
                            r,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13.5,
                              fontWeight:
                                  on ? FontWeight.w700 : FontWeight.w500,
                              color: urgent
                                  ? const Color(0xFFFCA5A5)
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: AppTheme.space2),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                minLines: 1,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13.5,
                    color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Anything else we should know? (optional)',
                  counterText: '',
                  hintStyle: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12.5,
                      color: AppTheme.textMuted),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.space4),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontFamily: 'Outfit', color: AppTheme.textMuted)),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space2),
                  Expanded(
                    flex: 2,
                    child: SacredButton(
                      label: 'Send report',
                      icon: Icons.flag_outlined,
                      loading: _sending,
                      onTap: _reason == null || _sending ? null : _send,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

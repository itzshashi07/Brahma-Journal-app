import 'package:flutter/material.dart';

import '../../core/constants/thoughts_365.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/sacred.dart';

/// How an admin sets the thought of the day.
///
/// The old version was a bare text box: to use one of the 365 lines already
/// written for this app, you had to remember it and type it out. So in practice
/// nobody did, and the same field that was meant to make the banner deliberate
/// made it either blank or improvised.
///
/// This offers both — browse and search the library, or write your own — with
/// today's default marked so it is obvious what is already showing.
class ThoughtPickerSheet extends StatefulWidget {
  final String current;

  const ThoughtPickerSheet({super.key, required this.current});

  static Future<bool?> show(BuildContext context, String current) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ThoughtPickerSheet(current: current),
    );
  }

  @override
  State<ThoughtPickerSheet> createState() => _ThoughtPickerSheetState();
}

class _ThoughtPickerSheetState extends State<ThoughtPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _searchCtrl = TextEditingController();
  late final TextEditingController _customCtrl =
      TextEditingController(text: widget.current);

  String? _selected;
  bool _saving = false;

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() => _saving = true);
    try {
      // Through the API rather than straight into the collection. `/metadata`
      // had to be client-writable for this one screen, and a Firestore rule
      // can say "an admin may write here" but not "an admin may write this key
      // with this shape". The endpoint is admin-gated *and* validates, and it
      // drops the server's cached copy so the change is live at once.
      // Stamped with the day it was chosen on. The dashboard only honours an
      // override while the stamp is the reader's own today, so this is a
      // choice about *today* rather than a switch left flipped until somebody
      // remembers to reset it — tomorrow the banner rolls on to the next line
      // of the library by itself.
      await ApiService().put('/api/support/metadata/thought_of_the_day', {
        'value': {
          'text': trimmed,
          'date': Thoughts365.dateKey(DateTime.now()),
        },
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e',
                style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Puts the banner back on the automatic day-of-year line straight away,
  /// rather than waiting for the override to expire at midnight.
  Future<void> _resetToAutomatic() async {
    setState(() => _saving = true);
    try {
      // Cleared rather than deleted. The endpoint upserts, so there is no
      // delete verb to reach for — and an empty string is what the dashboard
      // already treats as "no override", falling back to the day-of-year line.
      await ApiService().put('/api/support/metadata/thought_of_the_day', {
        'value': {'text': '', 'date': ''},
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not reset: $e',
                style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = Thoughts365.dayOfYear(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Container(
            margin: const EdgeInsets.all(AppTheme.space3),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppTheme.space3),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                const Text(
                  'Thought of the day',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Everyone sees this for the rest of today. Tomorrow the '
                  'banner moves on by itself unless you set another.',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11.5,
                      color: AppTheme.textMuted.withValues(alpha: 0.95)),
                ),
                const SizedBox(height: AppTheme.space3),
                TabBar(
                  controller: _tabs,
                  indicatorColor: AppTheme.primary,
                  labelColor: AppTheme.textPrimary,
                  unselectedLabelColor: AppTheme.textMuted,
                  labelStyle: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5),
                  tabs: [
                    Tab(text: 'Library (${Thoughts365.count})'),
                    const Tab(text: 'Write your own'),
                  ],
                ),
                Flexible(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _libraryTab(today),
                      _customTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _libraryTab(int today) {
    final results = Thoughts365.search(_searchCtrl.text);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.space4, AppTheme.space3,
              AppTheme.space4, AppTheme.space2),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
                fontFamily: 'Outfit', fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search — peace, anger, fear, patience…',
              hintStyle: const TextStyle(
                  fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textMuted),
              prefixIcon:
                  const Icon(Icons.search_rounded, size: 19, color: AppTheme.textMuted),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 17, color: AppTheme.textMuted),
                      onPressed: () => setState(() => _searchCtrl.clear()),
                    ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(
                  child: Text('Nothing matches that.',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: AppTheme.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space4, vertical: AppTheme.space2),
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final (day, text) = results[i];
                    final chosen = _selected == text;
                    final isToday = day == today;
                    final isLive = text == widget.current;

                    return GestureDetector(
                      onTap: () => setState(() => _selected = text),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        margin: const EdgeInsets.only(bottom: AppTheme.space2),
                        padding: const EdgeInsets.all(AppTheme.space3),
                        decoration: BoxDecoration(
                          color: chosen
                              ? AppTheme.primary.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.035),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: chosen ? AppTheme.primary : AppTheme.border,
                            width: chosen ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Day $day',
                                  style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: AppTheme.textMuted),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 6),
                                  _tag('TODAY', AppTheme.accentLight),
                                ],
                                if (isLive) ...[
                                  const SizedBox(width: 6),
                                  _tag('SHOWING NOW', AppTheme.success),
                                ],
                                const Spacer(),
                                if (chosen)
                                  const Icon(Icons.check_circle_rounded,
                                      size: 17, color: AppTheme.primaryLight),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              text,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13.5,
                                height: 1.5,
                                color: chosen
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        _footer(
          primaryLabel: 'Set as today\'s thought',
          onPrimary: _selected == null ? null : () => _save(_selected!),
        ),
      ],
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: color),
        ),
      );

  Widget _customTab() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space4),
            child: TextField(
              controller: _customCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  height: 1.55,
                  color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Write the line you want everyone to read today…',
                hintStyle: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: AppTheme.textMuted),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.all(14),
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
          ),
        ),
        _footer(
          primaryLabel: 'Publish this thought',
          onPrimary: _customCtrl.text.trim().isEmpty
              ? null
              : () => _save(_customCtrl.text),
        ),
      ],
    );
  }

  Widget _footer({required String primaryLabel, VoidCallback? onPrimary}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.space4, AppTheme.space2,
          AppTheme.space4, AppTheme.space4),
      child: Column(
        children: [
          SacredButton(
            label: primaryLabel,
            icon: Icons.check_rounded,
            loading: _saving,
            onTap: _saving ? null : onPrimary,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12.5,
                          color: AppTheme.textMuted)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _saving ? null : _resetToAutomatic,
                  child: const Text('Back to automatic',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12.5,
                          color: AppTheme.textMuted)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

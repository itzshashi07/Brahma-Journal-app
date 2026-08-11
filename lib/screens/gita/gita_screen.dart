import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/gita_verses.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';

/// Wisdom for real life, drawn from the Gita.
///
/// Organised by the situation you are actually in rather than by chapter, so
/// someone at 2am after a breakup can find something useful without knowing
/// where to look. Every verse leads with its application; the Sanskrit is there
/// for those who want it, collapsed for those who do not.
class GitaScreen extends StatefulWidget {
  const GitaScreen({super.key});

  @override
  State<GitaScreen> createState() => _GitaScreenState();
}

class _GitaScreenState extends State<GitaScreen> {
  GitaSituation? _filter;
  bool _hindi = false;

  @override
  void initState() {
    super.initState();
    _restoreLanguage();
  }

  // Remembered across visits — someone who reads in Hindi should not have to
  // switch every single time.
  Future<void> _restoreLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _hindi = prefs.getBool('gita_hindi') ?? false);
  }

  Future<void> _setLanguage(bool hindi) async {
    setState(() => _hindi = hindi);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gita_hindi', hindi);
  }

  @override
  Widget build(BuildContext context) {
    final verses = GitaLibrary.forSituation(_filter);

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: _hindi ? 'जीवन के लिए ज्ञान' : 'Wisdom for Real Life',
                subtitle: _hindi
                    ? '${verses.length} श्लोक'
                    : '${verses.length} verses',
                onBack: () => context.pop(),
                action: _LanguageToggle(
                  hindi: _hindi,
                  onChanged: _setLanguage,
                ),
              ),

              _SituationFilter(
                selected: _filter,
                hindi: _hindi,
                onChanged: (s) => setState(() => _filter = s),
              ),

              Expanded(
                child: verses.isEmpty
                    ? Center(
                        child: Text(
                          _hindi
                              ? 'इस विषय पर अभी कोई श्लोक नहीं'
                              : 'No verses for this yet',
                          style: const TextStyle(
                              fontFamily: 'Outfit', color: AppTheme.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppTheme.space4, 0,
                            AppTheme.space4, AppTheme.space8),
                        itemCount: verses.length,
                        itemBuilder: (_, i) =>
                            _VerseCard(verse: verses[i], hindi: _hindi),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── language ───────────────────────────

class _LanguageToggle extends StatelessWidget {
  final bool hindi;
  final ValueChanged<bool> onChanged;

  const _LanguageToggle({required this.hindi, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!hindi),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space2 + 2, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        ),
        child: Text(
          hindi ? 'हिं' : 'EN',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryLight,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── filter ───────────────────────────

class _SituationFilter extends StatelessWidget {
  final GitaSituation? selected;
  final bool hindi;
  final ValueChanged<GitaSituation?> onChanged;

  const _SituationFilter({
    required this.selected,
    required this.hindi,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final situations = GitaLibrary.availableSituations;

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
        children: [
          _Chip(
            label: hindi ? 'सभी' : 'All',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          ...situations.map(
            (s) => _Chip(
              label: '${s.emoji} ${hindi ? s.labelHi : s.labelEn}',
              selected: selected == s,
              onTap: () => onChanged(s),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.space2),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space4, vertical: AppTheme.space2),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color:
                    selected ? AppTheme.primaryLight : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── verse ───────────────────────────

class _VerseCard extends StatefulWidget {
  final GitaVerse verse;
  final bool hindi;

  const _VerseCard({required this.verse, required this.hindi});

  @override
  State<_VerseCard> createState() => _VerseCardState();
}

class _VerseCardState extends State<_VerseCard> {
  bool _showSanskrit = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.verse;
    final hindi = widget.hindi;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space2 + 2, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    '${v.chapter}.${v.verse}',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space2),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    children: v.situations
                        .take(2)
                        .map((s) => Text(
                              '${s.emoji} ${hindi ? s.labelHi : s.labelEn}',
                              style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 10.5,
                                  color: AppTheme.textMuted),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.space3),

            // The application leads. A verse nobody understands consoles
            // nobody, so the modern reading is the headline and the scripture
            // is the supporting evidence.
            Text(
              hindi ? v.applicationHi : v.applicationEn,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                height: 1.62,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: AppTheme.space4),

            Container(
              padding: const EdgeInsets.all(AppTheme.space3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hindi ? v.translationHi : v.translationEn,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      height: 1.55,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (_showSanskrit) ...[
                    const SizedBox(height: AppTheme.space3),
                    const Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: AppTheme.space3),
                    Text(
                      v.sanskrit,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14.5,
                        height: 1.75,
                        color: AppTheme.accentLight,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space2),
                    Text(
                      v.transliteration,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11.5,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.space2),
                  GestureDetector(
                    onTap: () => setState(() => _showSanskrit = !_showSanskrit),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showSanskrit
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 16,
                          color: AppTheme.primaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showSanskrit
                              ? (hindi ? 'संस्कृत छिपाएँ' : 'Hide Sanskrit')
                              : (hindi ? 'संस्कृत देखें' : 'Show Sanskrit'),
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

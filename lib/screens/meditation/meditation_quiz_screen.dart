import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/meditation_quiz.dart';
import '../../core/constants/meditation_techniques.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';

/// Five taps that pick a practice for today.
///
/// Nothing is stored anywhere. That is said on the screen, because the honest
/// answers to "what is going on right now" are the ones people will not give to
/// something that looks like it is keeping a file.
class MeditationQuizScreen extends StatefulWidget {
  const MeditationQuizScreen({super.key});

  @override
  State<MeditationQuizScreen> createState() => _MeditationQuizScreenState();
}

class _MeditationQuizScreenState extends State<MeditationQuizScreen> {
  final List<QuizOption> _answers = [];
  int _index = 0;

  bool get _done => _index >= MeditationQuiz.questions.length;

  void _pick(QuizOption o) {
    setState(() {
      _answers.add(o);
      _index++;
    });
  }

  void _restart() {
    setState(() {
      _answers.clear();
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: 'Find your practice',
                subtitle: _done
                    ? 'Three that fit today'
                    : 'Question ${_index + 1} of ${MeditationQuiz.questions.length}',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: _done ? _buildResults() : _buildQuestion(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final q = MeditationQuiz.questions[_index];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.space5, AppTheme.space3, AppTheme.space5, AppTheme.space8),
      children: [
        LinearProgressIndicator(
          value: _index / MeditationQuiz.questions.length,
          minHeight: 4,
          backgroundColor: AppTheme.bgCard,
          valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
        ),
        const SizedBox(height: AppTheme.space6),
        Text(
          q.question,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 22,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        if (q.hint != null) ...[
          const SizedBox(height: AppTheme.space2),
          Text(
            q.hint!,
            style: const TextStyle(
                fontFamily: 'Outfit', fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ],
        const SizedBox(height: AppTheme.space5),
        ...q.options.map(
          (o) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space3),
            child: GestureDetector(
              onTap: () => _pick(o),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space4, vertical: AppTheme.space4),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.label,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textMuted, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        const Text(
          'Nothing here is saved or sent anywhere.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Outfit', fontSize: 11.5, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final picks = MeditationQuiz.recommend(_answers);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.space4, AppTheme.space3, AppTheme.space4, AppTheme.space8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space2),
          child: Text(
            'Start with the first one. The others are there for the days it does not fit.',
            style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                height: 1.55,
                color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        for (var i = 0; i < picks.length; i++)
          _ResultCard(
            technique: picks[i],
            primary: i == 0,
            onTap: () => context.push('/meditation/technique/${picks[i].id}'),
          ),
        const SizedBox(height: AppTheme.space4),
        Center(
          child: TextButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Take it again',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 13)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final MeditationTechnique technique;
  final bool primary;
  final VoidCallback onTap;

  const _ResultCard({
    required this.technique,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.space4),
          decoration: BoxDecoration(
            gradient: primary
                ? LinearGradient(
                    colors: technique.gradient
                        .map((c) => c.withValues(alpha: 0.35))
                        .toList(),
                  )
                : null,
            color: primary ? null : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: primary ? technique.gradient.first : AppTheme.border,
              width: primary ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: technique.gradient),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(technique.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (primary)
                      const Text('BEST FIT TODAY',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 9.5,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70)),
                    Text(technique.name,
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(technique.tagline,
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12.5,
                            height: 1.4,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Text(
                      '${technique.minutes} min  ·  ${MeditationQuiz.reasonFor(technique)}',
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

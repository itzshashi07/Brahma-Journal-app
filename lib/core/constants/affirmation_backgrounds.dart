import 'package:flutter/material.dart';

/// Backgrounds for affirmation cards.
///
/// Gradients and motifs rather than photographs: they are a few bytes instead
/// of a few megabytes, they scale to any screen, they recolour with the theme,
/// and there is no licensing question about any of them. A stock photo of a
/// sunset would cost 2 MB and say less.
class AffirmationBackground {
  final String id;
  final String name;
  final List<Color> gradient;
  final Alignment begin;
  final Alignment end;

  const AffirmationBackground({
    required this.id,
    required this.name,
    required this.gradient,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });
}

class AffirmationBackgrounds {
  static const all = <AffirmationBackground>[
    AffirmationBackground(
      id: 'dawn',
      name: 'Dawn',
      gradient: [Color(0xFFF97316), Color(0xFFBE185D)],
    ),
    AffirmationBackground(
      id: 'violet',
      name: 'Violet Hour',
      gradient: [Color(0xFF7C3AED), Color(0xFF3730A3)],
    ),
    AffirmationBackground(
      id: 'ocean',
      name: 'Deep Ocean',
      gradient: [Color(0xFF0891B2), Color(0xFF0F172A)],
    ),
    AffirmationBackground(
      id: 'forest',
      name: 'Forest',
      gradient: [Color(0xFF059669), Color(0xFF064E3B)],
    ),
    AffirmationBackground(
      id: 'gold',
      name: 'Golden Light',
      gradient: [Color(0xFFFBBF24), Color(0xFFB45309)],
    ),
    AffirmationBackground(
      id: 'rose',
      name: 'Rose Quartz',
      gradient: [Color(0xFFF472B6), Color(0xFF7E22CE)],
    ),
    AffirmationBackground(
      id: 'midnight',
      name: 'Midnight',
      gradient: [Color(0xFF1E1B4B), Color(0xFF020617)],
    ),
    AffirmationBackground(
      id: 'sky',
      name: 'Clear Sky',
      gradient: [Color(0xFF38BDF8), Color(0xFF1D4ED8)],
    ),
  ];

  static AffirmationBackground byId(String? id) {
    for (final b in all) {
      if (b.id == id) return b;
    }
    return all.first;
  }

  /// A stable background for an affirmation that has not been given one, so the
  /// same line always looks the same rather than reshuffling on every rebuild.
  static AffirmationBackground forText(String text) =>
      all[text.hashCode.abs() % all.length];
}

/// Why affirmations are worth doing.
///
/// The section previously offered the practice with no explanation, which makes
/// it easy to dismiss as wishful thinking. These are the mechanisms, stated
/// plainly and without overclaiming — repetition shapes attention; it does not
/// rearrange reality.
class AffirmationBenefits {
  static const intro =
      'An affirmation is not a wish. It is a sentence you repeat until it '
      'becomes the one your mind reaches for first — instead of the one it '
      'learned from your worst day.';

  static const points = <(String, String, IconData)>[
    (
      'It changes what you notice',
      'Attention follows what it has been primed with. Repeat "I am capable" '
          'often enough and you start noticing evidence you were previously '
          'filtering out. The world does not change; what you register does.',
      Icons.visibility_outlined,
    ),
    (
      'It interrupts the automatic voice',
      'Most self-criticism is a habit, not a judgement — the same few phrases '
          'on a loop. A deliberate sentence gives the mind something else to '
          'reach for in the gap before the old one arrives.',
      Icons.record_voice_over_outlined,
    ),
    (
      'It works through repetition, not belief',
      'You do not have to believe it on day one. Saying it while doubting it '
          'still works, the way learning a language works before you are fluent. '
          'Conviction is the result, not the entry requirement.',
      Icons.repeat_rounded,
    ),
    (
      'It steadies you under pressure',
      'A phrase practised in calm becomes available in panic. This is why '
          'athletes and soldiers rehearse them. The sentence you have said a '
          'thousand times is the one that arrives when you cannot think.',
      Icons.shield_outlined,
    ),
    (
      'It is a return, not a climb',
      '"I am calm underneath this" is not motivation — it is a reminder of '
          'something that was already true before the day started. That is the '
          'whole of it: not becoming something, returning to something.',
      Icons.self_improvement_rounded,
    ),
  ];

  static const howTo = <String>[
    'Say it in the present tense — "I am", not "I will be".',
    'Keep it short enough to remember without reading.',
    'Repeat it at the same time daily; the habit does the work.',
    'Say it slowly. Speed defeats the point.',
    'Choose one and stay with it for a week before switching.',
  ];

  /// Honest about the limits. An app that promises affirmations fix everything
  /// loses the reader the first time life disagrees.
  static const caveat =
      'Affirmations shape attention and self-talk. They are not a substitute '
      'for medical care, therapy, or action in the world — and anyone telling '
      'you otherwise is selling something.';
}

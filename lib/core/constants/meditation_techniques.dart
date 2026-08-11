import 'package:flutter/material.dart';

/// A breathing pattern, in seconds per phase. Zero means the phase is skipped.
///
/// The player animates a circle against these numbers, so a technique that
/// carries a pattern needs no words on screen while it runs — which is the
/// point, since reading is the opposite of what a person is here to do.
class BreathPattern {
  final int inhale;
  final int holdIn;
  final int exhale;
  final int holdOut;

  const BreathPattern({
    required this.inhale,
    this.holdIn = 0,
    required this.exhale,
    this.holdOut = 0,
  });

  int get cycleSeconds => inhale + holdIn + exhale + holdOut;

  String get label {
    final parts = <String>[
      '$inhale in',
      if (holdIn > 0) 'hold $holdIn',
      '$exhale out',
      if (holdOut > 0) 'hold $holdOut',
    ];
    return parts.join(' · ');
  }
}

/// One instruction in a guided session.
class MeditationStep {
  final int seconds;
  final String instruction;

  /// Optional second line — the "why", kept short and only where it helps.
  final String? note;

  const MeditationStep(this.seconds, this.instruction, {this.note});
}

/// What a technique is for. Used by the quiz to match a person to a practice.
enum MindTag {
  anxiety,
  overthinking,
  anger,
  sadness,
  sleep,
  focus,
  selfWorth,
  grief,
  restlessness,
  spiritual,
  beginner,
  noTime,
}

class MeditationTechnique {
  final String id;
  final String name;

  /// The one-line promise, in plain words.
  final String tagline;

  final IconData icon;
  final List<Color> gradient;

  /// Default session length in minutes. The player lets it be changed.
  final int minutes;

  /// True for practices developed in the last century — breath protocols,
  /// noting, grounding. The rest are traditional. Shown as a small badge so a
  /// sceptic can find the clinical ones and a seeker can find the old ones.
  final bool modern;

  final List<MindTag> bestFor;
  final BreathPattern? breath;
  final List<MeditationStep> steps;

  /// Honest, specific, no overclaiming — what this actually does.
  final String howItHelps;

  const MeditationTechnique({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.gradient,
    required this.minutes,
    required this.modern,
    required this.bestFor,
    required this.steps,
    required this.howItHelps,
    this.breath,
  });

  int get scriptedSeconds =>
      steps.fold(0, (sum, s) => sum + s.seconds);
}

class MeditationTechniques {
  static const all = <MeditationTechnique>[
    // ─────────────────────────── breath ───────────────────────────
    MeditationTechnique(
      id: 'box',
      name: 'Box Breathing',
      tagline: 'Four counts each way. Steadies you fast.',
      icon: Icons.crop_square_rounded,
      gradient: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
      minutes: 5,
      modern: true,
      bestFor: [MindTag.anxiety, MindTag.focus, MindTag.noTime, MindTag.beginner],
      breath: BreathPattern(inhale: 4, holdIn: 4, exhale: 4, holdOut: 4),
      howItHelps:
          'An equal-length breath with two pauses slows the heart and gives the '
          'mind one simple thing to track. Used by people who have to stay calm '
          'under pressure — pilots, soldiers, surgeons — because it works in '
          'minutes and needs no privacy.',
      steps: [
        MeditationStep(20, 'Sit upright. Let the shoulders drop.'),
        MeditationStep(20, 'Breathe out fully once, through the mouth.'),
        MeditationStep(200, 'Follow the circle: in 4, hold 4, out 4, hold 4.'),
        MeditationStep(40, 'Let the breath go back to normal. Notice the change.'),
      ],
    ),
    MeditationTechnique(
      id: 'four-seven-eight',
      name: '4-7-8 Breath',
      tagline: 'The long exhale that makes sleep easier.',
      icon: Icons.nightlight_round,
      gradient: [Color(0xFF6366F1), Color(0xFF1E1B4B)],
      minutes: 5,
      modern: true,
      bestFor: [MindTag.sleep, MindTag.anxiety, MindTag.noTime],
      breath: BreathPattern(inhale: 4, holdIn: 7, exhale: 8),
      howItHelps:
          'A long exhale is one of the few direct levers on the nervous system. '
          'Making the out-breath twice the in-breath tips you toward rest. Best '
          'done lying down, and not while driving — it can make you drowsy, '
          'which is the point at night.',
      steps: [
        MeditationStep(20, 'Lie down or sit back. Tongue behind the front teeth.'),
        MeditationStep(20, 'Empty the lungs completely.'),
        MeditationStep(190, 'In through the nose for 4, hold 7, out through the mouth for 8.'),
        MeditationStep(70, 'Stop counting. Let the body stay heavy.'),
      ],
    ),
    MeditationTechnique(
      id: 'coherent',
      name: 'Coherent Breathing',
      tagline: 'Five in, five out. Nothing else.',
      icon: Icons.waves_rounded,
      gradient: [Color(0xFF06B6D4), Color(0xFF0E7490)],
      minutes: 8,
      modern: true,
      bestFor: [MindTag.anxiety, MindTag.restlessness, MindTag.beginner],
      breath: BreathPattern(inhale: 5, exhale: 5),
      howItHelps:
          'Around six breaths a minute is the rate at which heart rhythm and '
          'breathing fall into step. There is nothing to remember and nothing to '
          'hold — which makes it the easiest one to keep doing on a bad day.',
      steps: [
        MeditationStep(20, 'Sit comfortably. Hands anywhere.'),
        MeditationStep(400, 'Breathe in for five, out for five. Follow the circle.'),
        MeditationStep(60, 'Sit for a moment with the breath left alone.'),
      ],
    ),
    MeditationTechnique(
      id: 'bhramari',
      name: 'Bhramari (Humming)',
      tagline: 'Hum on the out-breath. Quiets the head.',
      icon: Icons.graphic_eq_rounded,
      gradient: [Color(0xFFF59E0B), Color(0xFF92400E)],
      minutes: 5,
      modern: false,
      bestFor: [MindTag.anger, MindTag.anxiety, MindTag.overthinking],
      breath: BreathPattern(inhale: 4, exhale: 8),
      howItHelps:
          'The vibration of a hum is felt in the skull and gives attention '
          'something physical to rest on. Old practice, and the reason it '
          'survived is that it works on a mind too agitated to sit still.',
      steps: [
        MeditationStep(20, 'Sit up. Close the eyes. Cover the ears lightly if you can.'),
        MeditationStep(30, 'Breathe in through the nose, slowly.'),
        MeditationStep(210, 'Hum on every out-breath. Long, low, unhurried.'),
        MeditationStep(40, 'Stop humming. Sit in the silence it leaves.'),
      ],
    ),
    MeditationTechnique(
      id: 'anulom-vilom',
      name: 'Anulom Vilom',
      tagline: 'Alternate nostril breathing. Evens you out.',
      icon: Icons.swap_horiz_rounded,
      gradient: [Color(0xFF10B981), Color(0xFF065F46)],
      minutes: 7,
      modern: false,
      bestFor: [MindTag.restlessness, MindTag.focus, MindTag.anxiety],
      howItHelps:
          'Closing one nostril at a time forces a slow, deliberate breath and '
          'gives the hands a job, which is why restless people can do it when '
          'they cannot sit still for anything else.',
      steps: [
        MeditationStep(25, 'Right thumb on the right nostril, ring finger ready on the left.'),
        MeditationStep(25, 'Close the right. Breathe in through the left.'),
        MeditationStep(25, 'Close the left. Breathe out through the right.'),
        MeditationStep(280, 'Continue: in one side, out the other, then swap. Slow and even.'),
        MeditationStep(45, 'Hands down. Breathe normally and notice the difference.'),
      ],
    ),

    // ─────────────────────────── body ───────────────────────────
    MeditationTechnique(
      id: 'body-scan',
      name: 'Body Scan',
      tagline: 'Head to feet, without fixing anything.',
      icon: Icons.accessibility_new_rounded,
      gradient: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
      minutes: 10,
      modern: true,
      bestFor: [MindTag.sleep, MindTag.anxiety, MindTag.overthinking],
      howItHelps:
          'Attention moved slowly through the body pulls it out of the loop of '
          'thinking and into sensation. Most people fall asleep in this one, '
          'which is a fine outcome at night and a sign of debt in the afternoon.',
      steps: [
        MeditationStep(30, 'Lie down or sit back. Eyes closed.'),
        MeditationStep(60, 'Notice the top of the head, the forehead, the jaw. Let the jaw loosen.'),
        MeditationStep(70, 'Shoulders. Feel their weight. Let them drop a little more.'),
        MeditationStep(70, 'Arms, hands, fingers. No need to move them.'),
        MeditationStep(80, 'Chest and stomach, rising and falling on their own.'),
        MeditationStep(80, 'Hips, legs, knees, feet. All the way to the toes.'),
        MeditationStep(80, 'The whole body at once, breathing.'),
        MeditationStep(60, 'Stay here. Nothing to do.'),
      ],
    ),
    MeditationTechnique(
      id: 'yoga-nidra',
      name: 'Yoga Nidra (Short)',
      tagline: 'Deep rest without sleeping.',
      icon: Icons.hotel_rounded,
      gradient: [Color(0xFF4338CA), Color(0xFF1E1B4B)],
      minutes: 12,
      modern: false,
      bestFor: [MindTag.sleep, MindTag.grief, MindTag.restlessness],
      howItHelps:
          'A structured rotation of attention through the body while lying '
          'completely still. Twenty minutes of it leaves most people more rested '
          'than an hour of scrolling on the bed.',
      steps: [
        MeditationStep(40, 'Lie flat. Palms up. Let the body be heavy and completely still.'),
        MeditationStep(60, 'Say to yourself once: I am about to rest, not sleep.'),
        MeditationStep(120, 'Right hand, right arm, right shoulder. Then the left.'),
        MeditationStep(120, 'Right leg, right foot. Then the left.'),
        MeditationStep(120, 'The back, the front, the whole body.'),
        MeditationStep(120, 'Feel the whole body breathing without your help.'),
        MeditationStep(80, 'Stay still. Let the mind drift without following it.'),
        MeditationStep(60, 'Slowly move the fingers. Come back gently.'),
      ],
    ),
    MeditationTechnique(
      id: 'walking',
      name: 'Walking Meditation',
      tagline: 'For the days you cannot sit still.',
      icon: Icons.directions_walk_rounded,
      gradient: [Color(0xFF22C55E), Color(0xFF14532D)],
      minutes: 10,
      modern: true,
      bestFor: [MindTag.restlessness, MindTag.anger, MindTag.overthinking],
      howItHelps:
          'Sitting is not the practice — attention is. For an agitated body, '
          'walking slowly with attention on the feet works better than forcing '
          'stillness, and it is far easier to actually start.',
      steps: [
        MeditationStep(30, 'Stand. Feel both feet on the ground.'),
        MeditationStep(60, 'Walk slower than usual. Half your normal speed.'),
        MeditationStep(180, 'Attention on the soles: lifting, moving, placing.'),
        MeditationStep(180, 'When the mind wanders, return to the feet. That is the whole practice.'),
        MeditationStep(150, 'Keep walking. No destination.'),
      ],
    ),

    // ─────────────────────── awareness / mind ───────────────────────
    MeditationTechnique(
      id: 'noting',
      name: 'Noting',
      tagline: 'Name what the mind is doing, then let it go.',
      icon: Icons.label_outline_rounded,
      gradient: [Color(0xFF0EA5E9), Color(0xFF075985)],
      minutes: 8,
      modern: true,
      bestFor: [MindTag.overthinking, MindTag.anxiety, MindTag.focus],
      howItHelps:
          'Instead of fighting thoughts, you label them — thinking, planning, '
          'remembering, hearing — and return. Labelling converts you from the '
          'person inside the thought to the one watching it, which is where the '
          'space comes from.',
      steps: [
        MeditationStep(30, 'Sit. Eyes closed or resting on one point.'),
        MeditationStep(60, 'Follow the breath until the mind wanders. It will.'),
        MeditationStep(150, 'When it does, say silently what it is: thinking. planning. hearing.'),
        MeditationStep(150, 'Then come back to the breath. No commentary, no judgement.'),
        MeditationStep(90, 'Continue. Forty wanderings is a good session, not a failed one.'),
      ],
    ),
    MeditationTechnique(
      id: 'rain',
      name: 'RAIN',
      tagline: 'For a feeling you cannot put down.',
      icon: Icons.water_drop_outlined,
      gradient: [Color(0xFF0891B2), Color(0xFF164E63)],
      minutes: 8,
      modern: true,
      bestFor: [MindTag.sadness, MindTag.anger, MindTag.grief, MindTag.selfWorth],
      howItHelps:
          'Four steps — Recognise, Allow, Investigate, Nurture — for sitting with '
          'a difficult emotion instead of arguing with it or drowning in it. '
          'Useful precisely on the days meditation feels impossible.',
      steps: [
        MeditationStep(45, 'Recognise. Name what is here: anger, fear, shame, grief.'),
        MeditationStep(90, 'Allow. Let it be there. You are not agreeing with it, only stopping the fight.'),
        MeditationStep(120, 'Investigate. Where is it in the body? What does it want you to believe?'),
        MeditationStep(120, 'Nurture. Say to yourself what you would say to a friend feeling this.'),
        MeditationStep(105, 'Sit. Let it be as big or small as it is.'),
      ],
    ),
    MeditationTechnique(
      id: 'grounding',
      name: '5-4-3-2-1 Grounding',
      tagline: 'When panic is rising. Eyes open.',
      icon: Icons.anchor_rounded,
      gradient: [Color(0xFFEF4444), Color(0xFF7F1D1D)],
      minutes: 4,
      modern: true,
      bestFor: [MindTag.anxiety, MindTag.noTime, MindTag.beginner],
      howItHelps:
          'Panic pulls attention into the future. Naming what is actually in the '
          'room drags it back to the present, which is the one place nothing '
          'terrible is currently happening. Works in public, with eyes open.',
      steps: [
        MeditationStep(45, 'Look around. Find five things you can see. Name them silently.'),
        MeditationStep(45, 'Four things you can feel. The chair, your feet, the air, your clothes.'),
        MeditationStep(45, 'Three things you can hear. Near and far.'),
        MeditationStep(45, 'Two things you can smell — or two smells you remember.'),
        MeditationStep(40, 'One slow breath. You are here. This moment is survivable.'),
      ],
    ),
    MeditationTechnique(
      id: 'open-awareness',
      name: 'Open Awareness',
      tagline: 'Sky mind. Let everything pass.',
      icon: Icons.cloud_outlined,
      gradient: [Color(0xFF64748B), Color(0xFF1E293B)],
      minutes: 10,
      modern: false,
      bestFor: [MindTag.overthinking, MindTag.spiritual, MindTag.restlessness],
      howItHelps:
          'No object, no counting. You rest as the space in which thoughts and '
          'sounds appear. Harder than it sounds — better once you have a few '
          'weeks of any other practice behind you.',
      steps: [
        MeditationStep(40, 'Sit. Eyes softly open or closed.'),
        MeditationStep(90, 'Let sounds come and go. Do not chase them or push them.'),
        MeditationStep(140, 'Same with thoughts. Clouds crossing a sky that is not disturbed by them.'),
        MeditationStep(180, 'Stop directing attention anywhere at all. Just be aware.'),
        MeditationStep(150, 'Rest as the sky, not the weather.'),
      ],
    ),

    // ───────────────────────── heart / soul ─────────────────────────
    MeditationTechnique(
      id: 'soul-consciousness',
      name: 'The Observer',
      tagline: 'You are the one watching, not the weather.',
      icon: Icons.auto_awesome_rounded,
      gradient: [Color(0xFF7C3AED), Color(0xFF4338CA)],
      minutes: 10,
      modern: false,
      bestFor: [MindTag.spiritual, MindTag.selfWorth, MindTag.anger],
      howItHelps:
          'Eyes open, attention resting on a point just behind the forehead, '
          'holding one true sentence. It separates what you are from what you '
          'are currently carrying — which is where the steadiness comes from.',
      steps: [
        MeditationStep(40, 'Sit upright. Eyes open, resting softly on one point.'),
        MeditationStep(90, 'I am not this body. I am the one aware of it.'),
        MeditationStep(120, 'A quiet point behind the forehead. Steady, small, calm.'),
        MeditationStep(150, 'I am calm underneath this. Say it slowly. Let it land, do not rush it.'),
        MeditationStep(150, 'Whatever came today happened to the role, not to you.'),
        MeditationStep(50, 'Carry that sentence out of the room with you.'),
      ],
    ),
    MeditationTechnique(
      id: 'metta',
      name: 'Loving-Kindness',
      tagline: 'Good wishes, starting with yourself.',
      icon: Icons.favorite_outline_rounded,
      gradient: [Color(0xFFEC4899), Color(0xFF831843)],
      minutes: 10,
      modern: false,
      bestFor: [MindTag.anger, MindTag.selfWorth, MindTag.sadness],
      howItHelps:
          'Repeating simple good wishes toward yourself, then people you love, '
          'then a stranger, then someone difficult. It sounds sentimental and it '
          'measurably softens how you react to people the next day.',
      steps: [
        MeditationStep(60, 'Yourself: may I be at peace. May I be well. May I be free from struggle.'),
        MeditationStep(90, 'Someone easy to love. Picture them. Same words.'),
        MeditationStep(90, 'Someone neutral — a shopkeeper, a neighbour you barely know.'),
        MeditationStep(120, 'Someone difficult. Not approval. Just: may you be at peace.'),
        MeditationStep(140, 'Everyone, everywhere, including you.'),
      ],
    ),
    MeditationTechnique(
      id: 'forgiveness',
      name: 'Letting Go',
      tagline: 'Put down what you have been carrying.',
      icon: Icons.volunteer_activism_outlined,
      gradient: [Color(0xFF34D399), Color(0xFF065F46)],
      minutes: 10,
      modern: false,
      bestFor: [MindTag.grief, MindTag.anger, MindTag.sadness],
      howItHelps:
          'Not reconciliation, and not saying it was fine — a practice for '
          'setting down the weight of an old injury. You can do this and still '
          'never speak to the person again.',
      steps: [
        MeditationStep(50, 'Bring the situation to mind. Only as much as you can hold.'),
        MeditationStep(90, 'Feel where it sits in the body. Chest, throat, stomach.'),
        MeditationStep(120, 'Say silently: this happened, and it cost me something real.'),
        MeditationStep(120, 'Say: I am not carrying this for them any more.'),
        MeditationStep(120, 'Breathe out longer than you breathe in. Let the shoulders drop.'),
        MeditationStep(100, 'If it comes back tomorrow, that is normal. Put it down again.'),
      ],
    ),
    MeditationTechnique(
      id: 'gratitude-scan',
      name: 'Gratitude Scan',
      tagline: 'Three specific things. Not a list.',
      icon: Icons.wb_sunny_outlined,
      gradient: [Color(0xFFFACC15), Color(0xFFA16207)],
      minutes: 5,
      modern: true,
      bestFor: [MindTag.sadness, MindTag.selfWorth, MindTag.noTime],
      howItHelps:
          'Attention defaults to what is wrong. This is a correction, and it '
          'only works when the things are specific — "my family" registers as '
          'nothing, "my brother messaged at the right time today" registers.',
      steps: [
        MeditationStep(40, 'Sit. One slow breath.'),
        MeditationStep(70, 'One thing that went well today. Small is fine.'),
        MeditationStep(70, 'Picture it properly. Where you were, who was there.'),
        MeditationStep(70, 'A second thing. Someone who made today easier.'),
        MeditationStep(70, 'A third — something about your own body that worked today.'),
        MeditationStep(50, 'Sit with all three at once before you get up.'),
      ],
    ),

    // ─────────────────────── focus / traditional ───────────────────────
    MeditationTechnique(
      id: 'trataka',
      name: 'Trataka (Steady Gaze)',
      tagline: 'One point. Eyes open. Trains attention.',
      icon: Icons.center_focus_strong_outlined,
      gradient: [Color(0xFFF97316), Color(0xFF7C2D12)],
      minutes: 6,
      modern: false,
      bestFor: [MindTag.focus, MindTag.overthinking, MindTag.spiritual],
      howItHelps:
          'Holding the eyes on one point — a flame, a dot, the point on this '
          'screen — steadies attention faster than most closed-eye practices, '
          'because a wandering gaze is easier to notice than a wandering mind.',
      steps: [
        MeditationStep(30, 'Sit an arm\'s length from a candle, or use the dot on screen.'),
        MeditationStep(120, 'Look at it without straining. Blink when you need to.'),
        MeditationStep(120, 'When attention slips, bring it back to the point.'),
        MeditationStep(90, 'Close the eyes. Watch the after-image until it fades.'),
      ],
    ),
    MeditationTechnique(
      id: 'mantra',
      name: 'One Phrase, Repeated',
      tagline: 'One phrase, repeated, until the noise drops.',
      icon: Icons.self_improvement_rounded,
      gradient: [Color(0xFFA78BFA), Color(0xFF5B21B6)],
      minutes: 8,
      modern: false,
      bestFor: [MindTag.spiritual, MindTag.overthinking, MindTag.beginner],
      howItHelps:
          'Repetition gives a busy mind a single track to run on. The meaning '
          'matters less than the repetition — which is why every tradition on '
          'earth arrived at some version of it.',
      steps: [
        MeditationStep(30, 'Sit upright. Hands resting.'),
        MeditationStep(90, 'Silently: let go. Once on the in-breath, once on the out.'),
        MeditationStep(180, 'Keep going. When you lose it, start again without comment.'),
        MeditationStep(120, 'Let the phrase get quieter until it is almost not there.'),
        MeditationStep(60, 'Sit in what is left.'),
      ],
    ),
    MeditationTechnique(
      id: 'two-minute-reset',
      name: 'Two-Minute Reset',
      tagline: 'At your desk. Nobody will notice.',
      icon: Icons.timer_10_select_rounded,
      gradient: [Color(0xFF14B8A6), Color(0xFF115E59)],
      minutes: 2,
      modern: true,
      bestFor: [MindTag.noTime, MindTag.focus, MindTag.anxiety, MindTag.beginner],
      howItHelps:
          'The practice most people will actually do. Two minutes between tasks '
          'stops the last meeting from leaking into the next one, and it is short '
          'enough that there is no excuse available.',
      steps: [
        MeditationStep(20, 'Both feet flat. Hands off the keyboard.'),
        MeditationStep(40, 'Three slow breaths, out longer than in.'),
        MeditationStep(30, 'Name what you just finished. Let it be finished.'),
        MeditationStep(30, 'Name the one thing that comes next.'),
      ],
    ),
    MeditationTechnique(
      id: 'sleep-wind-down',
      name: 'Sleep Wind-Down',
      tagline: 'For a mind that starts working at bedtime.',
      icon: Icons.bedtime_outlined,
      gradient: [Color(0xFF1E1B4B), Color(0xFF020617)],
      minutes: 10,
      modern: true,
      bestFor: [MindTag.sleep, MindTag.overthinking, MindTag.anxiety],
      howItHelps:
          'The mind raises unfinished business at night because it is the first '
          'quiet moment it has had. Writing it down and then breathing long tells '
          'it the matter is held, which is what it was waiting for.',
      steps: [
        MeditationStep(60, 'Anything unfinished? Say it once, silently. It will still be there tomorrow.'),
        MeditationStep(60, 'Now put it down. It has a slot tomorrow; it does not need one tonight.'),
        MeditationStep(150, 'Breathe in for four, out for eight. Let the body sink.'),
        MeditationStep(150, 'Feel the weight of the head, the shoulders, the legs.'),
        MeditationStep(180, 'Stop counting. Let the breath be uneven if it wants.'),
      ],
    ),
  ];

  static MeditationTechnique byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);

  static List<MeditationTechnique> forTag(MindTag tag) =>
      all.where((t) => t.bestFor.contains(tag)).toList();
}

/// Display names for the tags, used by the quiz results and the filter row.
const mindTagLabels = <MindTag, String>{
  MindTag.anxiety: 'Anxiety',
  MindTag.overthinking: 'Overthinking',
  MindTag.anger: 'Anger',
  MindTag.sadness: 'Low mood',
  MindTag.sleep: 'Sleep',
  MindTag.focus: 'Focus',
  MindTag.selfWorth: 'Self-worth',
  MindTag.grief: 'Grief',
  MindTag.restlessness: 'Restlessness',
  MindTag.spiritual: 'Spiritual',
  MindTag.beginner: 'New to this',
  MindTag.noTime: 'Very short',
};

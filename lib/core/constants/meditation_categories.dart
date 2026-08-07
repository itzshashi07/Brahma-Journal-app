import 'package:flutter/material.dart';

/// Guided meditation themes.
///
/// Each carries several short visualisations rather than one long script. They
/// are written to be *read slowly and then closed* — a line you can hold behind
/// your eyes for five minutes, not an essay you have to keep looking at.
class MeditationThought {
  final String title;
  final String guidance;
  const MeditationThought(this.title, this.guidance);
}

class MeditationCategory {
  final String id;
  final String name;
  final String tagline;
  final IconData icon;
  final List<Color> gradient;
  final int suggestedMinutes;
  final List<MeditationThought> thoughts;

  const MeditationCategory({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.gradient,
    required this.suggestedMinutes,
    required this.thoughts,
  });
}

class MeditationCategories {
  static const all = <MeditationCategory>[
    MeditationCategory(
      id: 'anxiety',
      name: 'Anxiety',
      tagline: 'When the mind runs ahead of you',
      icon: Icons.air_rounded,
      gradient: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
      suggestedMinutes: 10,
      thoughts: [
        MeditationThought(
          'The watcher on the bank',
          'Sit at the edge of a river. Every anxious thought is a leaf carried past you on the current. You are not required to catch any of them. Watch one arrive, watch it round the bend, and let the next one come. You are the bank, not the water.',
        ),
        MeditationThought(
          'Only this breath',
          'Anxiety lives entirely in a future that has not happened. Bring your attention to the breath moving right now — the coolness entering, the warmth leaving. Nothing in this exact moment is threatening you. Stay here for one more breath. Then one more.',
        ),
        MeditationThought(
          'Name it and it softens',
          'Say quietly to yourself: this is anxiety. Not "I am anxious" — "this is anxiety." Notice the difference. One is who you are, the other is weather passing through. Feel where it sits in the body, breathe into that place, and let it be there without arguing with it.',
        ),
        MeditationThought(
          'The lamp in the shelter',
          'Picture a small flame in a windless room. Outside, the storm continues exactly as it was. The flame does not fight the wind — it is simply somewhere the wind cannot reach. Your awareness is that room. Rest inside it.',
        ),
        MeditationThought(
          'It has passed before',
          'Recall a time you felt exactly this, and could not imagine it ending. It ended. You are here. This one has a shape and an end too, even though it does not feel like it now. You do not have to fix this feeling. You have to outlast it.',
        ),
      ],
    ),

    MeditationCategory(
      id: 'stress',
      name: 'Stress Relief',
      tagline: 'Set the weight down for a moment',
      icon: Icons.spa_outlined,
      gradient: [Color(0xFF34D399), Color(0xFF047857)],
      suggestedMinutes: 10,
      thoughts: [
        MeditationThought(
          'Putting down the bag',
          'Imagine everything you are carrying as a heavy bag on your shoulder. You are not throwing it away — you are setting it on the ground for ten minutes. It will still be there. Feel the shoulder rise as the weight leaves it.',
        ),
        MeditationThought(
          'Melting from the crown down',
          'Bring attention to the top of your head and let it soften. Move slowly down — forehead, jaw, throat, shoulders. Most people are holding the jaw and shoulders without knowing. Unclench them now. Continue down to the feet.',
        ),
        MeditationThought(
          'The lotus leaf',
          'A lotus sits in water without absorbing it. You can be fully inside a demanding day without letting it soak through. Picture the water beading and rolling off. Presence and absorption are not the same thing.',
        ),
        MeditationThought(
          'One thing at a time',
          'Stress is often many things arriving at once. In this quiet, place them in a line. Look at only the first. The others will wait — they have to. This is how they will actually get done, and it is how the mind stops shouting.',
        ),
      ],
    ),

    MeditationCategory(
      id: 'sleep',
      name: 'Better Sleep',
      tagline: 'Let the day finish',
      icon: Icons.nightlight_round,
      gradient: [Color(0xFF818CF8), Color(0xFF3730A3)],
      suggestedMinutes: 20,
      thoughts: [
        MeditationThought(
          'Closing the day',
          'Picture the day as a book in your hands. Turn through it briefly — the good, the awkward, the unfinished. Now close it and set it on the shelf. Tomorrow you may open it again. Tonight it is closed.',
        ),
        MeditationThought(
          'Sinking',
          'Feel the weight of your body pressing into the bed. With each exhale let it sink a little further, as though the mattress is slowly receiving you. Heaviness is the doorway to sleep — welcome it rather than resisting it.',
        ),
        MeditationThought(
          'Three good things',
          'Bring to mind three small things from today that went right. Not achievements — a warm cup, a kind message, a moment of quiet. Hold each one for a breath. The mind tends to replay what went wrong; give it something else to end on.',
        ),
        MeditationThought(
          'Nothing more is required',
          'There is nothing left for you to solve tonight. Every problem you can name will still be available in the morning, and you will meet it rested. Say once, silently: nothing more is required of me today.',
        ),
        MeditationThought(
          'The slow tide',
          'Breathe in for four counts, out for six. The longer out-breath is what tells the body it is safe. Let it become a slow tide going out, each wave a little further, until you cannot tell where counting stopped.',
        ),
      ],
    ),

    MeditationCategory(
      id: 'focus',
      name: 'Focus',
      tagline: 'Gather a scattered mind',
      icon: Icons.center_focus_strong_outlined,
      gradient: [Color(0xFFFBBF24), Color(0xFFB45309)],
      suggestedMinutes: 10,
      thoughts: [
        MeditationThought(
          'One point of light',
          'Picture a single point of light at the centre of your forehead. Everything else in the visual field dims. When the mind wanders — and it will — bring it back to the point. The returning is the exercise, not the staying.',
        ),
        MeditationThought(
          'Gathering the scattered',
          'Imagine your attention as filings scattered across a table, and your breath as a magnet drawing them into one place. Each inhale gathers a little more. By the end of ten breaths, everything is in one heap.',
        ),
        MeditationThought(
          'The one task',
          'Bring to mind the single most important thing you will do today. See yourself beginning it — not finishing, beginning. Notice the resistance that arises, and see yourself starting anyway. That is the whole of it.',
        ),
        MeditationThought(
          'Wherever it wanders',
          'The instruction is not "do not think." It is: wherever the mind goes, notice, and bring it back. A hundred returns in ten minutes is a hundred repetitions of the exact muscle you are trying to build.',
        ),
      ],
    ),

    MeditationCategory(
      id: 'confidence',
      name: 'Confidence',
      tagline: 'Remember what you already are',
      icon: Icons.bolt_outlined,
      gradient: [Color(0xFFF97316), Color(0xFF9A3412)],
      suggestedMinutes: 5,
      thoughts: [
        MeditationThought(
          'The unbroken point',
          'Beneath every role you play, every opinion held about you, there is a point of light that has never been damaged by anything that happened. Rest your attention there. Nothing anyone said today reached it.',
        ),
        MeditationThought(
          'Evidence',
          'Bring to mind one difficult thing you have already survived. You did not know you could, and you did. Whatever is in front of you now is being met by the person who got through that.',
        ),
        MeditationThought(
          'Standing tall inside',
          'Picture yourself walking into the room you are dreading — steady, unhurried, taking up your own space. Rehearse it once slowly. The body remembers rehearsal almost as well as it remembers experience.',
        ),
        MeditationThought(
          'Your own path, imperfectly',
          'Someone else is further ahead in a life that was never yours to live. Doing your own work badly is still the right direction. Let go of the comparison and feel how much lighter the same day becomes.',
        ),
      ],
    ),

    MeditationCategory(
      id: 'self_love',
      name: 'Self Love',
      tagline: 'The kindness you give everyone else',
      icon: Icons.favorite_border_rounded,
      gradient: [Color(0xFFF472B6), Color(0xFF9D174D)],
      suggestedMinutes: 10,
      thoughts: [
        MeditationThought(
          'How you speak to yourself',
          'Recall what you said to yourself after your last mistake. Now imagine saying those exact words to a friend who had done the same thing. You would never. Offer yourself the sentence you would have offered them.',
        ),
        MeditationThought(
          'Hand on the heart',
          'Place a hand on your chest and feel the warmth of it. This is the oldest gesture of comfort there is, and it works even when you are the one giving it. Breathe under your own hand for a few breaths.',
        ),
        MeditationThought(
          'The younger one',
          'Picture yourself at eight years old. See them clearly — what they hoped for, what frightened them. You would protect that child without hesitation. They are still in there. Say something kind to them now.',
        ),
        MeditationThought(
          'Enough, already',
          'Nothing needs to be achieved in the next ten minutes for you to deserve rest. You are not a project being completed. Sit as someone who is already enough, and notice how unfamiliar that feels.',
        ),
        MeditationThought(
          'Friend of the self',
          'The same mind that replays your failures at 2am can steady you instead. It listens to whoever speaks loudest. Decide, right now, to be the friend rather than the critic.',
        ),
      ],
    ),

    MeditationCategory(
      id: 'gratitude',
      name: 'Gratitude',
      tagline: 'Notice what is already here',
      icon: Icons.auto_awesome_outlined,
      gradient: [Color(0xFFFCD34D), Color(0xFFD97706)],
      suggestedMinutes: 5,
      thoughts: [
        MeditationThought(
          'The ordinary miracle',
          'Your heart has beaten every second of your life without being asked. Your lungs have never once forgotten. Sit for a moment with the machinery that has carried you here without any effort from you.',
        ),
        MeditationThought(
          'Someone unthanked',
          'Bring to mind a person who helped you and never knew how much. Hold their face. Send them a silent thank you. Gratitude does not require delivery to do its work in you.',
        ),
        MeditationThought(
          'What you nearly lost',
          'Think of something you have that you once feared losing. Feel it as though it had been returned to you this morning. Most of what we stop noticing is exactly what we would grieve.',
        ),
        MeditationThought(
          'Small and specific',
          'Not "I am grateful for my family" — too large to feel. Find something small: the first sip this morning, sunlight on a wall, a message that arrived at the right time. Specific gratitude is the kind that lands.',
        ),
      ],
    ),

    MeditationCategory(
      id: 'deep_relaxation',
      name: 'Deep Relaxation',
      tagline: 'Complete rest, nothing to do',
      icon: Icons.waves_rounded,
      gradient: [Color(0xFF22D3EE), Color(0xFF0E7490)],
      suggestedMinutes: 20,
      thoughts: [
        MeditationThought(
          'Head to feet',
          'Move attention slowly from scalp to toes, pausing at each place. Do not try to relax anything — simply visit it. Attention alone releases most of what is held.',
        ),
        MeditationThought(
          'Warm and heavy',
          'Let the arms become warm and heavy. Then the legs. Warmth and weight are the body\'s own signals for safety; suggesting them gently is often enough for the nervous system to follow.',
        ),
        MeditationThought(
          'Floating',
          'Imagine lying on still, warm water, held completely without any effort of your own. Nothing is required to stay afloat. Let the sensation of being carried replace the sensation of holding on.',
        ),
        MeditationThought(
          'The space behind the eyes',
          'Bring attention to the darkness behind closed eyes. Notice it has no edges. Rest your awareness in that spaciousness — there is nothing there to think about, and that is the point.',
        ),
      ],
    ),

    MeditationCategory(
      id: 'morning',
      name: 'Morning Energy',
      tagline: 'Meet the day before it meets you',
      icon: Icons.wb_twilight_rounded,
      gradient: [Color(0xFFFB923C), Color(0xFFC2410C)],
      suggestedMinutes: 5,
      thoughts: [
        MeditationThought(
          'Amrit Vela',
          'These early hours are the quietest the world gets. Nothing is being asked of you yet. Sit in the stillness before the day has any opinions about you, and let it fill up first.',
        ),
        MeditationThought(
          'Setting the tone',
          'The first thought of the day tends to colour the rest of it. Choose one deliberately, before the phone chooses one for you: I am a peaceful soul. Hold it for a few breaths so it settles.',
        ),
        MeditationThought(
          'Light entering',
          'With each inhale, picture light entering at the crown and filling the body downward. With each exhale, the night\'s heaviness leaves through the feet. Ten breaths and the day starts fresh.',
        ),
        MeditationThought(
          'One intention',
          'Not a task list — one quality. Patience. Attention. Kindness. Choose it now and it will be available later, in the moment you need it, because you already put it somewhere findable.',
        ),
      ],
    ),

    MeditationCategory(
      id: 'evening',
      name: 'Evening Calm',
      tagline: 'Come back to yourself',
      icon: Icons.bedtime_outlined,
      gradient: [Color(0xFFA78BFA), Color(0xFF5B21B6)],
      suggestedMinutes: 10,
      thoughts: [
        MeditationThought(
          'Laying down the roles',
          'All day you have been someone — employee, parent, friend, stranger on a train. Take each role off like a coat and hang it up. What is left underneath is what sits here now.',
        ),
        MeditationThought(
          'Reviewing without judging',
          'Walk back through the day as an observer, not a judge. Notice where you were kind, where you were rushed. No verdict is needed. Simply seeing it clearly is what changes tomorrow.',
        ),
        MeditationThought(
          'Releasing what was said',
          'If a conversation is still turning in your mind, picture yourself setting it on a shelf. You are not resolving it tonight. Placing it somewhere is enough to stop carrying it.',
        ),
        MeditationThought(
          'The unmoved ocean',
          'Rivers ran into you all day — demands, opinions, news. The ocean receives every river and its level does not change. Feel how much of you was never actually disturbed.',
        ),
      ],
    ),
  ];

  static MeditationCategory? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}

import 'package:flutter/foundation.dart' show kDebugMode;

class AppConstants {
  // App Info
  static const String appName = 'InnenFlow';
  static const String appTagline = 'A quieter place to think';

  /// Display names for the anonymous board.
  ///
  /// Rewritten to carry no religious signal. The previous set — Divine Spark,
  /// Holy Presence, Sacred Breath, Enlightened Heart — read as belonging to one
  /// tradition, and the point of this app is that it should not. Somebody
  /// Muslim, Christian, or of no faith at all was being handed a name from
  /// somebody else's vocabulary at the exact moment they were trying to say
  /// something honest.
  ///
  /// What replaces them describes a *manner*, not a belief: quiet, steady,
  /// careful. Anyone can be told they are a "Steady Hand" and recognise it.
  static const List<String> anonymousNames = [
    'Quiet Voice', 'Steady Hand', 'Night Thinker', 'Open Window',
    'Slow Reader', 'Kind Stranger', 'Second Thought', 'Long Walk',
    'Early Riser', 'Small Fire', 'Blue Hour', 'Calm Observer',
    'Deep Breath', 'Still Water', 'Soft Landing', 'Clear Sky',
    'Distant Light', 'Patient Sort', 'Warm Coat', 'Low Tide',
    'First Light', 'Anonymous Friend', 'Someone Nearby', 'Quiet Room',
    'Held Together', 'Halfway There', 'Honest Note', 'Gentle Answer',
    'Long Way Round', 'Sitting With It',
  ];

  // Colours paired with the names above.
  static const List<String> anonymousColors = [
    '#8B5CF6', '#06B6D4', '#10B981', '#F59E0B', '#EF4444',
    '#EC4899', '#6366F1', '#84CC16', '#F97316', '#14B8A6',
    '#8B5A2B', '#7C3AED', '#059669', '#DC2626', '#7C2D12',
  ];

  // Meditation Durations
  static const List<int> meditationDurations = [5, 10, 20, 30];

  // Thoughts of the Day
  static const List<String> thoughtsOfDay = [
    'Peace is not the absence of conflict, but the ability to cope with it through inner strength.',
    'Every moment is a fresh beginning. Use it to create something beautiful.',
    'Calm is not something you find. It is something you return to.',
    'When you change your thoughts, you change your world.',
    'Meditation is not about stopping thoughts, but recognizing that you are more than your thoughts.',
  ];

  /// Lines to rest attention on during a sitting.
  ///
  /// These were mantras from one tradition — "Om Shanti", "I am connected to
  /// the divine source". A phrase you repeat for ten minutes is not neutral
  /// furniture: it is the actual content of the practice, and handing somebody
  /// a devotional line from a faith that is not theirs makes the whole feature
  /// unusable for them. What is here now is the same mechanism — a short phrase
  /// paced to the breath — with nothing to opt into.
  static const List<String> groundingLines = [
    'Breathing in, I am here. Breathing out, I am here.',
    'This moment is enough.',
    'Let the shoulders drop.',
    'Breathe in slowly, let it go slowly.',
    'Nothing to fix right now.',
  ];

  // Default Affirmations (same as website)
  static const List<String> defaultAffirmations = [
    'I am worthy of love and respect',
    'I choose peace and happiness in every moment',
    'I am grateful for all the blessings in my life',
    'I trust in my ability to overcome challenges',
    'I radiate positive energy and attract good things',
    'I am confident in my unique gifts and talents',
    'I choose to see the good in every situation',
    'I am creating a life filled with purpose and joy',
    'I deserve success and abundance in all areas',
    'I am at peace with who I am becoming',
  ];

  // Mood Emojis (same as website)
  static const List<Map<String, dynamic>> moodEmojis = [
    {'value': 1, 'emoji': '😢', 'label': 'Very Sad'},
    {'value': 2, 'emoji': '😔', 'label': 'Sad'},
    {'value': 3, 'emoji': '😐', 'label': 'Neutral'},
    {'value': 4, 'emoji': '🙂', 'label': 'Happy'},
    {'value': 5, 'emoji': '😊', 'label': 'Very Happy'},
  ];

  // Placeholder coach responses.
  static const List<String> chatbotResponses = [
    '🙏 That is worth sitting with. Underneath a hard day there is usually a steadier version of you still there.',
    '✨ Your awareness is growing. Every question you ask is a step closer to understanding yourself.',
    '💜 Whatever you are feeling right now is allowed to be here. It does not have to be justified first.',
    '🌟 Take a deep breath. The answers you seek are often already within you.',
    '🌿 A hard moment is not a verdict on you. You have got through every one of them so far.',
    '🌸 Practice self-compassion today. You are doing better than you think.',
    '☀️ Start each day by remembering: calm is your baseline, not your reward.',
    '🌙 Rest in the awareness that you are much more than your thoughts and circumstances.',
  ];

  // Firebase Collection Names
  static const String entriesCollection = 'entries';
  static const String profilesCollection = 'profiles';
  static const String anonymousThoughtsCollection = 'anonymous_thoughts';
  static const String meditationSessionsCollection = 'meditation_sessions';
  /// Attention games. Separate from meditation so the meditation minutes stay
  /// an honest number.
  static const String focusSessionsCollection = 'focus_sessions';
  static const String affirmationProgressCollection = 'affirmation_progress';
  static const String affirmationSessionsCollection = 'affirmation_sessions';
  static const String userAffirmationsCollection = 'user_affirmations';

  // Firebase Storage Paths
  static const String meditationSoundsPath = 'meditation_sounds';

  // ───────────────────────── launch configuration ─────────────────────────

  /// Master switch for paid membership.
  ///
  /// While this is false, signing up is free and no checkout is shown. All the
  /// Razorpay code — subscription creation, HMAC verification, entitlement
  /// writes — is deliberately left in place and unmodified; it is simply not
  /// reached. Flip this back to true and the paid flow returns exactly as it
  /// was, with no code to rewrite.
  ///
  /// This also happens to remove the app's dependency on Cloud Functions for
  /// registration, which is what was blocking signup while the project sits on
  /// the Spark plan.
  static const bool paymentsEnabled = false;

  /// Whether everything is currently free for everyone.
  ///
  /// Deliberately the plain inverse of [paymentsEnabled] and nothing else.
  ///
  /// This used to be `DateTime.now().isBefore(freeAccessUntil)` against a
  /// hardcoded 7 November 2026. That is a trap: the app would begin telling
  /// people their access was running out — and eventually begin charging —
  /// on a date set months earlier by someone who would not be thinking about
  /// it when it arrived. A deadline that fires on its own is a deadline nobody
  /// decided to fire.
  ///
  /// Free access now ends when a human flips [paymentsEnabled] back to true
  /// and ships a build. There is no clock, and nothing counts down.
  static bool get isFreeAccessActive => !paymentsEnabled;

  /// Whether the app may be screenshotted and screen-recorded.
  ///
  /// Tied to the build mode rather than to a hand-flipped constant, and that is
  /// the point: **a release build is always protected**, so journal entries,
  /// check-ins, anonymous thoughts, counselling transcripts and the book reader
  /// cannot be left exposed by forgetting to change something back.
  ///
  /// Debug builds are capturable, which is what makes store screenshots and a
  /// walkthrough recording possible — with protection on, a screen recording
  /// comes out black and the app switcher shows a blank card. Debug builds are
  /// never distributed; App Distribution and the Play Store both get release
  /// builds.
  ///
  /// The same rule is expressed natively as well, because the native side runs
  /// before any Dart does — protection is applied in `onCreate` /
  /// `didFinishLaunching`, precisely so no frame can be captured in the gap:
  ///
  ///   * `MainActivity.ALLOW_SCREEN_CAPTURE` in
  ///     android/app/src/main/kotlin/com/brahma/brahmaApp/MainActivity.kt
  ///   * `ScreenSecurity.allowScreenCapture` in ios/Runner/AppDelegate.swift
  static const bool allowScreenCapture = kDebugMode;

  // Firestore collections owned by the server
  static const String leaderboardCollection = 'leaderboard';
  static const String purchasesCollection = 'purchases';

  /// TRANSITIONAL — remove once custom claims are issued.
  ///
  /// Admin is a server-minted custom claim, but there is no in-app way to mint
  /// the *first* one (that would be an escalation hole), so it needs
  /// functions/scripts/bootstrap-admin.js run once with a service-account key.
  /// Until that happens nobody holds the claim and every admin control is
  /// invisible, so this address is accepted as a fallback.
  ///
  /// This is not the old vulnerability returning. That was a hardcoded
  /// *password* shipping in the APK, which let anyone sign in as the operator.
  /// An email address is not a credential: it is compared against the address
  /// inside a Firebase-signed ID token, which cannot be forged, and Firebase
  /// enforces address uniqueness so no other account can claim it. The same
  /// check is what your currently-deployed rules already use.
  ///
  /// After running the bootstrap script, delete this constant and the matching
  /// `isConfiguredAdminEmail()` branch in firestore.rules.
  static const String adminEmail = 'officialshashi2023@gmail.com';

  // ─────────────────────── community channels ────────────────────────
  //
  // Public invite links, not secrets: they are meant to be handed out, and
  // they are what turns a reader into someone who comes back.

  /// WhatsApp group where updates are posted.
  static const String communityWhatsAppUrl =
      'https://chat.whatsapp.com/CSSPtnLv7q15UWuHgRD8ol';

  static const String instagramUrl =
      'https://www.instagram.com/____shashii_o7/';

  static const String instagramHandle = '@____shashii_o7';

  // NOTE — deliberately no secrets here.
  //
  // This class used to expose `razorpaySecret`, `resendApiKey`, plan ids and a
  // hardcoded admin email, all read from a .env file that pubspec.yaml bundled
  // as a Flutter asset. An asset is packaged verbatim into the APK, so every
  // one of those values could be read with `unzip app-release.apk` — no
  // rooting and no reverse engineering required. The Razorpay secret granted
  // full access to the merchant account and the Resend key allowed sending
  // mail as the brand to this app's own users.
  //
  // Those operations now run in Cloud Functions with the credentials held in
  // Secret Manager; the app reaches them through BackendService. The only
  // Razorpay value the client ever sees is the publishable key id, and it is
  // handed back by the server at checkout time rather than compiled in.
}

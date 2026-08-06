class AppConstants {
  // App Info
  static const String appName = 'Brahma Journal';
  static const String appTagline = 'Your Spiritual Wellness Companion';

  // Spiritual Names for Anonymous Thoughts (same as website)
  static const List<String> spiritualNames = [
    'Serene Seeker', 'Peaceful Soul', 'Mindful Heart', 'Gentle Spirit',
    'Wise Wanderer', 'Calm Observer', 'Kind Heart', 'Thoughtful Mind',
    'Pure Essence', 'Silent Sage', 'Loving Light', 'Quiet Strength',
    'Inner Peace', 'Sacred Journey', 'Divine Spark', 'Eternal Flame',
    'Mystic Soul', 'Radiant Being', 'Blessed Path', 'Cosmic Dreamer',
    'Spiritual Guide', 'Awakened One', 'Enlightened Heart', 'Tranquil Mind',
    'Sacred Breath', 'Universal Love', 'Infinite Grace', 'Celestial Voice',
    'Holy Presence', 'Divine Light',
  ];

  // Spiritual Colors
  static const List<String> spiritualColors = [
    '#8B5CF6', '#06B6D4', '#10B981', '#F59E0B', '#EF4444',
    '#EC4899', '#6366F1', '#84CC16', '#F97316', '#14B8A6',
    '#8B5A2B', '#7C3AED', '#059669', '#DC2626', '#7C2D12',
  ];

  // Meditation Durations
  static const List<int> meditationDurations = [5, 10, 20, 30];

  // Thoughts of the Day (same as website)
  static const List<String> thoughtsOfDay = [
    'Peace is not the absence of conflict, but the ability to cope with it through inner strength.',
    'Every moment is a fresh beginning. Use it to create something beautiful.',
    'The soul\'s natural state is one of peace, love, and happiness.',
    'When you change your thoughts, you change your world.',
    'Meditation is not about stopping thoughts, but recognizing that you are more than your thoughts.',
  ];

  // Mantras (same as website)
  static const List<String> mantras = [
    'Om Shanti... Om Shanti... Om Shanti...',
    'I am a peaceful soul...',
    'I am love, I am light...',
    'Breathe in peace, breathe out love...',
    'I am connected to the divine source...',
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

  // Dummy Chatbot Responses
  static const List<String> chatbotResponses = [
    '🙏 That is a beautiful reflection. Remember, the soul is always at peace beneath the surface of life\'s storms.',
    '✨ Your awareness is growing. Every question you ask is a step closer to your higher self.',
    '💜 In Brahma Kumaris wisdom, we say: "The original nature of the self is peace." Trust in this truth.',
    '🌟 Take a deep breath. The answers you seek are already within you.',
    '🕉️ Every challenge is an invitation for your soul to shine brighter. You have the inner strength to transform this.',
    '🌸 Practice self-compassion today. You are doing better than you think.',
    '☀️ Start each day by remembering: I am a peaceful soul. This simple thought can transform your day.',
    '🌙 Rest in the awareness that you are much more than your thoughts and circumstances.',
  ];

  // Firebase Collection Names
  static const String entriesCollection = 'entries';
  static const String profilesCollection = 'profiles';
  static const String anonymousThoughtsCollection = 'anonymous_thoughts';
  static const String meditationSessionsCollection = 'meditation_sessions';
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

  /// Everything is free for everyone until this moment.
  ///
  /// Three months from the 7 August 2026 launch. Stored as UTC so a device in
  /// another timezone counts down to the same instant. To extend the window,
  /// change this date and ship a build — or set `freeUntil` (an ISO-8601
  /// string) on the `app_config/access` document, which takes precedence and
  /// needs no release.
  static final DateTime freeAccessUntil = DateTime.utc(2026, 11, 7, 23, 59, 59);

  /// Whether the free window is still open.
  static bool get isFreeAccessActive => DateTime.now().toUtc().isBefore(freeAccessUntil);

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

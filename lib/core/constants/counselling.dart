/// Everything the counselling flow needs that is not code.
///
/// Kept in one place because these are the values most likely to change without
/// a developer present: the UPI handle, the fee, the meeting link. Hunting them
/// down across six widget files is how a fee ends up correct on one screen and
/// stale on another.
class Counselling {
  /// Whether the counselling room exists in this build at all.
  ///
  /// Off because one-to-one counselling is a "Mental and behavioural health"
  /// feature, which Google Play files under Medical, and Medical apps can only
  /// be published from an organization developer account. InnenFlow ships from
  /// a personal one, so 1.7.3 was rejected (8 Oct 2026). With this off there is
  /// no way in: the support button opens the contact form, the routes redirect
  /// to the dashboard, and notifications for a session open nothing.
  ///
  /// Turn it back on only after the app moves to an organization account AND
  /// the Play Console Health apps declaration ticks Mental and behavioural
  /// health again — shipping one without the other is a rejection either way.
  static const bool enabled = false;

  static const bool paymentsEnabled = false;

  /// Where the session fee is collected.
  static const String upiId = 'brahmajournal@ptaxis';
  static const String payeeName = 'InnenFlow';

  /// Rupees. Shown in the chat, encoded into the UPI intent, and stored on the
  /// session so a later change to this constant does not rewrite history.
  static const int fee = 299;

  static const int sessionMinutes = 30;

  /// The room a 30-minute call happens in.
  // NOTE: the hardcoded `meetLink` that used to live here has been removed.
  //
  // It was one Google Meet room, handed to every member who chose a video
  // call. Anybody holding it could join any other member's counselling
  // session — in an app whose central promise is that these conversations are
  // private. The counsellor now issues a room per session when they approve
  // the call; see CounsellingSession.meetLink.

  /// A UPI deep link, for paying from the same phone the app is on. A QR code
  /// is unscannable by the device displaying it, so the button matters more
  /// than the picture — the QR is there for someone paying from another phone.
  static String upiIntent({int? amount}) {
    final amt = amount ?? fee;
    return 'upi://pay'
        '?pa=$upiId'
        '&pn=${Uri.encodeComponent(payeeName)}'
        '&am=$amt'
        '&cu=INR'
        '&tn=${Uri.encodeComponent('InnenFlow counselling session')}';
  }

  /// The same string a UPI QR encodes.
  static String qrPayload({int? amount}) => upiIntent(amount: amount);

  /// How the fee was paid. Free text would arrive as "gpay", "G-Pay", "google
  /// pay" and "GPay" for the same thing, which makes the admin's job worse for
  /// no benefit to the user.
  static const paymentModes = <String>[
    'Google Pay',
    'PhonePe',
    'Paytm',
    'BHIM / other UPI',
    'Bank transfer',
  ];

  /// Plain-language topics help someone describe their experience without
  /// choosing a diagnosis. The free-text note covers anything not listed.
  /// Coverage informed by NIMH Psychotherapies and NHS Talking therapies:
  /// https://www.nimh.nih.gov/health/topics/psychotherapies
  /// https://www.nhs.uk/tests-and-treatments/talking-therapies/
  static const maxConcerns = 3;
  static const otherConcern = 'Other / not sure how to describe it';
  static const concerns = <String>[
    'Stress or feeling overwhelmed',
    'Anxiety, worry or panic',
    'Low mood or loss of motivation',
    'School, exams or study pressure',
    'Work, career or burnout',
    'Relationships or a breakup',
    'Family, parenting or caregiving',
    'Loneliness or friendship difficulties',
    'Bullying, peer or social pressure',
    'Confidence, self-worth or body image',
    'Grief or losing someone',
    'Sleep or difficulty relaxing',
    'Anger or managing emotions',
    'Painful memories or trauma',
    'Unwanted thoughts or repetitive habits',
    'Attention, focus or daily routines',
    'Food or eating concerns',
    'Alcohol, substances or other habits',
    'Screen time, gaming or social media',
    'Health worries or long-term illness',
    'Identity, belonging or discrimination',
    'Life changes or money worries',
    'Unusual or distressing experiences',
    otherConcern,
  ];

  static const languages = <String>['Hindi', 'English', 'Hinglish'];

  /// The reply that lands the moment someone finishes the intake form.
  ///
  /// Written as one message rather than four so the chat does not open with a
  /// wall of grey bubbles, and it says what happens next in order — the single
  /// most common support question is "what now?".
  static String welcome(String name) =>
      'Hello ${name.isEmpty ? 'friend' : name} 👋\n\n'
      'Thank you for reaching out — that is the hardest part, and you have done it.\n\n'
      'Here is how this works:\n'
      '1. Pay the ₹$fee session fee below.\n'
      '2. Send us the payment mode and transaction ID.\n'
      '3. Once we confirm it, your $sessionMinutes-minute session opens — '
      'a video call or a chat, whichever you prefer.\n\n'
      'Everything you say here stays between us, and the whole conversation is '
      'deleted automatically two hours after the session ends.';

  static const String paymentAsk =
      'When the payment is done, tap "I have paid" below and send your payment '
      'details — payment mode and transaction ID. We check it by hand, usually '
      'within a few minutes during working hours.';

  static const String paymentReceived =
      'Got it — your payment details are with us now. We are verifying them. '
      'You will see this chat open up the moment it is confirmed. You can close '
      'the app; nothing is lost.';

  static const String approved =
      'Your payment is confirmed. Your session is ready 🌼\n\n'
      'How would you like to talk? A video call is better if you want to be '
      'heard; chat is better if writing feels safer. There is no wrong answer.';

  /// The member asked for a call. Nothing is issued yet — see [meetApproved].
  static const String meetRequested =
      'A video call it is. Your counsellor has been asked to confirm a time.\n\n'
      'The joining link will appear right here in this chat as soon as they do. '
      'You can close the app — nothing is lost, and you will be notified.';

  /// The counsellor has confirmed and issued a room for this session.
  ///
  /// The link is passed in rather than read from a constant. A single shared
  /// room meant every member with an approved session held a working way into
  /// everybody else's call; each session now gets its own.
  static String meetApproved(String link) =>
      'Your $sessionMinutes-minute video call is confirmed 🌼\n\n'
      'Join here:\n$link\n\n'
      'Your counsellor will be waiting. If you get cut off, come back to this '
      'chat — it stays open.';

  static const String chatChosen =
      'We will talk here. Your counsellor has been notified and will reply '
      'shortly. Take your time — write as much or as little as you want.';

  static const String rejected =
      'We could not verify that payment. Nothing has been taken from you — '
      'please check the transaction ID and send it again, or reach out on '
      'WhatsApp and we will sort it out personally.';

  static const String ended =
      'This session has ended. Thank you for trusting us with it.\n\n'
      'This conversation, including any voice notes, will be deleted '
      'automatically two hours from now. If there is anything here you want to '
      'keep, write it into your journal before then.';

  /// The emoji panel in the chat composer. A curated set rather than a full
  /// picker: this is a counselling room, and the twelve hundred emoji a system
  /// picker offers are mostly noise here.
  static const emojis = <String>[
    '🙏',
    '❤️',
    '🥺',
    '😊',
    '😔',
    '😢',
    '😭',
    '😅',
    '😰',
    '😞',
    '😌',
    '🤗',
    '💪',
    '🌼',
    '✨',
    '🕊️',
    '🌱',
    '☀️',
    '🌙',
    '💛',
    '🫂',
    '👍',
    '👌',
    '🙌',
    '😇',
    '😴',
    '😤',
    '😳',
    '🤔',
    '💭',
    '🔥',
    '🎉',
  ];
}

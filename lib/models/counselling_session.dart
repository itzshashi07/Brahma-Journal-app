/// Where a counselling request has got to.
///
/// The order is the order a session actually moves through, so `index` can be
/// compared when a screen needs "has this got past payment yet".
enum CounsellingStatus {
  /// Intake answered, fee not paid.
  awaitingPayment,

  /// Member says they have paid and has given a transaction id. Waiting on a
  /// human to check it against the bank.
  paymentSubmitted,

  /// Payment confirmed. The member now chooses call or chat.
  approved,

  /// The member asked for a video call and is waiting for the counsellor to
  /// confirm a time and issue a room.
  ///
  /// This state exists because a call needs a human at both ends. The old flow
  /// handed out the room the instant the member picked "video call", so they
  /// could join at 3am and sit alone in an empty room believing they had been
  /// stood up. Nothing is issued now until somebody has actually agreed to be
  /// there.
  meetRequested,

  /// The session is running.
  active,

  /// Finished. The whole conversation is deleted two hours after this.
  ended,

  /// Payment could not be verified. Recoverable — they can send details again.
  rejected;

  static CounsellingStatus parse(String? raw) => switch (raw) {
        'payment_submitted' => CounsellingStatus.paymentSubmitted,
        'approved' => CounsellingStatus.approved,
        'meet_requested' => CounsellingStatus.meetRequested,
        'active' => CounsellingStatus.active,
        'ended' => CounsellingStatus.ended,
        'rejected' => CounsellingStatus.rejected,
        _ => CounsellingStatus.awaitingPayment,
      };

  String get wire => switch (this) {
        CounsellingStatus.awaitingPayment => 'awaiting_payment',
        CounsellingStatus.paymentSubmitted => 'payment_submitted',
        CounsellingStatus.approved => 'approved',
        CounsellingStatus.meetRequested => 'meet_requested',
        CounsellingStatus.active => 'active',
        CounsellingStatus.ended => 'ended',
        CounsellingStatus.rejected => 'rejected',
      };

  String get label => switch (this) {
        CounsellingStatus.awaitingPayment => 'Awaiting payment',
        CounsellingStatus.paymentSubmitted => 'Payment to verify',
        CounsellingStatus.approved => 'Approved — choosing format',
        CounsellingStatus.meetRequested => 'Call requested',
        CounsellingStatus.active => 'Session live',
        CounsellingStatus.ended => 'Ended',
        CounsellingStatus.rejected => 'Payment rejected',
      };
}

/// How the session is being held.
enum CounsellingMode {
  undecided,
  meet,
  chat;

  static CounsellingMode parse(String? raw) => switch (raw) {
        'meet' => CounsellingMode.meet,
        'chat' => CounsellingMode.chat,
        _ => CounsellingMode.undecided,
      };

  String get wire => switch (this) {
        CounsellingMode.meet => 'meet',
        CounsellingMode.chat => 'chat',
        CounsellingMode.undecided => '',
      };
}

/// One counselling request, from intake to deletion.
///
/// The personal details on this document are the reason it is owner-and-admin
/// readable only, and the reason [purgeAfter] exists: a counselling transcript
/// is the most sensitive thing this app will ever hold, and the promise made to
/// the member is that it does not outlive the session by more than two hours.
class CounsellingSession {
  final String id;
  final String uid;

  // Intake.
  final String name;
  final String age;
  final String gender;
  final String phone;
  final String concern;
  final String language;
  final String details;

  final CounsellingStatus status;
  final CounsellingMode mode;

  /// The video room for THIS session, issued by the counsellor when they
  /// approve the call.
  ///
  /// Deliberately a field rather than the constant it used to be. One hardcoded
  /// room shared by every session meant any member with an approved session
  /// held a working link into somebody else's counselling call — the single
  /// worst confidentiality failure available in this app.
  final String meetLink;

  // Payment, as reported by the member and verified by hand.
  final String paymentMode;
  final String transactionId;
  final int amount;

  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? endedAt;

  /// After this instant the session and every message under it are deleted.
  /// Null until the session ends.
  final DateTime? purgeAfter;

  /// Drives the unread dot on the admin inbox without reading the subcollection.
  final DateTime? lastMessageAt;
  final String lastMessagePreview;

  /// Who spoke last. Without it, a device cannot tell a reply it should be
  /// notified about from its own message coming back through the stream.
  final ChatSender? lastMessageBy;

  const CounsellingSession({
    required this.id,
    required this.uid,
    required this.name,
    required this.createdAt,
    this.age = '',
    this.gender = '',
    this.phone = '',
    this.concern = '',
    this.language = '',
    this.details = '',
    this.status = CounsellingStatus.awaitingPayment,
    this.mode = CounsellingMode.undecided,
    this.meetLink = '',
    this.paymentMode = '',
    this.transactionId = '',
    this.amount = 0,
    this.approvedAt,
    this.endedAt,
    this.purgeAfter,
    this.lastMessageAt,
    this.lastMessagePreview = '',
    this.lastMessageBy,
  });

  /// The API speaks ISO 8601. Firestore spoke `Timestamp`, which is why this
  /// used to sniff the type — there is only one wire format now.
  static DateTime? _date(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;

  factory CounsellingSession.fromJson(Map<String, dynamic> d) {
    return CounsellingSession(
      id: '${d['_id'] ?? d['id'] ?? ''}',
      uid: d['firebaseUid'] ?? d['uid'] ?? '',
      name: d['name'] ?? '',
      age: '${d['age'] ?? ''}',
      gender: d['gender'] ?? '',
      phone: d['phone'] ?? '',
      concern: d['concern'] ?? '',
      language: d['language'] ?? '',
      details: d['details'] ?? '',
      status: CounsellingStatus.parse(d['status']),
      mode: CounsellingMode.parse(d['mode']),
      meetLink: d['meetLink'] ?? '',
      paymentMode: d['paymentMode'] ?? '',
      transactionId: d['transactionId'] ?? '',
      amount: (d['amount'] is num) ? (d['amount'] as num).toInt() : 0,
      createdAt: _date(d['createdAt']) ?? DateTime.now(),
      approvedAt: _date(d['approvedAt']),
      endedAt: _date(d['endedAt']),
      purgeAfter: _date(d['purgeAfter']),
      lastMessageAt: _date(d['lastMessageAt']),
      lastMessagePreview: d['lastMessagePreview'] ?? '',
      lastMessageBy:
          d['lastMessageBy'] == null ? null : ChatSender.parse(d['lastMessageBy']),
    );
  }

  /// The intake payload. Only the fields `POST /api/counselling/sessions`
  /// accepts — status, amount and every timestamp are the server's to decide,
  /// and sending them would be a client asserting its own state.
  Map<String, dynamic> toIntakeJson() => {
        'name': name,
        'age': age,
        'gender': gender,
        'phone': phone,
        'concern': concern,
        'language': language,
        'details': details,
      };

  /// True once the two-hour window has passed and this session should no
  /// longer exist.
  bool get isExpired =>
      purgeAfter != null && DateTime.now().isAfter(purgeAfter!);

  /// How long is left before deletion. Shown to the member so the promise is
  /// visible rather than asserted.
  Duration? get timeUntilPurge {
    final p = purgeAfter;
    if (p == null) return null;
    final left = p.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get isLive =>
      status == CounsellingStatus.active || status == CounsellingStatus.approved;
}

/// Who sent a message.
enum ChatSender {
  member,
  admin,

  /// Written by the app itself: the welcome, the payment instructions, the
  /// approval. Rendered as a centred note rather than a bubble, so nobody
  /// mistakes automation for their counsellor.
  system;

  static ChatSender parse(String? raw) => switch (raw) {
        'admin' => ChatSender.admin,
        'system' => ChatSender.system,
        _ => ChatSender.member,
      };

  String get wire => name;
}

/// What a message carries.
enum ChatKind {
  text,
  audio,

  /// A structured payment report: mode + transaction id, rendered as a card so
  /// the admin can act on it without reading it out of a sentence.
  payment;

  static ChatKind parse(String? raw) => switch (raw) {
        'audio' => ChatKind.audio,
        'payment' => ChatKind.payment,
        _ => ChatKind.text,
      };

  String get wire => name;
}

class ChatMessage {
  final String id;
  final ChatSender sender;
  final ChatKind kind;
  final String text;

  /// Storage download URL for a voice note. Empty for anything else.
  final String audioUrl;
  final int audioSeconds;

  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.createdAt,
    this.kind = ChatKind.text,
    this.text = '',
    this.audioUrl = '',
    this.audioSeconds = 0,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> d) {
    return ChatMessage(
      id: '${d['_id'] ?? d['id'] ?? ''}',
      sender: ChatSender.parse(d['sender']),
      kind: ChatKind.parse(d['kind']),
      text: d['text'] ?? '',
      audioUrl: d['audioUrl'] ?? '',
      audioSeconds:
          (d['audioSeconds'] is num) ? (d['audioSeconds'] as num).toInt() : 0,
      // Every message is stamped by the server now, so the "written offline
      // with no stamp yet" case Firestore had cannot arise. The fallback stays
      // as a guard against a malformed row, and keeps it at the bottom of the
      // list where the sender expects it rather than at 1970.
      createdAt: CounsellingSession._date(d['createdAt']) ?? DateTime.now(),
    );
  }
}

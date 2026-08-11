import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/counselling.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';

/// The privacy policy and the terms, in the app.
///
/// Written to describe what this app actually does rather than copied from a
/// generator. That matters twice over: a store review reads them, and — more
/// to the point — a member is being asked to type the reason they are
/// struggling into a text box, and they are owed a plain answer about where it
/// goes and who can read it.
///
/// Kept in Dart rather than fetched from a URL so they open with no network, in
/// the app's own type, and cannot silently change under someone who already
/// agreed to them.
class LegalScreen extends StatelessWidget {
  final LegalDoc doc;

  const LegalScreen({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: doc.title,
                subtitle: 'Last updated ${doc.updated}',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppTheme.space5, 0,
                      AppTheme.space5, AppTheme.space8),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.22)),
                      ),
                      child: Text(
                        doc.summary,
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space6),
                    for (final section in doc.sections) ...[
                      Text(
                        section.$1,
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        section.$2,
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            height: 1.65,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: AppTheme.space5),
                    ],
                    const Divider(color: AppTheme.border),
                    const SizedBox(height: AppTheme.space4),
                    const Text(
                      'Questions, or want your data deleted?',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: AppTheme.space2),
                    const Text(
                      'Write to brahmajournal@gmail.com or message +91 8078633912. '
                      'Account deletion is done within 30 days of asking, and it '
                      'removes your journal, your check-ins and your profile.',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12.5,
                          height: 1.6,
                          color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    SacredButton(
                      label: 'Message us on WhatsApp',
                      icon: Icons.chat_bubble_outline_rounded,
                      secondary: true,
                      onTap: () => launchUrl(
                        Uri.parse('https://wa.me/918078633912'),
                        mode: LaunchMode.externalApplication,
                      ),
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

class LegalDoc {
  final String title;
  final String updated;

  /// The one paragraph most people will read. Written first, deliberately.
  final String summary;

  final List<(String, String)> sections;

  const LegalDoc({
    required this.title,
    required this.updated,
    required this.summary,
    required this.sections,
  });

  static const updatedOn = '9 August 2026';

  static const privacy = LegalDoc(
    title: 'Privacy Policy',
    updated: updatedOn,
    summary:
        'Your journal is yours. Nobody else — including us — can read your '
        'entries, your check-ins or your counselling messages, except where '
        'this page says otherwise. We do not sell data, we do not run ads, and '
        'we do not share anything with advertisers.',
    sections: [
      (
        'What we store',
        'Your account details (name, email, phone, age, gender), your journal '
            'entries and daily check-ins, your meditation and game sessions, '
            'anything you post publicly (articles, comments, anonymous '
            'reflections), and — if you book a counselling session — the intake '
            'details you fill in and the conversation itself.\n\n'
            'All of it lives in Google Firebase (Firestore and Cloud Storage) '
            'on servers operated by Google.',
      ),
      (
        'Who can read your journal',
        'Only you. Firestore security rules restrict every journal entry, '
            'check-in and affirmation to the account that wrote it. This is '
            'enforced on the server, not by the app — even someone with a '
            'modified copy of the app cannot read another member\'s entries.',
      ),
      (
        'What other members can see',
        'Only what you deliberately make public: your display name, avatar, '
            'streak and practice counters on the Community leaderboard; the '
            'number of published articles you have written; any article or '
            'comment you publish; and anonymous reflections, which carry a '
            'generated display name and never your identity.\n\n'
            'Your email, phone number, age and gender are never shown to other '
            'members.',
      ),
      (
        'Following',
        'How many followers someone has is shown on the Community screen. Who '
            'follows whom is not — not to other members, and not to the person '
            'being followed. Following someone is not announced to them and '
            'there is no way, anywhere in the app, to see a list of who '
            'follows you or who you follow other than your own.',
      ),
      (
        'Anonymous reflections',
        'A reflection is posted under a generated display name and is never '
            'linked to your account for other members to see.\n\n'
            'Reflections are deleted a month after they are posted, whether or '
            'not anyone has replied. You can delete your own at any time, and '
            'we remove any reflection that breaks the rules below.',
      ),
      (
        'Counselling sessions',
        'Your intake details and the whole conversation — text and voice notes '
            '— are readable only by you and the counsellor.\n\n'
            'The entire conversation is deleted automatically two hours after '
            'the session ends. That includes voice recordings. You can also end '
            'and delete a session yourself at any time.\n\n'
            'What you say in a counselling session is never used for anything '
            'else, and is never shown to other members.',
      ),
      (
        'Payments',
        'Counselling fees are paid by UPI directly to ${Counselling.upiId}. We '
            'never see or store your card number, UPI PIN, or bank credentials — '
            'you pay from your own banking app. All we record is the payment '
            'method you tell us and the transaction reference you send, so a '
            'human can verify the payment arrived.',
      ),
      (
        'Microphone and voice',
        'The microphone is used only while you are holding a voice input '
            'button or recording a voice note, and only after you grant '
            'permission. Speech-to-text is processed by your device\'s own '
            'speech recogniser. We do not record in the background, ever.',
      ),
      (
        'Notifications',
        'Notifications are generated on your own device from data you already '
            'have access to — a new article, a reply in your counselling chat. '
            'Turning them off in your phone\'s settings does not affect '
            'anything else in the app.',
      ),
      (
        'What we do not do',
        'We do not sell your data. We do not share it with advertisers or data '
            'brokers. We do not use your journal to train anything. There are '
            'no third-party analytics or advertising SDKs in this app.',
      ),
      (
        'Children',
        'InnenFlow is not intended for children under 13. If you believe a '
            'child has created an account, contact us and we will remove it.',
      ),
      (
        'Your rights',
        'You can view and edit your profile in the app, export or delete '
            'anything you wrote, and ask us to delete your account entirely. '
            'Deletion requests are completed within 30 days.',
      ),
      (
        'Changes',
        'If this policy changes in a way that affects what we do with your '
            'data, the app will tell you. Continuing to use it after that means '
            'you accept the change.',
      ),
    ],
  );

  static const terms = LegalDoc(
    title: 'Terms of Service',
    updated: updatedOn,
    summary:
        'InnenFlow is a journalling and wellbeing app. It is not medical '
        'treatment and it is not an emergency service. Be kind in the parts '
        'other people can see, and everything you write privately stays yours.',
    sections: [
      (
        'Not a medical service',
        'Nothing in this app — the journal, the analytics, the meditation '
            'timer, the counselling sessions — is medical care, a diagnosis, or '
            'a substitute for treatment by a qualified professional.\n\n'
            'If you are in danger or thinking about harming yourself, please '
            'contact emergency services or a crisis helpline immediately. In '
            'India: Tele-MANAS 14416, or KIRAN 1800-599-0019, both free and '
            'available 24 hours.',
      ),
      (
        'Counselling sessions',
        'A session is ${Counselling.sessionMinutes} minutes and costs '
            '₹${Counselling.fee}, paid by UPI before the session begins. Your '
            'payment is verified by a human, which usually takes a few minutes '
            'during working hours.\n\n'
            'If we cannot verify your payment, no session is opened and you can '
            'send the details again or contact us. If we cannot hold a session '
            'you have paid for, you get a refund.\n\n'
            'Sessions are conversations, not clinical treatment. See the note '
            'above.',
      ),
      (
        'Your account',
        'Keep your login details to yourself; you are responsible for what '
            'happens under your account. Give us real details when you book a '
            'counselling session — a wrong phone number means we cannot reach '
            'you if a call drops.',
      ),
      (
        'What you publish',
        'Articles, comments and anonymous reflections are visible to other '
            'people. You keep ownership of what you write, and you can delete '
            'your own posts at any time. By publishing you allow us to display '
            'it inside the app.\n\n'
            'Articles are checked before they go up. Until yours is approved '
            'only you and the InnenFlow team can read it, and we may send '
            'it back with a reason instead of publishing it. We do not edit '
            'what you wrote.\n\n'
            'Do not post anything unlawful, hateful, harassing, sexually '
            'explicit, or that impersonates someone else. Do not post other '
            'people\'s private information. We remove content that breaks this '
            'and may close accounts that keep doing it.',
      ),
      (
        'Free access period',
        'The app is currently free while it is being built out. If paid plans '
            'start later, you will be told in advance and nothing you already '
            'wrote is taken away.',
      ),
      (
        'Availability',
        'This is a small, actively developed app. Things will occasionally '
            'break, and features will change. We keep your data safe across '
            'those changes, but we cannot promise the service is never '
            'interrupted.',
      ),
      (
        'Ending it',
        'You can stop using the app and ask for your account to be deleted at '
            'any time. We may close an account that breaks these terms, and '
            'will say why.',
      ),
      (
        'Governing law',
        'These terms are governed by the laws of India, and disputes fall to '
            'the courts of Bihar.',
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/counselling.dart';
import '../../core/theme/app_theme.dart';
import '../../models/counselling_session.dart';
import '../../providers/auth_provider.dart';
import '../../services/counselling_service.dart';
import '../../widgets/sacred.dart';
import 'counselling_chat_view.dart';

/// The way in to counselling.
///
/// Decides for the member rather than asking them: if they have a session that
/// is still alive, it opens; if they do not, it takes the intake form. Someone
/// looking for help should not first have to work out which screen they need.
class CounsellingScreen extends StatefulWidget {
  const CounsellingScreen({super.key});

  @override
  State<CounsellingScreen> createState() => _CounsellingScreenState();
}

class _CounsellingScreenState extends State<CounsellingScreen> {
  final _service = CounsellingService();

  @override
  void initState() {
    super.initState();
    // Finished conversations past their two hours are destroyed on the way in,
    // from both sides of the room, so the promise holds without depending on a
    // deployed Cloud Function.
    _service.purgeExpired();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: StreamBuilder<List<CounsellingSession>>(
            stream: _service.streamMine(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary));
              }

              final sessions = (snap.data ?? const <CounsellingSession>[])
                  .where((s) => !s.isExpired)
                  .toList();
              final open = sessions
                  .where((s) => s.status != CounsellingStatus.ended)
                  .toList();

              if (open.isNotEmpty) {
                return CounsellingChatView(sessionId: open.first.id);
              }
              return _IntakeForm(
                service: _service,
                previous: sessions.isEmpty ? null : sessions.first,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── intake ───────────────────────────

/// Six questions and a button.
///
/// Everything asked here changes what the counsellor does in the first two
/// minutes. Anything that does not — address, occupation, marital status — is
/// left out, because a long form in front of someone in distress is a form
/// that does not get finished.
class _IntakeForm extends StatefulWidget {
  final CounsellingService service;
  final CounsellingSession? previous;

  const _IntakeForm({required this.service, this.previous});

  @override
  State<_IntakeForm> createState() => _IntakeFormState();
}

class _IntakeFormState extends State<_IntakeForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();

  String _gender = 'Prefer not to say';
  String _concern = Counselling.concerns.first;
  String _language = Counselling.languages.first;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _nameCtrl.text = profile?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.service.createSession(
        name: _nameCtrl.text.trim(),
        age: _ageCtrl.text.trim(),
        gender: _gender,
        phone: _phoneCtrl.text.trim(),
        concern: _concern,
        language: _language,
        details: _detailsCtrl.text.trim(),
      );
      // The stream above swaps this form for the chat on its own.
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open the session: $e',
                style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SacredAppBar(
          title: 'Talk to someone',
          subtitle: 'One-to-one, confidential',
          onBack: () => context.pop(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppTheme.space4, 0,
                AppTheme.space4, AppTheme.space8),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.space4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.22)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A ${Counselling.sessionMinutes}-minute session with a real person',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tell us a little about what is going on. Nothing here is '
                          'shared with anyone else, and the whole conversation is '
                          'deleted two hours after your session ends.',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12.5,
                              height: 1.55,
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  if (widget.previous != null) ...[
                    const SizedBox(height: AppTheme.space3),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space3),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.history_rounded,
                              size: 15, color: AppTheme.textMuted),
                          SizedBox(width: AppTheme.space2),
                          Expanded(
                            child: Text(
                              'Your last session ended. Its messages are being '
                              'deleted as promised.',
                              style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11.5,
                                  color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppTheme.space5),
                  _label('Your name'),
                  _field(
                    controller: _nameCtrl,
                    hint: 'What should we call you?',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please tell us your name'
                        : null,
                  ),
                  const SizedBox(height: AppTheme.space4),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Age'),
                            _field(
                              controller: _ageCtrl,
                              hint: 'e.g. 27',
                              keyboard: TextInputType.number,
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim());
                                if (n == null || n < 10 || n > 110) {
                                  return 'Enter a real age';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Gender'),
                            _dropdown(
                              value: _gender,
                              items: const [
                                'Female',
                                'Male',
                                'Other',
                                'Prefer not to say'
                              ],
                              onChanged: (v) => setState(() => _gender = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space4),

                  _label('Phone'),
                  _field(
                    controller: _phoneCtrl,
                    hint: 'So we can reach you if the call drops',
                    keyboard: TextInputType.phone,
                    validator: (v) {
                      final digits =
                          (v ?? '').replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 10) return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.space4),

                  _label('What is this mostly about?'),
                  _dropdown(
                    value: _concern,
                    items: Counselling.concerns,
                    onChanged: (v) => setState(() => _concern = v!),
                  ),
                  const SizedBox(height: AppTheme.space4),

                  _label('Which language are you most comfortable in?'),
                  _dropdown(
                    value: _language,
                    items: Counselling.languages,
                    onChanged: (v) => setState(() => _language = v!),
                  ),
                  const SizedBox(height: AppTheme.space4),

                  _label('Anything you want us to know first? (optional)'),
                  _field(
                    controller: _detailsCtrl,
                    hint: 'You can also say all of this in the chat.',
                    lines: 4,
                  ),
                  const SizedBox(height: AppTheme.space6),

                  SacredButton(
                    label: 'Start — ₹${Counselling.fee}',
                    icon: Icons.arrow_forward_rounded,
                    loading: _submitting,
                    onTap: _submitting ? null : _submit,
                  ),
                  const SizedBox(height: AppTheme.space3),
                  const Text(
                    'You pay after this, inside the chat. Nothing is charged now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11.5,
                        color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.space2),
        child: Text(
          text,
          style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    int lines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboard,
      maxLines: lines,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(
          fontFamily: 'Outfit', fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textMuted),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.bgCard,
          icon: const Icon(Icons.expand_more_rounded, color: AppTheme.textMuted),
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(i,
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            color: AppTheme.textPrimary)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────── helpers shared with the admin side ───────────

/// Opens a UPI app with the amount and payee already filled in.
Future<void> openUpiApp(BuildContext context) async {
  final uri = Uri.parse(Counselling.upiIntent());
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw 'no UPI app';
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No UPI app found. Scan the QR, or pay the ID by hand.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }
}

Future<void> copyUpiId(BuildContext context) async {
  await Clipboard.setData(const ClipboardData(text: Counselling.upiId));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('UPI ID copied.', style: TextStyle(fontFamily: 'Outfit')),
        backgroundColor: AppTheme.success,
      ),
    );
  }
}

/// Opens the room issued for this session.
///
/// Takes the link rather than reading a constant: each session gets its own
/// room, so there is no app-wide meeting link to fall back on any more.
Future<void> openMeet(BuildContext context, String link) async {
  if (link.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No link yet — your counsellor is confirming the time.',
            style: TextStyle(fontFamily: 'Outfit')),
        backgroundColor: AppTheme.accent,
      ),
    );
    return;
  }
  final uri = Uri.parse(link.trim());
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw 'could not open';
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the meeting link.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }
}

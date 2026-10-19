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

class CounsellingScreen extends StatefulWidget {
  const CounsellingScreen({super.key, this.service});
  final CounsellingService? service;
  @override
  State<CounsellingScreen> createState() => _CounsellingScreenState();
}

class _CounsellingScreenState extends State<CounsellingScreen> {
  late final _service = widget.service ?? CounsellingService();
  late final _sessions = _service.streamMine();
  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SacredBackdrop(
            child: SafeArea(
          child: StreamBuilder<List<CounsellingSession>>(
            stream: _sessions,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Could not load your requests. Please try again.'),
                  TextButton(
                      onPressed: () => _service.refresh(),
                      child: const Text('Retry')),
                  TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Back')),
                ]));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final open = snap.data!.where((s) =>
                  !s.isExpired &&
                  s.status != CounsellingStatus.ended &&
                  s.status != CounsellingStatus.rejected);
              if (open.isNotEmpty) {
                return CounsellingChatView(sessionId: open.first.id);
              }
              return CounsellingIntakeForm(
                service: _service,
                initialName:
                    context.read<AuthProvider>().profile?.displayName ?? '',
              );
            },
          ),
        )),
      );
}

/// A short support request, kept separate from its session feed so drafts stay
/// intact when the network retries or a notification refreshes the screen.
class CounsellingIntakeForm extends StatefulWidget {
  final CounsellingService service;
  final String initialName;
  const CounsellingIntakeForm(
      {super.key, required this.service, this.initialName = ''});
  @override
  State<CounsellingIntakeForm> createState() => _CounsellingIntakeFormState();
}

class _CounsellingIntakeFormState extends State<CounsellingIntakeForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _details = TextEditingController();
  final _concernField = GlobalKey<FormFieldState<List<String>>>();
  List<String> _concerns = [];
  String _language = 'Hinglish';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName;
  }

  @override
  void dispose() {
    _name.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _chooseConcerns() async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.bgCard,
      builder: (_) => _ConcernPicker(selected: _concerns),
    );
    if (selected == null || !mounted) return;
    setState(() => _concerns = selected);
    _concernField.currentState?.didChange(selected);
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await widget.service.createSession(
          name: _name.text.trim(),
          age: '',
          gender: '',
          phone: '',
          concern: _concerns.join('; '),
          language: _language,
          details: _details.text.trim());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not send your request. Your writing is still here; please retry.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        SacredAppBar(
            title: 'Talk to someone',
            subtitle: 'A little support, at your pace',
            onBack: () => context.pop()),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                    key: _form,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(24)),
                              child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.forum_outlined,
                                        color: AppTheme.primaryLight, size: 32),
                                    SizedBox(height: 12),
                                    Text('Start with what matters to you.',
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2)),
                                    SizedBox(height: 10),
                                    Text(
                                        'Choose a topic, share a little, and request a private chat. No payment needed.',
                                        style: TextStyle(
                                            height: 1.5, fontSize: 15)),
                                  ])),
                          const SizedBox(height: 24),
                          TextFormField(
                              controller: _name,
                              maxLength: 80,
                              enabled: !_busy,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                  labelText:
                                      'What should we call you? (optional)')),
                          const SizedBox(height: 12),
                          FormField<List<String>>(
                            key: _concernField,
                            initialValue: _concerns,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Choose a topic, or select Other / not sure.'
                                : null,
                            builder: (field) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('What is on your mind?',
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  const Text(
                                      'Choose up to 3. You do not need a diagnosis.',
                                      style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          height: 1.4)),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    key: const ValueKey('choose-concerns'),
                                    onPressed: _busy ? null : _chooseConcerns,
                                    style: OutlinedButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16)),
                                    icon: const Icon(Icons.tune_rounded),
                                    label: Text(_concerns.isEmpty
                                        ? 'Choose topics'
                                        : 'Change topics (${_concerns.length})'),
                                  ),
                                  if (_concerns.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _concerns
                                            .map((c) => Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                      color: AppTheme.primary
                                                          .withValues(
                                                              alpha: .15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              14)),
                                                  child: Text(c,
                                                      style: const TextStyle(
                                                          color: AppTheme
                                                              .primaryLight,
                                                          height: 1.3)),
                                                ))
                                            .toList()),
                                  ],
                                  if (field.hasError)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(field.errorText!,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error))),
                                ]),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                              controller: _details,
                              minLines: 3,
                              maxLines: 6,
                              maxLength: 2000,
                              enabled: !_busy,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                  labelText:
                                      'What would you like support with?',
                                  hintText:
                                      'Jo comfortable lage, utna likho. What has been difficult lately?',
                                  alignLabelWithHint: true),
                              validator: (s) => (s ?? '').trim().length < 10
                                  ? 'Write a little more so we can understand.'
                                  : null),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                              initialValue: _language,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Preferred language'),
                              items: Counselling.languages
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s)))
                                  .toList(),
                              onChanged: _busy
                                  ? null
                                  : (v) => setState(() => _language = v!)),
                          const SizedBox(height: 24),
                          SacredButton(
                              label: 'Request a conversation',
                              icon: Icons.send_rounded,
                              loading: _busy,
                              onTap: _busy ? null : _submit),
                          const SizedBox(height: 16),
                          const Text(
                              'An admin reviews your request. We will notify you when your chat opens; timing depends on availability. This chat offers support, not a diagnosis or medication advice.',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  height: 1.5,
                                  fontSize: 14)),
                          const SizedBox(height: 12),
                          const Text(
                              'Not an emergency service. If you are in immediate danger, contact local emergency services. If you are under 18, involve a trusted adult when seeking support.',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  height: 1.5,
                                  fontSize: 13)),
                          const SizedBox(height: 32),
                        ])))),
      ]);
}

class _ConcernPicker extends StatefulWidget {
  const _ConcernPicker({required this.selected});
  final List<String> selected;
  @override
  State<_ConcernPicker> createState() => _ConcernPickerState();
}

class _ConcernPickerState extends State<_ConcernPicker> {
  late final _selected = widget.selected.toSet();
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final choices = Counselling.concerns
        .where((c) => c.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
                child: Row(children: [
                  const Expanded(
                      child: Text('What is on your mind?',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w600))),
                  IconButton(
                      tooltip: 'Close topics',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ])),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: TextField(
                  key: const ValueKey('search-concerns'),
                  decoration: const InputDecoration(
                      hintText: 'Search topics',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (value) => setState(() => _query = value.trim()),
                )),
            Expanded(
                child: choices.isEmpty
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                                'No matching topic. Try another word, or choose Other / not sure.',
                                textAlign: TextAlign.center)))
                    : ListView.builder(
                        itemCount: choices.length,
                        itemBuilder: (_, i) {
                          final concern = choices[i];
                          final chosen = _selected.contains(concern);
                          return CheckboxListTile(
                            value: chosen,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(concern,
                                style: const TextStyle(
                                    fontSize: 15, height: 1.35)),
                            onChanged: !chosen &&
                                    _selected.length >= Counselling.maxConcerns
                                ? null
                                : (checked) => setState(() {
                                      if (checked == true) {
                                        _selected.add(concern);
                                      } else {
                                        _selected.remove(concern);
                                      }
                                    }),
                          );
                        })),
            Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                          context,
                          Counselling.concerns
                              .where(_selected.contains)
                              .toList()),
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                              'Done · ${_selected.length}/${Counselling.maxConcerns} selected')),
                    ))),
          ])),
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
          content: Text('No UPI app found. Scan the QR, or pay the ID by hand.',
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/quick_reset.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../services/journal_service.dart';
import '../../widgets/sacred.dart';

/// A useful first session that works without sign-in or a network connection.
class QuickResetScreen extends StatefulWidget {
  final JournalService? journalService;
  const QuickResetScreen({super.key, this.journalService});
  @override
  State<QuickResetScreen> createState() => _QuickResetScreenState();
}

class _QuickResetScreenState extends State<QuickResetScreen> {
  late final QuickReset _draft;
  late final TextEditingController _thought;
  late final TextEditingController _nextStep;
  int _step = 0;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().user?.uid;
    final pending = QuickReset.pending;
    _draft =
        pending != null && (pending.ownerUid == null || pending.ownerUid == uid)
            ? pending
            : QuickReset();
    _draft.ownerUid ??= uid;
    QuickReset.pending = _draft;
    _thought = TextEditingController(text: _draft.thought);
    _nextStep = TextEditingController(text: _draft.nextStep);
    if (_draft.completed) _step = 2;
  }

  @override
  void dispose() {
    _thought.dispose();
    _nextStep.dispose();
    super.dispose();
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    _draft.thought = _thought.text;
    _draft.nextStep = _nextStep.text;
    setState(() {
      _step++;
      if (_step == 2) _draft.completed = true;
    });
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      context.push('/login');
      return;
    }
    final journal = context.read<JournalProvider>();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Read the current record before merging; a cold dashboard can still be loading.
      final existing = await (widget.journalService ?? JournalService())
          .getTodaysEntry(user.uid);
      if (!mounted || auth.user?.uid != user.uid) return;
      await journal.saveEntry(_draft.toEntry(uid: user.uid, existing: existing),
          existingId: existing?.id);
      if (!mounted || auth.user?.uid != user.uid) return;
      QuickReset.pending = null;
      setState(() => _saved = true);
      await auth.refreshProfile();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not save. Your reset is still here. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final signedIn = auth.isAuthenticated;
    if (_draft.ownerUid != null && _draft.ownerUid != auth.user?.uid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your reset')),
        body: SafeArea(child: Padding(padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Your sign-in changed.', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            const Text('Your previous reset is no longer displayed. You can start a new one.'),
            const SizedBox(height: 24),
            SacredButton(label: 'Back to start', onTap: () => context.go(signedIn ? '/dashboard' : '/welcome')),
          ]))),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Your 2-minute reset')),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_step < 2) ...[
              Text('STEP ${_step + 1} OF 2',
                  style: const TextStyle(
                      color: AppTheme.primaryLight, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                  value: (_step + 1) / 2, semanticsLabel: 'Reset progress'),
              const SizedBox(height: 24),
            ],
            if (_step == 0) ...[
              const Text('A lot on your mind?',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text(
                  'Start with how you feel. You do not need to explain everything.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 20),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (i, label)
                    in ['Very low', 'Low', 'Okay', 'Good', 'Great'].indexed)
                  ChoiceChip(
                      label: Text(label),
                      selected: _draft.mood == i + 1,
                      onSelected: (_) => setState(() => _draft.mood = i + 1)),
              ]),
              const SizedBox(height: 24),
              const Text('What is taking up space?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final topic in QuickReset.topics)
                  ChoiceChip(
                      label: Text(topic),
                      selected: _draft.topic == topic,
                      onSelected: (_) => setState(() => _draft.topic = topic)),
              ]),
              const SizedBox(height: 28),
              SacredButton(
                  label: 'Choose one next step',
                  onTap: _draft.mood == null || _draft.topic.isEmpty
                      ? null
                      : _continue),
            ],
            if (_step == 1) ...[
              const Text('Give it a little space.',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text(
                  'You can leave the details blank. One small next step is enough.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 20),
              TextField(
                  controller: _thought,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                      labelText: 'What is on your mind? (optional)',
                      alignLabelWithHint: true)),
              const SizedBox(height: 16),
              const Text('What feels manageable?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final suggestion in QuickReset.suggestions[_draft.topic]!)
                  ActionChip(
                      label: Text(suggestion),
                      onPressed: () =>
                          setState(() => _nextStep.text = suggestion)),
              ]),
              const SizedBox(height: 16),
              TextField(
                  controller: _nextStep,
                  maxLength: 200,
                  minLines: 1,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'My next step')),
              const SizedBox(height: 20),
              SacredButton(
                  label: 'Finish my reset',
                  onTap: _nextStep.text.trim().isEmpty ? null : _continue),
              TextButton(
                  onPressed: () => setState(() => _step = 0),
                  child: const Text('Back')),
            ],
            if (_step == 2) ...[
              Icon(_saved ? Icons.check_circle_outline : Icons.wb_twilight,
                  size: 48, color: AppTheme.primaryLight),
              const SizedBox(height: 20),
              Text(_saved ? 'Your reset is saved.' : 'One thing at a time.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              const Text('YOUR NEXT STEP',
                  style:
                      TextStyle(letterSpacing: 1.5, color: AppTheme.textMuted)),
              const SizedBox(height: 12),
              Text(_draft.nextStep,
                  style: const TextStyle(fontSize: 22, height: 1.4)),
              const SizedBox(height: 20),
              const Text(
                  'You do not have to solve everything tonight. Come back whenever a short pause would help.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppTheme.danger)),
              ],
              const SizedBox(height: 28),
              if (!_saved)
                SacredButton(
                    label: signedIn
                        ? 'Save to my journal'
                        : 'Sign in to save my reset',
                    loading: _saving,
                    onTap: _save),
              if (!signedIn) ...[
                const SizedBox(height: 12),
                const Text(
                    'No account was needed to try this. Unsaved words stay in this app session only.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textMuted, fontSize: 12, height: 1.5)),
              ],
              TextButton(
                  onPressed: _saving
                      ? null
                      : () => context.go(signedIn ? '/dashboard' : '/welcome'),
                  child: Text(_saved ? 'Back to today' : 'Keep exploring')),
              if (!_saved)
                TextButton(
                    onPressed: _saving ? null : () => setState(() => _step = 1),
                    child: const Text('Edit my next step')),
              if (_saved)
                TextButton(
                    onPressed: () {
                      QuickReset.pending = null;
                      context.push('/journal');
                    },
                    child: const Text('Open my journal')),
            ],
          ]),
        ),
      ))),
    );
  }
}

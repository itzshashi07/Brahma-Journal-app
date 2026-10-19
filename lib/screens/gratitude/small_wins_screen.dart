import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../services/small_wins_service.dart';
import '../../services/dictation_service.dart';
import '../../widgets/voice_input_button.dart';
import '../../widgets/sacred.dart';
import '../../widgets/retry_notice.dart';

class SmallWinsScreen extends StatefulWidget {
  const SmallWinsScreen({super.key, this.service});
  final SmallWinsService? service;
  @override
  State<SmallWinsScreen> createState() => _SmallWinsScreenState();
}

class _SmallWinsScreenState extends State<SmallWinsScreen> {
  late final _service = widget.service ?? SmallWinsService();
  final _gratitude = TextEditingController();
  final _win = TextEditingController();
  final _next = TextEditingController();
  // Keep this draft attached to its displayed day even across midnight.
  late final _day = DateFormat('yyyy-MM-dd').format(DateTime.now());
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true, _saving = false, _finishingSave = false;
  String? _error;
  String? _voiceLanguage;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gratitude.dispose();
    _win.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _service.load();
      if (!mounted) return;
      final today = entries.where((e) => e['day'] == _day).firstOrNull;
      _gratitude.text = today?['gratitude'] ?? '';
      _win.text = today?['smallWin'] ?? '';
      _next.text = today?['nextStep'] ?? '';
      setState(() => _entries = entries);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not load your small wins. Please retry before writing.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _finishingSave) return;
    _finishingSave = true;
    try {
      await DictationService.shared.finishActive();
    } finally {
      _finishingSave = false;
    }
    if (!mounted) return;
    if (_gratitude.text.trim().isEmpty && _win.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'One small thing is enough. Add something you appreciate or a small win.')));
      return;
    }
    setState(() => _saving = true);
    final entry = {
      'day': _day,
      'gratitude': _gratitude.text.trim(),
      'smallWin': _win.text.trim(),
      'nextStep': _next.text.trim()
    };
    try {
      await _service.save(
          day: _day,
          gratitude: entry['gratitude']!,
          smallWin: entry['smallWin']!,
          nextStep: entry['nextStep']!);
      if (!mounted) return;
      setState(
          () => _entries = [entry, ..._entries.where((e) => e['day'] != _day)]);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saved privately. Small things count.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not save. Your words are still here; please retry.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String title, String hint, TextEditingController controller,
          int max) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: TextField(
              controller: controller,
              readOnly: _saving,
              minLines: 2,
              maxLines: 5,
              maxLength: max,
              decoration: InputDecoration(
                  labelText: title,
                  hintText: hint,
                  alignLabelWithHint: true,
                  suffixIcon: VoiceInputButton(
                    controller: controller,
                    fieldLabel: title,
                    languageCode: _voiceLanguage,
                    maxLength: max,
                    enabled: !_saving,
                  ))));
  @override
  Widget build(BuildContext context) => Scaffold(
          body: SacredBackdrop(
              child: SafeArea(
                  child: Column(children: [
        SacredAppBar(
            title: 'Gratitude & Small Wins',
            subtitle: 'Notice what quietly went right',
            onBack: () => context.pop()),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child:
                                RetryNotice(message: _error!, onRetry: _load)))
                    : ListView(padding: const EdgeInsets.all(20), children: [
                        Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Color(0xFF193C3B),
                                  Color(0xFF20203C)
                                ]),
                                borderRadius: BorderRadius.circular(24)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.wb_sunny_outlined,
                                      color: Color(0xFFE7CDA5), size: 32),
                                  const SizedBox(height: 16),
                                  const Text(
                                      'Not a perfect day.\nStill, something mattered.',
                                      style: TextStyle(
                                          fontSize: 27,
                                          height: 1.2,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 12),
                                  Text(
                                      DateFormat('EEEE, d MMMM')
                                          .format(DateTime.parse(_day)),
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary)),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'A kind message. Getting out of bed. Asking for help. Your small win gets to be small.',
                                      style: TextStyle(height: 1.5)),
                                ])),
                        const SizedBox(height: 24),
                        const Text('Type it, or say it',
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text(
                            'Tap a field’s mic and speak a short sentence. Review the words before saving.',
                            style: TextStyle(
                                color: AppTheme.textSecondary, height: 1.5)),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _voiceLanguage ?? 'default',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Voice language',
                            prefixIcon: Icon(Icons.translate_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'default', child: Text('Phone default')),
                            DropdownMenuItem(
                                value: 'hi', child: Text('Hindi · हिन्दी')),
                            DropdownMenuItem(
                                value: 'en', child: Text('English')),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) => setState(() {
                                    _voiceLanguage =
                                        value == 'default' ? null : value;
                                  }),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                            'Voice typing uses your phone’s speech service and may need internet. InnenFlow saves only the text you choose to keep.',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                height: 1.5)),
                        const SizedBox(height: 24),
                        _field(
                            'Something I appreciate',
                            'A person, a moment, or something ordinary…',
                            _gratitude,
                            1500),
                        _field('One small win', 'Aaj ka chhota sa win kya tha?',
                            _win, 1500),
                        _field(
                            'One gentle next step (optional)',
                            'Something kind and doable for tomorrow…',
                            _next,
                            500),
                        SacredButton(
                            label: 'Keep this moment',
                            icon: Icons.bookmark_border_rounded,
                            loading: _saving,
                            onTap: _saving ? null : _save),
                        const SizedBox(height: 12),
                        const Text(
                            'Private to your account. No scores, no perfect-day streak to keep.',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13),
                            textAlign: TextAlign.center),
                        if (_entries.any((e) => e['day'] != _day)) ...[
                          const SizedBox(height: 32),
                          const Text('Little things, remembered',
                              style: TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          for (final e
                              in _entries.where((e) => e['day'] != _day))
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(e['day'] ?? '',
                                              style: const TextStyle(
                                                  color:
                                                      AppTheme.primaryLight)),
                                          const SizedBox(height: 8),
                                          if ((e['gratitude'] ?? '').isNotEmpty)
                                            Text(
                                                'Grateful for: ${e['gratitude']}',
                                                style: const TextStyle(
                                                    height: 1.5)),
                                          if ((e['smallWin'] ?? '').isNotEmpty)
                                            Text('Small win: ${e['smallWin']}',
                                                style: const TextStyle(
                                                    height: 1.5)),
                                        ]))),
                        ],
                        const SizedBox(height: 32),
                      ])),
      ]))));
}

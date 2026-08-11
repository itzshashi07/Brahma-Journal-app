import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../services/account_deletion_service.dart';
import '../../widgets/sacred.dart';

/// Closing the account, for good.
///
/// Google Play requires this route to exist, but the shape of it is a judgement
/// call and this one is deliberate: **say exactly what disappears, then make
/// them type the word.**
///
/// Not a checkbox and not a two-button dialog. Someone reaches this screen in
/// one of two states — genuinely done, or upset and looking for a lever to
/// pull — and typing DELETE is enough friction to separate them without being
/// enough to trap the first person. Everything here is unrecoverable; there is
/// no soft-delete, no thirty-day grace period, and saying so up front is more
/// honest than discovering it afterwards.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _service = AccountDeletionService();
  final _confirmCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _working = false;
  bool _needsPassword = false;
  String? _error;

  static const _phrase = 'DELETE';

  @override
  void initState() {
    super.initState();
    _confirmCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _confirmed =>
      _confirmCtrl.text.trim().toUpperCase() == _phrase;

  Future<void> _delete() async {
    if (!_confirmed || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });

    // Firebase refuses to delete an account whose sign-in is old. Re-verify
    // first when we already know it will be needed, so the member is not sent
    // round the loop after watching a progress spinner.
    if (_needsPassword) {
      final failure =
          await _service.reauthenticateWithPassword(_passwordCtrl.text);
      if (failure != null) {
        if (!mounted) return;
        setState(() {
          _working = false;
          _error = failure;
        });
        return;
      }
    }

    final result = await _service.deleteEverything();
    if (!mounted) return;

    if (result == 'needs-reauth') {
      setState(() {
        _working = false;
        _needsPassword = _service.canReauthenticateInPlace;
        _error = _service.canReauthenticateInPlace
            ? 'For your security, confirm your password to finish.'
            : 'For your security, please sign out and sign in again, then '
                'come back here.';
      });
      return;
    }

    if (result != null) {
      setState(() {
        _working = false;
        _error = result;
      });
      return;
    }

    // Gone. Clear the in-memory journal so nothing is left rendered behind the
    // welcome screen, and send them out.
    context.read<JournalProvider>().clear();
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: 'Delete account',
                subtitle: 'This cannot be undone',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.space5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What gets deleted',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: AppTheme.space3),
                      const _Bullet('Every journal entry and daily check-in'),
                      const _Bullet('Your profile, streak and leaderboard place'),
                      const _Bullet('Meditation, focus and game history'),
                      const _Bullet('Your reflections on the anonymous board'),
                      const _Bullet('Any counselling session and its transcript'),
                      const _Bullet('Articles you published, and your comments'),
                      const _Bullet('The account itself — the email can be reused'),

                      const SizedBox(height: AppTheme.space4),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.space3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Text(
                          'Replies you left on other people\'s reflections stay '
                          'where they are. They carry no name and no link to '
                          'you, and pulling them out would break somebody '
                          'else\'s conversation months after the fact.',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              height: 1.5,
                              color: AppTheme.textMuted),
                        ),
                      ),

                      const SizedBox(height: AppTheme.space5),
                      const Text(
                        'There is no undo. No grace period, no archived copy, '
                        'nothing to restore from.',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFCA5A5)),
                      ),

                      const SizedBox(height: AppTheme.space5),
                      const Text(
                        'Type DELETE to confirm',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: AppTheme.space2),
                      TextField(
                        controller: _confirmCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 15,
                            letterSpacing: 2,
                            color: AppTheme.textPrimary),
                        decoration: _fieldDecoration('DELETE'),
                      ),

                      if (_needsPassword) ...[
                        const SizedBox(height: AppTheme.space4),
                        const Text(
                          'Confirm your password',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: AppTheme.space2),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 15,
                              color: AppTheme.textPrimary),
                          decoration: _fieldDecoration('Your password'),
                        ),
                      ],

                      if (_error != null) ...[
                        const SizedBox(height: AppTheme.space4),
                        Container(
                          padding: const EdgeInsets.all(AppTheme.space3),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.10),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(
                                color: AppTheme.danger.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12.5,
                                height: 1.45,
                                color: Color(0xFFFCA5A5)),
                          ),
                        ),
                      ],

                      const SizedBox(height: AppTheme.space5),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _confirmed && !_working ? _delete : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                            disabledBackgroundColor:
                                AppTheme.danger.withValues(alpha: 0.25),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                          child: _working
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Delete my account permanently',
                                  style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space3),
                      Center(
                        child: TextButton(
                          onPressed:
                              _working ? null : () => context.pop(),
                          child: const Text('Keep my account',
                              style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  color: AppTheme.textSecondary)),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space5),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'Outfit', fontSize: 14, color: AppTheme.textMuted),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
      );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.remove_rounded,
                size: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(width: AppTheme.space2),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

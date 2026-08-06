import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';

/// Password reset request.
///
/// Deliberately shows the same confirmation whether or not the address has an
/// account. A screen that says "no account found" is an account enumeration
/// oracle — it lets anyone check which of a list of emails is registered here,
/// which is the reconnaissance step before credential stuffing.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);

    final ok = await context.read<AuthProvider>().sendPasswordReset(
          _emailCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: 'Reset password',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space6, vertical: AppTheme.space4),
                  child: _sent ? _sentView() : _formView(auth),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formView(AuthProvider auth) {
    return Column(
      children: [
        const SizedBox(height: AppTheme.space6),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withValues(alpha: 0.12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
          ),
          child: const Icon(Icons.lock_reset_rounded,
              size: 38, color: AppTheme.primaryLight),
        ),
        const SizedBox(height: AppTheme.space5),
        const Text(
          'Forgotten your password?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.space2),
        const Text(
          'Enter the email you signed up with and we will send you a link to set a new one.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            height: 1.5,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        GlassCard(
          padding: const EdgeInsets.all(AppTheme.space5),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  style: const TextStyle(
                      fontFamily: 'Outfit', color: AppTheme.textPrimary),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your email';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.alternate_email_rounded,
                        size: 20, color: AppTheme.textMuted),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: AppTheme.space3),
                  Text(
                    auth.error!,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.5,
                        color: Color(0xFFFCA5A5)),
                  ),
                ],
                const SizedBox(height: AppTheme.space5),
                SacredButton(
                  label: 'Send reset link',
                  icon: Icons.send_rounded,
                  loading: _sending,
                  onTap: _send,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sentView() {
    return Column(
      children: [
        const SizedBox(height: AppTheme.space10),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.success.withValues(alpha: 0.12),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              size: 40, color: AppTheme.success),
        ),
        const SizedBox(height: AppTheme.space6),
        const Text(
          'Check your inbox',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        Text(
          'If an account exists for ${_emailCtrl.text.trim()}, a reset link is on its way. '
          'It can take a minute to arrive — remember to look in spam.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            height: 1.55,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        SacredButton(
          label: 'Back to sign in',
          icon: Icons.arrow_back_rounded,
          onTap: () => context.pop(),
        ),
        const SizedBox(height: AppTheme.space3),
        TextButton(
          onPressed: () => setState(() => _sent = false),
          child: const Text(
            'Use a different email',
            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}

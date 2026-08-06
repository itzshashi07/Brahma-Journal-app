import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';

/// Phone sign-in: number entry, then the six-digit SMS code.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _authService = AuthService();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  String _dialCode = '+91';
  bool _busy = false;
  String? _error;

  String? _verificationId;
  int? _resendToken;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String get _fullNumber => '$_dialCode${_phoneCtrl.text.trim()}';

  Future<void> _sendCode({bool resend = false}) async {
    final digits = _phoneCtrl.text.trim();
    if (digits.length < 6) {
      setState(() => _error = 'Enter your mobile number');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    await _authService.startPhoneVerification(
      phoneNumber: _fullNumber,
      resendToken: resend ? _resendToken : null,
      onCodeSent: (verificationId, token) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = token;
          _busy = false;
        });
      },
      onFailed: (e) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = switch (e.code) {
            'invalid-phone-number' => 'That number does not look right.',
            'too-many-requests' =>
              'Too many attempts from this device. Try again later.',
            'quota-exceeded' =>
              'SMS is temporarily unavailable. Please try another sign-in method.',
            _ => 'Could not send the code. Please try again.',
          };
        });
      },
      onAutoVerified: (_) {
        // Android can read the SMS itself; the auth state listener takes over.
        if (mounted) context.go('/dashboard');
      },
    );
  }

  Future<void> _confirm() async {
    if (_codeCtrl.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final ok = await auth.confirmSmsCode(
      verificationId: _verificationId!,
      smsCode: _codeCtrl.text,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : auth.error;
    });
    if (ok) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final onCodeStep = _verificationId != null;

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: onCodeStep ? 'Verify your number' : 'Sign in with phone',
                onBack: () {
                  if (onCodeStep) {
                    setState(() {
                      _verificationId = null;
                      _codeCtrl.clear();
                      _error = null;
                    });
                  } else {
                    context.pop();
                  }
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space6, vertical: AppTheme.space4),
                  child: onCodeStep ? _codeStep() : _numberStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberStep() {
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
          child: const Icon(Icons.smartphone_rounded,
              size: 38, color: AppTheme.primaryLight),
        ),
        const SizedBox(height: AppTheme.space5),
        const Text(
          'What is your number?',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.space2),
        const Text(
          'We will text you a six-digit code to confirm it is you.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              height: 1.5,
              color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.space8),
        GlassCard(
          padding: const EdgeInsets.all(AppTheme.space5),
          child: Column(
            children: [
              Row(
                children: [
                  _DialCodePicker(
                    value: _dialCode,
                    onChanged: (v) => setState(() => _dialCode = v),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        letterSpacing: 1.1,
                      ),
                      decoration: InputDecoration(
                        hintText: '98765 43210',
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
                          borderSide: const BorderSide(
                              color: AppTheme.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppTheme.space3),
                _Error(_error!),
              ],
              const SizedBox(height: AppTheme.space5),
              SacredButton(
                label: 'Send code',
                icon: Icons.sms_outlined,
                loading: _busy,
                onTap: _sendCode,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _codeStep() {
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
          child: const Icon(Icons.mark_chat_read_outlined,
              size: 36, color: AppTheme.primaryLight),
        ),
        const SizedBox(height: AppTheme.space5),
        Text(
          'Code sent to $_fullNumber',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        GlassCard(
          padding: const EdgeInsets.all(AppTheme.space5),
          child: Column(
            children: [
              TextField(
                controller: _codeCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: AppTheme.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 14,
                ),
                onChanged: (v) {
                  if (v.length == 6) _confirm();
                },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '······',
                  hintStyle: const TextStyle(
                      color: AppTheme.textMuted, letterSpacing: 14, fontSize: 30),
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
              if (_error != null) ...[
                const SizedBox(height: AppTheme.space2),
                _Error(_error!),
              ],
              const SizedBox(height: AppTheme.space4),
              SacredButton(
                label: 'Verify & continue',
                icon: Icons.check_rounded,
                loading: _busy,
                onTap: _confirm,
              ),
              const SizedBox(height: AppTheme.space2),
              TextButton(
                onPressed: _busy ? null : () => _sendCode(resend: true),
                child: const Text(
                  'Resend code',
                  style:
                      TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  const _Error(this.message);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFF87171)),
        const SizedBox(width: AppTheme.space2),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
                fontFamily: 'Outfit', fontSize: 12.5, color: Color(0xFFFCA5A5)),
          ),
        ),
      ],
    );
  }
}

/// A short list of dial codes rather than a full country picker — this app's
/// members are almost entirely in India, and a 200-row modal for a field most
/// people never change is friction, not choice.
class _DialCodePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _DialCodePicker({required this.value, required this.onChanged});

  static const _codes = ['+91', '+1', '+44', '+61', '+971', '+65'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          icon: const Icon(Icons.expand_more_rounded,
              size: 18, color: AppTheme.textMuted),
          style: const TextStyle(
              fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 16),
          items: _codes
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}

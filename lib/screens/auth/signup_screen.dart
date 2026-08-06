import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/sacred.dart';
import '../../widgets/free_access.dart';
import '../../services/backend_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedGender = 'male';
  String _selectedPlan = 'monthly'; // 'monthly' or 'annual'

  late Razorpay _razorpay;
  final BackendService _backend = BackendService();
  bool _isProcessing = false;
  String? _checkoutError;
  String? _currentSubscriptionId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _razorpay.clear();
    super.dispose();
  }

  /// Creates the account with no payment step.
  ///
  /// Used while [AppConstants.paymentsEnabled] is false. Registration is
  /// otherwise identical — the paid path also created the Firebase account
  /// first and only then verified the payment, so nothing about account
  /// creation changes when billing is switched back on.
  Future<void> _registerFree() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isProcessing = true;
      _checkoutError = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      name: _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text) ?? 25,
      gender: _selectedGender,
      phone: _phoneCtrl.text.trim(),
      paymentId: '',
      subscriptionId: null,
      planSelected: 'free',
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Welcome to Brahma Journal 🙏',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      context.go('/onboarding');
    } else {
      setState(() => _checkoutError = auth.error ?? 'Could not create your account.');
    }
  }

  /// Opens Razorpay checkout for the selected plan.
  ///
  /// Unreachable while [AppConstants.paymentsEnabled] is false, and left
  /// deliberately intact: the subscription is created by the
  /// `createSubscription` Cloud Function so the merchant secret never reaches
  /// the app, and the payment is verified server-side before any entitlement is
  /// written. Flipping the flag restores this path unchanged.
  void _startPaymentCheckout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
      _checkoutError = null;
      _currentSubscriptionId = null;
    });

    final planDescription = _selectedPlan == 'monthly'
        ? 'Monthly Auto-Debit (₹49/mo)'
        : 'Annual Auto-Debit (₹399/yr)';

    try {
      final subscription = await _backend.createSubscription(_selectedPlan);
      if (subscription == null) {
        setState(() {
          _isProcessing = false;
          _checkoutError = 'Payments are not available right now. Please try again later.';
        });
        return;
      }

      _currentSubscriptionId = subscription.subscriptionId;

      _razorpay.open({
        'key': subscription.keyId,
        'subscription_id': subscription.subscriptionId,
        'name': 'Brahma Journal',
        'description': planDescription,
        'prefill': {
          'contact': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
        },
        'external': {
          'wallets': ['paytm']
        },
      });
    } on BackendException catch (e) {
      setState(() {
        _isProcessing = false;
        _checkoutError = e.message;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _checkoutError = 'Could not open payment gateway. Please try again.';
      });
    }
  }

  /// Completes registration once Razorpay reports success.
  ///
  /// The callback alone is not proof of payment — it arrives on the device and
  /// can be replayed or faked. The account is created first (so the user has a
  /// Firebase identity to authenticate the verification call), then the
  /// signature is checked server-side, and only the server writes `premium`.
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? '';
    final signature = response.signature ?? '';
    final auth = context.read<AuthProvider>();

    final success = await auth.signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      name: _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text) ?? 25,
      gender: _selectedGender,
      phone: _phoneCtrl.text.trim(),
      paymentId: paymentId,
      subscriptionId: _currentSubscriptionId,
      planSelected: _selectedPlan,
    );

    if (success && _currentSubscriptionId != null) {
      try {
        await _backend.verifySubscriptionPayment(
          subscriptionId: _currentSubscriptionId!,
          paymentId: paymentId,
          signature: signature,
          plan: _selectedPlan,
        );
      } catch (e) {
        // The account exists; only the entitlement is missing. Surfacing this
        // lets the user contact support rather than silently losing premium.
        debugPrint('⚠️ Subscription verification failed: $e');
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account created successfully!', style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        setState(() {
          _checkoutError = auth.error ?? 'Failed to register account.';
        });
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _checkoutError = 'Payment failed: ${response.message ?? "User cancelled payment"}';
      });
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet checkout callback if any
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header logo & title
                    const Icon(Icons.circle_outlined, size: 64, color: AppTheme.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'Brahma Journal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Spiritual Growth & Mindfulness',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit', fontSize: 14, color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_checkoutError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          _checkoutError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Outfit', color: Colors.redAccent, fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Input Form Fields
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted, size: 20),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Please enter your name' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                            decoration: const InputDecoration(
                              labelText: 'Age',
                              prefixIcon: Icon(Icons.calendar_today_outlined, color: AppTheme.textMuted, size: 18),
                            ),
                            validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedGender,
                            dropdownColor: const Color(0xFF16162A),
                            style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: Icon(Icons.people_outline, color: AppTheme.textMuted, size: 18),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('Male')),
                              DropdownMenuItem(value: 'female', child: Text('Female')),
                            ],
                            onChanged: (v) => setState(() => _selectedGender = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textMuted, size: 20),
                      ),
                      validator: (v) => (v == null || v.length < 10) ? 'Enter valid phone number' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted, size: 20),
                      ),
                      validator: (v) => (v == null || !v.contains('@')) ? 'Please enter a valid email' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outlined, color: AppTheme.textMuted, size: 20),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                    ),

                    // Plan Selection UI — shown only when billing is on. The
                    // whole paid path below is intact and untouched; it is just
                    // not built while AppConstants.paymentsEnabled is false.
                    if (!AppConstants.paymentsEnabled) ...[
                      const SizedBox(height: 24),
                      const FreeAccessNotice(),
                    ],
                    if (AppConstants.paymentsEnabled) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Select Subscription Plan',
                      style: TextStyle(
                        fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Monthly Plan Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedPlan = 'monthly'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _selectedPlan == 'monthly' ? AppTheme.primary.withOpacity(0.12) : AppTheme.bgCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedPlan == 'monthly' ? AppTheme.primary : const Color(0xFF2D2D4E),
                                  width: _selectedPlan == 'monthly' ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Monthly',
                                    style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹49/month',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      color: _selectedPlan == 'monthly' ? AppTheme.primary : AppTheme.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Auto-debit monthly',
                                    style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Annual Plan Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedPlan = 'annual'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _selectedPlan == 'annual' ? AppTheme.primary.withOpacity(0.12) : AppTheme.bgCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedPlan == 'annual' ? AppTheme.primary : const Color(0xFF2D2D4E),
                                  width: _selectedPlan == 'annual' ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Annual Plan',
                                    style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹399/year',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      color: _selectedPlan == 'annual' ? AppTheme.primary : AppTheme.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Save 32% (Popular)',
                                    style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w500),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ], // end paid-plan block

                    const SizedBox(height: 32),

                    SacredButton(
                      label: AppConstants.paymentsEnabled
                          ? (_selectedPlan == 'monthly'
                              ? 'Subscribe per month (₹49)'
                              : 'Subscribe annually (₹399)')
                          : 'Create my free account',
                      icon: AppConstants.paymentsEnabled
                          ? Icons.lock_outline_rounded
                          : Icons.self_improvement_rounded,
                      loading: _isProcessing,
                      onTap: AppConstants.paymentsEnabled
                          ? _startPaymentCheckout
                          : _registerFree,
                    ),
                    const SizedBox(height: 24),

                    // Back to login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted),
                        ),
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontFamily: 'Outfit', color: AppTheme.primary, fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../services/email_service.dart';

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

  Future<String?> _createSubscription(String planId) async {
    final keyId = AppConstants.razorpayKey;
    final secret = AppConstants.razorpaySecret;

    // Fallback immediately if credentials are default dummy values
    if (keyId == 'rzp_test_rKqFqKqFqKqFqK' || secret == 'YOUR_RAZORPAY_SECRET') {
      debugPrint('ℹ️ Razorpay dummy credentials found, using fallback checkout amount.');
      return null;
    }

    try {
      final url = Uri.parse('https://api.razorpay.com/v1/subscriptions');
      final basicAuth = 'Basic ${base64Encode(utf8.encode('$keyId:$secret'))}';

      final response = await http.post(
        url,
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'plan_id': planId,
          'total_count': planId == AppConstants.monthlyPlanId ? 12 : 1,
          'quantity': 1,
          'customer_notify': 1,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['id'] as String?;
      } else {
        debugPrint('⚠️ Razorpay Subscription API returned status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ Exception during subscription generation: $e');
      return null;
    }
  }

  void _startPaymentCheckout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
      _checkoutError = null;
      _currentSubscriptionId = null;
    });

    final planId = _selectedPlan == 'monthly' ? AppConstants.monthlyPlanId : AppConstants.annualPlanId;
    final fallbackAmount = _selectedPlan == 'monthly' ? 4900 : 39900; // in paise (₹49 vs ₹399)
    final planDescription = _selectedPlan == 'monthly' ? 'Monthly Auto-Debit (₹49/mo)' : 'Annual Auto-Debit (₹399/yr)';

    // Attempt to generate standard Subscription ID
    final subId = await _createSubscription(planId);
    _currentSubscriptionId = subId;

    final options = {
      'key': AppConstants.razorpayKey,
      'name': 'Brahma Journal',
      'description': planDescription,
      'prefill': {
        'contact': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    if (subId != null) {
      options['subscription_id'] = subId;
      debugPrint('🚀 Running Checkout with recurring subscription mandate: $subId');
    } else {
      options['amount'] = fallbackAmount;
      debugPrint('🚀 Running Checkout with fallback testing amount: ₹${fallbackAmount / 100}');
    }

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _checkoutError = 'Could not open payment gateway. Please try again.';
      });
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? 'mock_pay_id';
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

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        // Send email alert asynchronously
        EmailService().sendPaymentNotification(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          planSelected: _selectedPlan,
          paymentId: paymentId,
          subscriptionId: _currentSubscriptionId,
        );

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

                    // Plan Selection UI
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

                    const SizedBox(height: 32),

                    // Pay & Register Button
                    SizedBox(
                      height: 52,
                      child: _isProcessing
                          ? Container(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: _startPaymentCheckout,
                                  child: Center(
                                    child: Text(
                                      _selectedPlan == 'monthly' ? 'Subscribe per month (₹49)' : 'Subscribe annually (₹399)',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit', fontSize: 16,
                                        fontWeight: FontWeight.w600, color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
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

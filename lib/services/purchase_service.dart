import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/purchase.dart';

class PurchaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'purchases';

  // Load Resend API key from .env dynamically
  String get _resendApiKey => dotenv.env['RESEND_API_KEY'] ?? '';

  /// Save a completed purchase record to Firestore
  Future<void> createPurchase(Purchase purchase) async {
    final docRef = _firestore.collection(_collection).doc();
    final purchaseWithId = Purchase(
      id: docRef.id,
      userId: purchase.userId,
      userEmail: purchase.userEmail,
      userName: purchase.userName,
      productId: purchase.productId,
      productTitle: purchase.productTitle,
      pdfLink: purchase.pdfLink,
      amountPaid: purchase.amountPaid,
      razorpayPaymentId: purchase.razorpayPaymentId,
      purchasedAt: purchase.purchasedAt,
    );
    await docRef.set(purchaseWithId.toMap());
  }

  /// Check if a user has already purchased a specific product
  Future<bool> hasPurchased(String userId, String productId) async {
    final query = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('productId', isEqualTo: productId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Stream all purchases by a user
  Stream<List<Purchase>> getUserPurchases(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Purchase.fromFirestore(d)).toList());
  }

  /// Send a purchase confirmation email via Resend API
  Future<void> sendPurchaseEmail({
    required String toEmail,
    required String userName,
    required String productTitle,
    required String pdfLink,
    required double amountPaid,
  }) async {
    final htmlBody = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; background: #0a0a1a; color: #e0e0f0; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 40px auto; background: #12122a; border-radius: 16px; overflow: hidden; }
    .header { background: linear-gradient(135deg, #6C63FF, #A78BFA); padding: 40px; text-align: center; }
    .header h1 { color: white; margin: 0; font-size: 24px; }
    .header p { color: rgba(255,255,255,0.85); margin: 8px 0 0 0; }
    .body { padding: 36px; }
    .greeting { font-size: 18px; font-weight: bold; color: #e0e0f0; margin-bottom: 12px; }
    .message { color: #a0a0c0; line-height: 1.6; margin-bottom: 28px; }
    .product-box { background: #1e1e3a; border: 1px solid #2d2d5e; border-radius: 12px; padding: 20px; margin-bottom: 28px; }
    .product-title { font-size: 16px; font-weight: bold; color: #c4b5fd; margin-bottom: 6px; }
    .amount { font-size: 14px; color: #10b981; font-weight: 600; }
    .btn { display: block; width: fit-content; margin: 0 auto; background: linear-gradient(135deg, #6C63FF, #A78BFA); color: white; text-decoration: none; padding: 16px 40px; border-radius: 12px; font-size: 16px; font-weight: bold; text-align: center; }
    .footer { text-align: center; padding: 24px; color: #555577; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🕉️ Brahma Journal</h1>
      <p>Purchase Confirmed — Wisdom Awaits</p>
    </div>
    <div class="body">
      <p class="greeting">Namaste, $userName! 🙏</p>
      <p class="message">
        Thank you for your purchase. Your payment has been received successfully. 
        Access your digital resource below and begin your journey to inner wisdom.
      </p>
      <div class="product-box">
        <div class="product-title">📚 $productTitle</div>
        <div class="amount">Amount Paid: ₹${amountPaid.toStringAsFixed(0)}</div>
      </div>
      <a class="btn" href="$pdfLink">
        📖 Open Your Book / PDF
      </a>
    </div>
    <div class="footer">
      This link is exclusive to your account. Please do not share it.<br>
      © ${DateTime.now().year} Brahma Journal. All rights reserved.
    </div>
  </div>
</body>
</html>
''';

    try {
      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $_resendApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'Brahma Journal <onboarding@resend.dev>',
          'to': [toEmail],
          'subject': '✅ Purchase Confirmed: $productTitle',
          'html': htmlBody,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Purchase email sent to $toEmail');
      } else {
        print('⚠️ Email failed: ${response.statusCode} — ${response.body}');
      }
    } catch (e) {
      // Email failure should not block the purchase flow
      print('⚠️ Email exception: $e');
    }
  }
}

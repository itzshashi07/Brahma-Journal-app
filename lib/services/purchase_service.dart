import 'package:flutter/foundation.dart';

import '../models/purchase.dart';
import 'api_service.dart';
import 'backend_service.dart';

/// Reads a member's entitlements. Purchases are never written from here.
///
/// Two things left this class earlier and stay gone:
///
///  * `createPurchase` wrote the record the moment Razorpay's client callback
///    fired, so a member could fabricate a purchase and unlock any paid product
///    without paying. A purchase is written only after the server verifies the
///    Razorpay HMAC signature; the API exposes no endpoint to create one.
///  * `sendPurchaseEmail` carried a Resend API key from the bundled .env, which
///    shipped readable inside the APK.
class PurchaseService {
  PurchaseService({BackendService? backend})
      : _backend = backend ?? BackendService();

  final ApiService _api = ApiService();
  final BackendService _backend;

  /// Verifies a completed payment and grants access. Returns the download link
  /// on success, or null if the signature did not verify.
  Future<String?> completePurchase({
    required String productId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    return _backend.verifyProductPayment(
      productId: productId,
      orderId: orderId,
      paymentId: paymentId,
      signature: signature,
    );
  }

  /// Whether the member already owns a product.
  ///
  /// [userId] is accepted for call-site compatibility and unused — the server
  /// answers for the ID token's owner, so nobody can probe somebody else's
  /// entitlements.
  Future<bool> hasPurchased([String? userId, String? productId]) async {
    if (productId == null) return false;
    final list = await fetchPurchases();
    return list.any((p) => p.productId == productId);
  }

  Future<List<Purchase>> fetchPurchases() async {
    try {
      final body = await _api.get('/api/library/purchases');
      final list = (body?['purchases'] as List? ?? const []);
      return list
          .map((p) => Purchase.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
    } catch (e) {
      debugPrint('❌ fetchPurchases failed: $e');
      return [];
    }
  }

  /// Single-shot stream, so existing StreamBuilder call sites compile
  /// unchanged. Entitlements change only at checkout, which the app already
  /// knows about, so there is nothing for a live stream to tell it.
  Stream<List<Purchase>> getUserPurchases([String? userId]) =>
      Stream.fromFuture(fetchPurchases());
}

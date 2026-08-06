import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase.dart';
import 'backend_service.dart';

/// Reads a user's entitlements and completes purchases through the server.
///
/// Two things moved out of this class:
///
///  * `createPurchase` wrote the purchase record straight from the app the
///    moment Razorpay's client callback fired. Firestore rules accepted it, so
///    a member could fabricate a purchase and unlock any paid product without
///    paying. Purchase records are now written only by the
///    `verifyProductPayment` Cloud Function, after it verifies the Razorpay
///    HMAC signature. Rules deny every client write to /purchases.
///
///  * `sendPurchaseEmail` carried a Resend API key from the bundled .env,
///    which shipped readable inside the APK. The confirmation email is now
///    sent by the same function.
class PurchaseService {
  PurchaseService({BackendService? backend})
      : _backend = backend ?? BackendService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BackendService _backend;
  static const String _collection = 'purchases';

  /// Deterministic id, matching the one the Cloud Function writes and the one
  /// firestore.rules checks when releasing a product's download link.
  static String purchaseId(String userId, String productId) =>
      '${userId}_$productId';

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

  /// Whether the user already owns a product.
  Future<bool> hasPurchased(String userId, String productId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(purchaseId(userId, productId))
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Stream all purchases by a user.
  Stream<List<Purchase>> getUserPurchases(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Purchase.fromFirestore(d)).toList());
  }
}

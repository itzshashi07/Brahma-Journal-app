import 'package:cloud_functions/cloud_functions.dart';

/// Client for the privileged operations that no longer run in the app.
///
/// Payment creation, payment verification, entitlement and outbound email all
/// require secrets. A mobile binary cannot hold a secret — its assets and code
/// are readable by anyone who downloads it — so those operations live in Cloud
/// Functions and are reached through here. The app now sends only its Firebase
/// ID token and an App Check token; the Razorpay and Resend keys never leave
/// the server.
class BackendService {
  BackendService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  /// Creates a Razorpay subscription for the premium membership.
  ///
  /// Returns the subscription id plus the *publishable* key id, which is safe
  /// in the client — it is the secret half that stayed behind on the server.
  Future<({String subscriptionId, String keyId})?> createSubscription(
    String plan,
  ) async {
    try {
      final result = await _functions
          .httpsCallable('createSubscription')
          .call<Map<String, dynamic>>({'plan': plan});
      final data = result.data;
      final id = data['subscriptionId'] as String?;
      final keyId = data['keyId'] as String?;
      if (id == null || keyId == null) return null;
      return (subscriptionId: id, keyId: keyId);
    } on FirebaseFunctionsException catch (e) {
      throw BackendException(_messageFor(e));
    }
  }

  /// Verifies a subscription payment server-side and activates premium.
  Future<bool> verifySubscriptionPayment({
    required String subscriptionId,
    required String paymentId,
    required String signature,
    required String plan,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('verifySubscriptionPayment')
          .call<Map<String, dynamic>>({
        'subscriptionId': subscriptionId,
        'paymentId': paymentId,
        'signature': signature,
        'plan': plan,
      });
      return result.data['ok'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw BackendException(_messageFor(e));
    }
  }

  /// Creates an order for a product. The amount is decided by the server from
  /// the product document, so a tampered client cannot set its own price.
  Future<({String orderId, int amount, String keyId})?> createProductOrder(
    String productId,
  ) async {
    try {
      final result = await _functions
          .httpsCallable('createProductOrder')
          .call<Map<String, dynamic>>({'productId': productId});
      final data = result.data;
      final orderId = data['orderId'] as String?;
      final keyId = data['keyId'] as String?;
      final amount = (data['amount'] as num?)?.toInt();
      if (orderId == null || keyId == null || amount == null) return null;
      return (orderId: orderId, amount: amount, keyId: keyId);
    } on FirebaseFunctionsException catch (e) {
      throw BackendException(_messageFor(e));
    }
  }

  /// Verifies a product payment and grants access. Returns the download link
  /// only when the signature checks out.
  Future<String?> verifyProductPayment({
    required String productId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('verifyProductPayment')
          .call<Map<String, dynamic>>({
        'productId': productId,
        'orderId': orderId,
        'paymentId': paymentId,
        'signature': signature,
      });
      if (result.data['ok'] != true) return null;
      return result.data['pdfLink'] as String? ?? '';
    } on FirebaseFunctionsException catch (e) {
      throw BackendException(_messageFor(e));
    }
  }

  /// Files a support ticket and emails the operator. The Resend key stays on
  /// the server, so the app can no longer be used to send mail as the brand.
  Future<bool> sendSupportTicket({
    required String category,
    required String message,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('sendSupportEmail')
          .call<Map<String, dynamic>>({
        'category': category,
        'message': message,
      });
      return result.data['ok'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw BackendException(_messageFor(e));
    }
  }

  /// Grants or revokes admin on another account. Rejected by the server unless
  /// the caller already holds the claim.
  Future<bool> setAdminClaim({required String email, required bool admin}) async {
    try {
      final result = await _functions
          .httpsCallable('setAdminClaim')
          .call<Map<String, dynamic>>({'email': email, 'admin': admin});
      return result.data['ok'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw BackendException(_messageFor(e));
    }
  }

  /// Server error codes carry detail that is useful to an attacker and
  /// meaningless to a user; surface something plain instead.
  String _messageFor(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Please sign in and try again.';
      case 'permission-denied':
        return 'That payment could not be verified.';
      case 'failed-precondition':
        return 'This is not available right now. Please contact support.';
      case 'not-found':
        return 'That item is no longer available.';
      case 'unavailable':
        return 'Network problem. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

class BackendException implements Exception {
  final String message;
  BackendException(this.message);
  @override
  String toString() => message;
}

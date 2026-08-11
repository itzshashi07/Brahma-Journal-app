import 'package:cloud_firestore/cloud_firestore.dart';

class Purchase {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String productId;
  final String productTitle;
  final String pdfLink;
  final double amountPaid;
  final String razorpayPaymentId;
  final DateTime purchasedAt;

  Purchase({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.productId,
    required this.productTitle,
    required this.pdfLink,
    required this.amountPaid,
    required this.razorpayPaymentId,
    required this.purchasedAt,
  });

  factory Purchase.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Purchase(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      productId: data['productId'] ?? '',
      productTitle: data['productTitle'] ?? '',
      pdfLink: data['pdfLink'] ?? '',
      amountPaid: (data['amountPaid'] ?? 0).toDouble(),
      razorpayPaymentId: data['razorpayPaymentId'] ?? '',
      purchasedAt: (data['purchasedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Built from the Node.js API's JSON.
  factory Purchase.fromJson(Map<String, dynamic> data) {
    return Purchase(
      id: data['_id']?.toString() ?? '',
      userId: data['firebaseUid'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      productId: data['productId'] ?? '',
      productTitle: data['productTitle'] ?? '',
      pdfLink: data['pdfLink'] ?? '',
      amountPaid: (data['amountPaid'] as num?)?.toDouble() ?? 0.0,
      razorpayPaymentId: data['razorpayPaymentId'] ?? '',
      purchasedAt:
          DateTime.tryParse(data['purchasedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'productId': productId,
      'productTitle': productTitle,
      'pdfLink': pdfLink,
      'amountPaid': amountPaid,
      'razorpayPaymentId': razorpayPaymentId,
      'purchasedAt': FieldValue.serverTimestamp(),
    };
  }
}

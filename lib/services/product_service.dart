import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import 'notification_service.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionPath = 'products';

  // Stream all products
  Stream<List<Product>> streamProducts() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
    });
  }

  /// Parses a display price ("₹299", "Free") into paise for the server.
  static int priceToPaise(String price) {
    final digits = price.replaceAll(RegExp(r'[^\d.]'), '');
    final amount = double.tryParse(digits) ?? 0.0;
    return (amount * 100).round();
  }

  /// Reads the download link for a product.
  ///
  /// The link lives in a `secure` subdocument rather than on the catalogue
  /// entry. The catalogue used to be world-readable *and* carried `pdfLink`,
  /// so the paid asset could be lifted straight out of Firestore without
  /// paying and without even signing in. Firestore rules release this document
  /// only to an admin, to a buyer with a verified purchase, or for a free
  /// product — the read below simply fails for anyone else.
  Future<String?> fetchSecureLink(String productId) async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(productId)
          .collection('secure')
          .doc('link')
          .get();
      return doc.data()?['pdfLink'] as String?;
    } catch (e) {
      // permission-denied is the expected outcome for a user without access.
      return null;
    }
  }

  // Create a new product
  Future<void> createProduct({
    required String title,
    required String description,
    required String price,
    required String coverImageUrl,
    required String pdfLink,
  }) async {
    final docRef = _firestore.collection(_collectionPath).doc();
    final paise = priceToPaise(price);
    final product = Product(
      id: docRef.id,
      title: title,
      description: description,
      price: price,
      coverImageUrl: coverImageUrl,
      pdfLink: '', // never stored on the readable catalogue document
      createdAt: DateTime.now(),
    );

    await docRef.set({
      ...product.toMap(),
      // Authoritative amount for server-side order creation, so the price can
      // never be set by the client at checkout time.
      'pricePaise': paise,
      'isFree': paise == 0,
    });

    await docRef.collection('secure').doc('link').set({'pdfLink': pdfLink});

    // Trigger local push notification
    await NotificationService().sendNotification(
      title: 'New Book in Library 📚',
      body: '"$title" is now available in Wisdom Library!',
      type: 'library',
      route: '/products',
    );
  }

  // Delete a product (book/resource)
  Future<void> deleteProduct(String productId) async {
    await _firestore.collection(_collectionPath).doc(productId).delete();
  }
}

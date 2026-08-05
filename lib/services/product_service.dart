import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

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

  // Create a new product
  Future<void> createProduct({
    required String title,
    required String description,
    required String price,
    required String coverImageUrl,
    required String pdfLink,
  }) async {
    final docRef = _firestore.collection(_collectionPath).doc();
    final product = Product(
      id: docRef.id,
      title: title,
      description: description,
      price: price,
      coverImageUrl: coverImageUrl,
      pdfLink: pdfLink,
      createdAt: DateTime.now(),
    );
    await docRef.set(product.toMap());
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String title;
  final String description;
  final String price; // e.g. "₹99" or "Free"
  final String coverImageUrl;
  final String pdfLink; // Google Drive or PDF link
  final DateTime createdAt;

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.coverImageUrl,
    required this.pdfLink,
    required this.createdAt,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: data['price'] ?? 'Free',
      coverImageUrl: data['coverImageUrl'] ?? '',
      pdfLink: data['pdfLink'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'coverImageUrl': coverImageUrl,
      'pdfLink': pdfLink,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

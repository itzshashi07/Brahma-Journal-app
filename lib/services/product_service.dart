import 'package:flutter/foundation.dart';

import '../models/product.dart';
import 'api_service.dart';

/// The library catalogue, served by the Node.js API.
///
/// The `secure` subcollection is gone and needs no replacement. It existed
/// because Firestore can allow or deny a whole document and has no way to hide
/// one field from a reader allowed to see the rest — so the paid PDF link had
/// to live in a separate document with its own rule, or the asset could be
/// lifted straight out of the catalogue without paying.
///
/// The API marks `pdfLink` as unselectable and releases it from one endpoint
/// that checks for a purchase first. One collection instead of two, and the
/// same guarantee.
///
/// `streamProducts` is now a `Future`. Firestore's `snapshots()` gave a live
/// stream for free; MongoDB has no client-side equivalent, and the catalogue
/// changes when an admin publishes a book — roughly never — so a fetch on
/// screen open is the honest shape rather than a stream that never fires.
class ProductService {
  final ApiService _api = ApiService();

  /// Parses a display price ("₹299", "Free") into paise for the server.
  static int priceToPaise(String price) {
    final digits = price.replaceAll(RegExp(r'[^\d.]'), '');
    final amount = double.tryParse(digits) ?? 0.0;
    return (amount * 100).round();
  }

  Future<List<Product>> fetchProducts() async {
    try {
      final body = await _api.get('/api/library/products');
      final list = (body?['products'] as List? ?? const []);
      return list
          .map((p) => Product.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
    } catch (e) {
      debugPrint('❌ fetchProducts failed: $e');
      return [];
    }
  }

  /// Kept as a single-shot stream so existing StreamBuilder call sites compile
  /// unchanged. It emits once — see the note on this class.
  Stream<List<Product>> streamProducts() => Stream.fromFuture(fetchProducts());

  /// The download link. Returns null when the caller has not bought the book —
  /// the server refuses, and a refusal is the expected outcome, not an error.
  Future<String?> fetchSecureLink(String productId) async {
    try {
      final body = await _api.get('/api/library/products/$productId/link');
      return body?['pdfLink'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<void> createProduct({
    required String title,
    required String description,
    required String price,
    required String coverImageUrl,
    required String pdfLink,
  }) async {
    await _api.post('/api/library/products', {
      'title': title,
      'description': description,
      'price': price,
      // The authoritative amount, so checkout cannot be re-priced by the client.
      'priceAmount': priceToPaise(price),
      'coverImageUrl': coverImageUrl,
      'pdfLink': pdfLink,
    });

    // Announcing the book is the server's job now: it writes the notification
    // record and pushes it through FCM in one step, so the pair cannot come
    // apart because the app was killed between two client writes.
    await _api.post('/api/notifications', {
      'title': 'New Book in Library 📚',
      'body': '"$title" is now available in Wisdom Library!',
      'type': 'library',
      'route': '/products',
    });
  }

  Future<void> deleteProduct(String productId) async {
    await _api.delete('/api/library/products/$productId');
  }
}

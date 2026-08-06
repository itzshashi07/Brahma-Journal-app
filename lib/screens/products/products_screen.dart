import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_service.dart';
import '../../services/purchase_service.dart';
import '../../services/backend_service.dart';
import '../../models/product.dart';
import '../../core/theme/app_theme.dart';
import 'pdf_reader_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _productService = ProductService();
  final PurchaseService _purchaseService = PurchaseService();
  final BackendService _backend = BackendService();
  late Razorpay _razorpay;

  // Store the product and server-issued order being paid for
  Product? _pendingProduct;
  String? _pendingOrderId;

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
    _razorpay.clear();
    super.dispose();
  }

  // ─── Razorpay Handlers ─────────────────────────────────────────────────────

  /// Completes a product purchase.
  ///
  /// The app used to write the purchase record itself here, straight from the
  /// Razorpay client callback, and then open the download link it already had
  /// in hand. Nothing verified that money had changed hands, and Firestore
  /// rules accepted the record — so a member could fabricate a purchase and
  /// unlock any paid book for free.
  ///
  /// Now the signature goes to `verifyProductPayment`, which checks the HMAC
  /// against the Razorpay secret on the server, writes the purchase record with
  /// the Admin SDK, and only then returns the download link. If the signature
  /// does not verify, no record is written and no link comes back.
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final product = _pendingProduct;
    final orderId = response.orderId ?? _pendingOrderId;
    _pendingProduct = null;
    _pendingOrderId = null;

    if (product == null || orderId == null) return;

    String? pdfLink;
    try {
      pdfLink = await _purchaseService.completePurchase(
        productId: product.id,
        orderId: orderId,
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );
    } catch (e) {
      debugPrint('⚠️ Purchase verification failed: $e');
    }

    if (!mounted) return;

    if (pdfLink == null || pdfLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'We could not confirm that payment. If you were charged, contact support and we will sort it out.',
            style: TextStyle(fontFamily: 'Outfit'),
          ),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Show success banner
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '🎉 Purchase successful! Opening your book...',
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500),
            ),
          ),
        ]),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );

    // Open in the in-app reader rather than a browser, so the freshly
    // purchased book gets the same no-download treatment as every other read.
    _openReader(product.title, pdfLink);
  }

  /// Fetches the link from the product's protected subdocument and opens the
  /// book in the in-app reader. Firestore returns the link only if this account
  /// actually has access, so an entitlement bug shows up as a refusal rather
  /// than a leaked asset.
  ///
  /// Reading happens inside the app rather than in a browser: the file is
  /// fetched into private cache, shown page by page with no share or save
  /// control, and deleted when the reader closes.
  Future<void> _openSecureLink(Product product) async {
    final link = await _productService.fetchSecureLink(product.id);
    if (!mounted) return;
    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This resource is not available for your account.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }
    _openReader(product.title, link);
  }

  void _openReader(String title, String link) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfReaderScreen(title: title, link: link),
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _pendingProduct = null;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment failed: ${response.message ?? "Unknown error"}',
          style: const TextStyle(fontFamily: 'Outfit'),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _pendingProduct = null;
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _confirmDeleteProduct(BuildContext context, String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Resource?', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to permanently delete this library book/PDF?', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _productService.deleteProduct(productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Library resource deleted.', style: TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  /// Parse price string to int paise for Razorpay (Rs.299 → 29900)
  int _toPaise(String priceStr) {
    final digits = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
    final amount = double.tryParse(digits) ?? 0.0;
    return (amount * 100).toInt();
  }

  /// Opens checkout for a product.
  ///
  /// Two things changed. The Razorpay key id used to be a literal in this
  /// method and is now returned by the server, so rotating it no longer
  /// requires shipping a new build. More importantly the
  /// amount was computed in the app from the displayed price string — a patched
  /// client could pay ₹1 for a ₹999 book. The order is now created server-side
  /// with the amount read from the product document, and the payment is
  /// verified against that order.
  void _openRazorpayCheckout(Product product, AuthProvider auth) async {
    try {
      final order = await _backend.createProductOrder(product.id);
      if (order == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checkout is unavailable right now. Please try again.',
                style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Color(0xFFB91C1C),
          ),
        );
        return;
      }

      _pendingProduct = product;
      _pendingOrderId = order.orderId;

      _razorpay.open({
        'key': order.keyId,
        'order_id': order.orderId,
        'amount': order.amount,
        'name': 'Brahma Journal',
        'description': product.title,
        'prefill': {
          'contact': auth.profile?.phone ?? '',
          'email': auth.user?.email ?? '',
          'name': auth.profile?.name ?? '',
        },
        'theme': {
          'color': '#6C63FF',
        },
      });
    } on BackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: const TextStyle(fontFamily: 'Outfit')),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    }
  }

  // ─── Product Detail Bottom Sheet ─────────────────────────────────────────

  void _showProductDetails(Product product, AuthProvider auth) async {
    // Check purchase status (only for non-admin)
    bool alreadyPurchased = false;
    if (!auth.isAdmin && auth.user != null) {
      alreadyPurchased = await _purchaseService.hasPurchased(auth.user!.uid, product.id);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isFree = product.price.trim().toLowerCase() == 'free' || _toPaise(product.price) == 0;
        final canAccessDirectly = auth.isAdmin || alreadyPurchased || isFree;

        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D3D6B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Product header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 70,
                      height: 100,
                      child: product.coverImageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.coverImageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppTheme.bgCardLight,
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppTheme.bgCardLight,
                                child: const Icon(Icons.book, color: AppTheme.primary, size: 30),
                              ),
                            )
                          : Container(color: AppTheme.bgCardLight, child: const Icon(Icons.book, color: AppTheme.primary, size: 30)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Price tag or Purchased badge
                        if (alreadyPurchased)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                            ),
                            child: const Text(
                              '✅ Already Purchased',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          )
                        else if (auth.isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                            ),
                            child: const Text(
                              '🔑 Admin Access',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                          )
                        else
                          Text(
                            isFree ? 'Free' : product.price,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    product.description,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Button — changes based on purchase state
              if (canAccessDirectly) ...[
                _buildActionButton(
                  icon: Icons.open_in_new_rounded,
                  label: auth.isAdmin ? 'Admin: Open PDF / Drive Link' : '📖 Open Your Book',
                  onTap: () {
                    Navigator.pop(ctx);
                    _openSecureLink(product);
                  },
                ),
              ] else ...[
                // What they get note
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_open_outlined, color: AppTheme.primaryLight, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'After payment, the PDF link will open instantly and a confirmation email will be sent to your inbox.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionButton(
                  icon: Icons.payment_rounded,
                  label: isFree ? '📖 Access Free Book' : '🔐 Buy Now — ${product.price}',
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isFree) {
                      _openSecureLink(product);
                    } else {
                      _openRazorpayCheckout(product, auth);
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: Text(
                        '📚 Wisdom Library',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),

              // Product Grid Stream
              Expanded(
                child: StreamBuilder<List<Product>>(
                  stream: _productService.streamProducts(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading library: ${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent, fontFamily: 'Outfit'),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                    }

                    final products = snapshot.data ?? [];
                    if (products.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('📚', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            const Text(
                              'No books available yet.',
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppTheme.textSecondary),
                            ),
                            if (auth.isAdmin) ...[
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => context.push('/products/create'),
                                child: const Text('Add First Book'),
                              ),
                            ]
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.55,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        return _buildProductCard(products[index], auth);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: auth.isAdmin
          ? FloatingActionButton(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add),
              onPressed: () => context.push('/products/create'),
            )
          : null,
    );
  }

  Widget _buildProductCard(Product product, AuthProvider auth) {
    final isFree = product.price.trim().toLowerCase() == 'free' || _toPaise(product.price) == 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D4E), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showProductDetails(product, auth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover Image
              Expanded(
                flex: 4,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: SizedBox.expand(
                        child: product.coverImageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: product.coverImageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppTheme.bgCardLight,
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppTheme.bgCardLight,
                                  child: const Icon(Icons.book, color: AppTheme.primary, size: 40),
                                ),
                              )
                            : Container(color: AppTheme.bgCardLight, child: const Icon(Icons.book, color: AppTheme.primary, size: 40)),
                      ),
                    ),
                    if (auth.isAdmin)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: GestureDetector(
                          onTap: () => _confirmDeleteProduct(context, product.id),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    // Lock / Free badge overlay
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isFree
                              ? const Color(0xFF10B981).withOpacity(0.85)
                              : Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFree ? Icons.lock_open : Icons.lock_outline,
                              color: Colors.white,
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isFree ? 'Free' : product.price,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Title and CTA
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            product.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isFree ? 'Free' : product.price,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isFree ? 'Get' : 'Buy',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

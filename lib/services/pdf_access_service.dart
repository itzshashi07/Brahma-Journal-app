import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';

/// Fetches a book for in-app reading.
///
/// Books are catalogued as links, and in practice those links are Google Drive
/// share URLs — which serve an HTML preview page, not a PDF stream, so they
/// cannot be handed to a PDF renderer as-is. This resolves the common forms to
/// something a renderer can actually read.
///
/// **On "they can't download it":** the file is fetched into the app's private
/// cache (unreadable by other apps and by the user without root) and deleted
/// when the reader closes, and the reader shows no share or save affordance.
/// Combined with FLAG_SECURE that blocks screenshots and screen recording. That
/// is as far as any app can go — the bytes must reach the device to be drawn on
/// it, so a rooted phone or a camera pointed at the screen still wins. This is
/// a strong deterrent, not DRM. Genuinely sensitive material needs watermarking
/// per reader or a server-rendered page-image viewer.
class PdfAccessService {
  static const MethodChannel _secureWindow =
      MethodChannel('com.brahma.brahmaApp/secure_window');

  /// Blocks screenshots, screen recording and the recents thumbnail.
  ///
  /// Belt and braces: the whole app is protected from launch — FLAG_SECURE in
  /// MainActivity.onCreate on Android, the secure-layer trick in AppDelegate on
  /// iOS — so this call only re-asserts what is already true. It stays because
  /// the reader should not silently depend on a setting made somewhere else in
  /// the app.
  ///
  /// Skipped entirely while [AppConstants.allowScreenCapture] is set, so a
  /// promo recording does not go black the moment a book is opened. The native
  /// side refuses the request as well; this check just avoids the round trip.
  static Future<void> enableScreenProtection() async {
    if (AppConstants.allowScreenCapture) return;
    try {
      await _secureWindow.invokeMethod('enable');
    } on PlatformException {
      // Protection is applied natively at launch regardless; reading proceeds.
    } on MissingPluginException {
      // Older build without the channel — not worth failing the read over.
    }
  }

  /// Intentionally does not unprotect anything any more.
  ///
  /// Protection is app-wide, so honouring a "disable" from the reader would
  /// unprotect the journal, the check-ins and the support threads sitting
  /// behind it. The native side treats this as a no-op; the method is kept so
  /// existing callers still compile and read honestly.
  static Future<void> disableScreenProtection() async {
    try {
      await _secureWindow.invokeMethod('disable');
    } catch (_) {}
  }

  /// Rewrites a share link into something that returns PDF bytes.
  ///
  /// Returns null when the link is not a form we can render, so the caller can
  /// fall back to opening it in a browser rather than showing a broken reader.
  static String? toDirectUrl(String link) {
    final url = link.trim();
    if (url.isEmpty) return null;

    // Already a PDF, or a Firebase Storage object (which serves real bytes).
    if (url.toLowerCase().contains('.pdf') ||
        url.contains('firebasestorage.googleapis.com')) {
      return url;
    }

    // Google Drive: /file/d/<id>/view, ?id=<id>, or /open?id=<id>
    final driveId = _driveFileId(url);
    if (driveId != null) {
      return 'https://drive.google.com/uc?export=download&id=$driveId';
    }

    return null;
  }

  static String? _driveFileId(String url) {
    if (!url.contains('drive.google.com') && !url.contains('docs.google.com')) {
      return null;
    }
    final patterns = [
      RegExp(r'/file/d/([a-zA-Z0-9_-]{20,})'),
      RegExp(r'[?&]id=([a-zA-Z0-9_-]{20,})'),
      RegExp(r'/d/([a-zA-Z0-9_-]{20,})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// Downloads the book into private cache and returns the file.
  ///
  /// Throws [PdfUnavailable] with a readable reason on failure — the reader
  /// surfaces that instead of a blank page.
  static Future<File> fetch(String link) async {
    final direct = toDirectUrl(link);
    if (direct == null) {
      throw PdfUnavailable(
        'This book is not stored in a format the in-app reader can open.',
        canOpenExternally: true,
      );
    }

    late final http.Response response;
    try {
      response = await http
          .get(Uri.parse(direct))
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw PdfUnavailable('Could not reach the book. Check your connection.');
    }

    if (response.statusCode != 200) {
      throw PdfUnavailable('The book could not be opened right now.');
    }

    // A Drive file that is not publicly shared, or one large enough to trigger
    // the virus-scan interstitial, returns an HTML page with a 200. Rendering
    // that as a PDF gives a blank screen, so detect it by the magic number.
    final bytes = response.bodyBytes;
    final looksLikePdf = bytes.length > 4 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46; // F
    if (!looksLikePdf) {
      throw PdfUnavailable(
        'This book is not shared publicly, so it cannot be opened in the app.',
        canOpenExternally: true,
      );
    }

    // getApplicationSupportDirectory, not the downloads folder: this path is
    // private to the app and invisible to the file manager and other apps.
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/reading_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Removes the cached copy once reading finishes.
  static Future<void> discard(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

class PdfUnavailable implements Exception {
  final String message;
  final bool canOpenExternally;
  PdfUnavailable(this.message, {this.canOpenExternally = false});

  @override
  String toString() => message;
}

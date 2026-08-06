import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../services/pdf_access_service.dart';
import '../../widgets/sacred.dart';

/// Reads a book inside the app, page by page.
///
/// Deliberately offers no share, save or print control, keeps the file in
/// private cache only for as long as the screen is open, and turns on
/// FLAG_SECURE so the pages are excluded from screenshots and screen
/// recording. See PdfAccessService for what that does and does not achieve.
class PdfReaderScreen extends StatefulWidget {
  final String title;
  final String link;

  const PdfReaderScreen({super.key, required this.title, required this.link});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  File? _file;
  String? _error;
  bool _canOpenExternally = false;
  bool _loading = true;

  int _page = 0;
  int _pageCount = 0;

  @override
  void initState() {
    super.initState();
    PdfAccessService.enableScreenProtection();
    _load();
  }

  @override
  void dispose() {
    // Both matter: drop the protection flag so the rest of the app can be
    // screenshotted normally, and delete the cached copy so a book does not
    // linger on disk after it has been closed.
    PdfAccessService.disableScreenProtection();
    PdfAccessService.discard(_file);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final file = await PdfAccessService.fetch(widget.link);
      if (!mounted) return;
      setState(() {
        _file = file;
        _loading = false;
      });
    } on PdfUnavailable catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _canOpenExternally = e.canOpenExternally;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong opening this book.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SacredBackdrop(
        showMandala: false,
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: widget.title,
                subtitle: _pageCount > 0 ? 'Page ${_page + 1} of $_pageCount' : null,
                onBack: () => context.pop(),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: AppTheme.space4),
            Text(
              'Opening your book…',
              style: TextStyle(
                  fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book_outlined,
                  size: 44, color: AppTheme.textMuted),
              const SizedBox(height: AppTheme.space4),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (_canOpenExternally) ...[
                const SizedBox(height: AppTheme.space6),
                SacredButton(
                  label: 'Open in browser instead',
                  icon: Icons.open_in_new_rounded,
                  expand: false,
                  onTap: () => launchUrl(Uri.parse(widget.link),
                      mode: LaunchMode.externalApplication),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        PDFView(
          filePath: _file!.path,
          // Vertical swipe, one page at a time — reading a book, not scrolling
          // a document.
          swipeHorizontal: false,
          pageSnap: true,
          pageFling: true,
          autoSpacing: true,
          fitPolicy: FitPolicy.BOTH,
          nightMode: false,
          onRender: (pages) => setState(() => _pageCount = pages ?? 0),
          onPageChanged: (page, total) => setState(() {
            _page = page ?? 0;
            _pageCount = total ?? _pageCount;
          }),
          onError: (e) => setState(() => _error = 'This book could not be displayed.'),
        ),
        if (_pageCount > 0)
          Positioned(
            bottom: AppTheme.space5,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space4, vertical: AppTheme.space2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '${_page + 1} / $_pageCount',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

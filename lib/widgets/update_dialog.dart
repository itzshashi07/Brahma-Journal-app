import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/app_release.dart';
import '../services/app_update_service.dart';
import 'sacred.dart';

/// Update prompt with an inline download.
///
/// One surface for the whole flow — details, progress, errors — rather than a
/// dialog that dismisses into a browser and leaves the user to work out what
/// happens next.
///
/// A mandatory update cannot be escaped: no Later, no barrier dismiss, and back
/// is intercepted.
class UpdateDialog extends StatefulWidget {
  final AppRelease release;

  const UpdateDialog({super.key, required this.release});

  static Future<void> show(BuildContext context, AppRelease release) {
    return showDialog(
      context: context,
      barrierDismissible: !release.mandatory,
      builder: (_) => UpdateDialog(release: release),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final _cancelToken = CancelToken();

  bool _downloading = false;
  double? _progress;
  int _received = 0;
  int? _total;
  String? _error;
  bool _needsPermission = false;

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final release = widget.release;

    // Not a direct APK — an App Distribution or Play page has to open in the
    // browser, because downloading it would just fetch HTML.
    if (!release.isDirectApk) {
      await AppUpdateService.openDownloadPage(release);
      if (mounted && !release.mandatory) Navigator.pop(context);
      return;
    }

    setState(() {
      _downloading = true;
      _error = null;
      _needsPermission = false;
      _progress = null;
      _received = 0;
    });

    final failure = await AppUpdateService.downloadAndInstall(
      release,
      cancelToken: _cancelToken,
      onProgress: (p, received, total) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          _received = received;
          _total = total;
        });
      },
    );

    if (!mounted) return;

    if (failure == 'needs-permission') {
      setState(() {
        _downloading = false;
        _needsPermission = true;
      });
      return;
    }

    setState(() {
      _downloading = false;
      _error = failure;
    });

    // Success hands off to the system installer; leave the dialog up so the
    // user has somewhere to land if they cancel that.
  }

  String get _progressLabel {
    if (_total != null && _total! > 0) {
      final mb = (_received / (1024 * 1024)).toStringAsFixed(1);
      final totalMb = (_total! / (1024 * 1024)).toStringAsFixed(1);
      return '$mb MB of $totalMb MB';
    }
    return '${(_received / (1024 * 1024)).toStringAsFixed(1)} MB downloaded';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;

    return PopScope(
      canPop: !r.mandatory && !_downloading,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppTheme.space5),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.space5),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.shadowSoft,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: r.mandatory
                          ? AppTheme.goldGradient
                          : AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(Icons.system_update_rounded,
                        color: Colors.white, size: 23),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.mandatory ? 'Update required' : 'Update available',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Version ${r.version}',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.space4),

              Row(
                children: [
                  _Chip(
                    icon: Icons.sd_storage_outlined,
                    label: r.readableSize,
                  ),
                  const SizedBox(width: AppTheme.space2),
                  if (r.releasedAt != null)
                    _Chip(
                      icon: Icons.event_outlined,
                      label: DateFormat('d MMM yyyy').format(r.releasedAt!),
                    ),
                ],
              ),

              if (r.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.space3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        r.releaseNotes,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12.5,
                          height: 1.55,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              if (_downloading) ...[
                const SizedBox(height: AppTheme.space5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
                const SizedBox(height: AppTheme.space2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _progressLabel,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          color: AppTheme.textMuted),
                    ),
                    if (_progress != null)
                      Text(
                        '${(_progress! * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryLight),
                      ),
                  ],
                ),
              ],

              if (_needsPermission) ...[
                const SizedBox(height: AppTheme.space4),
                _Notice(
                  icon: Icons.lock_open_outlined,
                  text: 'Android needs your permission to install apps from '
                      'Brahma Journal. Allow it, then tap Update again.',
                  actionLabel: 'Open settings',
                  onAction: AppUpdateService.openInstallSettings,
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: AppTheme.space4),
                _Notice(
                  icon: Icons.error_outline_rounded,
                  text: _error!,
                  danger: true,
                  actionLabel: 'Open in browser',
                  onAction: () => AppUpdateService.openDownloadPage(r),
                ),
              ],

              const SizedBox(height: AppTheme.space5),

              Row(
                children: [
                  if (!r.mandatory && !_downloading)
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Later',
                            style: TextStyle(
                                fontFamily: 'Outfit',
                                color: AppTheme.textMuted)),
                      ),
                    ),
                  if (!r.mandatory && !_downloading)
                    const SizedBox(width: AppTheme.space2),
                  Expanded(
                    flex: 2,
                    child: SacredButton(
                      label: _downloading
                          ? 'Downloading…'
                          : (_error != null ? 'Try again' : 'Update now'),
                      icon: _downloading ? null : Icons.download_rounded,
                      loading: _downloading,
                      onTap: _downloading ? null : _start,
                    ),
                  ),
                ],
              ),

              if (r.mandatory) ...[
                const SizedBox(height: AppTheme.space3),
                const Center(
                  child: Text(
                    'This update is required to continue',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        color: AppTheme.textMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space3, vertical: AppTheme.space1 + 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool danger;

  const _Notice({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = danger ? AppTheme.danger : AppTheme.accent;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: danger ? const Color(0xFFF87171) : AppTheme.accentLight),
              const SizedBox(width: AppTheme.space2),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    height: 1.45,
                    color: danger ? const Color(0xFFFCA5A5) : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (actionLabel != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel!,
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: danger ? const Color(0xFFFCA5A5) : AppTheme.accentLight)),
              ),
            ),
        ],
      ),
    );
  }
}

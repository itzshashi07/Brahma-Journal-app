import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/app_release.dart';
import '../services/app_update_service.dart';
import 'sacred.dart';

/// Update prompt.
///
/// Shows what is in the new version and sends the user to the store to get it.
///
/// It used to download and install the APK inline, with a progress bar and an
/// install-permission prompt. All of that is gone: Play does not allow an app
/// to update itself, so the honest version of this dialog is one that hands off
/// to the store. See [AppUpdateService] for the policy.
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
  /// True once the store has been opened, so the button can say something
  /// truthful if the user comes back without having updated.
  bool _sentToStore = false;

  Future<void> _start() async {
    await AppUpdateService.openStoreListing(widget.release);
    if (!mounted) return;
    setState(() => _sentToStore = true);

    // An optional update closes behind them; a mandatory one stays, because
    // coming back without updating must not leave them inside the app.
    if (!widget.release.mandatory) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;

    return PopScope(
      canPop: !r.mandatory,
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

              if (_sentToStore && r.mandatory) ...[
                const SizedBox(height: AppTheme.space4),
                const _Notice(
                  icon: Icons.storefront_outlined,
                  text: 'Finish the update in the Play Store, then reopen '
                      'InnenFlow.',
                ),
              ],

              const SizedBox(height: AppTheme.space5),

              Row(
                children: [
                  if (!r.mandatory)
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Later',
                            style: TextStyle(
                                fontFamily: 'Outfit',
                                color: AppTheme.textMuted)),
                      ),
                    ),
                  if (!r.mandatory) const SizedBox(width: AppTheme.space2),
                  Expanded(
                    flex: 2,
                    child: SacredButton(
                      label: _sentToStore ? 'Open store again' : 'Update now',
                      icon: Icons.storefront_rounded,
                      onTap: _start,
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

/// The one remaining inline message: shown to somebody held on a mandatory
/// update after they have been sent to the store.
///
/// It used to carry an action button and a danger variant, for the download
/// errors and the install-permission prompt. Neither exists now that the store
/// does the work, so both are gone rather than left as unused parameters.
class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.accentLight),
          const SizedBox(width: AppTheme.space2),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

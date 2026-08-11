import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_release.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_update_service.dart';
import '../../widgets/sacred.dart';
import '../../widgets/update_dialog.dart';

/// App Updates.
///
/// Shows what is installed, what is published, and the difference between them.
/// Checking on launch is silent by design — it only interrupts when there is
/// something to say — so this screen exists for the times someone wants to ask
/// rather than wait to be told.
class AppUpdatesScreen extends StatefulWidget {
  const AppUpdatesScreen({super.key});

  @override
  State<AppUpdatesScreen> createState() => _AppUpdatesScreenState();
}

class _AppUpdatesScreenState extends State<AppUpdatesScreen> {
  UpdateStatus? _status;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final status = await AppUpdateService.check();
    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: 'App Updates',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _check,
                  color: AppTheme.primary,
                  backgroundColor: AppTheme.bgCard,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(AppTheme.space5, 0,
                        AppTheme.space5, AppTheme.space8),
                    children: [
                      const SizedBox(height: AppTheme.space2),
                      _statusCard(),
                      const SizedBox(height: AppTheme.space4),
                      _versionsCard(),
                      if (_status?.release != null &&
                          _status!.updateAvailable) ...[
                        const SizedBox(height: AppTheme.space4),
                        _releaseCard(_status!.release!),
                      ],
                      const SizedBox(height: AppTheme.space5),
                      SacredButton(
                        label: _checking ? 'Checking…' : 'Check for updates',
                        icon: Icons.refresh_rounded,
                        loading: _checking,
                        onTap: _checking ? null : _check,
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: AppTheme.space5),
                        _adminNote(),
                      ],
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

  // ─────────────────────────── status ───────────────────────────

  Widget _statusCard() {
    if (_checking && _status == null) {
      return const GlassCard(
        padding: EdgeInsets.symmetric(vertical: AppTheme.space8),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: AppTheme.space4),
              Text('Checking for updates…',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    final s = _status!;

    if (s.error != null) {
      return _bigState(
        icon: Icons.cloud_off_rounded,
        tint: AppTheme.danger,
        title: 'Could not check',
        subtitle: s.error!,
      );
    }

    if (s.updateAvailable) {
      final r = s.release!;
      return _bigState(
        icon: Icons.system_update_rounded,
        tint: r.mandatory ? AppTheme.accent : AppTheme.primary,
        title: r.mandatory ? 'Update required' : 'Update available',
        subtitle: 'Version ${r.version} is ready to install.',
        action: SacredButton(
          label: 'Update now',
          icon: Icons.download_rounded,
          onTap: () async {
            await UpdateDialog.show(context, r);
            if (mounted) _check();
          },
        ),
      );
    }

    return _bigState(
      icon: Icons.verified_rounded,
      tint: AppTheme.success,
      title: "You're up to date",
      subtitle: 'InnenFlow ${s.currentVersion} is the latest version.',
    );
  }

  Widget _bigState({
    required IconData icon,
    required Color tint,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(
          vertical: AppTheme.space6, horizontal: AppTheme.space5),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withValues(alpha: 0.13),
              border: Border.all(color: tint.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: 30, color: tint),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.space1 + 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppTheme.space5),
            action,
          ],
        ],
      ),
    );
  }

  // ─────────────────────────── versions ───────────────────────────

  Widget _versionsCard() {
    final s = _status;
    return GlassCard(
      child: Column(
        children: [
          _row(
            'Current version',
            s == null ? '—' : '${s.currentVersion} (${s.currentBuild})',
          ),
          const Divider(color: AppTheme.border, height: AppTheme.space5),
          _row(
            'Latest version',
            s?.release == null
                ? '—'
                : '${s!.release!.version} (${s.release!.build})',
            highlight: s?.updateAvailable == true,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontFamily: 'Outfit', fontSize: 13.5, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: highlight ? AppTheme.primaryLight : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── release detail ───────────────────────────

  Widget _releaseCard(AppRelease r) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
              title: "What's new", icon: Icons.auto_awesome_rounded),
          const SizedBox(height: AppTheme.space3),
          Wrap(
            spacing: AppTheme.space2,
            runSpacing: AppTheme.space2,
            children: [
              _meta(Icons.sd_storage_outlined, r.readableSize),
              if (r.releasedAt != null)
                _meta(Icons.event_outlined,
                    DateFormat('d MMM yyyy').format(r.releasedAt!)),
              _meta(
                r.mandatory ? Icons.priority_high_rounded : Icons.info_outline,
                r.mandatory ? 'Required' : 'Optional',
              ),
            ],
          ),
          if (r.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space4),
            Text(
              r.releaseNotes,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                height: 1.6,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String label) {
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

  Widget _adminNote() {
    return GlassCard(
      tint: AppTheme.accent.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_outlined,
              size: 18, color: AppTheme.accentLight),
          const SizedBox(width: AppTheme.space3),
          const Expanded(
            child: Text(
              'To release an update: distribute the new build, then use '
              '“Publish this build as latest” on your Profile. Everyone else is '
              'prompted the next time they open the app.',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

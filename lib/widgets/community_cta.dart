import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';

/// Where an article ends.
///
/// Somebody who has just read eight hundred words to the end is the most
/// willing they will ever be to follow you somewhere else — and a link at the
/// bottom of the reading, not a banner at the top of it, is the version that
/// does not interrupt anyone.
class CommunityCta extends StatelessWidget {
  const CommunityCta({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw 'could not open';
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $url',
                style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Liked this? Stay with us.',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'New articles, daily thoughts and updates — no spam, leave anytime.',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              height: 1.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          _ChannelButton(
            asset: 'assets/art/whatsapp.svg',
            label: 'Join the WhatsApp community',
            sublabel: 'For updates',
            colors: const [Color(0xFF25D366), Color(0xFF128C7E)],
            onTap: () => _open(context, AppConstants.communityWhatsAppUrl),
          ),
          const SizedBox(height: AppTheme.space3),
          _ChannelButton(
            asset: 'assets/art/instagram.svg',
            label: 'Follow on Instagram',
            sublabel: AppConstants.instagramHandle,
            colors: const [
              Color(0xFFF97316),
              Color(0xFFDB2777),
              Color(0xFF7C3AED),
            ],
            onTap: () => _open(context, AppConstants.instagramUrl),
          ),
        ],
      ),
    );
  }
}

class _ChannelButton extends StatelessWidget {
  final String asset;
  final String label;
  final String sublabel;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ChannelButton({
    required this.asset,
    required this.label,
    required this.sublabel,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space4, vertical: AppTheme.space3),
          child: Row(
            children: [
              SvgPicture.asset(
                asset,
                width: 22,
                height: 22,
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      sublabel,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_outward_rounded,
                  size: 17, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

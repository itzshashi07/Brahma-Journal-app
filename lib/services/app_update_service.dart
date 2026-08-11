import 'api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_release.dart';

/// Tells the user when a newer build exists, and sends them to the Play Store
/// to get it.
///
/// **This used to download an APK and install it.** That is not allowed on
/// Google Play, and not as a matter of taste — the Device and Network Abuse
/// policy states that an app distributed through Play may not update itself by
/// any mechanism other than Play's own. The old flow was genuinely nicer while
/// the app shipped by direct link (one tap, a progress bar, no hunting in the
/// Downloads folder), and it is exactly why the store forbids it: an app that
/// can replace its own binary can ship anything after review.
///
/// So the download, the file writing, the APK sniffing, the install permission
/// and the whole native installer channel are gone, along with
/// REQUEST_INSTALL_PACKAGES and the FileProvider. What remains is the part that
/// was always useful — noticing that this build is behind — and one button that
/// opens the store listing.
class AppUpdateService {
  /// Play listing for this app. `market://` opens the Play app directly; the
  /// https form is the fallback for a device with no Play app (and the link
  /// that works when the message is shared).
  static const String playPackage = 'com.brahma.brahmaApp';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$playPackage';

  /// Kept under the old name so callers and the admin publish screen do not
  /// have to change: it is simply the store listing now.
  static const String defaultDownloadLink = playStoreUrl;

  static PackageInfo? _info;
  static Future<PackageInfo> _packageInfo() async =>
      _info ??= await PackageInfo.fromPlatform();

  static Future<String> currentVersion() async => (await _packageInfo()).version;

  static Future<int> currentBuild() async =>
      int.tryParse((await _packageInfo()).buildNumber) ?? 0;

  // ─────────────────────────── checking ───────────────────────────

  /// Reads the published release and compares it with the running build.
  ///
  /// Never throws — a failed check must not stop the app from opening, and on
  /// the settings screen it becomes a readable error rather than a crash.
  static Future<UpdateStatus> check() async {
    final version = await currentVersion();
    final build = await currentBuild();

    try {
      // Served by the Node.js API from MongoDB. The endpoint 404s when no
      // release has been published, which ApiService raises as an
      // ApiException — caught below and reported as "no update", which is the
      // truthful answer rather than an error.
      final body = await ApiService().get('/api/support/config/version');
      final data = body?['value'];

      if (data is! Map) {
        return UpdateStatus(currentVersion: version, currentBuild: build);
      }

      final release =
          AppRelease.fromMap(Map<String, dynamic>.from(data), defaultDownloadLink);
      return UpdateStatus(
        currentVersion: version,
        currentBuild: build,
        release: release,
        // Build number, not the version string: "1.10.0" sorts before "1.9.0"
        // lexically, and an integer cannot be got wrong.
        updateAvailable: release.build > build,
      );
    } catch (e) {
      debugPrint('ℹ️ Update check failed: $e');
      return UpdateStatus(
        currentVersion: version,
        currentBuild: build,
        error: 'Could not reach the update server.',
      );
    }
  }

  /// Convenience for the launch-time check: returns the release only when one
  /// is actually available.
  static Future<AppRelease?> checkForUpdate() async {
    final status = await check();
    return status.updateAvailable ? status.release : null;
  }

  // ─────────────────────────── getting it ───────────────────────────

  /// Opens this app's Play Store listing, where the update actually happens.
  ///
  /// Tries the `market://` scheme first so the Play app opens directly rather
  /// than bouncing through a browser. A device without Play — or a release
  /// document pointing somewhere else entirely — falls back to a normal URL.
  static Future<void> openStoreListing([AppRelease? release]) async {
    final published = release?.downloadUrl.trim() ?? '';
    // A release document may carry its own link (a different store, a web
    // build). Only override when it is genuinely something else.
    final target = published.isNotEmpty && published != playStoreUrl
        ? published
        : playStoreUrl;

    if (target == playStoreUrl) {
      try {
        final market = Uri.parse('market://details?id=$playPackage');
        if (await launchUrl(market, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {
        // No Play app installed. The https link below handles it.
      }
    }

    try {
      await launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ Could not open the store listing: $e');
    }
  }

  // ─────────────────────────── publishing ───────────────────────────

  /// Publishes the running build as the latest available. Admin only.
  static Future<void> publishCurrentBuild({
    required String releaseNotes,
    bool forceUpdate = false,
    String? downloadUrl,
    int? fileSizeBytes,
  }) async {
    final info = await _packageInfo();
    final now = DateTime.now().toUtc().toIso8601String();

    // Admin-gated on the server. `force_update` puts a blocking banner on every
    // device, so it is not a value the API takes from just any caller.
    await ApiService().put('/api/support/config/version', {
      'value': {
        'latest_version': info.version,
        'latest_build': int.tryParse(info.buildNumber) ?? 0,
        'release_notes': releaseNotes,
        'force_update': forceUpdate,
        'download_url': downloadUrl?.trim().isNotEmpty == true
            ? downloadUrl!.trim()
            : defaultDownloadLink,
        if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
        'released_at': now,
        'updated_at': now,
      },
    });
  }

  static Future<void> shareApp() async {
    await Share.share(
      '🧘 *InnenFlow* — A quieter place to think\n\n'
      'Five minutes a day of journaling, meditation and reflection — with a '
      'record that shows you it is working.\n\n'
      '🎁 Free for everyone right now — no payment, no card.\n\n'
      '📥 Download: $playStoreUrl\n\n'
      '#InnenFlow #Meditation #Mindfulness',
    );
  }
}

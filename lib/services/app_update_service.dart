import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_release.dart';

/// Update checking, downloading and installing.
///
/// **What "in-app update" can and cannot mean on Android.** No app outside the
/// Play Store can install an update silently — the user always confirms in the
/// system installer. What this removes is everything *around* that: no browser,
/// no hunting in Downloads, no wondering whether the file is the right one. One
/// tap, a progress bar, then the system dialog.
///
/// Where the published URL is not a direct `.apk` — an App Distribution or Play
/// link is a web page behind a login — downloading it would fetch HTML, so
/// those open externally instead. [AppRelease.isDirectApk] decides.
class AppUpdateService {
  static const String defaultDownloadLink =
      'https://appdistribution.firebase.google.com/testerapps/1:440787316408:android:38e64b73850e55b977ce4d';

  static const MethodChannel _installer =
      MethodChannel('com.brahma.brahmaApp/installer');

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
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();

      if (!doc.exists) {
        return UpdateStatus(currentVersion: version, currentBuild: build);
      }

      final release = AppRelease.fromMap(doc.data()!, defaultDownloadLink);
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

  // ─────────────────────── install permission ───────────────────────

  /// Whether the user has allowed this app to install packages.
  static Future<bool> canInstallPackages() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _installer.invokeMethod<bool>('canInstall') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system screen where that permission is granted.
  static Future<void> openInstallSettings() async {
    try {
      await _installer.invokeMethod('openInstallSettings');
    } catch (_) {}
  }

  // ─────────────────────────── downloading ───────────────────────────

  /// Downloads [release] and hands it to Android's installer.
  ///
  /// [onProgress] receives 0.0–1.0, or null while the total size is unknown
  /// (a server that omits Content-Length), so the UI can show an indeterminate
  /// bar rather than a fake one.
  ///
  /// Returns null on success, or a message describing what went wrong.
  static Future<String?> downloadAndInstall(
    AppRelease release, {
    void Function(double? progress, int received, int? total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!Platform.isAndroid) {
      await openDownloadPage(release);
      return null;
    }

    if (!await canInstallPackages()) {
      return 'needs-permission';
    }

    http.StreamedResponse response;
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(release.downloadUrl));
      response = await client.send(request);
    } catch (e) {
      client.close();
      return 'Could not start the download. Check your connection.';
    }

    if (response.statusCode != 200) {
      client.close();
      return 'The update could not be downloaded (${response.statusCode}).';
    }

    try {
      // Cache, not Downloads: this is a temporary artefact, and the FileProvider
      // is only configured to share out of the cache directory.
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      if (!await dir.exists()) await dir.create(recursive: true);

      final file = File('${dir.path}/brahma-${release.build}.apk');
      if (await file.exists()) await file.delete();

      final sink = file.openWrite();
      final total = response.contentLength ?? release.fileSizeBytes;
      var received = 0;

      await for (final chunk in response.stream) {
        if (cancelToken?.isCancelled == true) {
          await sink.close();
          await file.delete().catchError((_) => file);
          return null;
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(
          total != null && total > 0 ? (received / total).clamp(0.0, 1.0) : null,
          received,
          total,
        );
      }
      await sink.flush();
      await sink.close();

      // An App Distribution page returns HTML with a 200; installing that fails
      // with an opaque system error, so check the file really is an APK (a zip,
      // so it starts "PK").
      final head = await file.openRead(0, 2).first;
      if (head.length < 2 || head[0] != 0x50 || head[1] != 0x4B) {
        await file.delete().catchError((_) => file);
        return 'That link does not point to an installable file.';
      }

      await _installer.invokeMethod('installApk', {'path': file.path});
      return null;
    } catch (e) {
      debugPrint('❌ Update install failed: $e');
      return 'The update could not be installed.';
    } finally {
      client.close();
    }
  }

  /// Opens the release page in the browser — used when the link is not a
  /// direct APK, and as the fallback everywhere else.
  static Future<void> openDownloadPage(AppRelease release) async {
    try {
      await launchUrl(Uri.parse(release.downloadUrl),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ Could not open the download link: $e');
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
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc('version')
        .set({
      'latest_version': info.version,
      'latest_build': int.tryParse(info.buildNumber) ?? 0,
      'release_notes': releaseNotes,
      'force_update': forceUpdate,
      'download_url': downloadUrl?.trim().isNotEmpty == true
          ? downloadUrl!.trim()
          : defaultDownloadLink,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      'released_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> shareApp() async {
    await Share.share(
      '🧘 *Brahma Journal* — Your Spiritual Wellness Companion\n\n'
      'Five minutes a day of journaling, meditation and reflection — with a '
      'record that shows you it is working.\n\n'
      '🎁 Free for everyone right now — no payment, no card.\n\n'
      '📥 Download: $defaultDownloadLink\n\n'
      '#BrahmaJournal #Meditation #OmShanti',
    );
  }
}

/// Lets the UI abandon an in-flight download when the sheet is dismissed.
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

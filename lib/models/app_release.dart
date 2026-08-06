import 'package:cloud_firestore/cloud_firestore.dart';

/// A published release, as described by `app_config/version`.
class AppRelease {
  final String version;
  final int build;
  final String releaseNotes;
  final DateTime? releasedAt;
  final int? fileSizeBytes;
  final bool mandatory;
  final String downloadUrl;

  const AppRelease({
    required this.version,
    required this.build,
    required this.releaseNotes,
    required this.downloadUrl,
    this.releasedAt,
    this.fileSizeBytes,
    this.mandatory = false,
  });

  factory AppRelease.fromMap(Map<String, dynamic> data, String fallbackUrl) {
    return AppRelease(
      version: data['latest_version'] as String? ?? '',
      build: (data['latest_build'] as num?)?.toInt() ?? 0,
      releaseNotes: data['release_notes'] as String? ?? '',
      releasedAt: _date(data['released_at'] ?? data['updated_at']),
      fileSizeBytes: (data['file_size_bytes'] as num?)?.toInt(),
      mandatory: data['force_update'] as bool? ?? false,
      downloadUrl: (data['download_url'] as String?)?.trim().isNotEmpty == true
          ? data['download_url'] as String
          : fallbackUrl,
    );
  }

  static DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Whether the URL points at an APK we can fetch and install ourselves.
  ///
  /// An App Distribution or Play link is a web page behind a login, not a file
  /// — downloading it would yield HTML. Those open in the browser instead.
  bool get isDirectApk {
    final u = downloadUrl.toLowerCase().split('?').first;
    return u.endsWith('.apk');
  }

  String get readableSize {
    final b = fileSizeBytes;
    if (b == null || b <= 0) return '—';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Result of a version check.
class UpdateStatus {
  final AppRelease? release;
  final String currentVersion;
  final int currentBuild;
  final bool updateAvailable;
  final String? error;

  const UpdateStatus({
    required this.currentVersion,
    required this.currentBuild,
    this.release,
    this.updateAvailable = false,
    this.error,
  });

  bool get isUpToDate => !updateAvailable && error == null;
}
